import 'dart:io';

import '../utils/utils.dart';

String _getSample(className, filename) {
  return '''
import 'package:dox_core/dox_core.dart';

class ${className}Controller {
  Future<dynamic> index(DoxRequest req) async {
    /// write your logic here
  }
}

${className}Controller ${toPascalWithFirstLetterLowerCase(className)}Controller = ${className}Controller();
''';
}

String _getWsSample(className, filename) {
  return '''
import 'package:dox_websocket/dox_websocket.dart';

class ${className}Controller {
  void index(WebsocketEmitter emitter, dynamic message) async {
    /// write your logic here
  }
}
''';
}

String _getResourceSample(className, filename) {
  return '''
import 'package:dox_core/dox_core.dart';

class ${className}Controller {
  /// GET /resource
  Future<dynamic> index(DoxRequest req) async {}

  /// GET /resource/create
  Future<dynamic> create(DoxRequest req) async {}

  /// POST /resource
  Future<dynamic> store(DoxRequest req) async {}

  /// GET /resource/{id}
  Future<dynamic> show(DoxRequest req, String id) async {}

  /// GET /resource/{id}/edit
  Future<dynamic> edit(DoxRequest req, String id) async {}

  /// PUT|PATCH /resource/{id}
  Future<dynamic> update(DoxRequest req, String id) async {}

  /// DELETE /resource/{id}
  Future<dynamic> destroy(DoxRequest req, String id) async {}
}

${className}Controller ${toPascalWithFirstLetterLowerCase(className)}Controller = ${className}Controller();
''';
}

bool createController(String filename, bool resource) {
  filename = filename.toLowerCase().replaceAll('controller', '');
  filename = pascalToSnake(filename);
  String className = snakeToPascal(filename);
  String path = '${Directory.current.path}/lib/app/http/controllers/';
  String controllerName = '$filename.controller';
  final file = File('$path$filename.controller.dart');

  if (file.existsSync()) {
    print('\x1B[32m$controllerName already exists\x1B[0m');
    return false;
  }

  String sample = resource
      ? _getResourceSample(className, filename)
      : _getSample(className, filename);

  file.createSync(recursive: true);
  file.writeAsStringSync(sample, mode: FileMode.write);
  print('\x1B[32m$controllerName created successfully.\x1B[0m');
  return true;
}

bool createWsController(String filename) {
  filename = filename.toLowerCase().replaceAll('controller', '');
  filename = pascalToSnake(filename);
  String className = snakeToPascal(filename);
  String path = '${Directory.current.path}/lib/app/ws/controllers/';
  String controllerName = '$filename.controller';
  final file = File('$path$filename.controller.dart');

  if (file.existsSync()) {
    print('\x1B[32m$controllerName already exists\x1B[0m');
    return false;
  }

  String sample = _getWsSample(className, filename);

  file.createSync(recursive: true);
  file.writeAsStringSync(sample, mode: FileMode.write);
  print('\x1B[32m$controllerName created successfully.\x1B[0m');
  return true;
}
