import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/testing.dart';
import 'package:test/test.dart';

const String svg = '<svg xmlns="http://www.w3.org/2000/svg"></svg>';

class After implements IDoxNextMiddleware {
  @override
  Future<DoxResponse> handle(DoxRequest req, Next next) async {
    DoxResponse res = await next();
    return res.header('X-After', 'yes');
  }
}

/// a value json can not encode, so writing the response fails
class NotJson {}

/// thrown by a route. [BrokenHandler] answers it with a body that fails.
class BreakTheHandler implements Exception {}

/// its answer for [BreakTheHandler] fails too, while it is written
class BrokenHandler extends ExceptionHandler {
  BrokenHandler();

  final List<Object> reported = <Object>[];

  @override
  void report(Object error, StackTrace stackTrace) => reported.add(error);

  @override
  dynamic render(Object error, HttpRequest req) {
    if (error is BreakTheHandler) return response(<NotJson>[NotJson()]);
    return super.render(error, req);
  }
}

final BrokenHandler handler = BrokenHandler();

void routes() {
  Route.get('svg', (DoxRequest req) {
    return response(svg).header('Content-Type', 'image/svg+xml');
  });
  Route.get('svg-lower', (DoxRequest req) {
    return response(svg).header('content-type', 'image/svg+xml');
  });
  Route.get('broken', (DoxRequest req) => response(<NotJson>[NotJson()]));
  Route.get('broken-async', (DoxRequest req) async {
    return response(<NotJson>[NotJson()]);
  });
  Route.get('broken-handler', (DoxRequest req) => throw BreakTheHandler());
  Route.get('broken-handler-async', (DoxRequest req) async {
    throw BreakTheHandler();
  });
  Route.get('broken-svg', (DoxRequest req) {
    return response(<NotJson>[NotJson()])
        .header('Content-Type', 'image/svg+xml');
  });
}

class PlainRouter extends Router {
  @override
  String get prefix => 'plain';

  @override
  void register() => routes();
}

class AfterRouter extends Router {
  @override
  String get prefix => 'after';

  @override
  List<dynamic> get middleware => <dynamic>[After()];

  @override
  void register() => routes();
}

class SessionRouter extends Router {
  @override
  String get prefix => 'session';

  @override
  List<dynamic> get middleware => <dynamic>[const SessionMiddleware()];

  @override
  void register() {
    routes();
    Route.get('svg-put', (DoxRequest req) {
      req.session.put('seen', true);
      return response(svg).header('Content-Type', 'image/svg+xml');
    });
  }
}

void main() {
  late DoxTestClient client;

  setUpAll(() async {
    client = await DoxTestClient.start(
      AppConfig(
        appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
        routers: <Router>[PlainRouter(), AfterRouter(), SessionRouter()],
        exceptionHandler: handler,
      ),
    );
  });

  tearDownAll(() async {
    await client.close();
  });

  Future<TestResponse> get(String path) {
    return client.get(path).timeout(const Duration(seconds: 5));
  }

  for (String group in <String>['plain', 'after', 'session']) {
    test('$group: header() sets the content type', () async {
      TestResponse res = await get('/$group/svg');
      expect(res.status, 200);
      expect(res.header(HttpHeaders.contentTypeHeader), 'image/svg+xml');
      expect(res.body, svg);
    });

    test('$group: header() with a lower case name works too', () async {
      TestResponse res = await get('/$group/svg-lower');
      expect(res.status, 200);
      expect(res.header(HttpHeaders.contentTypeHeader), 'image/svg+xml');
    });

    test('$group: a failing response answers 500, no hang', () async {
      expect((await get('/$group/broken')).status, 500);
      expect((await get('/$group/broken-async')).status, 500);
      expect((await get('/$group/broken-svg')).status, 500);
    });

    test('$group: a failing error answer still answers 500', () async {
      handler.reported.clear();
      expect((await get('/$group/broken-handler')).status, 500);
      expect((await get('/$group/broken-handler-async')).status, 500);
      // the route error and the error of the failed answer
      expect(handler.reported.whereType<BreakTheHandler>(), hasLength(2));
      expect(
        handler.reported.whereType<JsonUnsupportedObjectError>(),
        hasLength(2),
      );
    });

    test('$group: in development the error text is sent, no hang', () async {
      Env().env['APP_ENV'] = 'development';
      addTearDown(() => Env().env.remove('APP_ENV'));
      expect((await get('/$group/broken-svg')).status, 500);
      expect((await get('/$group/svg')).status, 200);
    });
  }

  test('session: header() works when the session cookie is sent', () async {
    TestResponse res = await get('/session/svg-put');
    expect(res.status, 200);
    expect(res.header(HttpHeaders.contentTypeHeader), 'image/svg+xml');
    expect(res.cookies, isNotEmpty);
  });
}
