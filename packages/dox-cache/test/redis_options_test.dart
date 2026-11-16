import 'dart:io';

import 'package:dox_cache/dox_cache.dart';
import 'package:ioredis/ioredis.dart';
import 'package:test/test.dart';

/// These tests need no Redis. They use a plain TCP server.
void main() {
  const RedisDriverFactory factory = RedisDriverFactory();

  Future<Redis> clientOf(Map<String, dynamic> store) async {
    RedisDriver driver = factory.create(store) as RedisDriver;
    addTearDown(driver.redis.disconnect);
    return driver.redis;
  }

  group('redis store options key', () {
    test('uses the RedisOptions as it is', () async {
      Redis redis = await clientOf(<String, dynamic>{
        'options': RedisOptions(
          host: 'cache.invalid',
          port: 6380,
          db: 4,
          maxConnection: 3,
          commandTimeout: const Duration(seconds: 7),
        ),
      });
      expect(redis.option.host, 'cache.invalid');
      expect(redis.option.port, 6380);
      expect(redis.option.db, 4);
      expect(redis.option.maxConnection, 3);
      expect(redis.option.commandTimeout, const Duration(seconds: 7));
    });

    test('prefix and max_value_bytes still work', () async {
      RedisDriver driver = factory.create(<String, dynamic>{
        'options': RedisOptions(),
        'prefix': 'p:',
        'max_value_bytes': 5,
      }) as RedisDriver;
      addTearDown(driver.redis.disconnect);
      expect(driver.prefix, 'p:');
      expect(
        () => driver.put('k', 'longer than five', null),
        throwsA(isA<Object>()),
      );
    });

    test('commandTimeout fails fast when the server never replies', () async {
      ServerSocket server = await ServerSocket.bind('127.0.0.1', 0);
      addTearDown(server.close);
      List<Socket> clients = <Socket>[];
      server.listen(clients.add);
      addTearDown(() {
        for (Socket client in clients) {
          client.destroy();
        }
      });
      RedisDriver driver = factory.create(<String, dynamic>{
        'options': RedisOptions(
          port: server.port,
          commandTimeout: const Duration(milliseconds: 200),
        ),
      }) as RedisDriver;
      addTearDown(driver.redis.disconnect);
      Stopwatch watch = Stopwatch()..start();
      await expectLater(driver.get('k'), throwsA(isA<RedisTimeoutError>()));
      expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('options with a connection key throws an ArgumentError', () {
      for (String key in CacheConstants.redisConnectionOptions) {
        expect(
          () => factory.create(<String, dynamic>{
            'options': RedisOptions(),
            key: key == 'port' || key == 'db' || key == 'pool_size'
                ? 1
                : key == 'tls'
                ? true
                : 'x',
          }),
          throwsA(
            isA<ArgumentError>().having(
              (ArgumentError e) => e.message,
              'message',
              allOf(contains("'options'"), contains(key)),
            ),
          ),
        );
      }
    });

    test('a value that is not a RedisOptions throws an ArgumentError', () {
      expect(
        () => factory.create(<String, dynamic>{
          'options': <String, dynamic>{'host': 'x'},
        }),
        throwsArgumentError,
      );
    });

    test('a config without options is unchanged', () async {
      Redis redis = await clientOf(<String, dynamic>{
        'host': 'cache.invalid',
        'port': 6380,
        'db': 2,
        'pool_size': 3,
      });
      expect(redis.option.host, 'cache.invalid');
      expect(redis.option.port, 6380);
      expect(redis.option.db, 2);
      expect(redis.option.maxConnection, 3);
      expect(redis.option.retryStrategy, RedisDriverFactory.retryDelay);
    });
  });
}
