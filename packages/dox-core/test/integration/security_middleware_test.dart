import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/testing.dart';
import 'package:test/test.dart';

import 'requirements/handler.dart';

/// a clock the tests can move
DateTime clock = DateTime.utc(2026, 1, 1, 12);
DateTime now() => clock;

bool databaseUp = true;

class SecurityRouter extends Router {
  @override
  void register() {
    Route.get('/limited', <dynamic>[
      RateLimit(max: 2, now: now),
      (DoxRequest req) => 'ok',
    ]);
    Route.get('/limited-by-header', <dynamic>[
      RateLimit(
        max: 1,
        name: 'by-header',
        key: (DoxRequest req) => req.header('x-user') ?? '',
        now: now,
      ),
      (DoxRequest req) => 'ok',
    ]);
    Route.get('/headers', <dynamic>[
      const SecurityHeaders(),
      (DoxRequest req) => 'ok',
    ]);
    Route.get('/headers-custom', <dynamic>[
      const SecurityHeaders(
        frameOptions: 'SAMEORIGIN',
        permissionsPolicy: null,
        contentSecurityPolicy: "frame-ancestors 'none'",
        extra: <String, String>{'X-Extra': 'yes'},
      ),
      (DoxRequest req) => 'ok',
    ]);
    Route.health('/health');
    Route.health(
      '/health/full',
      checks: <String, HealthCheckFunction>{
        'cache': HealthCheck.cache(),
        'database': () => databaseUp,
      },
    );
    Route.health(
      '/health/slow',
      timeout: const Duration(milliseconds: 50),
      checks: <String, HealthCheckFunction>{
        'slow': () => Future<void>.delayed(const Duration(seconds: 2)),
      },
    );
    Route.health(
      '/health/throws',
      checks: <String, HealthCheckFunction>{
        'database': () => throw StateError('db is down'),
      },
    );
  }
}

/// keeps the expected health check errors out of the test output
class QuietHandler extends ExceptionHandler {
  @override
  void report(Object error, StackTrace stackTrace) {}
}

void main() {
  late DoxTestClient client;

  setUpAll(() async {
    client = await DoxTestClient.start(
      AppConfig(
        appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
        routers: <Router>[SecurityRouter()],
        responseHandler: ResponseHandler(),
        trustedProxies: <String>['127.0.0.1'],
        exceptionHandler: QuietHandler(),
        cache: const CacheConfig(
          defaultStore: 'memory',
          stores: <String, Map<String, dynamic>>{
            'memory': <String, dynamic>{'driver': 'memory'},
          },
        ),
      ),
    );
  });

  tearDownAll(() async {
    await client.close();
  });

  group('RateLimit |', () {
    test('429 after max requests, with the headers', () async {
      (await client.get('/limited'))
          .expectStatus(200)
          .expectHeader('x-ratelimit-limit', '2')
          .expectHeader('x-ratelimit-remaining', '1')
          .expectHeader('retry-after', isNull);
      (await client.get('/limited'))
          .expectStatus(200)
          .expectHeader('x-ratelimit-remaining', '0');

      clock = clock.add(const Duration(seconds: 20));
      TestResponse res = await client.get('/limited');
      res
          .expectStatus(HttpStatus.tooManyRequests)
          .expectHeader('x-ratelimit-remaining', '0')
          .expectHeader('retry-after', '40')
          .expectHeader('x-error-handled', 'yes')
          .expectJson(<String, dynamic>{
            'code': 'too_many_requests',
            'message': 'Too Many Requests',
          });
    });

    test('the next window starts again', () async {
      clock = clock.add(const Duration(minutes: 1));
      (await client.get('/limited'))
          .expectStatus(200)
          .expectHeader('x-ratelimit-remaining', '1');
    });

    test('each key has its own count', () async {
      Map<String, String> ann = <String, String>{'x-user': 'ann'};
      Map<String, String> bob = <String, String>{'x-user': 'bob'};
      (await client.get('/limited-by-header', headers: ann)).expectStatus(200);
      (await client.get('/limited-by-header', headers: ann)).expectStatus(429);
      (await client.get('/limited-by-header', headers: bob)).expectStatus(200);
    });

    test('max must be 1 or more', () {
      expect(() => RateLimit(max: 0), throwsArgumentError);
    });

    String? redisPort = Platform.environment['REDIS_PORT'];
    test('Redis: two servers share one count', () async {
      CacheConfig redis = CacheConfig(
        defaultStore: 'redis',
        stores: <String, Map<String, dynamic>>{
          'redis': <String, dynamic>{
            'driver': 'redis',
            'host': Platform.environment['REDIS_HOST'] ?? '127.0.0.1',
            'port': int.parse(redisPort ?? '6379'),
          },
        },
      );
      // two managers: two connections, like two servers
      CacheManager one = CacheManager(redis);
      CacheManager two = CacheManager(redis);
      String name = 'shared-${DateTime.now().microsecondsSinceEpoch}';
      RateLimit first = RateLimit(max: 1, name: name, cacheStore: one.store());
      RateLimit second = RateLimit(max: 1, name: name, cacheStore: two.store());
      Route.get('/redis-1', <dynamic>[first, (DoxRequest req) => 'ok']);
      Route.get('/redis-2', <dynamic>[second, (DoxRequest req) => 'ok']);
      (await client.get('/redis-1')).expectStatus(200);
      (await client.get('/redis-2')).expectStatus(429);
      await one.close();
      await two.close();
    }, skip: redisPort == null ? 'set REDIS_PORT to run it' : false);
  });

  group('SecurityHeaders |', () {
    test('safe defaults, no HSTS on http', () async {
      (await client.get('/headers'))
          .expectStatus(200)
          .expectHeader('x-content-type-options', 'nosniff')
          .expectHeader('x-frame-options', 'DENY')
          .expectHeader('referrer-policy', 'strict-origin-when-cross-origin')
          .expectHeader(
            'permissions-policy',
            'camera=(), microphone=(), geolocation=()',
          )
          .expectHeader('cross-origin-opener-policy', 'same-origin')
          .expectHeader('strict-transport-security', isNull)
          .expectHeader('content-security-policy', isNull);
    });

    test('HSTS on https from a trusted proxy', () async {
      (await client.get(
        '/headers',
        headers: <String, String>{'X-Forwarded-Proto': 'https'},
      )).expectHeader(
        'strict-transport-security',
        'max-age=31536000; includeSubDomains',
      );
    });

    test('change, turn off and add headers', () async {
      (await client.get('/headers-custom'))
          .expectHeader('x-frame-options', 'SAMEORIGIN')
          .expectHeader('permissions-policy', isNull)
          .expectHeader('content-security-policy', "frame-ancestors 'none'")
          .expectHeader('x-extra', 'yes')
          .expectHeader('x-content-type-options', 'nosniff');
    });
  });

  group('Route.health |', () {
    test('no checks', () async {
      (await client.get('/health'))
          .expectStatus(200)
          .expectJson(<String, dynamic>{'status': 'ok'});
    });

    test('all checks pass', () async {
      databaseUp = true;
      (await client.get('/health/full'))
          .expectStatus(200)
          .expectJson(<String, dynamic>{
            'status': 'ok',
            'checks': <String, dynamic>{'cache': 'ok', 'database': 'ok'},
          });
    });

    test('a check that returns false gives 503', () async {
      databaseUp = false;
      (await client.get('/health/full'))
          .expectStatus(503)
          .expectJson(<String, dynamic>{
            'status': 'fail',
            'checks': <String, dynamic>{'cache': 'ok', 'database': 'fail'},
          });
    });

    test('a slow check fails', () async {
      (await client.get('/health/slow')).expectStatus(503);
    });

    test('a check that throws fails, details only in development', () async {
      (await client.get('/health/throws'))
          .expectStatus(503)
          .expectJson(isNot(contains('errors')));

      Env().env['APP_ENV'] = 'development';
      addTearDown(() => Env().env.remove('APP_ENV'));
      (await client.get('/health/throws'))
          .expectStatus(503)
          .expectJson(
            containsPair('errors', <String, dynamic>{
              'database': 'Bad state: db is down',
            }),
          );
    });
  });
}
