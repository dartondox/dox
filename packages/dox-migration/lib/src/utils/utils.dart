import 'dart:io';

import 'package:dox_migration/src/utils/db_connection.dart';
import 'package:dox_migration/src/utils/file_extension.dart';

enum MigrationType { up, down }

/// get content from file
String fileGetContents(File file) {
  return File(file.path).readAsStringSync();
}

/// crete migration table if not exist
Future<void> createMigrationTableIfNotExist(DbConnection conn) async {
  // sqlite needs INTEGER PRIMARY KEY for an auto increment id
  String id = conn.isSqlite
      ? 'INTEGER PRIMARY KEY AUTOINCREMENT'
      : 'SERIAL PRIMARY KEY NOT NULL';
  String query = '''
      CREATE TABLE IF NOT EXISTS dox_db_migration 
      (
        id $id, 
        migration VARCHAR(100) NOT NULL,
        batch INTEGER NOT NULL
      )
    ''';
  await conn.execute(query);
}

/// save migration record to migrations table with batch number
Future<void> saveMigratedRecord(
  DbConnection conn,
  File file,
  int batch,
  MigrationType type,
) async {
  if (type == MigrationType.up) {
    String query = '''
      INSERT INTO dox_db_migration 
      (migration,batch) 
      VALUES 
      (?, ?)
    ''';
    await conn.execute(query, <Object>[file.name, batch]);
    return;
  }

  String query = '''
      DELETE from dox_db_migration 
      WHERE migration = ?
    ''';
  await conn.execute(query, <Object>[file.name]);
  return;
}

// get the next batch number
Future<int> getNextBatchNumber(DbConnection conn) async {
  String query = '''
        SELECT batch FROM dox_db_migration 
        ORDER BY batch desc 
        LIMIT 1 OFFSET 0
      ''';
  List<Map<String, dynamic>> latestBatch = await conn.execute(query);

  int batchNumber = 1;

  if (latestBatch.isNotEmpty) {
    int? latestBatchNumber = latestBatch.first['batch'] ?? 0;
    if (latestBatchNumber != null) {
      String latestBatchNumberString = latestBatchNumber.toString();
      batchNumber = int.parse(latestBatchNumberString) + 1;
    }
  }
  return batchNumber;
}

/// get migration directory `db/migration`
Directory getMigrationDirectory() {
  return Directory('${Directory.current.path}/db/migration');
}

/// get temporary directory `db/migration/tmp`
Directory getTempDirectory() {
  return Directory('${getMigrationDirectory().path}/tmp');
}

/// get list of files from db/migration folder
List<File> getFilesFromDirectory(Directory migrationDirectory) {
  List<File> migrationFiles = migrationDirectory
      .listSync()
      .whereType<File>()
      .where(
        (File entity) =>
            entity.path.endsWith('.dart') || entity.path.endsWith('.sql'),
      )
      .toList();

  /// sort by filename
  migrationFiles.sort((File a, File b) => a.path.compareTo(b.path));
  return migrationFiles;
}

/// split migration sql into `up` and `down` sections.
/// only a line that is just `-- up` or `-- down` starts a section.
Map<String, String> parseMigrationSql(String contents) {
  RegExp marker = RegExp(r'^--\s*(up|down)$', caseSensitive: false);
  Map<String, String> sections = <String, String>{};
  String? key;
  StringBuffer buffer = StringBuffer();

  for (String line in contents.split('\n')) {
    RegExpMatch? match = marker.firstMatch(line.trim());
    if (match == null) {
      if (key != null) buffer.writeln(line);
      continue;
    }
    if (key != null) sections[key] = buffer.toString().trim();
    key = match.group(1)!.toLowerCase();
    buffer.clear();
  }
  if (key != null) sections[key] = buffer.toString().trim();

  return sections;
}

/// split sql into statements on `;` and remove comments.
/// `;` inside quotes, comments and postgres `$$` bodies does not split.
/// [backslashEscape] is for mysql, where `\'` does not end a string.
List<String> splitSqlStatements(String sql, {bool backslashEscape = false}) {
  RegExp dollarTag = RegExp(r'\$([A-Za-z_][A-Za-z_0-9]*)?\$');
  List<String> statements = <String>[];
  StringBuffer current = StringBuffer();
  int i = 0;

  void addStatement() {
    String statement = current.toString().trim();
    if (statement.isNotEmpty) statements.add(statement);
    current.clear();
  }

  while (i < sql.length) {
    String char = sql[i];
    String next = i + 1 < sql.length ? sql[i + 1] : '';

    if (char == '-' && next == '-') {
      // line comment, skip to end of line
      int end = sql.indexOf('\n', i);
      i = end == -1 ? sql.length : end;
    } else if (char == '/' && next == '*') {
      // block comment
      int end = sql.indexOf('*/', i + 2);
      i = end == -1 ? sql.length : end + 2;
      current.write(' ');
    } else if (char == "'" || char == '"' || char == '`') {
      // quoted string or name. `''` works as two strings next to each other.
      int end = i + 1;
      while (end < sql.length && sql[end] != char) {
        if (backslashEscape && sql[end] == r'\') end++;
        end++;
      }
      end = end < sql.length ? end + 1 : sql.length;
      current.write(sql.substring(i, end));
      i = end;
    } else if (char == r'$' && dollarTag.matchAsPrefix(sql, i) != null) {
      // postgres body like `$$ ... $$` or `$tag$ ... $tag$`
      String tag = dollarTag.matchAsPrefix(sql, i)!.group(0)!;
      int end = sql.indexOf(tag, i + tag.length);
      end = end == -1 ? sql.length : end + tag.length;
      current.write(sql.substring(i, end));
      i = end;
    } else if (char == ';') {
      addStatement();
      i++;
    } else {
      current.write(char);
      i++;
    }
  }
  addStatement();

  return statements;
}
