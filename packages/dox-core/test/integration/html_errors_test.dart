import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import '../utils/start_http_server.dart';
import '../utils/test_app_key.dart';

class TeapotException implements Exception {}

class CustomPageException implements Exception {}

class TeapotHandler extends ExceptionHandler {
  const TeapotHandler();

  @override
  void report(Object error, StackTrace stackTrace) {}

  @override
  dynamic render(Object error, HttpRequest req) {
    if (error is TeapotException) {
      return response(<String, String>{'tea': 'yes'}).statusCode(418);
    }
    return super.render(error, req);
  }
}

String customPage(int status, Object error, StackTrace stack, bool debug) {
  if (error is CustomPageException) return '<p>custom $status</p>';
  return defaultErrorPage(status, error, stack, debug);
}

int get port => Dox().server.httpServer.port;

/// status, content type and body of a request
Future<(int, String, String, HttpHeaders)> send(
  String path, {
  String method = 'GET',
  Map<String, String> headers = const <String, String>{
    'accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
  },
}) async {
  HttpClient client = HttpClient();
  try {
    HttpClientRequest req = await client.open(method, 'localhost', port, path);
    headers.forEach(req.headers.set);
    HttpClientResponse res = await req.close();
    return (
      res.statusCode,
      res.headers.contentType?.mimeType ?? '',
      await utf8.decodeStream(res),
      res.headers,
    );
  } finally {
    client.close();
  }
}

void main() {
  setUpAll(() async {
    Route.get('/missing', (DoxRequest req) {
      throw NotFoundHttpException(message: 'no post');
    });
    Route.get('/boom', (DoxRequest req) {
      throw StateError('<script>alert("db host x")</script>');
    });
    Route.get('/teapot', (DoxRequest req) => throw TeapotException());
    Route.get('/custom', (DoxRequest req) => throw CustomPageException());
    Route.get('/invalid', (DoxRequest req) {
      throw ValidationException(message: <String, String>{'name': 'required'});
    });
    Route.get('/only-get', (DoxRequest req) => 'ok');
    await startHttpServer(
      AppConfig(
        appKey: testAppKey,
        serverPort: 0,
        totalIsolate: 1,
        exceptionHandler: const TeapotHandler(),
        htmlErrors: true,
        errorPage: customPage,
      ),
    );
  });

  tearDownAll(() async {
    await Dox().server.close();
  });

  tearDown(() => Env().env.remove('APP_ENV'));

  test('a browser gets an HTML page with only the status', () async {
    Env().env['APP_ENV'] = 'production';
    var (int status, String type, String body, _) = await send('/missing');
    expect(status, 404);
    expect(type, 'text/html');
    expect(body, contains('<h1>404 Not Found</h1>'));
    expect(body, isNot(contains('no post')));
    expect(body, isNot(contains('<pre>')));
    expect(body, isNot(contains('http')));

    (status, type, body, _) = await send('/boom');
    expect(status, 500);
    expect(body, contains('500 Server Error'));
    expect(body, isNot(contains('db host')));
  });

  test('debug adds the escaped message and the stack trace', () async {
    Env().env['APP_ENV'] = 'development';
    var (int status, _, String body, _) = await send('/boom');
    expect(status, 500);
    expect(body, isNot(contains('<script>')));
    expect(body, contains('&lt;script&gt;alert(&quot;db host x&quot;)'));
    expect(body, contains('<pre>'));
    expect(body, contains('html_errors_test.dart'));
  });

  test('a page with no route and a 405 keep their status', () async {
    var (int status, String type, String body, _) = await send('/nope');
    expect((status, type), (404, 'text/html'));
    expect(body, contains('404 Not Found'));
    HttpHeaders headers;
    (status, type, body, headers) = await send('/only-get', method: 'POST');
    expect((status, type), (405, 'text/html'));
    expect(headers.value('allow'), contains('GET'));
  });

  test('JSON clients keep the JSON answer', () async {
    for (Map<String, String> headers in <Map<String, String>>[
      <String, String>{'accept': 'application/json'},
      <String, String>{'accept': 'application/problem+json'},
      <String, String>{'x-requested-with': 'XMLHttpRequest'},
      <String, String>{'content-type': 'application/json'},
    ]) {
      var (int status, String type, String body, _) = await send(
        '/missing',
        headers: headers,
      );
      expect((status, type), (404, 'application/json'), reason: '$headers');
      expect(body, '{"code":"not_found","message":"no post"}');
    }
  });

  test('a validation error stays JSON', () async {
    var (int status, String type, String body, _) = await send('/invalid');
    expect(
      (status, type, body),
      (422, 'application/json', '{"name":"required"}'),
    );
  });

  test('an answer from ExceptionHandler.render stays', () async {
    var (int status, _, String body, _) = await send('/teapot');
    expect((status, body), (418, '{"tea":"yes"}'));
  });

  test('the app can replace the page', () async {
    var (int status, String type, String body, _) = await send('/custom');
    expect((status, type, body), (500, 'text/html', '<p>custom 500</p>'));
  });

  test('defaultErrorPage escapes every value', () {
    String page = defaultErrorPage(
      999,
      NotFoundHttpException(message: '<b>"x" & \'y\'</b>'),
      StackTrace.fromString('<i>stack</i>'),
      true,
    );
    expect(page, contains('<h1>999 Error</h1>'));
    expect(
      page,
      contains('&lt;b&gt;&quot;x&quot; &amp; &#39;y&#39;&lt;&#47;b&gt;'),
    );
    expect(page, contains('&lt;i&gt;stack&lt;&#47;i&gt;'));
  });
}
