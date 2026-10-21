import 'dart:io';

import 'package:dox_migration/src/utils/db_connection.dart';
import 'package:dox_migration/src/utils/utils.dart';

/// a `.sql` migration file with `-- up` and `-- down` sections
class SqlExtMigration {
  final File file;

  const SqlExtMigration(this.file);

  /// run the [type] section, one statement at a time
  /// (mysql can not run many statements in one query)
  Future<void> run(DbConnection conn, MigrationType type) async {
    String? query = parseMigrationSql(fileGetContents(file))[type.name];
    if (query == null || query.isEmpty) return;
    for (String statement in splitSqlStatements(
      query,
      backslashEscape: conn.isMysql,
    )) {
      await conn.execute(statement);
    }
  }
}
