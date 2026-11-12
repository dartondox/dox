import 'dart:io';

import 'package:dox_cache/dox_cache.dart';
import 'package:ioredis/ioredis.dart';
import 'package:test/test.dart';

import 'support/redis_env.dart';
import 'support/test_encrypter.dart';

const CacheEncrypter rightKey = TestEncrypter('right');
const CacheEncrypter wrongKey = TestEncrypter('wrong');

Future<void> main() async {
  bool reachable = await RedisEnv.isReachable();
  Object? skipRedis = reachable
      ? null
      : 'Redis not reachable at ${RedisEnv.host}:${RedisEnv.port}';

  group('encrypt option', () {
    test('a store with encrypt: true and no encrypter throws', () {
      CacheManager cache = CacheManager(
        const CacheConfig(
          defaultStore: 'secret',
          stores: <String, Map<String, dynamic>>{
            'secret': <String, dynamic>{'driver': 'file', 'encrypt': true},
          },
        ),
      );
      expect(
        () => cache.store(),
        throwsA(
          isA<StateError>().having(
            (StateError e) => e.message,
            'message',
            contains('"secret"'),
          ),
        ),
      );
    });

    test('memory store ignores encrypt', () async {
      CacheManager cache = CacheManager(
        const CacheConfig(
          defaultStore: 'm',
          stores: <String, Map<String, dynamic>>{
            'm': <String, dynamic>{'driver': 'memory', 'encrypt': true},
          },
          encrypter: rightKey,
        ),
      );
      await cache.store().put('a', 'x');
      expect(await cache.store().get('a'), 'x');
      await cache.close();
    });
  });

  group('file driver encrypt', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('dox_cache_enc_');
    });

    tearDown(() async {
      await dir.delete(recursive: true);
    });

    CacheStore storeWith(CacheEncrypter? encrypter) {
      return CacheStore(FileDriver(directory: dir, encrypter: encrypter));
    }

    Future<String> allFileText() async {
      StringBuffer text = StringBuffer();
      await for (FileSystemEntity entity in dir.list(recursive: true)) {
        if (entity is File) text.write(await entity.readAsString());
      }
      return text.toString();
    }

    test('round trip, tags, many, increment and pull work', () async {
      CacheStore cache = storeWith(rightKey);
      await cache.put('name', 'dox-secret-value');
      expect(await cache.get('name'), 'dox-secret-value');
      expect(await cache.has('name'), isTrue);
      expect(await cache.getRaw('name'), '"dox-secret-value"');

      await cache.putMany(<String, Object?>{'a': 1, 'b': 'two'});
      expect(await cache.many(<String>['a', 'b', 'c']), <String, dynamic>{
        'a': 1,
        'b': 'two',
        'c': null,
      });
      expect(await cache.increment('hits'), 1);
      expect(await cache.increment('hits', 4), 5);
      expect(await cache.decrement('hits'), 4);
      expect(await cache.add('name', 'other'), isFalse);
      expect(await cache.add('fresh', 'v'), isTrue);
      expect(await cache.touch('fresh', const Duration(minutes: 1)), isTrue);
      expect(await cache.pull('fresh'), 'v');
      expect(await cache.get('fresh'), isNull);

      await cache.tags(<String>['t']).put('x', 'tagged-secret');
      expect(await cache.tags(<String>['t']).get('x'), 'tagged-secret');
      await cache.tags(<String>['t']).flush();
      expect(await cache.tags(<String>['t']).get('x'), isNull);
    });

    test('the files do not hold the plain value', () async {
      CacheStore cache = storeWith(rightKey);
      await cache.put('name', 'dox-secret-value');
      await cache.tags(<String>['t']).put('x', 'tagged-secret');
      String text = await allFileText();
      expect(text, isNotEmpty);
      expect(text, isNot(contains('dox-secret-value')));
      expect(text, isNot(contains('tagged-secret')));
      expect(text, isNot(contains('expires_at')));
    });

    test('another key gives a miss, not a crash', () async {
      await storeWith(rightKey).put('name', 'v');
      CacheStore other = storeWith(wrongKey);
      expect(await other.get('name'), isNull);
      expect(await other.has('name'), isFalse);
      expect(await other.pull('name'), isNull);
    });

    test('a plain file reads as a miss when encrypt is on', () async {
      await storeWith(null).put('name', 'v');
      expect(await storeWith(rightKey).get('name'), isNull);
    });

    test('without encrypt the file is plain JSON, as before', () async {
      await storeWith(null).put('name', 'v');
      expect(await allFileText(), '{"value":"v","expires_at":null}');
      expect(await storeWith(null).get('name'), 'v');
    });

    test('the manager turns it on with the store option', () async {
      CacheManager cache = CacheManager(
        CacheConfig(
          defaultStore: 'f',
          stores: <String, Map<String, dynamic>>{
            'f': <String, dynamic>{
              'driver': 'file',
              'path': dir.path,
              'encrypt': true,
            },
          },
          encrypter: rightKey,
        ),
      );
      await cache.store().put('name', 'dox-secret-value');
      expect(await cache.store().get('name'), 'dox-secret-value');
      expect(await allFileText(), isNot(contains('dox-secret-value')));
      await cache.close();
    });
  });

  group('redis driver encrypt', skip: skipRedis, () {
    late RedisDriver driver;
    late Redis redis;
    late String prefix;

    setUp(() {
      prefix = 'dox_cache_enc:${CacheLock.randomOwner()}:';
      redis = Redis(
        RedisOptions(
          host: RedisEnv.host,
          port: RedisEnv.port,
          retryStrategy: RedisDriverFactory.retryDelay,
        ),
      );
      driver = RedisDriver(redis, prefix: prefix, encrypter: rightKey);
    });

    tearDown(() async {
      await driver.flush();
      await redis.disconnect();
    });

    Future<String?> rawStored(String key) async {
      Object? reply = await redis.sendCommand(<String>['GET', prefix + key]);
      return reply?.toString();
    }

    test('round trip, many, putMany, add, pull and tags work', () async {
      CacheStore cache = CacheStore(driver);
      await cache.put('name', 'dox-secret-value');
      expect(await cache.get('name'), 'dox-secret-value');
      expect(await cache.has('name'), isTrue);
      expect(await cache.getRaw('name'), '"dox-secret-value"');
      await cache.putMany(<String, Object?>{'a': 1, 'b': 'two', 'c': 1.5});
      expect(await cache.many(<String>['a', 'b', 'c', 'd']), <String, dynamic>{
        'a': 1,
        'b': 'two',
        'c': 1.5,
        'd': null,
      });
      expect(await cache.add('name', 'other'), isFalse);
      expect(await cache.add('fresh', 'v'), isTrue);
      expect(await cache.pull('fresh'), 'v');
      await cache.tags(<String>['t']).put('x', 'tagged-secret');
      expect(await cache.tags(<String>['t']).get('x'), 'tagged-secret');
      await cache.tags(<String>['t']).flush();
      expect(await cache.tags(<String>['t']).get('x'), isNull);
    });

    test('Redis does not hold the plain value', () async {
      await CacheStore(driver).put('name', 'dox-secret-value');
      String? stored = await rawStored('name');
      expect(stored, isNotNull);
      expect(stored, isNot(contains('dox-secret-value')));
    });

    test('a plain int stays plain, so increment works', () async {
      CacheStore cache = CacheStore(driver);
      await cache.put('n', 7);
      expect(await rawStored('n'), '7');
      expect(await cache.get('n'), 7);
      expect(await cache.increment('n', 3), 10);
      expect(await cache.decrement('n'), 9);
      expect(await cache.increment('new'), 1);
      expect(await cache.get('new'), 1);
      await cache.put('s', '5');
      expect(await cache.get('s'), '5');
    });

    test('another key gives a miss, not a crash', () async {
      await CacheStore(driver).put('name', 'v');
      CacheStore other = CacheStore(
        RedisDriver(redis, prefix: prefix, encrypter: wrongKey),
      );
      expect(await other.get('name'), isNull);
      expect(await other.has('name'), isFalse);
      expect(await other.many(<String>['name']), <String, dynamic>{
        'name': null,
      });
      expect(await other.pull('name'), isNull);
    });

    test('without encrypt the value is plain JSON, as before', () async {
      RedisDriver plain = RedisDriver(redis, prefix: prefix);
      await CacheStore(plain).put('name', 'v');
      expect(await rawStored('name'), '"v"');
    });
  });
}
