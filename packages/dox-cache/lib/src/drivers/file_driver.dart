import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../cache_clock.dart';
import '../cache_driver.dart';
import '../cache_encrypter.dart';
import '../cache_lock.dart';
import '../constants/cache_constants.dart';

/// Keeps one JSON text file per key.
///
/// Each prefix has its own folder inside [directory], named by a short
/// hash of the prefix. So two stores can share [directory], and `flush`
/// of one store does not touch the other.
///
/// The file name is the sha256 of prefix + key. The file holds
/// `{"value": ..., "expires_at": <ms or null>}`. Writes go to a temp file
/// first and then rename, so a reader never sees half a file.
///
/// With an [encrypter], the whole entry text (value and expiry time) is
/// encrypted before it is written. A file that cannot be decrypted (wrong
/// key, changed text, or a plain file from before) reads as a miss. Lock
/// files are not encrypted. They hold no values.
///
/// [prune] deletes a file that cannot be decrypted, as it is a miss. So
/// after a key change with no previous keys, or in a folder that apps with
/// different keys share, [prune] removes the files of the other key.
///
/// A read never deletes a file. An expired file stays until it is
/// written again, removed, or a prune runs. Set [pruneEvery] to run
/// [prune] by itself in the background once every that many writes.
/// With [pruneEvery] 0 (the default), a light prune runs in the
/// background at most once an hour: it deletes expired files, temp files
/// left by a crash and free lock files. It keeps files it cannot read or
/// decrypt, and files the cache did not make. A process first tries one
/// a minute after its first write. A lock file on disk makes sure only
/// one runs per hour for all processes on the folder.
///
/// [fsync] true (the default) syncs each value file to the disk before
/// the rename. Without it a write is faster, and after a power cut the
/// last writes can be lost or read as a miss. A crash of the app alone
/// loses nothing. Lock files are never synced: a lock does not outlive a
/// power cut anyway.
///
/// `add`, `increment` and `touch` take a file lock on the key, so they
/// are safe across isolates and processes on one machine.
class FileDriver extends CacheDriver {
  FileDriver({
    Directory? directory,
    this.prefix = CacheConstants.defaultPrefix,
    this._clock = const CacheClock(),
    this.pruneEvery = CacheConstants.filePruneEvery,
    this.encrypter,
    this.fsync = true,
  }) : directory = directory ?? Directory(CacheConstants.defaultFilePath);

  /// Base folder of the cache. Stores keep their files in sub folders.
  final Directory directory;

  @override
  final String prefix;

  final CacheClock _clock;

  /// Run [prune] in the background once every this many writes.
  /// 0 (the default) turns it off.
  final int pruneEvery;

  /// Encrypts the entry text. Null means plain JSON.
  final CacheEncrypter? encrypter;

  /// Sync each value file to the disk before the rename. See the class
  /// doc.
  final bool fsync;

  int _writes = 0;
  bool _pruning = false;

  /// Time of the next auto prune in ms. Null until the first write.
  int? _nextAutoPrune;

  /// Folder of this store: a short hash of [prefix] inside [directory].
  late final Directory storeDirectory = Directory(
    '${directory.path}${Platform.pathSeparator}'
    '${_hash(prefix).substring(0, 16)}',
  );

  /// File used for [key].
  File fileFor(String key) {
    return File(_pathFor(prefix + key));
  }

  @override
  Future<dynamic> get(String key) async {
    Map<String, dynamic>? entry = await _read(fileFor(key));
    return entry?[CacheConstants.fileValueField];
  }

  @override
  Future<bool> has(String key) async {
    return await get(key) != null;
  }

  @override
  Future<void> put(String key, Object? value, Duration? ttl) async {
    await _write(key, value, _expiresAt(ttl));
  }

  @override
  Future<bool> add(String key, Object? value, Duration? ttl) async {
    CacheLock lock = await _lockKey(key);
    try {
      if (await _read(fileFor(key)) != null) {
        return false;
      }
      await put(key, value, ttl);
      return true;
    } finally {
      await lock.release();
    }
  }

  @override
  Future<int> increment(String key, int by) async {
    CacheLock lock = await _lockKey(key);
    try {
      Map<String, dynamic>? entry = await _read(fileFor(key));
      Object? current = entry?[CacheConstants.fileValueField] ?? 0;
      if (current is! int) {
        throw StateError('Cache value of "$key" is not an integer');
      }
      int next = current + by;
      await _write(
        key,
        next,
        entry?[CacheConstants.fileExpiresAtField] as int?,
      );
      return next;
    } finally {
      await lock.release();
    }
  }

  @override
  Future<bool> touch(String key, Duration? ttl) async {
    CacheLock lock = await _lockKey(key);
    try {
      Map<String, dynamic>? entry = await _read(fileFor(key));
      if (entry == null) {
        return false;
      }
      await _write(key, entry[CacheConstants.fileValueField], _expiresAt(ttl));
      return true;
    } finally {
      await lock.release();
    }
  }

  /// Rename the file away first. Rename is atomic, so only one caller
  /// gets the value.
  @override
  Future<dynamic> pull(String key) async {
    File moved = _movedFor(fileFor(key));
    try {
      await fileFor(key).rename(moved.path);
    } on FileSystemException {
      return null;
    }
    Map<String, dynamic>? entry = await _read(moved);
    await _delete(moved);
    return entry?[CacheConstants.fileValueField];
  }

  @override
  Future<bool> forget(String key) async {
    bool existed = await _read(fileFor(key)) != null;
    await _delete(fileFor(key));
    return existed;
  }

  /// Delete the value files of this store. Temp files of writes that
  /// run right now, and lock files, are kept.
  @override
  Future<void> flush() async {
    for (File file in await _dataFiles()) {
      await _delete(file);
    }
  }

  /// Delete the expired and broken files of this store. With an encrypter,
  /// a file that cannot be decrypted counts as broken and is deleted.
  /// Returns how many value files were deleted. It also deletes temp
  /// files left by a crash and lock files that are free (expired). Run it
  /// from time to time, eg. in a schedule, to free disk space.
  ///
  /// It takes the same key lock as `add`, `increment` and `touch`, and
  /// reads the file again under it. So it never deletes their new value.
  /// A key that is locked right now is skipped.
  Future<int> prune() {
    return _prune(deleteBroken: true);
  }

  /// [deleteBroken] false keeps files that cannot be read or decrypted,
  /// eg. of an app with another key in the same folder.
  Future<int> _prune({required bool deleteBroken}) async {
    int removed = 0;
    List<File> values = <File>[];
    List<File> others = <File>[];
    if (!await storeDirectory.exists()) return 0;
    await for (FileSystemEntity entity in storeDirectory.list()) {
      if (entity is! File) continue;
      if (_isDataFile(entity)) {
        values.add(entity);
      } else if (_isPrunable(entity)) {
        others.add(entity);
      }
    }
    for (File file in values) {
      if (!await _isGone(file, deleteBroken)) continue;
      CacheLock lock = _keyLock(file, '');
      if (!await lock.get()) continue;
      try {
        // ponytail: `put` takes no lock. A `put` between this read and
        // the delete is lost, which is only a cache miss. A check of the
        // modified time would only make the gap smaller, not close it.
        if (await _isGone(file, deleteBroken)) {
          await _delete(file);
          removed++;
        }
      } finally {
        await lock.release();
      }
    }
    for (File file in others) {
      if (file.path.endsWith(CacheConstants.fileTempSuffix)) {
        await _deleteIfOld(file);
      } else {
        await FileLock(file, _clock, '', null)._removeIfFree();
      }
    }
    return removed;
  }

  /// True when [file] can be deleted: expired, or with [deleteBroken]
  /// also broken.
  Future<bool> _isGone(File file, bool deleteBroken) async {
    Map<String, dynamic>? entry = await _readEntry(file);
    if (entry == null) return deleteBroken;
    return _expired(entry);
  }

  /// A lock kept in a file. Works across isolates and processes that
  /// share the folder.
  @override
  CacheLock lock(String name, Duration? ttl, [String? owner]) {
    File file = File(
      '${_pathFor('$prefix${CacheConstants.lockKeyPart}$name')}'
      '${CacheConstants.fileLockSuffix}',
    );
    return FileLock(file, _clock, name, ttl, owner);
  }

  /// Take the lock of one key, used by read-then-write methods.
  Future<CacheLock> _lockKey(String key) async {
    Duration wait = CacheConstants.fileKeyLockTtl;
    CacheLock lock = _keyLock(fileFor(key), key);
    if (!await lock.block<bool>(wait)) {
      throw LockTimeoutException(key, wait);
    }
    return lock;
  }

  /// The lock of the key kept in [file]
  FileLock _keyLock(File file, String key) {
    return FileLock(
      File('${file.path}${CacheConstants.fileKeyLockSuffix}'),
      _clock,
      key,
      CacheConstants.fileKeyLockTtl,
    );
  }

  /// Value files only. Their names have no dot, unlike temp and lock files.
  Future<List<File>> _dataFiles() async {
    List<File> files = <File>[];
    if (!await storeDirectory.exists()) {
      return files;
    }
    await for (FileSystemEntity entity in storeDirectory.list()) {
      if (entity is File && _isDataFile(entity)) {
        files.add(entity);
      }
    }
    return files;
  }

  /// A value file: the sha256 of the key, with no dot.
  static final RegExp _dataName = RegExp(r'^[0-9a-f]{64}$');

  /// Files that prune may delete: temp files of [_write] and lock files.
  /// Moved files (`.mv`) and files the cache did not make are never
  /// touched.
  static final RegExp _prunableName = RegExp(
    r'^[0-9a-f]{64}(\.[0-9a-f]{32}\.tmp|\.lock|\.klock)$',
  );

  static bool _isDataFile(File file) {
    return _dataName.hasMatch(file.uri.pathSegments.last);
  }

  static bool _isPrunable(File file) {
    return _prunableName.hasMatch(file.uri.pathSegments.last);
  }

  /// The stored entry, or null when missing, expired or broken.
  Future<Map<String, dynamic>?> _read(File file) async {
    Map<String, dynamic>? entry = await _readEntry(file);
    if (entry == null || _expired(entry)) return null;
    return entry;
  }

  bool _expired(Map<String, dynamic> entry) {
    int? expiresAt = entry[CacheConstants.fileExpiresAtField] as int?;
    return expiresAt != null && _clock.nowMs() >= expiresAt;
  }

  /// The stored entry, expired or not. Null when missing or broken.
  Future<Map<String, dynamic>?> _readEntry(File file) async {
    String text;
    try {
      text = await file.readAsString();
    } on FileSystemException {
      return null;
    }
    Map<String, dynamic> entry;
    CacheEncrypter? secret = encrypter;
    if (secret == null) {
      try {
        entry = jsonDecode(text) as Map<String, dynamic>;
      } on FormatException {
        return null;
      } on TypeError {
        // JSON that is not a map
        return null;
      }
    } else {
      // A decrypt error can be any type, so catch them all here.
      try {
        entry = jsonDecode(secret.decrypt(text)) as Map<String, dynamic>;
      } on Object {
        return null;
      }
    }
    return entry;
  }

  Future<void> _write(String key, Object? value, int? expiresAt) async {
    String text = jsonEncode(<String, Object?>{
      CacheConstants.fileValueField: value,
      CacheConstants.fileExpiresAtField: expiresAt,
    });
    text = encrypter?.encrypt(text) ?? text;
    File file = fileFor(key);
    File temp = _tempFor(file);
    try {
      try {
        await temp.writeAsString(text, flush: fsync);
      } on PathNotFoundException {
        /// make the folder only when it is missing, not on every write
        await storeDirectory.create(recursive: true);
        await temp.writeAsString(text, flush: fsync);
      }
      await temp.rename(file.path);
    } catch (_) {
      // eg. a full disk: do not leave the temp file behind
      await _delete(temp);
      rethrow;
    }
    _pruneSometimes();
  }

  /// Start [prune] once every [pruneEvery] writes. With [pruneEvery] 0,
  /// start a light prune at most once per
  /// [CacheConstants.fileAutoPruneInterval]. It is not awaited, and only
  /// one runs at a time.
  void _pruneSometimes() {
    if (_pruning) return;
    if (pruneEvery > 0) {
      if (++_writes < pruneEvery) return;
      _writes = 0;
      _startPrune(prune());
      return;
    }
    int now = _clock.nowMs();
    int? next = _nextAutoPrune;
    if (next != null && now < next) return;
    if (next == null) {
      // the first write only sets the time, so a short run (eg. a
      // command) never starts a prune
      _nextAutoPrune =
          now + CacheConstants.fileAutoPruneFirstDelay.inMilliseconds;
      return;
    }
    _nextAutoPrune = now + CacheConstants.fileAutoPruneInterval.inMilliseconds;
    // the lock on disk decides if it runs: once per interval for all
    // processes, also when they restart often
    _startPrune(_autoPrune());
  }

  void _startPrune(Future<int> run) {
    _pruning = true;
    run.catchError(_ignorePruneError).whenComplete(_prunedDone);
  }

  /// Prune expired files only, once per interval for all isolates and
  /// processes that share the folder. The lock is not released: it ends
  /// with its ttl, so the next run waits a full interval.
  Future<int> _autoPrune() async {
    CacheLock once = lock(
      CacheConstants.fileAutoPruneLock,
      CacheConstants.fileAutoPruneInterval,
    );
    if (!await once.get()) return 0;
    return _prune(deleteBroken: false);
  }

  /// Delete a temp file that a crash left behind.
  static Future<void> _deleteIfOld(File file) async {
    try {
      DateTime changed = await file.lastModified();
      if (DateTime.now().difference(changed) >
          CacheConstants.fileStaleTempAge) {
        await file.delete();
      }
    } on FileSystemException {
      // Already gone.
    }
  }

  /// a failed prune only leaves files for the next one
  int _ignorePruneError(Object error) => 0;

  void _prunedDone() {
    _pruning = false;
  }

  int? _expiresAt(Duration? ttl) {
    return ttl == null ? null : _clock.nowMs() + ttl.inMilliseconds;
  }

  String _pathFor(String name) {
    return '${storeDirectory.path}${Platform.pathSeparator}${_hash(name)}';
  }

  /// A name to move [file] to for a moment. See
  /// [CacheConstants.fileMovedSuffix].
  static File _movedFor(File file) {
    return File(
      '${file.path}.${CacheLock.randomOwner()}${CacheConstants.fileMovedSuffix}',
    );
  }

  static File _tempFor(File file) {
    return File(
      '${file.path}.${CacheLock.randomOwner()}${CacheConstants.fileTempSuffix}',
    );
  }

  static String _hash(String text) {
    return sha256.convert(utf8.encode(text)).toString();
  }

  static Future<void> _delete(File file) async {
    try {
      await file.delete();
    } on FileSystemException {
      // Already gone.
    }
  }
}

/// Lock kept in one file. `File.create(exclusive: true)` makes sure only
/// one owner creates it. The file holds the owner and the expiry time.
class FileLock extends CacheLock {
  FileLock(this.file, this._clock, super.name, super.ttl, [super.owner]);

  /// The lock file.
  final File file;

  final CacheClock _clock;

  @override
  Future<bool> get() async {
    if (await _create()) {
      return true;
    }
    if (await _isFree(await _readData(file), file) && await _takeAway(null)) {
      return await _create();
    }
    return false;
  }

  @override
  Future<bool> release() async {
    Map<String, dynamic>? data = await _readData(file);
    if (data?[CacheConstants.fileOwnerField] != owner) {
      return false;
    }
    return await _takeAway(owner);
  }

  @override
  Future<bool> forceRelease() async {
    try {
      await file.delete();
      return true;
    } on FileSystemException {
      return false;
    }
  }

  /// Delete the lock file when the lock is free. Used by prune. The same
  /// steps as [get] uses to take a free lock.
  Future<bool> _removeIfFree() async {
    return await _isFree(await _readData(file), file) && await _takeAway(null);
  }

  /// Create the lock file. False when it is there already.
  Future<bool> _create() async {
    try {
      await file.create(exclusive: true);
    } on PathNotFoundException {
      await file.parent.create(recursive: true);
      return await _create();
    } on FileSystemException {
      return false;
    }
    int? expiresAt = ttl == null ? null : _clock.nowMs() + ttl!.inMilliseconds;
    await file.writeAsString(
      jsonEncode(<String, Object?>{
        CacheConstants.fileOwnerField: owner,
        CacheConstants.fileExpiresAtField: expiresAt,
      }),
    );
    return true;
  }

  /// Move the lock file away when [ownerToMatch] holds it, or, when
  /// [ownerToMatch] is null, when the lock is free (expired).
  /// The rename is atomic, so only one caller moves the file. When the
  /// moved file does not match, it is put back.
  Future<bool> _takeAway(String? ownerToMatch) async {
    File moved = FileDriver._movedFor(file);
    try {
      await file.rename(moved.path);
    } on FileSystemException {
      return false;
    }
    Map<String, dynamic>? data = await _readData(moved);
    bool match = ownerToMatch == null
        ? await _isFree(data, moved)
        : data?[CacheConstants.fileOwnerField] == ownerToMatch;
    if (match) {
      await moved.delete();
      return true;
    }
    // ponytail: a lock made in the short time the file was away is
    // overwritten here. Use the redis driver when this matters.
    await moved.rename(file.path);
    return false;
  }

  /// True when the lock in [data] is expired. An empty file is a lock
  /// that is being written. It counts as free only when it is old.
  Future<bool> _isFree(Map<String, dynamic>? data, File from) async {
    if (data == null) {
      try {
        DateTime changed = await from.lastModified();
        return DateTime.now().difference(changed) >
            CacheConstants.fileKeyLockTtl;
      } on FileSystemException {
        return false;
      }
    }
    int? expiresAt = data[CacheConstants.fileExpiresAtField] as int?;
    return expiresAt != null && _clock.nowMs() >= expiresAt;
  }

  static Future<Map<String, dynamic>?> _readData(File from) async {
    try {
      return jsonDecode(await from.readAsString()) as Map<String, dynamic>;
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    } on TypeError {
      // JSON that is not a map
      return null;
    }
  }
}

/// Builds a [FileDriver]. Options: path, prefix, prune_every, encrypt,
/// fsync. `encrypt: true` needs an encrypter. `fsync: false` turns off the
/// sync to disk on each write.
class FileDriverFactory implements CacheDriverFactory {
  const FileDriverFactory([this._clock = const CacheClock(), this._encrypter]);

  final CacheClock _clock;
  final CacheEncrypter? _encrypter;

  @override
  CacheDriver create(Map<String, dynamic> options) {
    return FileDriver(
      directory: Directory(
        options[CacheConstants.pathOption] as String? ??
            CacheConstants.defaultFilePath,
      ),
      prefix:
          options[CacheConstants.prefixOption] as String? ??
          CacheConstants.defaultPrefix,
      pruneEvery:
          options[CacheConstants.pruneEveryOption] as int? ??
          CacheConstants.filePruneEvery,
      clock: _clock,
      encrypter: options[CacheConstants.encryptOption] == true
          ? _encrypter
          : null,
      fsync: options[CacheConstants.fsyncOption] as bool? ?? true,
    );
  }
}
