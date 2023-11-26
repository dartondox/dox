import 'dart:io';

import '../utils/utils.dart';

String _getSample(className, filename) {
  return '''
import 'package:dox_core/dox_core.dart';

class ${className}Controller {
  index(DoxRequest req) async {
    return 'Support String, Map, Model, List and List<Model> to return';
  }
}
''';
}

String _getWsSample(className, filename) {
  return '''
import 'package:dox_core/dox_core.dart';

class ${className}Controller {
  index(SocketEmitter emitter, message) async {
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
  index(DoxRequest req) async {}

  /// GET /resource/create
  create(DoxRequest req) async {}

  /// POST /resource
  store(DoxRequest req) async {}

  /// GET /resource/{id}
  show(DoxRequest req, String id) async {}

  /// GET /resource/{id}/edit
  edit(DoxRequest req, String id) async {}

  /// PUT|PATCH /resource/{id}
  update(DoxRequest req, String id) async {}

  /// DELETE /resource/{id}
  destroy(DoxRequest req, String id) async {}
}
''';
}

bool createController(String filename, bool resource) {
  filename = filename.toLowerCase().replaceAll('controller', '');
  filename = pascalToSnake(filename);
  String className = snakeToPascal(filename);
  String path = '${Directory.current.path}/lib/http/controllers/';
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
  String path = '${Directory.current.path}/lib/ws/controllers/';
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
