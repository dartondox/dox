import 'package:dox_orm/dox_orm.dart';
import 'package:dox_orm/src/drivers/mysql_driver.dart';
import 'package:dox_orm/src/drivers/sqlite_driver.dart';
import 'package:mysql_dart/mysql_dart.dart' as mysql;
import 'package:postgres/postgres.dart' as pg;
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

  group('Postgres statement cache |', () {
    late pg.Pool<dynamic> pool;
    late PostgresDriver driver;

    setUp(() {
      pool = pg.Pool<dynamic>.withEndpoints(
        <pg.Endpoint>[
          pg.Endpoint(
            host: config.host,
            port: config.port,
            username: config.user,
            password: config.password,
            database: config.database,
          ),
        ],
        settings: const pg.PoolSettings(
          maxConnectionCount: 1,
          sslMode: pg.SslMode.disable,
        ),
      );
      driver = PostgresDriver(conn: pool, statementCacheSize: 2);
    });

    tearDown(() async {
      await pool.close();
    });

    Future<StatementCache<pg.Statement>?> cache() {
      return pool.withConnection((pg.Connection c) async {
        return driver.statementCacheOf(c);
      });
    }

    Future<int> serverStatements() async {
      List<Map<String, dynamic>> rows = await driver.query(
        "SELECT count(*)::int AS n FROM pg_prepared_statements",
      );
      return rows.first['n'] as int;
    }

    test('reuse one statement for the same sql', () async {
      for (int i = 1; i <= 3; i++) {
        List<Map<String, dynamic>> rows = await driver.query(
          'SELECT @a::int + @b::int AS total',
          substitutionValues: <String, dynamic>{'a': i, 'b': 1},
        );
        expect(rows.first['total'], i + 1);
      }
      StatementCache<pg.Statement> c = (await cache())!;
      expect(c.misses, 1);
      expect(c.hits, 2);
      expect(c.length, 1);
    });

    test('the LRU limit closes old statements on the server', () async {
      for (int i = 0; i < 5; i++) {
        await driver.query('SELECT $i AS n');
      }
      StatementCache<pg.Statement> c = (await cache())!;
      expect(c.length, 2);
      expect(c.evictions, 3);

      /// the count query is kept too, so it is one of the 2
      expect(await serverStatements(), 2);
    });

    test('a dropped connection gets new statements', () async {
      List<Map<String, dynamic>> rows = await driver.query(
        'SELECT pg_backend_pid() AS pid',
      );
      int pid = rows.first['pid'] as int;
      pg.Connection? old;
      await pool.withConnection((pg.Connection c) async {
        old = c;
      });
      expect(driver.statementCacheOf(old!)!.length, 1);

      /// kill the connection from another one
      await SqlQueryBuilder().dbDriver.query(
        'SELECT pg_terminate_backend(@pid)',
        substitutionValues: <String, dynamic>{'pid': pid},
      );
      await old!.closed.timeout(const Duration(seconds: 5));
      expect(driver.statementCacheOf(old!), null);

      rows = await driver.query('SELECT pg_backend_pid() AS pid');
      expect(rows.first['pid'], isNot(pid));
      StatementCache<pg.Statement> c = (await cache())!;
      expect(c.misses, 1);
    });

    test('a changed table gives the new columns', () async {
      await driver.execute('DROP TABLE IF EXISTS cache_t');
      await driver.execute('CREATE TABLE cache_t (id int)');
      await driver.execute('INSERT INTO cache_t VALUES (1)');
      expect((await driver.query('SELECT * FROM cache_t')).first.keys, <String>[
        'id',
      ]);
      await driver.execute('ALTER TABLE cache_t ADD COLUMN name text');
      expect((await driver.query('SELECT * FROM cache_t')).first.keys, <String>[
        'id',
        'name',
      ]);
      await driver.execute('DROP TABLE cache_t');
    });

    test('a kept statement runs in a transaction', () async {
      await driver.execute('DROP TABLE IF EXISTS cache_tx');
      await driver.execute('CREATE TABLE cache_tx (id int)');
      String insert = 'INSERT INTO cache_tx VALUES (@id)';
      await driver.execute(
        insert,
        substitutionValues: <String, dynamic>{'id': 1},
      );
      try {
        await driver.transaction(() async {
          await driver.execute(
            insert,
            substitutionValues: <String, dynamic>{'id': 2},
          );
          throw Exception('rollback');
        });
      } catch (_) {}
      List<Map<String, dynamic>> rows = await driver.query(
        'SELECT id FROM cache_tx',
      );
      expect(rows.map((Map<String, dynamic> r) => r['id']), <int>[1]);
      await driver.execute('DROP TABLE cache_tx');
    });

    test('sql the simple parser skips still works', () async {
      List<Map<String, dynamic>> rows = await driver.query(
        "SELECT '@a' AS text, @a::int AS n, @b:int4 AS typed",
        substitutionValues: <String, dynamic>{'a': 5, 'b': 6},
      );
      expect(rows.first, <String, dynamic>{'text': '@a', 'n': 5, 'typed': 6});
    });
  }, skip: config.driver != Driver.postgres);

  group('MySQL statement cache |', () {
    late mysql.MySQLConnectionPool pool;
    late MysqlDriver driver;

    setUp(() {
      pool = mysql.MySQLConnectionPool(
        host: config.host,
        port: config.port,
        userName: config.user,
        password: config.password,
        databaseName: config.database,
        maxConnections: 1,
        secure: false,
        autoPreparedStatementCacheCapacity: 2,
      );
      driver = MysqlDriver(conn: pool);
    });

    tearDown(() async {
      await pool.close();
    });

    Future<mysql.AutoPreparedStatementCacheStats> stats() async {
      return await pool.withConnection((mysql.MySQLConnection c) {
        return c.autoPreparedStatementCacheStats;
      });
    }

    test('reuse one statement for the same sql', () async {
      for (int i = 1; i <= 3; i++) {
        List<Map<String, dynamic>> rows = await driver.query(
          'SELECT @a + 1 AS total',
          substitutionValues: <String, dynamic>{'a': i},
        );
        expect(rows.first['total'], i + 1);
      }
      mysql.AutoPreparedStatementCacheStats s = await stats();
      expect(s.misses, 1);
      expect(s.hits, 2);
    });

    test('the LRU limit', () async {
      for (int i = 0; i < 5; i++) {
        await driver.query(
          'SELECT @a + $i AS n',
          substitutionValues: <String, dynamic>{'a': 1},
        );
      }
      mysql.AutoPreparedStatementCacheStats s = await stats();
      expect(s.cachedStatements, 2);
      expect(s.evictions, 3);
    });

    test('a dropped connection gets new statements', () async {
      Map<String, dynamic> values = <String, dynamic>{'a': 1};
      List<Map<String, dynamic>> rows = await driver.query(
        'SELECT CONNECTION_ID() AS id, @a AS a',
        substitutionValues: values,
      );
      int id = rows.first['id'] as int;
      await SqlQueryBuilder().dbDriver.execute('KILL $id');

      /// the first query may see the dead connection, then the pool opens
      /// a new one
      for (int i = 0; i < 3; i++) {
        try {
          rows = await driver.query(
            'SELECT CONNECTION_ID() AS id, @a AS a',
            substitutionValues: values,
          );
          break;
        } catch (_) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
      expect(rows.first['id'], isNot(id));
      expect((await stats()).misses, 1);
    });
  }, skip: config.driver != Driver.mysql);

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
