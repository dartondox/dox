import 'dart:io';

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

  Future<List<int>> get bytes => stream.first;

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
    List<int> b = await bytes;
    await file.writeAsBytes(b);
    return file.path.replaceFirst(Directory.current.path, '');
  }

  String _sanitizePath(String path) {
    path = path.replaceAll(RegExp(r'/+'), '/');
    return "/${path.replaceAll(RegExp('^\\/+|\\/+\$'), '')}";
  }
}
