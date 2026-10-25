import 'package:dox_orm/dox_orm.dart';
import 'package:dox_orm/src/drivers/sqlite_driver.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:test/test.dart';

import 'connection.dart';

/// `SqlQueryBuilder.close()` closes the default and the named
/// connections. The first test uses the connection of the CI job
/// (Postgres, MySQL or SQLite).
void main() {
  test('close() closes the connection of this job', () async {
    SqlQueryBuilder.initializeWithDatabaseConfig(databaseConfig);
    DBDriver driver = SqlQueryBuilder().dbDriver;
    await driver.query('SELECT 1 AS n');

    await SqlQueryBuilder.close();
    // safe to call twice
    await SqlQueryBuilder.close();

    expect(() => SqlQueryBuilder().dbDriver, throwsStateError);
    await expectLater(driver.query('SELECT 1 AS n'), throwsA(anything));
  });

  test('close() closes every SQLite connection', () async {
    ConnectionConfig memory = ConnectionConfig(
      driver: Driver.sqlite,
      database: ':memory:',
      debug: false,
    );
    SqlQueryBuilder.initializeWithDatabaseConfig(
      DatabaseConfig(
        connection: 'main',
        url: '',
        connections: <String, ConnectionConfig>{
          'main': memory,
          'other': memory,
        },
      ),
    );
    SqliteDriver main = SqlQueryBuilder().dbDriver as SqliteDriver;
    SqliteDriver other = SqlQueryBuilder().getDBDriver('other') as SqliteDriver;
    await main.query('SELECT 1 AS n');
    await other.query('SELECT 1 AS n');
    sqlite.Database mainDb = main.conn as sqlite.Database;
    sqlite.Database otherDb = other.conn as sqlite.Database;

    await SqlQueryBuilder.close();
    await SqlQueryBuilder.close();

    expect(() => mainDb.execute('SELECT 1'), throwsA(anything));
    expect(() => otherDb.execute('SELECT 1'), throwsA(anything));
    expect(main.conn, isNull);
    expect(other.conn, isNull);

    // set it up again and it works
    SqlQueryBuilder.initializeWithDatabaseConfig(databaseConfig);
    expect(await SqlQueryBuilder().dbDriver.query('SELECT 1 AS n'), isNotEmpty);
    await SqlQueryBuilder.close();
  });
}
