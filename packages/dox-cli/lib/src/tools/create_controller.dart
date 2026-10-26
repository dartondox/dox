import 'dart:io';

import '../utils/utils.dart';

String _getSample(String className, String filename) {
  return '''
import 'package:dox_core/dox_core.dart';

/// Route: Route.get('path', (${className}Controller c) => c.index);
@Inject()
class ${className}Controller {
  Future<dynamic> index(DoxRequest req) async {
    /// write your logic here
  }
}
''';
}

String _getResourceSample(String className, String filename) {
  return '''
import 'package:dox_core/dox_core.dart';

/// Route: Route.resource('path', ${className}Controller);
@Inject()
class ${className}Controller {
  /// GET /resource
  Future<dynamic> index(DoxRequest req) async {}

  /// GET /resource/create
  Future<dynamic> create(DoxRequest req) async {}

  /// POST /resource
  Future<dynamic> store(DoxRequest req) async {}

  /// GET /resource/{id}
  Future<dynamic> show(DoxRequest req, int id) async {}

  /// GET /resource/{id}/edit
  Future<dynamic> edit(DoxRequest req, int id) async {}

  /// PUT|PATCH /resource/{id}
  Future<dynamic> update(DoxRequest req, int id) async {}

  /// DELETE /resource/{id}
  /// delete() gives the number of rows it deleted, so 0 is a 404:
  /// `if (await Post().where('id', id).delete() == 0) throw NotFoundHttpException();`
  Future<dynamic> destroy(DoxRequest req, int id) async {}
}
''';
}

bool createController(String filename, bool resource) {
  filename = pascalToSnake(filename).replaceAll(RegExp(r'_?controller$'), '');
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
  print('Run `dart run build_runner build` to add it to the container.');
  return true;
}
