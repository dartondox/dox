import 'dart:io';

import 'package:dox_migration/src/utils/string_extension.dart';
import 'package:dox_migration/src/utils/utils.dart';

class MigrationFile {
  final String name;

  MigrationFile(this.name, String fileType) {
    String filename = _getFileName(name);
    String type = fileType.isEmpty ? 'sql' : fileType.replaceAll('--', '');

    if (type == 'dart') {
      _createDartFile(filename);
    }

    if (type == 'sql') {
      _createSqlFile(filename);
    }

    print('\x1B[32m$filename migration created successfully.\x1B[0m');
  }

  void _createDartFile(String filename) {
    Directory migrationDirectory = getMigrationDirectory();
    File file = File('${migrationDirectory.path}/$filename.dart');
    file.createSync(recursive: true);
    file.writeAsStringSync(_sampleDart);
  }

  void _createSqlFile(String filename) {
    Directory migrationDirectory = getMigrationDirectory();
    File file = File('${migrationDirectory.path}/$filename.sql');
    file.createSync(recursive: true);
    file.writeAsStringSync(_sampleSql);
  }

  String _getFileName(String name) {
    DateTime now = DateTime.now();
    String uuid =
        '${now.year}_${_formatNumber(now.month)}_${_formatNumber(now.day)}_${_formatNumber(now.hour)}${_formatNumber(now.minute)}${_formatNumber(now.second)}${now.microsecond}';
    return '${uuid}_$name'.replaceAll(RegExp(r'[^\w]'), '').toSnake();
  }

  String _formatNumber(int number) {
    return number.toString().padLeft(2, '0');
  }
}

String _sampleDart = '''
import 'package:dox_query_builder/dox_query_builder.dart'; // ignore: file_names

Future<void> up() async {
  await Schema.create('table_name', (Table table) {});
}

Future<void> down() async {
  await Schema.drop('table_name');
}
''';

String _sampleSql = '''
-- up
-- Write your up query here. Do not remove `-- up` comment.

-- down
-- Write your down query here. Do not remove `-- down` comment.
''';
