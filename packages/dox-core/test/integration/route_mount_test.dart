import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import '../utils/start_http_server.dart';
import '../utils/test_app_key.dart';

/// stops every request that has `?block=1`
dynamic blocker(DoxRequest req) {
  if (req.input('block') == '1') return response('blocked').statusCode(403);
  return req;
}

/// throws for every request that has `?throw=1`
dynamic thrower(DoxRequest req) {
  if (req.input('throw') == '1') throw StateError('middleware failed');
  return req;
}

/// stops every request
dynamic blockAll(DoxRequest req) => response('all blocked').statusCode(401);

/// keeps the status of each answer it sees in `terminate`
class Ends implements IDoxMiddleware, IDoxTerminableMiddleware {
  final List<int> statuses = <int>[];

  @override
  dynamic handle(IDoxRequest req) => req;

  @override
  void terminate(DoxRequest req, DoxResponse res) {
    statuses.add(res.status!);
  }
}

/// keeps every reported error
class Errors extends ExceptionHandler {
  final List<Object> reported = <Object>[];

  @override
  void report(Object error, StackTrace stackTrace) {
    reported.add(error);
  }

  /// also count errors whose request already got its answer
  @override
  void reportFor(HttpRequest req, Object error, StackTrace stackTrace) {
    reported.add(error);
  }
}

AppConfig mountConfig([List<dynamic>? middleware, Errors? errors]) {
  return AppConfig(
    appKey: testAppKey,
    serverPort: 0,
    totalIsolate: 1,
    globalMiddleware: middleware ?? <dynamic>[const SecurityHeaders(), blocker],
    exceptionHandler: errors ?? const ExceptionHandler(),
  );
}

/// answers with the path it got
Future<void> echo(HttpRequest req) async {
  req.response.write('mount:${req.uri.path}');
  await req.response.close();
}

Future<HttpClientResponse> get(String path) async {
  HttpClient client = HttpClient();
  try {
    return await (await client.get(
      '127.0.0.1',
      Dox().server.httpServer.port,
      path,
    )).close().timeout(const Duration(seconds: 5));
  } finally {
    client.close();
  }
}

Future<String> body(HttpClientResponse res) {
  return res.transform(systemEncoding.decoder).join();
}

void main() {
  tearDown(() async {
    Route.unmount('/admin');
    Route.unmount('/admin/secure');
    Route.unmount('/io/');
    Route.unmount('/fail');
    await Dox().server.close();
  });

  test('a prefix matches whole path parts only', () async {
    Route.mount('/admin', echo);
    await startHttpServer(mountConfig());

    for (String path in <String>['/admin', '/admin/', '/admin/users']) {
      HttpClientResponse res = await get(path);
      expect(await body(res), 'mount:$path', reason: path);
    }
    HttpClientResponse q = await get('/admin?x=1');
    expect(await body(q), 'mount:/admin');

    for (String path in <String>['/administrator', '/admin-login']) {
      HttpClientResponse res = await get(path);
      expect(res.statusCode, 404, reason: path);
      await res.drain<void>();
    }
  });

  test('a prefix with a trailing slash also matches without it', () async {
    Route.mount('/io/', echo);
    await startHttpServer(mountConfig());

    for (String path in <String>['/io', '/io/', '/io/x?EIO=4']) {
      HttpClientResponse res = await get(path);
      expect(await body(res), startsWith('mount:/io'), reason: path);
    }
    HttpClientResponse res = await get('/iox');
    expect(res.statusCode, 404);
    await res.drain<void>();
  });

  test('by default no global middleware runs', () async {
    Route.mount('/admin', echo);
    await startHttpServer(mountConfig());

    HttpClientResponse res = await get('/admin?block=1');
    expect(res.statusCode, 200);
    expect(res.headers.value('referrer-policy'), isNull);
    expect(await body(res), 'mount:/admin');
  });

  test('middleware: true runs the global middleware first', () async {
    Route.mount('/admin', echo, middleware: true);
    await startHttpServer(mountConfig());

    HttpClientResponse res = await get('/admin/users');
    expect(res.statusCode, 200);
    expect(
      res.headers.value('referrer-policy'),
      'strict-origin-when-cross-origin',
    );
    expect(await body(res), 'mount:/admin/users');
  });

  test('a middleware that gives a response stops the handler', () async {
    bool ran = false;
    Route.mount('/admin', (HttpRequest req) async {
      ran = true;
      await echo(req);
    }, middleware: true);
    await startHttpServer(mountConfig());

    HttpClientResponse res = await get('/admin?block=1');
    expect(res.statusCode, 403);
    expect(await body(res), 'blocked');
    expect(ran, isFalse);
  });

  test('an error in the handler still answers 500', () async {
    for (bool middleware in <bool>[false, true]) {
      Route.mount('/fail', (HttpRequest req) async {
        throw StateError('mount failed');
      }, middleware: middleware);
      await startHttpServer(mountConfig());

      HttpClientResponse res = await get('/fail');
      expect(res.statusCode, 500, reason: 'middleware: $middleware');
      await res.drain<void>();
      await Dox().server.close();
    }
  });

  test('a restart with new global middleware uses the new list', () async {
    Route.mount('/admin', echo, middleware: true);
    await startHttpServer(mountConfig());
    HttpClientResponse res = await get('/admin');
    expect(res.statusCode, 200);
    await res.drain<void>();
    await Dox().server.close();

    await startHttpServer(mountConfig(<dynamic>[blockAll]));
    res = await get('/admin');
    expect(res.statusCode, 401);
    expect(await body(res), 'all blocked');
  });

  test('terminate runs once the mount answer is sent', () async {
    Ends ends = Ends();
    Route.mount('/admin', (HttpRequest req) async {
      req.response.statusCode = 201;
      await echo(req);
    }, middleware: true);
    await startHttpServer(mountConfig(<dynamic>[ends, blocker]));

    HttpClientResponse res = await get('/admin');
    expect(res.statusCode, 201);
    await res.drain<void>();
    res = await get('/admin?block=1');
    expect(res.statusCode, 403);
    await res.drain<void>();

    for (int i = 0; i < 50 && ends.statuses.length < 2; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(ends.statuses, <int>[201, 403]);
  });

  test('ETag sends no second answer for a mount', () async {
    Errors errors = Errors();
    Route.mount('/admin', echo, middleware: true);
    await startHttpServer(mountConfig(<dynamic>[ETag()], errors));

    for (int i = 0; i < 2; i++) {
      HttpClientResponse res = await get('/admin/x');
      expect(res.statusCode, 200);
      expect(await body(res), 'mount:/admin/x');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(errors.reported, isEmpty);
  });

  test('RequestTimeout does not answer for a slow mount', () async {
    Errors errors = Errors();
    Route.mount('/admin', (HttpRequest req) async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await echo(req);
    }, middleware: true);
    await startHttpServer(
      mountConfig(<dynamic>[
        const RequestTimeout(Duration(milliseconds: 50)),
      ], errors),
    );

    HttpClientResponse res = await get('/admin');
    expect(res.statusCode, 200);
    expect(await body(res), 'mount:/admin');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(errors.reported, isEmpty);
  });

  test('the longest matching prefix wins', () async {
    Route.mount('/admin', echo);
    Route.mount('/admin/secure', echo, middleware: true);
    await startHttpServer(mountConfig());

    HttpClientResponse res = await get('/admin/secure/x?block=1');
    expect(res.statusCode, 403);
    await res.drain<void>();
    res = await get('/admin/x?block=1');
    expect(await body(res), 'mount:/admin/x');
  });

  test('the handler does not run after an answer was sent', () async {
    Errors errors = Errors();
    bool ran = false;
    Route.mount('/admin', (HttpRequest req) async {
      ran = true;
      await echo(req);
    }, middleware: true);
    await startHttpServer(mountConfig(<dynamic>[GiveUp(), slow], errors));

    HttpClientResponse res = await get('/admin');
    expect(res.statusCode, 503);
    await res.drain<void>();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(ran, isFalse);
    expect(errors.reported, isEmpty);
  });

  test('// cannot skip a longer mount, %2F stays encoded', () async {
    Route.mount('/admin', echo);
    Route.mount('/admin/secure', echo, middleware: true);
    await startHttpServer(mountConfig());

    // `//` counts as one `/`: the inner mount and its middleware
    HttpClientResponse res = await get('/admin//secure/x?block=1');
    expect(res.statusCode, 403);
    await res.drain<void>();

    // the handler still gets the path as it came
    res = await get('/admin//secure/x');
    expect(await body(res), 'mount:/admin//secure/x');

    // `%2F` stays encoded: it is not a path part, so the outer mount
    res = await get('/admin/secure%2Fx?block=1');
    expect(res.statusCode, 200);
    expect(await body(res), 'mount:/admin/secure%2Fx');
  });

  test(
    'a middleware that throws gives 500, the handler does not run',
    () async {
      Errors errors = Errors();
      Ends ends = Ends();
      bool ran = false;
      Route.mount('/admin', (HttpRequest req) async {
        ran = true;
        await echo(req);
      }, middleware: true);
      await startHttpServer(mountConfig(<dynamic>[ends, thrower], errors));

      HttpClientResponse res = await get('/admin?throw=1');
      expect(res.statusCode, 500);
      await res.drain<void>();
      for (int i = 0; i < 50 && ends.statuses.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(ran, isFalse);
      expect(ends.statuses, <int>[500]);
      expect(errors.reported, hasLength(1));
    },
  );
}

/// a `next` middleware that answers 503 after 50 ms, while the rest of
/// the chain still runs
class GiveUp implements IDoxNextMiddleware {
  @override
  Future<DoxResponse> handle(DoxRequest req, Next next) {
    next();
    return Future<DoxResponse>.delayed(
      const Duration(milliseconds: 50),
      () => response('gave up').statusCode(503),
    );
  }
}

/// waits 200 ms, then goes on
Future<dynamic> slow(DoxRequest req) async {
  await Future<void>.delayed(const Duration(milliseconds: 200));
  return req;
}
