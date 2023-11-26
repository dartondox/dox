import 'dart:io';

import '../utils/utils.dart';

String _getSample(className, filename) {
  return '''
import 'package:dox_query_builder/dox_query_builder.dart';

part '$filename.model.g.dart';

@DoxModel()
class $className extends ${className}Generator {
  @override
  List<String> get hidden => [];
}
''';
}

bool createModel(filename) {
  filename = pascalToSnake(filename);
  String className = snakeToPascal(filename);
  String path = '${Directory.current.path}/lib/models/$filename/';
  final file = File('$path$filename.model.dart');

  if (file.existsSync()) {
    print('\x1B[32m$className model already exists\x1B[0m');
    return false;
  }

  file.createSync(recursive: true);
  file.writeAsStringSync(_getSample(className, filename), mode: FileMode.write);
  print('\x1B[32m$className model created successfully.\x1B[0m');
  return true;
}
