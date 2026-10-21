import 'dart:io';

import 'package:dox_migration/src/utils/db_connection.dart';
import 'package:dox_migration/src/utils/file_extension.dart';
import 'package:dox_migration/src/utils/logger.dart';
import 'package:dox_migration/src/utils/utils.dart';

class SqlExtMigration {
  final DbConnection conn;
  final MigrationType type;

  const SqlExtMigration({
    required this.conn,
    required this.type,
  });

  Future<void> run(File file, int batch) async {
    String info = type == MigrationType.up ? 'Migrating' : 'Rolling back';
    Logger.info('$info: ${file.name}');
    Map<String, String> queries = getQueries(file);
    try {
      if (type == MigrationType.up) {
        await _runQuery(queries['up'], file, batch);
      }
      if (type == MigrationType.down) {
        await _runQuery(queries['down'], file, batch);
      }

      String info2 = type == MigrationType.up ? 'Migrated' : 'Finished';
      Logger.info('$info2: ${file.name}');
    } catch (error) {
      Logger.warn(queries[MigrationType.up.name]);
      Logger.danger('Error: ${error.toString()}');
    }
  }

  Map<String, String> getQueries(File file) {
    String contents = fileGetContents(file);
    RegExp regex = RegExp(r'-- (up|down)\n([^--]+)', multiLine: true);
    Iterable<RegExpMatch> matches = regex.allMatches(contents);

    Map<String, String> resultMap = <String, String>{};

    for (RegExpMatch match in matches) {
      String? key = match.group(1);
      String? value = match.group(2);
      if (key != null) {
        resultMap[key.toLowerCase()] =
            (value ?? '').trim().replaceAll('\n', ' ');
      }
    }

    return resultMap;
  }

  Future<void> _runQuery(String? query, File file, int batch) async {
    if (query == null) return;
    if (query.isEmpty) return;
    query = query.replaceAll(RegExp(r'\s+'), ' ').trim();

    // mysql can not run many statements in one query, so run one by one.
    // ponytail: split on `;`, breaks if a string value has `;` in it.
    List<String> statements = query
        .split(';')
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toList();

    // mysql auto commits DDL (create, alter, drop), so rollback on error
    // only undoes data changes there. postgres undoes everything.
    await conn.execute('BEGIN');
    try {
      for (String statement in statements) {
        await conn.execute(statement);
      }
      await saveMigratedRecord(conn, file, batch, type);
      await conn.execute('COMMIT');
    } catch (error) {
      await conn.execute('ROLLBACK');
      rethrow;
    }
  }
}
