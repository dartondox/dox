import 'dart:io';

import 'package:dox/src/utils/utils.dart';

class MigrationFile {
  final String name;

  MigrationFile(this.name, String fileType) {
    String filename = _getFileName(name);
    String type = fileType.isEmpty ? 'sql' : fileType.replaceAll('--', '');

    if (type == 'sql') {
      _createSqlFile(filename);
    }

    print('\x1B[32m$filename migration created successfully.\x1B[0m');
  }

  void _createSqlFile(String filename) {
    Directory migrationDirectory = _getMigrationDirectory();
    File file = File('${migrationDirectory.path}/$filename.sql');
    file.createSync(recursive: true);
    file.writeAsStringSync(_sampleSql);
  }

  String _getFileName(String name) {
    DateTime now = DateTime.now();
    String uuid =
        '${now.year}_${_formatNumber(now.month)}_${_formatNumber(now.day)}_${_formatNumber(now.hour)}${_formatNumber(now.minute)}${_formatNumber(now.second)}${now.microsecond}';
    return pascalToSnake('${uuid}_$name'.replaceAll(RegExp(r'[^\w]'), ''));
  }

  String _formatNumber(int number) {
    return number.toString().padLeft(2, '0');
  }

  /// get migration directory `db/migration`
  Directory _getMigrationDirectory() {
    return Directory('${Directory.current.path}/db/migration');
  }
}

String _sampleSql = '''
-- up
-- Write your up query here. Do not remove `-- up` comment.

-- down
-- Write your down query here. Do not remove `-- down` comment.
''';
