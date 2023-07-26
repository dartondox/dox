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

  Storage disk(String disk) {
    _disk = disk;
    return this;
  }

  StorageDriverInterface get _driver {
    return storageDriver[_disk] ??
        storageDriver[Dox().config.fileStorageConfig.defaultDriver] ??
        LocalStorageDriver();
  }

  Future<String> putRequestFile(String folder, RequestFile requestFile) async {
    return _driver.put(folder, await requestFile.bytes);
  }

  Future<String> put(String folder, List<int> bytes) async {
    return _driver.put(folder, bytes);
  }

  Future<List<int>?> get(String filename) async {
    return _driver.get(filename);
  }

  Future<bool> exists(String filename) async {
    return _driver.exists(filename);
  }

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
