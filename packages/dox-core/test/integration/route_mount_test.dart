import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import '../utils/start_http_server.dart';

/// stops every request that has `?block=1`
dynamic blocker(DoxRequest req) {
  if (req.input('block') == '1') return response('blocked').statusCode(403);
  return req;
}

AppConfig mountConfig() {
  return AppConfig(
    appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
    serverPort: 0,
    totalIsolate: 1,
    globalMiddleware: <dynamic>[const SecurityHeaders(), blocker],
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
}
