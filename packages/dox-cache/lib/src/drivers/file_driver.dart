import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../cache_clock.dart';
import '../cache_driver.dart';
import '../cache_lock.dart';
import '../constants/cache_constants.dart';

/// Keeps one JSON text file per key in [directory].
///
/// The file name is the sha256 of prefix + key. The file holds
/// `{"value": ..., "expires_at": <ms or null>}`. Writes go to a temp file
/// first and then rename, so a reader never sees half a file.
/// Expired files are deleted when read.
///
/// `add` and `increment` read and then write. They are not atomic
/// between processes. No locks.
class FileDriver extends CacheDriver {
  FileDriver({
    Directory? directory,
    this.prefix = CacheConstants.defaultPrefix,
    this._clock = const CacheClock(),
  }) : directory = directory ?? Directory(CacheConstants.defaultFilePath);

  /// Folder for the cache files. `flush` deletes everything inside it.
  final Directory directory;

  @override
  final String prefix;

  final CacheClock _clock;

  /// File used for [key].
  File fileFor(String key) {
    String hash = sha256.convert(utf8.encode(prefix + key)).toString();
    return File('${directory.path}${Platform.pathSeparator}$hash');
  }

  @override
  Future<dynamic> get(String key) async {
    Map<String, dynamic>? entry = await _read(key);
    return entry?[CacheConstants.fileValueField];
  }

  @override
  Future<void> put(String key, Object? value, Duration? ttl) async {
    DateTime? expiresAt = ttl == null ? null : _clock.now().add(ttl);
    await _write(key, value, expiresAt?.millisecondsSinceEpoch);
  }

  @override
  Future<bool> add(String key, Object? value, Duration? ttl) async {
    if (await _read(key) != null) {
      return false;
    }
    await put(key, value, ttl);
    return true;
  }

  @override
  Future<int> increment(String key, int by) async {
    Map<String, dynamic>? entry = await _read(key);
    Object? current = entry?[CacheConstants.fileValueField] ?? 0;
    if (current is! int) {
      throw StateError('Cache value of "$key" is not an integer');
    }
    int next = current + by;
    await _write(key, next, entry?[CacheConstants.fileExpiresAtField] as int?);
    return next;
  }

  @override
  Future<bool> forget(String key) async {
    bool existed = await _read(key) != null;
    await _delete(fileFor(key));
    return existed;
  }

  @override
  Future<void> flush() async {
    if (!await directory.exists()) {
      return;
    }
    await for (FileSystemEntity entity in directory.list()) {
      await entity.delete(recursive: true);
    }
  }

  /// The stored entry, or null when missing, expired or broken.
  Future<Map<String, dynamic>?> _read(String key) async {
    File file = fileFor(key);
    String text;
    try {
      text = await file.readAsString();
    } on FileSystemException {
      return null;
    }
    Map<String, dynamic> entry;
    try {
      entry = jsonDecode(text) as Map<String, dynamic>;
    } on FormatException {
      await _delete(file);
      return null;
    }
    int? expiresAt = entry[CacheConstants.fileExpiresAtField] as int?;
    if (expiresAt != null && _clock.now().millisecondsSinceEpoch >= expiresAt) {
      await _delete(file);
      return null;
    }
    return entry;
  }

  Future<void> _write(String key, Object? value, int? expiresAt) async {
    String text = jsonEncode(<String, Object?>{
      CacheConstants.fileValueField: value,
      CacheConstants.fileExpiresAtField: expiresAt,
    });
    File file = fileFor(key);
    File temp = File('${file.path}.${CacheLock.randomOwner()}.tmp');
    try {
      await temp.writeAsString(text, flush: true);
    } on PathNotFoundException {
      /// make the folder only when it is missing, not on every write
      await directory.create(recursive: true);
      await temp.writeAsString(text, flush: true);
    }
    await temp.rename(file.path);
  }

  Future<void> _delete(File file) async {
    try {
      await file.delete();
    } on FileSystemException {
      // Already gone.
    }
  }
}

/// Builds a [FileDriver]. Options: path, prefix.
class FileDriverFactory implements CacheDriverFactory {
  const FileDriverFactory([this._clock = const CacheClock()]);

  final CacheClock _clock;

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
      clock: _clock,
    );
  }
}
