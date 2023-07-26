import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/storage/local_storage_driver.dart';
import 'package:mime/mime.dart';

class StreamFile {
  final ContentType contentType;
  final Stream<List<int>> stream;
  const StreamFile(this.contentType, this.stream);
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
    String? fileExtension,
  }) async {
    return _driver.put(folder, bytes, fileExtension: fileExtension);
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
  /// StreamFile file = Storage().download('images/avatar/sample.jpeg');
  /// return file;
  /// ```
  /// or
  /// ```
  /// StreamFile file = Storage().download('images/avatar/sample.jpeg');
  /// return response(file);
  /// ```
  Future<StreamFile> download(String filepath) async {
    List<int>? image = await get(filepath);
    if (image == null) {
      throw Exception('file not found');
    }

    String? primaryType =
        lookupMimeType('', headerBytes: image)?.split('/').first;
    String? subType = lookupMimeType('', headerBytes: image)?.split('/').last;

    if (primaryType == null || subType == null) {
      throw Exception('invalid file');
    }

    ContentType contentType = ContentType(primaryType, subType);
    Stream<List<int>> stream = Stream.fromIterable(<List<int>>[image]);
    return StreamFile(contentType, stream);
  }
}
