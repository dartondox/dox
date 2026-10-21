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

  /// run the migration, return false when it failed
  Future<bool> run(File file, int batch) async {
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
      return true;
    } catch (error) {
      Logger.warn(queries[type.name]);
      Logger.danger('Error: ${error.toString()}');
      return false;
    }
  }

  Map<String, String> getQueries(File file) {
    return parseMigrationSql(fileGetContents(file));
  }

  Future<void> _runQuery(String? query, File file, int batch) async {
    if (query == null) return;
    if (query.isEmpty) return;
    // mysql can not run many statements in one query, so run one by one.
    List<String> statements =
        splitSqlStatements(query, backslashEscape: conn.isMysql);

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
