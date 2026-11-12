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
/// written again, removed, or [prune] runs. Set [pruneEvery] to run
/// [prune] by itself in the background once every that many writes.
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

  int _writes = 0;
  bool _pruning = false;

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
    File moved = _tempFor(fileFor(key));
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
  /// Returns how many were deleted. Run it from time to time, eg. in a
  /// schedule, to free disk space.
  ///
  /// It takes the same key lock as `add`, `increment` and `touch`, and
  /// reads the file again under it. So it never deletes their new value.
  /// A key that is locked right now is skipped.
  Future<int> prune() async {
    int removed = 0;
    for (File file in await _dataFiles()) {
      if (await _read(file) != null) continue;
      CacheLock lock = _keyLock(file, '');
      if (!await lock.get()) continue;
      try {
        // ponytail: `put` takes no lock. A `put` between this read and
        // the delete is lost, which is only a cache miss.
        if (await _read(file) == null) {
          await _delete(file);
          removed++;
        }
      } finally {
        await lock.release();
      }
    }
    return removed;
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
      if (entity is File && !entity.uri.pathSegments.last.contains('.')) {
        files.add(entity);
      }
    }
    return files;
  }

  /// The stored entry, or null when missing, expired or broken.
  Future<Map<String, dynamic>?> _read(File file) async {
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
      }
    } else {
      // A decrypt error can be any type, so catch them all here.
      try {
        entry = jsonDecode(secret.decrypt(text)) as Map<String, dynamic>;
      } on Object {
        return null;
      }
    }
    int? expiresAt = entry[CacheConstants.fileExpiresAtField] as int?;
    if (expiresAt != null && _clock.nowMs() >= expiresAt) {
      return null;
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
      await temp.writeAsString(text, flush: true);
    } on PathNotFoundException {
      /// make the folder only when it is missing, not on every write
      await storeDirectory.create(recursive: true);
      await temp.writeAsString(text, flush: true);
    }
    await temp.rename(file.path);
    _pruneSometimes();
  }

  /// Start [prune] once every [pruneEvery] writes. It is not awaited, and
  /// only one runs at a time.
  void _pruneSometimes() {
    if (pruneEvery <= 0 || ++_writes < pruneEvery || _pruning) return;
    _writes = 0;
    _pruning = true;
    prune().catchError(_ignorePruneError).whenComplete(_prunedDone);
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
      flush: true,
    );
    return true;
  }

  /// Move the lock file away when [ownerToMatch] holds it, or, when
  /// [ownerToMatch] is null, when the lock is free (expired).
  /// The rename is atomic, so only one caller moves the file. When the
  /// moved file does not match, it is put back.
  Future<bool> _takeAway(String? ownerToMatch) async {
    File moved = File(
      '${file.path}.${CacheLock.randomOwner()}${CacheConstants.fileTempSuffix}',
    );
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
    }
  }
}

/// Builds a [FileDriver]. Options: path, prefix, prune_every, encrypt.
/// `encrypt: true` needs an encrypter.
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
    );
  }
}
