/// Database helpers for app tests.
/// ```
/// import 'package:dox_orm/testing.dart';
/// ```
library;

import 'package:dox_orm/dox_orm.dart';

/// The table of `dox_migration`, it is kept by [refreshDatabase].
const String migrationTable = 'dox_db_migration';

/// Empty every table of the database, and start the ids at 1 again.
/// Use it in `setUp`, so each test starts with an empty database:
/// ```
/// setUp(refreshDatabase);
/// ```
///
/// Run the migrations once before, in `setUpAll`. The tables stay, only
/// the rows go. The tables in [keep] keep their rows (default: the
/// migrations table). [connection] is a connection name, the default
/// connection when null.
///
/// Foreign keys are not checked while the tables are emptied.
/// Never run it on a database with real data.
Future<void> refreshDatabase({
  List<String> keep = const <String>[migrationTable],
  String? connection,
}) async {
  DBDriver driver = SqlQueryBuilder().getDBDriver(connection);
  switch (driver.getName()) {
    case Driver.sqlite:
      await _refreshSqlite(driver, keep);
    case Driver.postgres:
      await _refreshPostgres(driver, keep);
    case Driver.mysql:
      await _refreshMysql(driver, keep);
  }
}

Future<List<String>> _tables(
  DBDriver driver,
  String sql,
  List<String> keep,
) async {
  List<Map<String, dynamic>> rows = await driver.query(sql);
  return <String>[
    for (Map<String, dynamic> row in rows)
      if (!keep.contains('${row.values.first}')) '${row.values.first}',
  ];
}

Future<void> _refreshSqlite(DBDriver driver, List<String> keep) async {
  List<String> tables = await _tables(
    driver,
    "SELECT name FROM sqlite_schema WHERE type = 'table' "
    "AND name NOT LIKE 'sqlite_%'",
    keep,
  );
  if (tables.isEmpty) return;
  // foreign_keys can only be changed outside a transaction
  List<Map<String, dynamic>> state = await driver.query('PRAGMA foreign_keys');
  bool fkOn = state.first.values.first == 1;
  if (fkOn) await driver.execute('PRAGMA foreign_keys = OFF');
  try {
    await driver.transaction(() async {
      for (String table in tables) {
        await driver.execute('DELETE FROM ${driver.wrap(table)}');
      }
      List<Map<String, dynamic>> sequence = await driver.query(
        "SELECT 1 FROM sqlite_schema WHERE name = 'sqlite_sequence'",
      );
      if (sequence.isNotEmpty) {
        await driver.execute('DELETE FROM sqlite_sequence');
      }
    });
  } finally {
    if (fkOn) await driver.execute('PRAGMA foreign_keys = ON');
  }
}

Future<void> _refreshPostgres(DBDriver driver, List<String> keep) async {
  List<String> tables = await _tables(
    driver,
    'SELECT tablename FROM pg_tables WHERE schemaname = current_schema()',
    keep,
  );
  if (tables.isEmpty) return;
  String names = tables.map(driver.wrap).join(', ');
  await driver.execute('TRUNCATE TABLE $names RESTART IDENTITY CASCADE');
}

Future<void> _refreshMysql(DBDriver driver, List<String> keep) async {
  List<String> tables = await _tables(
    driver,
    'SELECT table_name FROM information_schema.tables '
    "WHERE table_schema = DATABASE() AND table_type = 'BASE TABLE'",
    keep,
  );
  if (tables.isEmpty) return;
  // the transaction keeps every query on one pooled connection, so the
  // FOREIGN_KEY_CHECKS setting is for the TRUNCATE queries
  await driver.transaction(() async {
    await driver.execute('SET FOREIGN_KEY_CHECKS = 0');
    try {
      for (String table in tables) {
        await driver.execute('TRUNCATE TABLE ${driver.wrap(table)}');
      }
    } finally {
      await driver.execute('SET FOREIGN_KEY_CHECKS = 1');
    }
  });
}
