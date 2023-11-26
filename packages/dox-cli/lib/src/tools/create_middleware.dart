import 'dart:io';

import '../utils/utils.dart';

String _getSample(className, filename) {
  return '''
import 'package:dox_core/dox_core.dart';

class ${className}Middleware extends DoxMiddleware {
  @override
  handle(DoxRequest req) {
    /// add your logic here
    return req;
  }
}
''';
}

bool createMiddleware(String filename) {
  filename = filename.toLowerCase().replaceAll('middleware', '');
  filename = pascalToSnake(filename);
  String className = snakeToPascal(filename);
  String path = '${Directory.current.path}/lib/http/middleware/';
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
