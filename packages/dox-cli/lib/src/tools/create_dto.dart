import 'dart:io';

import '../utils/utils.dart';

String _getSample(String className, String filename) {
  return '''
import 'package:dox_core/dox_core.dart';

part '$filename.dto.g.dart';

/// Typed, checked input. Run `dox build_runner:build` after a change.
@Dto()
class $className {
  @Length(min: 1, max: 255)
  final String name;

  const $className({required this.name});

  static const DtoSchema<$className> schema = \$${className}Dto;
}
''';
}

/// `dox create:dto CreateBlog` makes
/// `lib/app/http/dtos/create_blog.dto.dart`.
bool createDto(String filename) {
  filename = pascalToSnake(filename).replaceAll(RegExp(r'_?dto$'), '');
  String className = snakeToPascal(filename);
  String path = '${Directory.current.path}/lib/app/http/dtos/';
  String dtoName = '$filename.dto';
  File file = File('$path$filename.dto.dart');

  if (file.existsSync()) {
    print('\x1B[32m$dtoName already exists\x1B[0m');
    return false;
  }

  file.createSync(recursive: true);
  file.writeAsStringSync(_getSample(className, filename), mode: FileMode.write);
  print('\x1B[32m$dtoName created successfully.\x1B[0m');
  print('Run `dox build_runner:build` to make $filename.dto.g.dart.');
  return true;
}
