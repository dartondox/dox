import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'driver_contract.dart';
import 'exceptions.dart';
import 'key_normalizer.dart';
import 'types.dart';

/// The public API for one storage disk.
///
/// A disk wraps a [DriverContract]. It cleans every key with
/// [KeyNormalizer] and turns unknown driver errors into [StorageException]s.
class Disk {
  final DriverContract driver;
  final KeyNormalizer normalizer;

  const Disk(this.driver, {this.normalizer = const KeyNormalizer()});

  /// Write a file. [contents] can be a `String` (saved as UTF-8),
  /// a `List<int>` or a `Stream<List<int>>`.
  Future<void> put(
    String key,
    Object contents, {
    WriteOptions options = const WriteOptions(),
  }) async {
    if (contents is Stream<List<int>>) {
      return putStream(key, contents, options: options);
    }
    Uint8List bytes;
    if (contents is String) {
      bytes = Uint8List.fromList(utf8.encode(contents));
    } else if (contents is Uint8List) {
      bytes = contents;
    } else if (contents is List<int>) {
      bytes = Uint8List.fromList(contents);
    } else {
      throw ArgumentError.value(
        contents,
        'contents',
        'must be String, List<int> or Stream<List<int>>',
      );
    }
    String k = normalizer.key(key);
    try {
      await driver.put(k, bytes, options);
    } catch (error, stack) {
      _fail(error, stack, k);
    }
  }

  /// Write a file from a stream.
  Future<void> putStream(
    String key,
    Stream<List<int>> contents, {
    WriteOptions options = const WriteOptions(),
  }) async {
    String k = normalizer.key(key);
    try {
      await driver.putStream(k, contents, options);
    } catch (error, stack) {
      _fail(error, stack, k);
    }
  }

  /// Read a file as bytes.
  Future<Uint8List> get(String key) async {
    String k = normalizer.key(key);
    try {
      return await driver.get(k);
    } catch (error, stack) {
      _fail(error, stack, k);
    }
  }

  /// Read a file as a UTF-8 string.
  Future<String> getString(String key) async {
    return utf8.decode(await get(key));
  }

  /// Read a file as a stream.
  Future<Stream<List<int>>> getStream(String key) async {
    String k = normalizer.key(key);
    try {
      return await driver.getStream(k);
    } catch (error, stack) {
      _fail(error, stack, k);
    }
  }

  /// Size, content type, last modified time and etag.
  Future<ObjectMetaData> getMetaData(String key) async {
    String k = normalizer.key(key);
    try {
      return await driver.getMetaData(k);
    } catch (error, stack) {
      _fail(error, stack, k);
    }
  }

  /// True when the file exists.
  Future<bool> exists(String key) async {
    String k = normalizer.key(key);
    try {
      return await driver.exists(k);
    } catch (error, stack) {
      _fail(error, stack, k);
    }
  }

  /// Delete a file. A missing file is not an error.
  Future<void> delete(String key) async {
    String k = normalizer.key(key);
    try {
      await driver.delete(k);
    } catch (error, stack) {
      _fail(error, stack, k);
    }
  }

  /// Delete every file under [prefix]. An empty prefix deletes everything.
  Future<void> deleteAll([String prefix = '']) async {
    String p = normalizer.prefix(prefix);
    try {
      await driver.deleteAll(p);
    } catch (error, stack) {
      _fail(error, stack, p);
    }
  }

  /// Copy a file to a new key.
  Future<void> copy(
    String source,
    String destination, {
    WriteOptions options = const WriteOptions(),
  }) async {
    String from = normalizer.key(source);
    String to = normalizer.key(destination);
    try {
      await driver.copy(from, to, options);
    } catch (error, stack) {
      _fail(error, stack, from);
    }
  }

  /// Move a file to a new key.
  Future<void> move(
    String source,
    String destination, {
    WriteOptions options = const WriteOptions(),
  }) async {
    String from = normalizer.key(source);
    String to = normalizer.key(destination);
    try {
      await driver.move(from, to, options);
    } catch (error, stack) {
      _fail(error, stack, from);
    }
  }

  /// List files and folders under [prefix].
  Future<ListResult> listAll([
    String prefix = '',
    ListOptions options = const ListOptions(),
  ]) async {
    String p = normalizer.prefix(prefix);
    try {
      return await driver.listAll(p, options);
    } catch (error, stack) {
      _fail(error, stack, p);
    }
  }

  /// Public URL of a file.
  Future<String> getUrl(String key) async {
    String k = normalizer.key(key);
    try {
      return await driver.getUrl(k);
    } catch (error, stack) {
      _fail(error, stack, k);
    }
  }

  /// Temporary URL to download a file.
  Future<String> getSignedUrl(
    String key, {
    SignedUrlOptions options = const SignedUrlOptions(),
  }) async {
    String k = normalizer.key(key);
    try {
      return await driver.getSignedUrl(k, options);
    } catch (error, stack) {
      _fail(error, stack, k);
    }
  }

  /// Temporary URL a client can `PUT` a file to directly.
  Future<String> getSignedUploadUrl(
    String key, {
    SignedUrlOptions options = const SignedUrlOptions(),
  }) async {
    String k = normalizer.key(key);
    try {
      return await driver.getSignedUploadUrl(k, options);
    } catch (error, stack) {
      _fail(error, stack, k);
    }
  }

  /// Get the visibility of a file.
  Future<Visibility> getVisibility(String key) async {
    String k = normalizer.key(key);
    try {
      return await driver.getVisibility(k);
    } catch (error, stack) {
      _fail(error, stack, k);
    }
  }

  /// Change the visibility of a file.
  Future<void> setVisibility(String key, Visibility visibility) async {
    String k = normalizer.key(key);
    try {
      await driver.setVisibility(k, visibility);
    } catch (error, stack) {
      _fail(error, stack, k);
    }
  }

  /// Rethrow storage errors as they are. Wrap everything else.
  Never _fail(Object error, StackTrace stack, String key) {
    if (error is StorageException) {
      Error.throwWithStackTrace(error, stack);
    }
    if (error is PathNotFoundException) {
      Error.throwWithStackTrace(
        FileNotFoundException(key, cause: error),
        stack,
      );
    }
    Error.throwWithStackTrace(
      DriverException(key, 'Driver operation failed', cause: error),
      stack,
    );
  }
}
