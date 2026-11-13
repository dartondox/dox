import 'dart:convert';
import 'dart:io';

import 'package:dox_cache/dox_cache.dart';
import 'package:dox_cache_database/dox_cache_database.dart';
import 'package:dox_orm/dox_orm.dart';
import 'package:test/test.dart';

import 'support/cache_contract.dart';
import 'support/driver_harness.dart';

/// SQLite always runs. Postgres, MariaDB and MySQL run when `PG_PORT`,
/// `MARIADB_PORT` and `MYSQL_PORT` are set (see .github/workflows/ci.yaml
/// and ci/start-services.sh).
Map<String, String> env = Platform.environment;

ConnectionConfig mysqlConfig(String port) {
  return ConnectionConfig(
    driver: Driver.mysql,
    host: '127.0.0.1',
    port: int.parse(port),
    user: 'dox',
    password: 'password',
    database: 'dox-framework',
    debug: false,
  );
}

ConnectionConfig postgresConfig() {
  return ConnectionConfig(
    driver: Driver.postgres,
    host: '127.0.0.1',
    port: int.parse(env['PG_PORT'] ?? '5432'),
    user: 'postgres',
    password: 'postgres',
    database: 'postgres',
    debug: false,
  );
}

/// `<name>_cache` is a second connection (its own pool) to the same
/// database, like an app that gives the cache store its own connection.
DatabaseConfig dbConfig = DatabaseConfig(
  connection: 'sqlite',
  connections: <String, ConnectionConfig>{
    'sqlite': ConnectionConfig(
      driver: Driver.sqlite,
      database: ':memory:',
      debug: false,
    ),
    'postgres': postgresConfig(),
    'postgres_cache': postgresConfig(),
    'mariadb': mysqlConfig(env['MARIADB_PORT'] ?? '3306'),
    'mariadb_cache': mysqlConfig(env['MARIADB_PORT'] ?? '3306'),
    'mysql': mysqlConfig(env['MYSQL_PORT'] ?? '3307'),
    'mysql_cache': mysqlConfig(env['MYSQL_PORT'] ?? '3307'),
  },
);

/// the connection of the group that runs now
String connection = 'sqlite';

/// A clock that only moves when told.
class FakeClock extends CacheClock {
  DateTime _now = DateTime.utc(2026);

  @override
  DateTime now() {
    return _now;
  }

  void advance(Duration duration) {
    _now = _now.add(duration);
  }
}

/// A fake encrypter: base64 of the key and the text.
class TestEncrypter implements CacheEncrypter {
  const TestEncrypter();

  @override
  String encrypt(String text) {
    return base64Encode(utf8.encode('k|$text'));
  }

  @override
  String decrypt(String text) {
    String plain = utf8.decode(base64Decode(text));
    if (!plain.startsWith('k|')) throw const FormatException('wrong key');
    return plain.substring(2);
  }
}

class DatabaseHarness implements DriverHarness {
  FakeClock clock = FakeClock();

  @override
  String get name {
    return 'database';
  }

  @override
  bool get supportsLocks {
    return true;
  }

  @override
  Future<CacheDriver> create() async {
    clock = FakeClock();
    await clearCacheTable();
    return DatabaseCacheDriver(connection: connection, clock: clock);
  }

  @override
  Future<void> advance(Duration duration) async {
    clock.advance(duration);
  }

  @override
  Future<void> close() async {}
}

Schema schema() {
  return Schema(SqlQueryBuilder().getDBDriver(connection));
}

QueryBuilder<Map<String, dynamic>> cacheTable() {
  return QueryBuilder.table('cache').withConnection(connection);
}

Future<void> clearCacheTable() async {
  await cacheTable().truncate();
}

Future<int> rowCount() async {
  return await cacheTable().count();
}

void main() {
  setUpAll(() {
    SqlQueryBuilder.initializeWithDatabaseConfig(dbConfig);
  });

  for (String name in <String>['sqlite', 'postgres', 'mariadb', 'mysql']) {
    String? skip = switch (name) {
      'postgres' when env['PG_PORT'] == null => 'no PG_PORT',
      'mariadb' when env['MARIADB_PORT'] == null => 'no MARIADB_PORT',
      'mysql' when env['MYSQL_PORT'] == null => 'no MYSQL_PORT',
      _ => null,
    };
    group(name, skip: skip, () => tests(name));
  }
}

void tests(String name) {
  setUpAll(() async {
    connection = name;
    await CacheTables.down(schema());
    await CacheTables.up(schema());
  });
  tearDownAll(() => CacheTables.down(schema()));

  runCacheContract(DatabaseHarness());

  group('database cache driver |', () {
    late FakeClock clock;
    late DatabaseCacheDriver driver;

    setUp(() async {
      await clearCacheTable();
      clock = FakeClock();
      driver = DatabaseCacheDriver(connection: connection, clock: clock);
    });

    test('a row holds the prefixed key, JSON text and expiry ms', () async {
      await driver.put('a', <String, dynamic>{'b': 1}, Duration(seconds: 10));
      Map<String, dynamic>? row = await cacheTable().first();
      expect(row?['key'], 'dox_cache:a');
      // MariaDB gives JSON looking text as a Map
      Object? value = row?['value'];
      expect(value is String ? jsonDecode(value) : value, <String, dynamic>{
        'b': 1,
      });
      expect(
        int.parse('${row?['expires_at']}'),
        clock.nowMs() + Duration(seconds: 10).inMilliseconds,
      );
    });

    test('keys A and a are two entries', () async {
      await driver.put('A', 1, null);
      await driver.put('a', 2, null);
      expect(await driver.get('A'), 1);
      expect(await driver.get('a'), 2);
      expect(await driver.add('a', 3, null), isFalse);
      expect(await rowCount(), 2);
    });

    test('a key over 255 characters throws', () async {
      String long = 'k' * 250;
      Matcher error = throwsA(isA<ArgumentError>());
      await expectLater(driver.put(long, 1, null), error);
      await expectLater(driver.get(long), error);
      await expectLater(driver.add(long, 1, null), error);
      await expectLater(driver.increment(long, 1), error);
      await expectLater(driver.pull(long), error);
      await expectLater(driver.touch(long, null), error);
      await expectLater(driver.forget(long), error);
      await expectLater(driver.many(<String>['a', long]), error);
      await expectLater(driver.has(long), error);
      await expectLater(driver.getRaw(long), error);
      await expectLater(
        driver.putMany(<String, Object?>{long: 1}, null),
        error,
      );
      await expectLater(driver.lock(long, null).get(), error);
      await expectLater(driver.lock(long, null).release(), error);
      await expectLater(driver.lock(long, null).forceRelease(), error);
      expect(await rowCount(), 0);
      // 255 with the prefix is fine
      String max = 'k' * (255 - driver.prefix.length);
      await driver.put(max, 1, null);
      expect(await driver.get(max), 1);
    });

    test('flush with an empty prefix throws', () async {
      DatabaseCacheDriver empty = DatabaseCacheDriver(
        connection: connection,
        prefix: '',
      );
      await empty.put('a', 1, null);
      await expectLater(empty.flush(), throwsStateError);
      expect(await empty.get('a'), 1);
    });

    test('flush and prune do not touch a prefix in another case', () async {
      DatabaseCacheDriver lower = DatabaseCacheDriver(
        connection: connection,
        prefix: 'a_b',
        clock: clock,
      );
      DatabaseCacheDriver upper = DatabaseCacheDriver(
        connection: connection,
        prefix: 'A_B',
        clock: clock,
      );
      await upper.put('keep', 1, null);
      await upper.put('old', 2, Duration(seconds: 1));
      await lower.put('old', 3, Duration(seconds: 1));
      clock.advance(Duration(seconds: 2));
      expect(await lower.prune(), 1);
      await lower.flush();
      expect(await rowCount(), 2);
      expect(await upper.get('keep'), 1);
    });

    test('release of an expired lock is false', () async {
      CacheLock lock = driver.lock('job', Duration(seconds: 1));
      expect(await lock.get(), isTrue);
      clock.advance(Duration(seconds: 2));
      expect(await lock.release(), isFalse);
      expect(await driver.lock('job', Duration(seconds: 1)).get(), isTrue);
    });

    test('a lock owner in another case can not release', () async {
      CacheLock lock = driver.lock('job', Duration(seconds: 5), 'abc');
      expect(await lock.get(), isTrue);
      CacheLock other = driver.lock('job', Duration(seconds: 5), 'ABC');
      expect(await other.release(), isFalse);
      expect(await lock.release(), isTrue);
    });

    test('many with more keys than one query takes', () async {
      List<String> keys = <String>[for (int i = 0; i < 1200; i++) 'k$i'];
      await driver.putMany(<String, Object?>{'k3': 3, 'k1100': 1100}, null);
      Map<String, dynamic> values = await driver.many(keys);
      expect(values, hasLength(1200));
      expect(values['k3'], 3);
      expect(values['k1100'], 1100);
      expect(values['k5'], isNull);
    });

    test('many with the same key twice', () async {
      await driver.put('a', 1, null);
      expect(await driver.many(<String>['a', 'a', 'b']), <String, dynamic>{
        'a': 1,
        'b': null,
      });
    });

    test('flush and prune with a non-ASCII prefix', () async {
      List<DatabaseCacheDriver> stores = <DatabaseCacheDriver>[
        for (String prefix in <String>['é', 'e', '日本', '日', '🐶', '🐱'])
          DatabaseCacheDriver(
            connection: connection,
            prefix: prefix,
            clock: clock,
          ),
      ];
      for (DatabaseCacheDriver store in stores) {
        await store.put('keep', store.prefix, null);
        await store.put('old', 1, Duration(seconds: 1));
      }
      clock.advance(Duration(seconds: 2));
      for (int i = 0; i < stores.length; i += 2) {
        expect(await stores[i].prune(), 1);
        await stores[i].flush();
      }
      expect(await rowCount(), 6);
      for (int i = 1; i < stores.length; i += 2) {
        expect(await stores[i].get('keep'), stores[i].prefix);
      }
    });

    test('prune with an empty prefix deletes all expired rows', () async {
      DatabaseCacheDriver empty = DatabaseCacheDriver(
        connection: connection,
        prefix: '',
        clock: clock,
      );
      DatabaseCacheDriver other = DatabaseCacheDriver(
        connection: connection,
        prefix: 'other',
        clock: clock,
      );
      await other.put('old', 1, Duration(seconds: 1));
      await other.put('keep', 2, null);
      await empty.put('old', 3, Duration(seconds: 1));
      clock.advance(Duration(seconds: 2));
      expect(await empty.prune(), 2);
      expect(await rowCount(), 1);
    });

    test('putMany writes all values', () async {
      await driver.putMany(<String, Object?>{
        'a': 1,
        'b': 'two',
      }, Duration(seconds: 1));
      expect(await driver.get('b'), 'two');
      clock.advance(Duration(seconds: 2));
      expect(await driver.get('a'), isNull);
    });

    group(
      'on its own connection |',
      () {
        late DatabaseCacheDriver own;

        setUp(() {
          own = DatabaseCacheDriver(
            connection: '${connection}_cache',
            clock: clock,
          );
        });

        test('an app transaction does not roll it back', () async {
          DBDriver app = SqlQueryBuilder().getDBDriver(connection);
          await expectLater(
            app.transaction(() async {
              await own.put('own', 1, null);
              await driver.put('same', 1, null);
              throw StateError('rollback');
            }),
            throwsStateError,
          );
          expect(await own.get('own'), 1);
          // the store on the app connection joined the transaction
          expect(await driver.get('same'), isNull);
        });

        test('two connections race on add: only one wins', () async {
          List<bool> results = await Future.wait(<Future<bool>>[
            for (int i = 0; i < 10; i++)
              (i.isEven ? driver : own).add('once', i, null),
          ]);
          expect(results.where(_isTrue), hasLength(1));
        });

        test('two connections race on a lock: only one gets it', () async {
          List<CacheLock> locks = <CacheLock>[
            for (int i = 0; i < 10; i++)
              (i.isEven ? driver : own).lock('job', Duration(seconds: 5)),
          ];
          List<bool> taken = await Future.wait(<Future<bool>>[
            for (CacheLock lock in locks) lock.get(),
          ]);
          expect(taken.where(_isTrue), hasLength(1));
        });

        // Two connections, 12 parallel calls on one key, 40 rounds. MySQL
        // reports deadlocks for these shapes: the driver runs them again.
        test('stress: put and forget', () async {
          for (int round = 0; round < 40; round++) {
            await Future.wait(<Future<Object?>>[
              for (int i = 0; i < 12; i++)
                i.isEven
                    ? (i % 4 == 0 ? driver : own).put('pf', round, null)
                    : (i % 4 == 1 ? driver : own).forget('pf'),
            ]);
            Object? value = await driver.get('pf');
            expect(value == null || value == round, isTrue);
          }
        });

        test('stress: add and pull', () async {
          int added = 0;
          int pulled = 0;
          for (int round = 0; round < 40; round++) {
            List<Object?> results = await Future.wait(<Future<Object?>>[
              for (int i = 0; i < 12; i++)
                i.isEven
                    ? (i % 4 == 0 ? driver : own).add('ap', i, null)
                    : (i % 4 == 1 ? driver : own).pull('ap'),
            ]);
            for (int i = 0; i < 12; i++) {
              if (i.isEven && results[i] == true) added++;
              if (i.isOdd && results[i] != null) pulled++;
            }
          }
          int left = await driver.has('ap') ? 1 : 0;
          expect(added, pulled + left);
        });

        test('stress: increment and pull', () async {
          int pulled = 0;
          for (int round = 0; round < 40; round++) {
            List<Object?> results = await Future.wait(<Future<Object?>>[
              for (int i = 0; i < 12; i++)
                i.isEven
                    ? (i % 4 == 0 ? driver : own).increment('ip', 1)
                    : (i % 4 == 1 ? driver : own).pull('ip'),
            ]);
            for (int i = 1; i < 12; i += 2) {
              pulled += results[i] as int? ?? 0;
            }
          }
          int left = await driver.get('ip') as int? ?? 0;
          expect(pulled + left, 40 * 6);
        });

        test('two connections increment: all count', () async {
          await Future.wait(<Future<int>>[
            for (int i = 0; i < 20; i++)
              (i.isEven ? driver : own).increment('hits', 1),
          ]);
          expect(await own.get('hits'), 20);
        });
      },
      skip: name == 'sqlite'
          ? 'SQLite: the test database is :memory:, one connection'
          : null,
    );

    test('add replaces an expired row', () async {
      await driver.put('once', 'old', Duration(seconds: 1));
      clock.advance(Duration(seconds: 2));
      expect(await driver.add('once', 'new', null), isTrue);
      expect(await driver.get('once'), 'new');
      expect(await rowCount(), 1);
    });

    test('parallel add of an expired row: only one wins', () async {
      await driver.put('once', 'old', Duration(seconds: 1));
      clock.advance(Duration(seconds: 2));
      List<bool> results = await Future.wait(<Future<bool>>[
        for (int i = 0; i < 10; i++) driver.add('once', i, null),
      ]);
      expect(results.where(_isTrue), hasLength(1));
      int winner = results.indexOf(true);
      expect(await driver.get('once'), winner);
    });

    test('two lock owners race: only one gets the lock', () async {
      DatabaseCacheDriver other = DatabaseCacheDriver(
        connection: connection,
        clock: clock,
      );
      List<CacheLock> locks = <CacheLock>[
        for (int i = 0; i < 10; i++)
          (i.isEven ? driver : other).lock('job', Duration(seconds: 5)),
      ];
      List<bool> taken = await Future.wait(<Future<bool>>[
        for (CacheLock lock in locks) lock.get(),
      ]);
      expect(taken.where(_isTrue), hasLength(1));
      CacheLock winner = locks[taken.indexOf(true)];
      for (CacheLock lock in locks) {
        if (lock != winner) expect(await lock.release(), isFalse);
      }
      expect(await winner.release(), isTrue);
    });

    test('an expired lock is taken over by one owner only', () async {
      CacheLock first = driver.lock('job', Duration(seconds: 1));
      expect(await first.get(), isTrue);
      clock.advance(Duration(seconds: 2));
      List<CacheLock> locks = <CacheLock>[
        for (int i = 0; i < 10; i++) driver.lock('job', Duration(seconds: 5)),
      ];
      List<bool> taken = await Future.wait(<Future<bool>>[
        for (CacheLock lock in locks) lock.get(),
      ]);
      expect(taken.where(_isTrue), hasLength(1));
      // the old owner can not free the lock of the new owner
      expect(await first.release(), isFalse);
    });

    test('parallel increments all count', () async {
      await Future.wait(<Future<int>>[
        for (int i = 0; i < 20; i++) driver.increment('hits', 1),
      ]);
      expect(await driver.get('hits'), 20);
    });

    test('increment of an expired key starts at 0 with no ttl', () async {
      await driver.put('hits', 5, Duration(seconds: 1));
      clock.advance(Duration(seconds: 2));
      expect(await driver.increment('hits', 1), 1);
      clock.advance(Duration(days: 1));
      expect(await driver.get('hits'), 1);
    });

    test('flush deletes only rows of this prefix', () async {
      DatabaseCacheDriver like = DatabaseCacheDriver(
        connection: connection,
        prefix: 'doxXcache:',
      );
      DatabaseCacheDriver longer = DatabaseCacheDriver(
        connection: connection,
        prefix: 'dox_cache2',
      );
      await driver.put('a', 1, null);
      await like.put('a', 2, null);
      await longer.put('a', 3, null);
      await driver.flush();
      expect(await driver.get('a'), isNull);
      expect(await like.get('a'), 2);
      expect(await longer.get('a'), 3);
    });

    test('prune deletes only expired rows of this prefix', () async {
      DatabaseCacheDriver other = DatabaseCacheDriver(
        connection: connection,
        prefix: 'other',
        clock: clock,
      );
      await driver.put('old', 1, Duration(seconds: 1));
      await driver.put('keep', 2, null);
      await other.put('old', 3, Duration(seconds: 1));
      clock.advance(Duration(seconds: 2));
      expect(await driver.prune(), 1);
      expect(await rowCount(), 2);
      expect(await driver.get('keep'), 2);
    });

    test('encrypt: values are secret, a plain int stays plain', () async {
      DatabaseCacheDriver secret = DatabaseCacheDriver(
        connection: connection,
        clock: clock,
        encrypter: const TestEncrypter(),
      );
      await secret.put('user', <String, dynamic>{'name': 'ann'}, null);
      await secret.put('hits', 3, null);
      List<Map<String, dynamic>> rows = await cacheTable().orderBy('key').get();
      expect('${rows.first['value']}', '3');
      expect('${rows.last['value']}', isNot(contains('ann')));
      expect(await secret.get('user'), <String, dynamic>{'name': 'ann'});
      expect(await secret.increment('hits', 2), 5);
    });

    test('factory reads table, prefix and encrypt', () async {
      DatabaseCacheDriver built =
          const DatabaseCacheDriverFactory(TestEncrypter())
                  .create(<String, dynamic>{
                    'driver': 'database',
                    'table': 'cache',
                    'connection': connection,
                    'prefix': 'app',
                    'encrypt': true,
                  })
              as DatabaseCacheDriver;
      expect(built.table, 'cache');
      expect(built.connection, connection);
      expect(built.prefix, 'app:');
      expect(built.encrypter, isNotNull);
    });

    test('works as a store of CacheManager', () async {
      CacheManager manager = CacheManager(
        CacheConfig(
          defaultStore: 'database',
          stores: <String, Map<String, dynamic>>{
            'database': <String, dynamic>{
              'driver': 'database',
              'connection': connection,
            },
          },
        ),
      );
      manager.extend('database', const DatabaseCacheDriverFactory());
      await manager.store().put('a', 'b');
      expect(await manager.store().get('a'), 'b');
    });
  });
}

bool _isTrue(bool value) {
  return value;
}
