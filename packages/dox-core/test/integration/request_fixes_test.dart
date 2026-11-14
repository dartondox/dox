import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import '../utils/start_http_server.dart';
import '../utils/test_app_key.dart';

int get port => Dox().server.httpServer.port;

Future<(int, String)> send(
  String method,
  String path, {
  Map<String, List<String>> headers = const <String, List<String>>{},
}) async {
  HttpClient client = HttpClient();
  try {
    HttpClientRequest req = await client.open(method, 'localhost', port, path);
    headers.forEach((String name, List<String> values) {
      for (String value in values) {
        req.headers.add(name, value);
      }
    });
    HttpClientResponse res = await req.close();
    return (res.statusCode, await utf8.decodeStream(res));
  } finally {
    client.close();
  }
}

String? lastMethod;

void main() {
  setUpAll(() async {
    Route.get('/fix/users/{name}', (DoxRequest req, String name) {
      return <String, String>{'name': name};
    });
    Route.get('/fix/files/{path*}', (DoxRequest req, String path) {
      return <String, String>{'path': path};
    });
    Route.get('/fix/headers', (DoxRequest req) {
      return <String, dynamic>{'accept': req.headers['accept']};
    });
    Route.get('/fix/method', (DoxRequest req) {
      lastMethod = req.method;
      return 'ok';
    });
    Route.get('/fix/plain', (DoxRequest req) {
      Map<String, dynamic> before = Map<String, dynamic>.of(req.param);
      req.param['x'] = 'set';
      return before;
    });
    await startHttpServer(
      AppConfig(appKey: testAppKey, serverPort: 0, totalIsolate: 1),
    );
  });

  tearDownAll(() async {
    await Dox().server.close();
  });

  test('path params are URL-decoded', () async {
    expect(await send('GET', '/fix/users/a%20b'), (200, '{"name":"a b"}'));
    expect(await send('GET', '/fix/files/a/b%2Fc%C3%A9'), (
      200,
      '{"path":"a/b/cé"}',
    ));
  });

  test('a path param that is not UTF-8 is 404', () async {
    expect((await send('GET', '/fix/users/a%ff')).$1, 404);
    // Uri reads a bad % code as a plain %
    expect(await send('GET', '/fix/users/a%zz'), (200, '{"name":"a%zz"}'));
  });

  test('req.headers joins repeated values with a comma', () async {
    (int, String) res = await send(
      'GET',
      '/fix/headers',
      headers: <String, List<String>>{
        'accept': <String>['text/html', 'application/json'],
      },
    );
    expect(res.$2, '{"accept":"text/html, application/json"}');
  });

  test('req.method is HEAD for a HEAD request on a GET route', () async {
    await send('HEAD', '/fix/method');
    expect(lastMethod, 'HEAD');
    await send('GET', '/fix/method');
    expect(lastMethod, 'GET');
  });

  test(
    'a write to req.param on a plain route does not reach the next request',
    () async {
      expect(await send('GET', '/fix/plain'), (200, '{}'));
      expect(await send('GET', '/fix/plain'), (200, '{}'));
    },
  );
}
