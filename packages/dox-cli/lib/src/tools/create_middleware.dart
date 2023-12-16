import 'dart:io';

import '../utils/utils.dart';

String _getSample(className, filename) {
  return '''
import 'package:dox_core/dox_core.dart';

class ${className}Middleware extends IDoxMiddleware {
  @override
  dynamic handle(IDoxRequest req) {
    /// add your logic here
    /// return req (IDoxRequest) to process next to the controller
    /// or throw an error or return Map, String, List etc to return 200 response
    return req;
  }
}
''';
}

bool createMiddleware(String filename) {
  filename = filename.toLowerCase().replaceAll('middleware', '');
  filename = pascalToSnake(filename);
  String className = snakeToPascal(filename);
  String path = '${Directory.current.path}/lib/app/http/middleware/';
  String middlewareName = '$filename.middleware';
  final file = File('$path$filename.middleware.dart');

  if (file.existsSync()) {
    print('\x1B[32m$middlewareName already exists\x1B[0m');
    return false;
  }

  file.createSync(recursive: true);
  file.writeAsStringSync(_getSample(className, filename), mode: FileMode.write);
  print('\x1B[32m$middlewareName created successfully.\x1B[0m');
  return true;
}
