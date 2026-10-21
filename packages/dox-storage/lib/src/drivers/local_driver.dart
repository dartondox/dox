import 'dart:io';
import 'dart:typed_data';

import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import '../clock.dart';
import '../constants/storage_constants.dart';
import '../driver_contract.dart';
import '../exceptions.dart';
import '../key_normalizer.dart';
import '../types.dart';
import 'listing.dart';
import 'local_url_signer.dart';

/// Settings for [LocalDriver].
class LocalDriverConfig {
  /// Folder where files are stored. Relative paths use the current folder.
  final String root;

  /// Public URL base, for example `https://app.test/uploads`.
  /// Needed for `getUrl` and `getSignedUrl`.
  final String? urlBase;

  /// Secret for signed URLs (use your APP_KEY). Needed for `getSignedUrl`.
  final String? appKey;

  /// The local disk has no per-file access rules. This value is what
  /// `getVisibility` returns for every file.
  final Visibility visibility;

  const LocalDriverConfig({
    required this.root,
    this.urlBase,
    this.appKey,
    this.visibility = Visibility.public,
  });
}

/// Stores files in a folder on the local disk.
class LocalDriver implements DriverContract {
  final LocalDriverConfig config;
  final Clock clock;
  final KeyEncoder encoder;

  /// Absolute, normalized root folder.
  final String root;

  final LocalUrlSigner? signer;
  final Listing _listing = const Listing();

  LocalDriver(
    this.config, {
    this.clock = const Clock(),
    this.encoder = const KeyEncoder(),
  }) : root = p.normalize(p.absolute(config.root)),
       signer = config.appKey == null
           ? null
           : LocalUrlSigner(config.appKey!, clock: clock);

  /// Check a signed URL in the route that serves files.
  /// [key] is the decoded file key from the path.
  bool verifySignedUrl(String key, Map<String, String> queryParameters) {
    LocalUrlSigner? urlSigner = signer;
    if (urlSigner == null) {
      return false;
    }
    return urlSigner.verify(key, queryParameters);
  }

  /// Absolute path for a key. Blocks paths outside [root] as extra defense.
  String pathFor(String key) {
    String full = p.normalize(p.join(root, key));
    if (full != root && !p.isWithin(root, full)) {
      throw InvalidKeyException(key, 'path is outside the storage root');
    }
    return full;
  }

  /// Run a file system action and map its errors to storage errors.
  Future<T> _io<T>(String key, Future<T> action) async {
    try {
      return await action;
    } on PathNotFoundException catch (error) {
      throw FileNotFoundException(key, cause: error);
    } on PathAccessException catch (error) {
      throw PermissionDeniedException(key, cause: error);
    }
  }

  Future<File> _writableFile(String key) async {
    File file = File(pathFor(key));
    await _io(key, file.parent.create(recursive: true));
    return file;
  }

  @override
  Future<bool> exists(String key) async {
    return File(pathFor(key)).exists();
  }

  @override
  Future<Uint8List> get(String key) async {
    return _io(key, File(pathFor(key)).readAsBytes());
  }

  @override
  Future<Stream<List<int>>> getStream(String key) async {
    File file = File(pathFor(key));
    if (!await file.exists()) {
      throw FileNotFoundException(key);
    }
    return file.openRead();
  }

  @override
  Future<ObjectMetaData> getMetaData(String key) async {
    File file = File(pathFor(key));
    FileStat stat = await _io(key, file.stat());
    if (stat.type != FileSystemEntityType.file) {
      throw FileNotFoundException(key);
    }
    return ObjectMetaData(
      size: stat.size,
      contentType: lookupMimeType(key) ?? StorageConstants.defaultContentType,
      lastModified: stat.modified.toUtc(),
      etag:
          '${stat.size.toRadixString(16)}-'
          '${stat.modified.millisecondsSinceEpoch.toRadixString(16)}',
    );
  }

  @override
  Future<Visibility> getVisibility(String key) async {
    if (!await exists(key)) {
      throw FileNotFoundException(key);
    }
    return config.visibility;
  }

  @override
  Future<void> setVisibility(String key, Visibility visibility) async {
    // ponytail: no per-file ACL on a local disk; protect files with routes.
    if (!await exists(key)) {
      throw FileNotFoundException(key);
    }
  }

  @override
  Future<String> getUrl(String key) async {
    String? base = config.urlBase;
    if (base == null) {
      throw UnsupportedOperationException(key, 'urlBase is not configured');
    }
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return '$base/${encoder.urlPath(key)}';
  }

  @override
  Future<String> getSignedUrl(String key, SignedUrlOptions options) async {
    String? base = config.urlBase;
    LocalUrlSigner? urlSigner = signer;
    if (base == null || urlSigner == null) {
      throw UnsupportedOperationException(
        key,
        'urlBase and appKey are needed for signed URLs',
      );
    }
    return urlSigner.sign(base, key, options.expiresIn);
  }

  @override
  Future<String> getSignedUploadUrl(
    String key,
    SignedUrlOptions options,
  ) async {
    throw UnsupportedOperationException(
      key,
      'LocalDriver does not support signed upload URLs',
    );
  }

  @override
  Future<void> put(String key, Uint8List contents, WriteOptions options) async {
    File file = await _writableFile(key);
    await _io(key, file.writeAsBytes(contents, flush: true));
  }

  @override
  Future<void> putStream(
    String key,
    Stream<List<int>> contents,
    WriteOptions options,
  ) async {
    File file = await _writableFile(key);
    IOSink sink = file.openWrite();
    try {
      await sink.addStream(contents);
    } finally {
      await sink.close();
    }
  }

  @override
  Future<void> copy(
    String source,
    String destination,
    WriteOptions options,
  ) async {
    String from = pathFor(source);
    await _writableFile(destination);
    await _io(source, File(from).copy(pathFor(destination)));
  }

  @override
  Future<void> move(
    String source,
    String destination,
    WriteOptions options,
  ) async {
    String from = pathFor(source);
    await _writableFile(destination);
    await _io(source, File(from).rename(pathFor(destination)));
  }

  @override
  Future<void> delete(String key) async {
    File file = File(pathFor(key));
    if (await file.exists()) {
      await _io(key, file.delete());
    }
  }

  @override
  Future<void> deleteAll(String prefix) async {
    Directory directory = Directory(pathFor(prefix));
    if (!await directory.exists()) {
      return;
    }
    if (prefix.isNotEmpty) {
      await _io(prefix, directory.delete(recursive: true));
      return;
    }
    // Keep the root folder itself, delete what is inside.
    await for (FileSystemEntity entity in directory.list()) {
      await _io(prefix, entity.delete(recursive: true));
    }
  }

  @override
  Future<ListResult> listAll(String prefix, ListOptions options) async {
    Directory directory = Directory(pathFor(prefix));
    List<DriveEntry> entries = <DriveEntry>[];
    if (!await directory.exists()) {
      return ListResult(entries);
    }
    Stream<FileSystemEntity> items = directory.list(
      recursive: options.recursive,
      followLinks: false,
    );
    await for (FileSystemEntity entity in items) {
      String key = p.split(p.relative(entity.path, from: root)).join('/');
      if (entity is File) {
        entries.add(DriveFile(key));
      } else if (entity is Directory && !options.recursive) {
        entries.add(DriveDirectory(key));
      }
    }
    return _listing.paginate(entries, options);
  }
}
