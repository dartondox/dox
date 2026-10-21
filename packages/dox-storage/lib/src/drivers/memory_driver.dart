import 'dart:typed_data';

import 'package:mime/mime.dart';

import '../clock.dart';
import '../constants/storage_constants.dart';
import '../driver_contract.dart';
import '../exceptions.dart';
import '../types.dart';
import 'listing.dart';

class _MemoryFile {
  final Uint8List bytes;
  final String contentType;
  final DateTime lastModified;
  Visibility visibility;

  _MemoryFile(this.bytes, this.contentType, this.lastModified, this.visibility);
}

/// Keeps files in a map. Use it as a fake in tests.
class MemoryDriver implements DriverContract {
  /// Base for `getUrl` and signed URLs.
  final String urlBase;

  /// Visibility for files written without one.
  final Visibility visibility;

  final Clock clock;
  final Listing _listing = const Listing();
  final Map<String, _MemoryFile> _files = <String, _MemoryFile>{};

  MemoryDriver({
    this.urlBase = 'memory://',
    this.visibility = Visibility.public,
    this.clock = const Clock(),
  });

  /// All stored keys. Handy for test checks.
  Iterable<String> get keys {
    return _files.keys;
  }

  _MemoryFile _file(String key) {
    _MemoryFile? file = _files[key];
    if (file == null) {
      throw FileNotFoundException(key);
    }
    return file;
  }

  @override
  Future<bool> exists(String key) async {
    return _files.containsKey(key);
  }

  @override
  Future<Uint8List> get(String key) async {
    return Uint8List.fromList(_file(key).bytes);
  }

  @override
  Future<Stream<List<int>>> getStream(String key) async {
    return Stream<List<int>>.value(await get(key));
  }

  @override
  Future<ObjectMetaData> getMetaData(String key) async {
    _MemoryFile file = _file(key);
    return ObjectMetaData(
      size: file.bytes.length,
      contentType: file.contentType,
      lastModified: file.lastModified,
      etag: '${file.bytes.length}-${file.lastModified.millisecondsSinceEpoch}',
    );
  }

  @override
  Future<Visibility> getVisibility(String key) async {
    return _file(key).visibility;
  }

  @override
  Future<void> setVisibility(String key, Visibility visibility) async {
    _file(key).visibility = visibility;
  }

  @override
  Future<String> getUrl(String key) async {
    return '$urlBase$key';
  }

  @override
  Future<String> getSignedUrl(String key, SignedUrlOptions options) async {
    int expires = clock.now().add(options.expiresIn).millisecondsSinceEpoch;
    return '$urlBase$key?expires=$expires&signature=fake';
  }

  @override
  Future<String> getSignedUploadUrl(
    String key,
    SignedUrlOptions options,
  ) async {
    int expires = clock.now().add(options.expiresIn).millisecondsSinceEpoch;
    return '$urlBase$key?upload=1&expires=$expires&signature=fake';
  }

  @override
  Future<void> put(String key, Uint8List contents, WriteOptions options) async {
    _files[key] = _MemoryFile(
      Uint8List.fromList(contents),
      options.contentType ??
          lookupMimeType(key) ??
          StorageConstants.defaultContentType,
      clock.now(),
      options.visibility ?? visibility,
    );
  }

  @override
  Future<void> putStream(
    String key,
    Stream<List<int>> contents,
    WriteOptions options,
  ) async {
    BytesBuilder builder = BytesBuilder(copy: false);
    await for (List<int> chunk in contents) {
      builder.add(chunk);
    }
    await put(key, builder.takeBytes(), options);
  }

  @override
  Future<void> copy(
    String source,
    String destination,
    WriteOptions options,
  ) async {
    _MemoryFile file = _file(source);
    _files[destination] = _MemoryFile(
      Uint8List.fromList(file.bytes),
      options.contentType ?? file.contentType,
      clock.now(),
      options.visibility ?? file.visibility,
    );
  }

  @override
  Future<void> move(
    String source,
    String destination,
    WriteOptions options,
  ) async {
    await copy(source, destination, options);
    if (source != destination) {
      _files.remove(source);
    }
  }

  @override
  Future<void> delete(String key) async {
    _files.remove(key);
  }

  @override
  Future<void> deleteAll(String prefix) async {
    if (prefix.isEmpty) {
      _files.clear();
      return;
    }
    List<String> doomed = <String>[];
    for (String key in _files.keys) {
      if (key.startsWith('$prefix/')) {
        doomed.add(key);
      }
    }
    doomed.forEach(_files.remove);
  }

  @override
  Future<ListResult> listAll(String prefix, ListOptions options) async {
    List<DriveEntry> entries = _listing.fromKeys(
      _files.keys,
      prefix,
      options.recursive,
    );
    return _listing.paginate(entries, options);
  }
}
