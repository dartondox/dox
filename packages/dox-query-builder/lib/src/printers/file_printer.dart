import 'dart:convert';
import 'dart:io';

import 'package:dox_query_builder/dox_query_builder.dart';

// coverage:ignore-file
class FileQueryPrinter implements QueryPrinter {
  Function(String)? filter;
  final File file;

  FileQueryPrinter({
    required this.file,
    this.filter,
  });

  @override
  void log(String query, List<String> params) {
    Map<String, dynamic> payload = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'level': 'INFO',
      'message': query,
      'payload': <String, dynamic>{
        'query': query,
        'params': params,
      }
    };

    Directory directory = file.parent;
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    String stringToPrint = jsonEncode(payload);
    if (filter != null) {
      stringToPrint = filter!(stringToPrint);
    }

    RandomAccessFile fileToWrite = file.openSync(mode: FileMode.append);
    fileToWrite.writeStringSync('$stringToPrint\n');
    fileToWrite.closeSync();
  }
}
