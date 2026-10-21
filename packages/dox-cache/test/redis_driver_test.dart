import 'package:dox_cache/dox_cache.dart';
import 'package:ioredis/ioredis.dart';
import 'package:test/test.dart';

import 'support/cache_contract.dart';
import 'support/driver_harness.dart';
import 'support/redis_env.dart';

Redis newRedis() {
  return Redis(RedisOptions(
      host: RedisEnv.host,
      port: RedisEnv.port,
      retryStrategy: RedisDriverFactory.retryDelay));
}

class RedisHarness implements DriverHarness {
  RedisDriver? driver;

  @override
  String get name {
    return 'redis';
  }

  @override
  bool get supportsLocks {
    return true;
  }

  @override
  Future<CacheDriver> create() async {
    RedisDriver created = RedisDriver(newRedis(),
        prefix: 'dox_cache_test:${CacheLock.randomOwner()}:');
    driver = created;
    return created;
  }

  @override
  Future<void> advance(Duration duration) async {
    await Future<void>.delayed(duration);
  }

  @override
  Future<void> close() async {
    await driver?.flush();
    await driver?.redis.disconnect();
  }
}

Future<void> main() async {
  bool reachable = await RedisEnv.isReachable();
  Object? skip = reachable
      ? null
      : 'Redis not reachable at ${RedisEnv.host}:${RedisEnv.port}';

  runCacheContract(RedisHarness(), skip: skip);

  group('redis driver', () {
    late Redis redis;
    late RedisDriver driver;

    setUp(() {
      redis = newRedis();
      driver = RedisDriver(redis, prefix: 'dox_cache_spec:*[x]:');
    });

    tearDown(() async {
      await driver.flush();
      await redis.sendCommand(<String>['DEL', 'dox_cache_spec:other']);
      await redis.disconnect();
    });

    test('keys are stored with the prefix as JSON', () async {
      await driver.put('a', <String, dynamic>{'b': 1}, null);
      expect(await redis.sendCommand(<String>['GET', 'dox_cache_spec:*[x]:a']),
          '{"b":1}');
    });

    test('ttl uses PX', () async {
      await driver.put('a', 1, const Duration(seconds: 30));
      Object? pttl =
          await redis.sendCommand(<String>['PTTL', 'dox_cache_spec:*[x]:a']);
      int ms = int.parse('$pttl');
      expect(ms, greaterThan(29000));
      expect(ms, lessThanOrEqualTo(30000));
    });

    test('flush keeps keys outside the prefix', () async {
      await redis.sendCommand(<String>['SET', 'dox_cache_spec:other', 'keep']);
      for (int i = 0; i < 1200; i++) {
        await driver.put('k$i', i, null);
      }
      await driver.flush();
      expect(await driver.get('k1'), isNull);
      expect(await driver.get('k1199'), isNull);
      expect(await redis.sendCommand(<String>['GET', 'dox_cache_spec:other']),
          'keep');
    });

    test('flush with glob characters in prefix matches only that prefix',
        () async {
      RedisDriver lookalike =
          RedisDriver(redis, prefix: 'dox_cache_spec:a[x]:');
      await lookalike.put('k', 1, null);
      await driver.put('k', 2, null);
      await driver.flush();
      expect(await lookalike.get('k'), 1);
      await lookalike.flush();
    });

    test('empty prefix refuses to flush', () async {
      await expectLater(
          RedisDriver(redis, prefix: '').flush(), throwsStateError);
    });

    test('too big value throws before sending', () async {
      RedisDriver small =
          RedisDriver(redis, prefix: 'dox_cache_spec:', maxValueBytes: 10);
      await expectLater(small.put('big', 'x' * 20, null), throwsArgumentError);
    });

    test('lock is shared by two connections', () async {
      Redis otherRedis = newRedis();
      RedisDriver other =
          RedisDriver(otherRedis, prefix: 'dox_cache_spec:*[x]:');
      CacheLock first = driver.lock('job', const Duration(seconds: 5));
      expect(await first.get(), isTrue);
      expect(
          await other.lock('job', const Duration(seconds: 5)).get(), isFalse);
      expect(await first.release(), isTrue);
      expect(await other.lock('job', const Duration(seconds: 5)).get(), isTrue);
      await otherRedis.disconnect();
    });

    test('factory builds a driver from config', () async {
      CacheDriver built = const RedisDriverFactory().create(<String, dynamic>{
        'host': RedisEnv.host,
        'port': RedisEnv.port,
        'prefix': 'dox_cache_spec:f:',
      });
      await built.put('a', 'b', null);
      expect(await built.get('a'), 'b');
      await built.flush();
      await (built as RedisDriver).redis.disconnect();
    });
  }, skip: skip);
}
