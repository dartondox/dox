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

  /// the file on disk for a stored [filename]
  File file(String filename) {
    return File(_sanitizePath('$storagePath/$filename'));
  }

  /// store an uploaded file. a temp file is moved, not copied
  /// into memory, so big uploads stay cheap.
  Future<String> putRequestFile(
    String folder,
    RequestFile requestFile, {
    String? extension,
  }) async {
    if (extension == null) {
      List<int> head = <int>[];
      await for (List<int> chunk in requestFile.stream()) {
        head.addAll(chunk);
        if (head.length >= defaultMagicNumbersMaxLength) break;
      }
      extension = lookupMimeType('', headerBytes: head)?.split('/').last;
    }
    if (extension == null) {
      throw Exception('invalid file');
    }
    String path = _sanitizePath('$storagePath/$folder/${uuid.v1()}.$extension');
    File saved = await requestFile.moveTo(path);
    return saved.path.replaceFirst(storagePath, '');
  }

  @override
  Future<String> put(
    String folder,
    List<int> bytes, {
    String? extension,
  }) async {
    extension =
        extension ?? lookupMimeType('', headerBytes: bytes)?.split('/').last;
    if (extension == null) {
      throw Exception('invalid file');
    }
    String uid = uuid.v1();
    String path = _sanitizePath('$storagePath/$folder/$uid.$extension');
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
