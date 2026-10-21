import 'dart:io';
import 'dart:typed_data';

import 'package:dox_core/dox_core.dart';
import 'package:dox_storage/dox_storage.dart';
import 'package:mime/mime.dart';

class StreamFile {
  final ContentType contentType;
  final Stream<List<int>> stream;

  /// size in bytes when known, sent as Content-Length
  final int? length;
  const StreamFile(this.contentType, this.stream, {this.length});
}

class DownloadableFile {
  final ContentType contentType;
  final Stream<List<int>> stream;

  /// size in bytes when known, sent as Content-Length
  final int? length;

  String contentDisposition = '';
  DownloadableFile(
    this.contentType,
    this.stream,
    String filename, {
    this.length,
  }) {
    contentDisposition = 'attachment; filename="$filename"';
  }
}

/// Storage facade on top of `dox_storage`.
///
/// Disks come from `AppConfig.storage`. Files are read as streams, so a
/// big file is never loaded into memory to send it.
/// ```
/// String path = await Storage().put('images', bytes, extension: 'png');
/// return Storage().disk('s3').download(path);
/// Disk s3 = Storage().use('s3'); // full dox_storage API
/// ```
class Storage {
  /// [manager] is the `dox_storage` DriveManager. Default is `Dox().storage`.
  Storage({this._manager});

  final DriveManager? _manager;
  String? _disk;

  /// set the disk name
  /// ```
  /// Storage().disk('local').get('image.jpg');
  /// ```
  Storage disk(String disk) {
    _disk = disk;
    return this;
  }

  /// The `dox_storage` disk, for the full API (copy, move, list, ...).
  Disk use([String? name]) {
    return (_manager ?? Dox().storage).use(name ?? _disk);
  }

  /// store the request file into storage, with a new uuid file name.
  /// a temp file on the local disk is moved, not read into memory.
  /// ```
  /// RequestFile file = req.input('avatar');
  /// String path = await Storage().putRequestFile('images/avatar', file);
  /// ```
  Future<String> putRequestFile(String folder, RequestFile requestFile) async {
    String? extension = requestFile.extension.isEmpty
        ? await _sniff(requestFile.stream())
        : requestFile.extension;
    String key = _newKey(folder, extension);
    Disk target = use();
    DriverContract driver = target.driver;
    if (driver is LocalDriver) {
      await requestFile.moveTo(driver.pathFor(target.normalizer.key(key)));
    } else {
      await target.putStream(key, requestFile.stream());
    }
    return '/$key';
  }

  /// store bytes with a new uuid file name and return its path.
  /// the extension is guessed from the bytes when not given.
  /// ```
  /// String path = await Storage().put('images', bytes, extension: 'png');
  /// ```
  Future<String> put(
    String folder,
    List<int> bytes, {
    String? extension,
  }) async {
    extension ??= lookupMimeType('', headerBytes: bytes)?.split('/').last;
    String key = _newKey(folder, extension);
    await use().put(key, bytes);
    return '/$key';
  }

  /// get stored file as bytes, or null when it does not exist.
  /// prefer [stream] or [download] to send a file.
  Future<Uint8List?> get(String filename) async {
    try {
      return await use().get(_key(filename));
    } on FileNotFoundException {
      return null;
    }
  }

  /// check the file exists in storage
  Future<bool> exists(String filename) {
    return use().exists(_key(filename));
  }

  /// delete file from storage. a missing file is not an error.
  Future<void> delete(String filename) {
    return use().delete(_key(filename));
  }

  /// public URL of a file (needs `url` in the disk config)
  Future<String> url(String filename) {
    return use().getUrl(_key(filename));
  }

  /// a URL that works for [expiresIn]. For the local disk, serve it with
  /// `Route.files('files')` and set the disk `url` to that path.
  Future<String> signedUrl(
    String filename, {
    Duration expiresIn = const Duration(minutes: 30),
  }) {
    return use().getSignedUrl(
      _key(filename),
      options: SignedUrlOptions(expiresIn: expiresIn),
    );
  }

  /// return the file as a stream, from any disk.
  /// ```
  /// return await Storage().stream('images/avatar/sample.jpeg');
  /// ```
  Future<StreamFile> stream(String filename) async {
    String key = _key(filename);
    Disk target = use();
    try {
      ObjectMetaData meta = await target.getMetaData(key);
      return StreamFile(
        ContentType.parse(meta.contentType),
        await target.getStream(key),
        length: meta.size,
      );
    } on FileNotFoundException {
      throw NotFoundHttpException(message: 'file not found');
    }
  }

  /// return the file as a download (Content-Disposition: attachment).
  /// ```
  /// return await Storage().download('images/avatar/sample.jpeg');
  /// ```
  Future<DownloadableFile> download(String filename) async {
    StreamFile file = await stream(filename);
    return DownloadableFile(
      file.contentType,
      file.stream,
      filename.split('/').last,
      length: file.length,
    );
  }

  /// old paths start with `/`. dox_storage keys do not.
  String _key(String filename) {
    int start = 0;
    while (start < filename.length && filename.codeUnitAt(start) == 47) {
      start++;
    }
    return filename.substring(start);
  }

  String _newKey(String folder, String? extension) {
    if (extension == null) throw ArgumentError('invalid file');
    String dir = _key(folder);
    String name = '${uuid.v1()}.$extension';
    return dir.isEmpty ? name : '$dir/$name';
  }

  Future<String?> _sniff(Stream<List<int>> stream) async {
    List<int> head = <int>[];
    await for (List<int> chunk in stream) {
      head.addAll(chunk);
      if (head.length >= defaultMagicNumbersMaxLength) break;
    }
    return lookupMimeType('', headerBytes: head)?.split('/').last;
  }
}
