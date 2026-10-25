import 'package:dox_orm/dox_orm.dart';
import 'package:dox_orm/src/drivers/sqlite_driver.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:test/test.dart';

import 'connection.dart';

void main() async {
  await initQueryBuilder();
  ConnectionConfig config = databaseConfig.getConnectionConfig();

  group('StatementCache |', () {
    test('keeps the newest statements and drops the oldest one', () {
      StatementCache<String> cache = StatementCache<String>(2);
      expect(cache.put('a', 'A'), null);
      expect(cache.put('b', 'B'), null);
      expect(cache.get('a'), 'A');

      /// b is now the oldest use
      expect(cache.put('c', 'C'), 'B');
      expect(cache.keys, <String>['a', 'c']);
      expect(cache.get('b'), null);
      expect(cache.hits, 1);
      expect(cache.misses, 1);
      expect(cache.evictions, 1);
      expect(cache.clear(), <String>['A', 'C']);
      expect(cache.length, 0);
    });
  });

  group('SQLite statement cache |', () {
    late sqlite.Database db;
    late SqliteDriver driver;

    setUp(() {
      db = sqlite.sqlite3.openInMemory();
      driver = SqliteDriver(conn: db, statementCacheSize: 2);
    });

    tearDown(() {
      driver.clearStatementCache();
      db.close();
    });

    test('reuse one statement for the same sql', () async {
      for (int i = 1; i <= 3; i++) {
        List<Map<String, dynamic>> rows = await driver.query(
          'SELECT @a + 1 AS total',
          substitutionValues: <String, dynamic>{'a': i},
        );
        expect(rows.first['total'], i + 1);
      }
      StatementCache<sqlite.PreparedStatement> c = driver.statementCacheOf(db)!;
      expect(c.misses, 1);
      expect(c.hits, 2);
    });

    test('the LRU limit closes old statements', () async {
      for (int i = 0; i < 5; i++) {
        await driver.query('SELECT $i AS n');
      }
      StatementCache<sqlite.PreparedStatement> c = driver.statementCacheOf(db)!;
      expect(c.length, 2);
      expect(c.evictions, 3);
      driver.clearStatementCache();
      expect(c.length, 0);
    });

    test('a changed table gives the new columns', () async {
      await driver.execute('CREATE TABLE t (id int)');
      await driver.execute('INSERT INTO t VALUES (1)');
      expect((await driver.query('SELECT * FROM t')).first.keys, <String>[
        'id',
      ]);
      await driver.execute('ALTER TABLE t ADD COLUMN name text');
      expect((await driver.query('SELECT * FROM t')).first.keys, <String>[
        'id',
        'name',
      ]);

      /// a kept statement does not lock the table
      await driver.execute('DROP TABLE t');
    });
  }, skip: config.driver != Driver.sqlite);
}
