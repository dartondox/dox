import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dox_mysql_native/dox_mysql_native.dart';
import 'package:mysql_dart/exception.dart';
import 'package:test/test.dart';

/// DB_PORT and DB_USER like the dox_orm tests. MySQL 8.4 or MariaDB 11.
Future<MysqlNativePool> open() {
  return MysqlNativePool.connect(
    host: Platform.environment['DB_HOST'] ?? '127.0.0.1',
    port: int.parse(Platform.environment['DB_PORT'] ?? '3306'),
    user: Platform.environment['DB_USER'] ?? 'root',
    password: 'password',
    database: 'dox-framework',
  );
}

void main() {
  late MysqlNativePool pool;

  setUpAll(() async {
    pool = await open();
    await pool.execute('DROP TABLE IF EXISTS mn_types');
    await pool.execute('''
      CREATE TABLE mn_types (
        id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        i INT, big BIGINT, small SMALLINT, tiny TINYINT,
        flag TINYINT(1), price DECIMAL(10,2), f FLOAT, d DOUBLE,
        name VARCHAR(50), body TEXT, info JSON, data BLOB,
        day DATE, at DATETIME(6), ts TIMESTAMP NULL, t TIME, y YEAR
      )''');
  });

  tearDownAll(() async {
    await pool.execute('DROP TABLE IF EXISTS mn_types');
    pool.close();
  });

  setUp(() => pool.execute('DELETE FROM mn_types'));

  Future<Map<String, dynamic>> insertAndRead(bool prepared) async {
    MysqlNativeResult insert = await pool.query(
      'INSERT INTO mn_types (i, big, small, tiny, flag, price, f, d, name, '
      'body, info, data, day, at, ts, t, y) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        -7,
        9007199254740993,
        300,
        -5,
        true,
        '12.34',
        1.5,
        2.25,
        'héllo',
        'long text',
        '{"a":[1,2]}',
        Uint8List.fromList(<int>[0, 1, 255]),
        '2024-02-29',
        DateTime.utc(2024, 2, 29, 13, 14, 15, 123, 456),
        '2024-03-01 01:02:03',
        '12:34:56',
        2024,
      ],
    );
    expect(insert.columns, isEmpty);
    expect(insert.affectedRows, 1);
    expect(insert.insertId, greaterThan(0));
    String sql = 'SELECT * FROM mn_types WHERE id = ${insert.insertId}';
    MysqlNativeResult r = prepared
        ? await pool.query('SELECT * FROM mn_types WHERE id = ?', <Object?>[
            insert.insertId,
          ])
        : await pool.query(sql);
    expect(r.rows, hasLength(1));
    return r.rows.first;
  }

  for (bool prepared in <bool>[true, false]) {
    test('types (${prepared ? 'binary' : 'text'} protocol)', () async {
      Map<String, dynamic> row = await insertAndRead(prepared);
      expect(row['i'], -7);
      expect(row['big'], 9007199254740993);
      expect(row['small'], 300);
      expect(row['tiny'], -5);
      expect(row['flag'], true);
      expect(row['price'], 12.34);
      expect(row['f'], 1.5);
      expect(row['d'], 2.25);
      expect(row['name'], 'héllo');
      expect(row['body'], 'long text');
      expect(row['data'], Uint8List.fromList(<int>[0, 1, 255]));
      expect(row['day'], DateTime.utc(2024, 2, 29));
      expect(row['at'], DateTime.utc(2024, 2, 29, 13, 14, 15, 123, 456));
      expect(row['ts'], DateTime.utc(2024, 3, 1, 1, 2, 3));
      expect(row['t'], '12:34:56');
      expect(row['y'], 2024);
      // mysql: a JSON column. mariadb: LONGTEXT, decoded too.
      expect(row['info'], <String, dynamic>{
        'a': <int>[1, 2],
      });
    });
  }

  test('null values', () async {
    await pool.execute('INSERT INTO mn_types (i) VALUES (?)', <Object?>[null]);
    MysqlNativeResult r = await pool.query('SELECT i, name, at FROM mn_types');
    expect(r.rows.single, <String, dynamic>{
      'i': null,
      'name': null,
      'at': null,
    });
  });

  test('many queries at once', () async {
    List<MysqlNativeResult> all = await Future.wait(<Future<MysqlNativeResult>>[
      for (int i = 0; i < 200; i++) pool.query('SELECT ? AS n', <Object?>[i]),
    ]);
    for (int i = 0; i < 200; i++) {
      expect(all[i].rows.single['n'], i);
    }
  });

  test('transaction commit and rollback', () async {
    await pool.transaction((MysqlNativeTransaction tx) {
      return tx.execute('INSERT INTO mn_types (i) VALUES (1)');
    });
    await expectLater(
      pool.transaction((MysqlNativeTransaction tx) async {
        await tx.execute('INSERT INTO mn_types (i) VALUES (2)');
        MysqlNativeResult inside = await tx.query(
          'SELECT COUNT(*) AS c FROM mn_types',
        );
        expect(inside.rows.single['c'], 2);
        throw StateError('stop');
      }),
      throwsStateError,
    );
    MysqlNativeResult r = await pool.query('SELECT i FROM mn_types');
    expect(r.rows, <Map<String, dynamic>>[
      <String, dynamic>{'i': 1},
    ]);
  });

  test('server error has the mysql_dart shape', () async {
    await expectLater(
      pool.query('SELECT * FROM no_such_table'),
      throwsA(
        isA<MySQLServerException>()
            .having((MySQLServerException e) => e.errorCode, 'code', 1146)
            .having(
              (MySQLServerException e) => e.message,
              'message',
              contains('no_such_table'),
            ),
      ),
    );
    // the pool still works after an error
    MysqlNativeResult r = await pool.query('SELECT 1 AS one');
    expect(r.rows.single['one'], 1);
  });

  test('wrong password is a server error', () async {
    await expectLater(
      MysqlNativePool.connect(
        host: Platform.environment['DB_HOST'] ?? '127.0.0.1',
        port: int.parse(Platform.environment['DB_PORT'] ?? '3306'),
        user: Platform.environment['DB_USER'] ?? 'root',
        password: 'wrong',
        database: 'dox-framework',
      ),
      throwsA(isA<MySQLServerException>()),
    );
  });

  test('connection error is a client error', () async {
    await expectLater(
      MysqlNativePool.connect(port: 1, database: 'x'),
      throwsA(isA<MySQLClientException>()),
    );
  });

  test('one pool used by many isolates', () async {
    List<int> sums = await Future.wait(<Future<int>>[
      for (int i = 0; i < 4; i++) Isolate.run(_isolateWork),
    ]);
    expect(sums, everyElement(_isolateSum));
  });
}

const int _isolateSum = 50 * 49 ~/ 2;

Future<int> _isolateWork() async {
  MysqlNativePool pool = await open();
  List<MysqlNativeResult> all = await Future.wait(<Future<MysqlNativeResult>>[
    for (int i = 0; i < 50; i++) pool.query('SELECT ? AS n', <Object?>[i]),
  ]);
  pool.close();
  int sum = 0;
  for (MysqlNativeResult r in all) {
    sum += r.rows.single['n'] as int;
  }
  return sum;
}
