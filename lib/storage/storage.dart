import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/storage/local_storage_driver.dart';
import 'package:mime/mime.dart';

class StreamFile {
  final ContentType contentType;
  final Stream<List<int>> stream;
  const StreamFile(this.contentType, this.stream);
}

class DownloadableFile {
  final ContentType contentType;
  final Stream<List<int>> stream;

  String contentDisposition = '';
  DownloadableFile(this.contentType, this.stream, String filename) {
    contentDisposition = 'attachment; filename="$filename"';
  }
}

class Storage {
  String? _disk;

  Map<String, StorageDriverInterface> storageDriver =
      <String, StorageDriverInterface>{
    'local': LocalStorageDriver(),
    ...Dox().config.fileStorageConfig.drivers,
  };

  /// set the disk name
  /// ```
  /// Storage().disk('local').get('image.jpg');
  /// ```
  Storage disk(String disk) {
    _disk = disk;
    return this;
  }

  StorageDriverInterface get _driver {
    return storageDriver[_disk] ??
        storageDriver[Dox().config.fileStorageConfig.defaultDriver] ??
        LocalStorageDriver();
  }

  /// store the request file into storage
  /// ```
  /// RequestFile file = req.input('avatar');
  /// Storage().putRequestFile('images/avatar', file);
  /// ```
  Future<String> putRequestFile(String folder, RequestFile requestFile) async {
    return _driver.put(folder, await requestFile.bytes);
  }

  /// store file with bytes into storage
  /// ```
  /// RequestFile file = req.input('avatar');
  /// Storage().put(
  ///   'images/avatar',
  ///   await file.bytes,
  ///   fileExtension: file.fileExtension, /// this is optional
  /// );
  /// ```
  Future<String> put(
    String folder,
    List<int> bytes, {
    String? extension,
  }) async {
    return _driver.put(folder, bytes, extension: extension);
  }

  /// get stored file into bytes
  /// ```
  /// Storage().get('images/avatar/sample.jpeg');
  /// ```
  Future<List<int>?> get(String filename) async {
    return _driver.get(filename);
  }

  /// check the file exists in storage
  /// ```
  /// Storage().exists('images/avatar/sample.jpeg');
  /// ```
  Future<bool> exists(String filename) async {
    return _driver.exists(filename);
  }

  /// delete file from storage
  /// ```
  /// Storage().exists('images/avatar/sample.jpeg');
  ///```
  Future<dynamic> delete(String filename) async {
    return _driver.delete(filename);
  }

  /// return the file as downloadable/stream file
  /// ```
  /// StreamFile file = Storage().stream('images/avatar/sample.jpeg');
  /// return file;
  /// ```
  /// or
  /// ```
  /// StreamFile file = Storage().stream('images/avatar/sample.jpeg');
  /// return response(file);
  /// ```
  Future<StreamFile> stream(String filename) async {
    List<int>? image = await get(filename);
    if (image == null) {
      throw NotFoundHttpException(message: 'file not found');
    }

    String? mimeType = lookupMimeType(filename, headerBytes: image);

    if (mimeType == null) {
      throw NotFoundHttpException(message: 'invalid file');
    }

    String primaryType = mimeType.split('/').first;
    String subType = mimeType.split('/').last;

    ContentType contentType = ContentType(primaryType, subType);
    Stream<List<int>> stream =
        Stream<List<int>>.fromIterable(<List<int>>[image]);
    return StreamFile(contentType, stream);
  }

  /// return the file as downloadable/stream file
  /// ```
  /// DownloadableFile file = Storage().download('images/avatar/sample.jpeg');
  /// return file;
  /// ```
  /// or
  /// ```
  /// DownloadableFile file = Storage().download('images/avatar/sample.jpeg');
  /// return response(file);
  /// ```
  Future<DownloadableFile> download(String filename) async {
    StreamFile streamFile = await stream(filename);
    String name = filename.split('/').last;
    return DownloadableFile(streamFile.contentType, streamFile.stream, name);
  }
}
