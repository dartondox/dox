import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dox_orm/dox_orm.dart';
import 'package:dox_postgres_native/dox_postgres_native.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

// Postgres like in CI. DB_PORT=5472 dart test, for another port.
String host = Platform.environment['DB_HOST'] ?? 'localhost';
int port = int.parse(Platform.environment['DB_PORT'] ?? '5432');

PgNativePool openNative() => PgNativePool.open(
  host: host,
  port: port,
  user: 'postgres',
  password: 'postgres',
  database: 'postgres',
);

typedef Rows = List<Map<String, dynamic>>;

void main() {
  late PgNativePool native;
  late Pool<dynamic> dart;

  setUpAll(() async {
    native = openNative();
    dart = Pool<dynamic>.withEndpoints(<Endpoint>[
      Endpoint(
        host: host,
        port: port,
        username: 'postgres',
        password: 'postgres',
        database: 'postgres',
      ),
    ], settings: PoolSettings(sslMode: SslMode.disable));
    await native.query('DROP TABLE IF EXISTS pgn_types');
    await native.query('''
      CREATE TABLE pgn_types (
        id serial PRIMARY KEY,
        i2 int2, i4 int4, i8 int8, f4 float4, f8 float8, num numeric(20, 6),
        t text, vc varchar(20), bp char(3), b bool,
        ts timestamp, tz timestamptz, d date,
        j json, jb jsonb, u uuid, by bytea,
        ai int4[], at text[], ab bool[], af float8[], ats timestamptz[],
        iv interval
      )''');
  });

  tearDownAll(() async {
    await native.query('DROP TABLE IF EXISTS pgn_types');
    await dart.close();
  });

  /// rows of [sql] from both drivers
  Future<(Rows, Rows)> both(String sql, [Map<String, dynamic>? params]) async {
    PgNativeResult n = await native.query(sql, parameters: params);
    Result d = await dart.execute(Sql.named(sql), parameters: params);
    return (
      n.rows,
      <Map<String, dynamic>>[for (ResultRow r in d) r.toColumnMap()],
    );
  }

  Map<String, dynamic> values = <String, dynamic>{
    'i2': 7,
    'i4': -2147483648,
    'i8': 9007199254740993,
    'f4': 1.5,
    'f8': 3.14159,
    'num': '12345.678900',
    't': 'héllo \' " \\ wörld',
    'vc': 'short',
    'bp': 'ab',
    'b': true,
    'ts': DateTime.utc(2024, 2, 29, 13, 45, 1, 123, 456),
    'tz': DateTime.utc(1999, 12, 31, 23, 59, 59),
    'd': DateTime.utc(2024, 1, 2),
    'j': <String, dynamic>{
      'a': 1,
      'b': <dynamic>[true, null, 'x'],
    },
    'jb': <String, dynamic>{
      'nested': <String, dynamic>{'k': 'v'},
    },
    'u': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    'by': Uint8List.fromList(<int>[0, 1, 2, 255]),
    'ai': <int>[1, 2, 3],
    'at': <String>['a', 'b c', 'd"e'],
    'ab': <bool>[true, false],
    'af': <double>[1.25, -2.5],
    'ats': <DateTime>[DateTime.utc(2020, 5, 6, 7, 8, 9)],
  };
  String cols = values.keys.join(', ');
  String marks = values.keys.map((String k) => '@$k').join(', ');

  test('every type comes back like with the postgres package', () async {
    await native.query(
      'INSERT INTO pgn_types ($cols) VALUES ($marks)',
      parameters: values,
    );
    await dart.execute(
      Sql.named('INSERT INTO pgn_types ($cols) VALUES ($marks)'),
      parameters: values,
    );
    await native.query('INSERT INTO pgn_types (t) VALUES (NULL)');
    await native.query("UPDATE pgn_types SET iv = '1 day 2 hours'");

    (Rows, Rows) r = await both('SELECT * FROM pgn_types ORDER BY id');
    Rows n = r.$1;
    Rows d = r.$2;
    expect(n, hasLength(3));
    expect(n, equals(d));
    // native insert and Dart insert stored the same values
    Map<String, dynamic> a = Map<String, dynamic>.of(n[0])..remove('id');
    Map<String, dynamic> b = Map<String, dynamic>.of(n[1])..remove('id');
    expect(a, equals(b));
    expect(n[0]['i8'], 9007199254740993);
    expect(n[0]['ts'], values['ts']);
    expect(
      n[0]['tz'],
      isA<DateTime>().having((DateTime t) => t.isUtc, 'utc', true),
    );
    expect(n[0]['by'], isA<Uint8List>());
    expect(n[0]['ai'], <int>[1, 2, 3]);
    expect(n[0]['j'], values['j']);
    expect(n[0]['iv'], isA<Interval>());
    expect(n[2]['t'], isNull);
    expect(n[2]['ai'], isNull);
  });

  test('expressions, null params and the select order', () async {
    (Rows, Rows) r = await both(
      'SELECT @a::int + 1 AS x, @b::text AS y, @c AS z, 2 AS a, 1 AS b, '
      "'@not' AS lit, NULL::int AS nothing",
      <String, dynamic>{'a': 41, 'b': null, 'c': 'zz'},
    );
    Rows n = r.$1;
    Rows d = r.$2;
    expect(n, equals(d));
    expect(n.single.keys.toList(), <String>[
      'x',
      'y',
      'z',
      'a',
      'b',
      'lit',
      'nothing',
    ]);
    expect(n.single['x'], 42);
    expect(n.single['lit'], '@not');
  });

  test('typed values and positional params', () async {
    PgNativeResult r = await native.query(
      r'SELECT $1 AS a, $2 AS b',
      parameters: <Object?>[TypedValue<int>(Type.integer, 5), 'x'],
    );
    expect(r.rows.single, <String, dynamic>{'a': 5, 'b': 'x'});
    expect(r.columns, <String>['a', 'b']);
  });

  test('the cached plan is renewed after ALTER TABLE', () async {
    await native.query('DROP TABLE IF EXISTS pgn_alter');
    await native.query('CREATE TABLE pgn_alter (a int)');
    await native.query('INSERT INTO pgn_alter VALUES (1)');
    String sql = 'SELECT * FROM pgn_alter';
    expect((await native.query(sql)).rows.single, <String, dynamic>{'a': 1});
    await native.query("ALTER TABLE pgn_alter ADD COLUMN b text DEFAULT 'x'");
    expect((await native.query(sql)).rows.single, <String, dynamic>{
      'a': 1,
      'b': 'x',
    });
    await native.query('DROP TABLE pgn_alter');
  });

  group('errors have the shape of the postgres package', () {
    Future<Object> fail(Future<Object?> Function() run) async {
      try {
        await run();
      } catch (e) {
        return e;
      }
      throw TestFailure('no error');
    }

    test('unique violation', () async {
      await native.query('DROP TABLE IF EXISTS pgn_uniq');
      await native.query('CREATE TABLE pgn_uniq (k int PRIMARY KEY)');
      await native.query('INSERT INTO pgn_uniq VALUES (1)');
      String sql = 'INSERT INTO pgn_uniq VALUES (@k)';
      Map<String, dynamic> p = <String, dynamic>{'k': 1};
      Object n = await fail(() => native.query(sql, parameters: p));
      Object d = await fail(() => dart.execute(Sql.named(sql), parameters: p));
      expect(n, isA<UniqueViolationException>());
      expect(d, isA<UniqueViolationException>());
      expect(n.toString(), d.toString());
      ServerException e = n as ServerException;
      expect(e.code, '23505');
      expect(e.constraintName, 'pgn_uniq_pkey');
      expect(e.tableName, 'pgn_uniq');
      expect(e.severity, Severity.error);
      await native.query('DROP TABLE pgn_uniq');
    });

    test('syntax error and missing table', () async {
      for (String sql in <String>['SELEC 1', 'SELECT * FROM pgn_nope']) {
        Object n = await fail(() => native.query(sql));
        Object d = await fail(() => dart.execute(sql));
        expect(n, isA<ServerException>());
        expect(n.runtimeType, d.runtimeType);
        expect(n.toString(), d.toString());
        expect(
          (n as ServerException).position,
          (d as ServerException).position,
        );
      }
    });

    test('a missing or an unknown parameter', () async {
      expect(
        () => native.query('SELECT @a', parameters: <String, dynamic>{}),
        throwsArgumentError,
      );
      expect(
        () => native.query('SELECT 1', parameters: <String, dynamic>{'x': 1}),
        throwsArgumentError,
      );
    });

    test('a bad server is a PgException', () async {
      PgNativePool bad = PgNativePool.open(
        host: host,
        port: 1,
        user: 'postgres',
        database: 'postgres',
      );
      Object e = await fail(() => bad.query('SELECT 1'));
      expect(e, isA<PgException>());
      bad.close();
      Object closed = await fail(() => bad.query('SELECT 1'));
      expect('$closed', contains('closed'));
    });

    test('a wrong password is a fatal ServerException', () async {
      PgNativePool bad = PgNativePool.open(
        host: host,
        port: port,
        user: 'postgres',
        password: 'wrong',
        database: 'postgres',
      );
      Object e = await fail(() => bad.query('SELECT 1'));
      expect(e, isA<ServerException>());
      expect((e as ServerException).code, '28P01');
      expect(e.severity, Severity.fatal);
      bad.close();
    });
  });

  group('transactions', () {
    setUp(() async {
      await native.query('DROP TABLE IF EXISTS pgn_tx');
      await native.query('CREATE TABLE pgn_tx (v int)');
    });

    Future<List<int>> all() async => <int>[
      for (Map<String, dynamic> r in (await native.query(
        'SELECT v FROM pgn_tx ORDER BY v',
      )).rows)
        r['v'] as int,
    ];

    test('commit and rollback, on one connection', () async {
      int tx = await native.begin();
      await native.query('INSERT INTO pgn_tx VALUES (1)', transaction: tx);
      expect(await all(), isEmpty, reason: 'not committed yet');
      // many queries at once still run in order on the connection
      await Future.wait(<Future<Object?>>[
        for (int i = 2; i < 12; i++)
          native.query('INSERT INTO pgn_tx VALUES ($i)', transaction: tx),
      ]);
      PgNativeResult inside = await native.query(
        'SELECT count(*) AS n FROM pgn_tx',
        transaction: tx,
      );
      expect(inside.rows.single['n'], 11);
      await native.commit(tx);
      expect(await all(), hasLength(11));

      int tx2 = await native.begin();
      await native.query('DELETE FROM pgn_tx', transaction: tx2);
      await native.rollback(tx2);
      expect(await all(), hasLength(11));
      expect(
        () => native.query('SELECT 1', transaction: tx2),
        throwsA(isA<PgException>()),
      );
    });

    test('the ORM driver commits, rolls back and joins nested ones', () async {
      PostgresNativeDriver driver = PostgresNativeDriver(native);
      await driver.transaction(() async {
        await driver.execute('INSERT INTO pgn_tx VALUES (1)');
        await driver.transaction(() async {
          await driver.execute('INSERT INTO pgn_tx VALUES (2)');
        });
      });
      expect(await all(), <int>[1, 2]);
      await expectLater(
        driver.transaction(() async {
          await driver.execute('INSERT INTO pgn_tx VALUES (3)');
          throw StateError('stop');
        }),
        throwsStateError,
      );
      expect(await all(), <int>[1, 2]);
    });

    test('a request sent after the end still gets an answer', () async {
      // Sent in one batch: Rust got the second end and the query while the
      // first end still ran. They waited forever.
      int tx = await native.begin();
      List<Future<Object?>> after = <Future<Object?>>[
        native.rollback(tx),
        native.rollback(tx),
        native.query('SELECT 1', transaction: tx),
      ];
      List<Object?> out = await Future.wait(<Future<Object?>>[
        for (Future<Object?> f in after)
          f.then<Object?>((_) => 'ok', onError: (Object e) => e),
      ]).timeout(const Duration(seconds: 5));
      expect(out.first, 'ok');
      expect(out.skip(1), everyElement(isA<PgException>()));
    });
  });

  test('a value Dart can not decode fails only its own query', () async {
    // Out of the DateTime range. It threw in the middle of a result batch,
    // so the other results of that batch were lost.
    List<Future<Object?>> all = <Future<Object?>>[
      for (int i = 0; i < 20; i++)
        i == 10
            ? native.query("SELECT '294276-12-31'::timestamp AS t")
            : native.query('SELECT $i AS n'),
    ];
    List<Object?> out = await Future.wait(<Future<Object?>>[
      for (Future<Object?> f in all)
        f.then<Object?>((Object? r) => r, onError: (Object e) => e),
    ]).timeout(const Duration(seconds: 5));
    expect(out[10], isA<PgException>());
    expect(out.whereType<PgNativeResult>(), hasLength(19));
  });

  test('one pool, used by many isolates', () async {
    await native.query('DROP TABLE IF EXISTS pgn_iso');
    await native.query('CREATE TABLE pgn_iso (id int PRIMARY KEY, w int)');
    int handle = native.handle;
    List<int> sums = await Future.wait(<Future<int>>[
      for (int w = 0; w < 8; w++) Isolate.run(_job(handle, w)),
    ]);
    for (int w = 0; w < 8; w++) {
      expect(sums[w], 200 * w * 1000 + 199 * 200 ~/ 2);
    }
    PgNativeResult count = await native.query(
      'SELECT count(*) AS n FROM pgn_iso',
    );
    expect(count.rows.single['n'], 1600);
    await native.query('DROP TABLE pgn_iso');
  });

  test('fromConfig reads a Dox ConnectionConfig', () async {
    PostgresNativeDriver driver = PostgresNativeDriver.fromConfig(
      ConnectionConfig(
        driver: Driver.postgres,
        host: host,
        port: port,
        user: 'postgres',
        password: 'postgres',
        database: 'postgres',
        debug: false,
      ),
    );
    expect(driver.getName(), Driver.postgres);
    expect(await driver.query('SHOW TimeZone'), <Map<String, dynamic>>[
      <String, dynamic>{'TimeZone': 'UTC'},
    ]);
    driver.pool.close();
  });
}

/// runs in another isolate: 200 inserts at once on the shared pool
Future<int> _insertMany(int handle, int w) async {
  PgNativePool pool = PgNativePool.fromHandle(handle);
  List<PgNativeResult> res = await Future.wait(<Future<PgNativeResult>>[
    for (int i = 0; i < 200; i++)
      pool.query(
        'INSERT INTO pgn_iso VALUES (@id, @w) RETURNING id',
        parameters: <String, dynamic>{'id': w * 1000 + i, 'w': w},
      ),
  ]);
  int sum = 0;
  for (PgNativeResult r in res) {
    sum += r.rows.single['id'] as int;
  }
  return sum;
}

/// a closure with only [handle] and [w], so it can go to another isolate
Future<int> Function() _job(int handle, int w) =>
    () => _insertMany(handle, w);
