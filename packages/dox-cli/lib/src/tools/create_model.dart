import 'dart:io';

import '../utils/utils.dart';

String _getSample(String className, String filename, String? table) {
  String annotation = table == null ? '' : "table: '$table'";
  return '''
import 'package:dox_orm/dox_orm.dart';

part '$filename.model.g.dart';

@DoxModel($annotation)
class $className extends ${className}Generator {
  @override
  List<String> get hidden => <String>[];
}
''';
}

/// [table] sets `@DoxModel(table: ...)`, so the model uses that table
/// (`make:model X -m` makes the plural table, the model default is singular).
bool createModel(String filename, {String? table}) {
  filename = pascalToSnake(filename);
  String className = snakeToPascal(filename);
  String path = '${Directory.current.path}/lib/app/models/$filename/';
  final file = File('$path$filename.model.dart');

  if (file.existsSync()) {
    print('\x1B[32m$className model already exists\x1B[0m');
    return false;
  }

  file.createSync(recursive: true);
  file.writeAsStringSync(
    _getSample(className, filename, table),
    mode: FileMode.write,
  );
  print('\x1B[32m$className model created successfully.\x1B[0m');
  return true;
}
