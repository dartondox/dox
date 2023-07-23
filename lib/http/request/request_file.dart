import 'dart:io';
import 'dart:typed_data';

import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

final Uuid uuid = Uuid();

class RequestFile {
  final String filename;
  final String filetype;
  final MimeMultipart stream;

  /// Get file extension
  /// eg. png, jpeg, pdf
  String get extension =>
      path.extension(filename).toLowerCase().replaceFirst('.', '');

  RequestFile({
    required this.filename,
    required this.filetype,
    required this.stream,
  });

  /// this function will store the file in your project storage folder
  ///
  /// ```
  /// RequestFile image = req.input('image');
  /// String filename = await image.store();
  /// ```
  Future<String> store({String folder = 'storage'}) async {
    String uid = uuid.v1();
    String path =
        _sanitizePath('${Directory.current.path}/$folder/$uid.$extension');
    File file = File(path);

    Directory directory = Directory(file.parent.path);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    Uint8List b = await _convertMimeMultipartToBytes(stream);
    await file.writeAsBytes(b);
    return file.path.replaceFirst(Directory.current.path, '');
  }

  String _sanitizePath(String path) {
    path = path.replaceAll(RegExp(r'/+'), '/');
    return "/${path.replaceAll(RegExp('^\\/+|\\/+\$'), '')}";
  }

  /// convert mimeMultipart To bytes
  Future<Uint8List> _convertMimeMultipartToBytes(
      MimeMultipart multipart) async {
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
