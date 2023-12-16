import 'dart:io';

import '../utils/utils.dart';

String _getSample(className, filename) {
  return '''
import 'package:dox_core/dox_core.dart';

class ${className}Request extends FormRequest {
  @override
  void setUp() {}

  @override
  Map<String, String> rules() {
    return <String, String>{};
  }

  @override
  Map<String, String> messages() {
    return <String, String>{};
  }
}
''';
}

bool createRequest(String filename) {
  filename = filename.toLowerCase().replaceAll('request', '');
  filename = pascalToSnake(filename);
  String className = snakeToPascal(filename);
  String path = '${Directory.current.path}/lib/app/http/requests/';
  String requestName = '$filename.request';
  final file = File('$path$filename.request.dart');

  if (file.existsSync()) {
    print('\x1B[32m$requestName already exists\x1B[0m');
    return false;
  }

  file.createSync(recursive: true);
  file.writeAsStringSync(_getSample(className, filename), mode: FileMode.write);
  print('\x1B[32m$requestName created successfully.\x1B[0m');
  return true;
}
