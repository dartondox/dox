import 'dart:io';

import '../utils/utils.dart';

String _getSample(className, filename) {
  return '''
import 'package:dox_core/dox_core.dart';

import '../../../app/models/$filename/$filename.model.dart';

class ${className}Serializer extends Serializer<$className> {
  ${className}Serializer(super.data);

  @override
  Map<String, dynamic> convert($className m) {
    return <String, dynamic>{};
  }
}
''';
}

bool createSerializer(String filename) {
  filename = filename.toLowerCase().replaceAll('serializer', '');
  filename = pascalToSnake(filename);
  String className = snakeToPascal(filename);
  String path = '${Directory.current.path}/lib/app/http/serializers/';
  String serializerName = '$filename.serializer';
  final file = File('$path$filename.serializer.dart');

  if (file.existsSync()) {
    print('\x1B[32m$serializerName already exists\x1B[0m');
    return false;
  }

  file.createSync(recursive: true);
  file.writeAsStringSync(_getSample(className, filename), mode: FileMode.write);
  print('\x1B[32m$serializerName created successfully.\x1B[0m');
  return true;
}
