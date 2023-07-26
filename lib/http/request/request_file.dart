import 'dart:typed_data';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/extensions/num.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

final Uuid uuid = Uuid();

class RequestFile {
  final String filename;
  final String filetype;
  final MimeMultipart stream;
  Uint8List? _bytes;

  /// Get file extension
  /// eg. png, jpeg, pdf
  String get extension =>
      path.extension(filename).toLowerCase().replaceFirst('.', '');

  RequestFile({
    required this.filename,
    required this.filetype,
    required this.stream,
  });

  /// get file content in bytes
  /// ```
  /// await file.bytes
  /// ```
  Future<Uint8List> get bytes async {
    _bytes ??= await _convertMultipartToBytes(stream);
    return _bytes!;
  }

  /// get file size in kilobytes
  /// ```
  /// await file.size
  /// ```
  Future<num> get size async {
    return _bytesToKB(await bytes);
  }

  /// get file extension
  /// ```
  /// await file.fileExtension
  /// ```
  String? get fileExtension {
    return filetype.split('/').last;
  }

  /// this function will store the file in your project storage folder
  ///
  /// ```
  /// RequestFile image = req.input('image');
  /// String filename = await image.store();
  /// ```
  Future<String> store(String folder) async {
    return Storage().put(folder, await bytes, fileExtension: fileExtension);
  }

  /// convert bytes list into kilobytes
  num _bytesToKB(Uint8List bytesList) {
    int totalBytes =
        bytesList.reduce((int value, int element) => value + element);
    num sizeInKB = totalBytes / 1024;
    return sizeInKB.toFixed(2);
  }

  /// convert mimeMultipart To bytes
  Future<Uint8List> _convertMultipartToBytes(MimeMultipart multipart) async {
    List<int> partBytesList = <int>[];

    await for (List<int> part in multipart) {
      List<int> partBytes = part.toList();
      partBytesList.addAll(partBytes);
    }

    // Combine all the bytes from individual parts into a single Uint8List
    Uint8List uint8list = Uint8List.fromList(
      partBytesList.map((int byte) => byte).toList(),
    );

    return uint8list;
  }
}
