import 'dart:io';
import 'dart:typed_data';

import 'package:dox_core/dox_core.dart';
import 'package:mime/mime.dart';

class LocalStorageDriver implements StorageDriverInterface {
  String storagePath = '${Directory.current.path}/storage';

  @override
  Future<bool> exists(String filename) {
    File file = File(_sanitizePath('$storagePath/$filename'));
    return file.exists();
  }

  @override
  Future<Uint8List?> get(String filename) async {
    File file = File(_sanitizePath('$storagePath/$filename'));
    if (file.existsSync()) {
      return await file.readAsBytes();
    }
    return null;
  }

  @override
  Future<dynamic> delete(String filename) async {
    File file = File(_sanitizePath('$storagePath/$filename'));
    if (file.existsSync()) {
      return await file.delete();
    }
  }

  @override
  Future<String> put(String folder, List<int> bytes) async {
    String? ext = lookupMimeType('', headerBytes: bytes)?.split('/').last;
    if (ext == null) {
      throw Exception('invalid file');
    }
    String uid = uuid.v1();
    String path = _sanitizePath('$storagePath/$folder/$uid.$ext');
    File file = File(path);

    Directory directory = Directory(file.parent.path);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    await file.writeAsBytes(bytes);
    return file.path.replaceFirst(storagePath, '');
  }

  /// sanitize the path to store
  String _sanitizePath(String path) {
    path = path.replaceAll(RegExp(r'/+'), '/');
    return "/${path.replaceAll(RegExp('^\\/+|\\/+\$'), '')}";
  }
}
