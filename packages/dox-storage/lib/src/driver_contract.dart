import 'dart:typed_data';

import 'types.dart';

/// The interface every storage driver implements.
///
/// Keys and prefixes reach the driver already normalized by [Disk], so a
/// driver does not need to check for `..` itself (but may, as extra defense).
///
/// Throw [FileNotFoundException] when a file is missing and
/// [PermissionDeniedException] when access is refused. Any other error is
/// wrapped in [DriverException] by [Disk].
abstract class DriverContract {
  Future<bool> exists(String key);

  Future<Uint8List> get(String key);

  Future<Stream<List<int>>> getStream(String key);

  Future<ObjectMetaData> getMetaData(String key);

  Future<Visibility> getVisibility(String key);

  Future<void> setVisibility(String key, Visibility visibility);

  Future<String> getUrl(String key);

  Future<String> getSignedUrl(String key, SignedUrlOptions options);

  /// Throw [UnsupportedOperationException] if the driver cannot do it.
  Future<String> getSignedUploadUrl(String key, SignedUrlOptions options);

  Future<void> put(String key, Uint8List contents, WriteOptions options);

  Future<void> putStream(
    String key,
    Stream<List<int>> contents,
    WriteOptions options,
  );

  Future<void> copy(String source, String destination, WriteOptions options);

  Future<void> move(String source, String destination, WriteOptions options);

  /// Deleting a missing file is not an error.
  Future<void> delete(String key);

  /// Delete every file under [prefix]. An empty prefix means everything.
  Future<void> deleteAll(String prefix);

  Future<ListResult> listAll(String prefix, ListOptions options);
}
