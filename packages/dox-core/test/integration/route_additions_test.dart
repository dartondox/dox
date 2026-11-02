import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/http_controller_handler.dart';
import 'package:dox_core/router/route_data.dart';
import 'package:dox_core/testing.dart';
import 'package:test/test.dart';

dynamic addHeader(DoxRequest req) {
  req.httpRequest.response.headers.set('x-global', 'yes');
  return req;
}

class Forgot extends IDoxMiddleware {
  @override
  dynamic handle(IDoxRequest req) => null;
}

class ExtraRouter extends Router {
  @override
  void register() {
    Route.match(<String>['get', 'POST'], 'contact', (DoxRequest req) {
      return 'contact ${req.method}';
    });
    Route.any('hook', (DoxRequest req) => 'hook ${req.method}');
    Route.redirect('home', '/');
    Route.permanentRedirect('old', '/new');

    Route.get(
      'users/{id}',
      (DoxRequest req) => 'id ${req.param['id']}',
    ).where('id', '[0-9]+');
    Route.get('users/{name}', (DoxRequest req) => 'name ${req.param['name']}');
    Route.get(
      'docs/{page}',
      (DoxRequest req) => 'page ${req.param['page']}',
    ).where('page', '.*');
    Route.get(
      'tag/{tag?}',
      (DoxRequest req) => 'tag ${req.param['tag']}',
    ).where('tag', '[a-z]+');
    Route.post('only-post', (DoxRequest req) => 'posted');

    Route.get('forgot', <dynamic>[Forgot(), (DoxRequest req) => 'controller']);

    Route.fallback((DoxRequest req) => 'fallback ${req.uri.path}');
    Route.group('admin', () {
      Route.fallback((DoxRequest req) => 'admin fallback');
    });
  }
}

void main() {
  late DoxTestClient client;

  setUpAll(() async {
    client = await DoxTestClient.start(
      AppConfig(
        appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
        globalMiddleware: <dynamic>[addHeader],
        routers: <Router>[ExtraRouter()],
      ),
    );
  });

  tearDownAll(() async {
    await client.close();
  });

  test('Route.match adds a route for each method', () async {
    (await client.get('/contact')).expectBody('contact GET');
    (await client.post('/contact')).expectBody('contact POST');
    (await client.put('/contact')).expectStatus(405);
  });

  test('Route.any answers the common methods', () async {
    (await client.get('/hook')).expectBody('hook GET');
    (await client.post('/hook')).expectBody('hook POST');
    (await client.put('/hook')).expectBody('hook PUT');
    (await client.patch('/hook')).expectBody('hook PATCH');
    (await client.delete('/hook')).expectBody('hook DELETE');
  });

  test('Route.redirect and Route.permanentRedirect', () async {
    (await client.get('/home')).expectStatus(302).expectHeader('location', '/');
    (await client.post('/home')).expectStatus(302);
    (await client.get('/old'))
        .expectStatus(301)
        .expectHeader('location', '/new');
  });

  test('where picks the route by the param text', () async {
    (await client.get('/users/42')).expectBody('id 42');
    (await client.get('/users/bob')).expectBody('name bob');
  });

  test('where can let a param match slashes', () async {
    (await client.get('/docs/a/b/c')).expectBody('page a/b/c');
  });

  test('where works on an optional param', () async {
    (await client.get('/tag/news')).expectBody('tag news');
    (await client.get('/tag')).expectBody('tag null');
    (await client.get('/tag/123'))
        .expectStatus(200)
        .expectBody('fallback /tag/123');
  });

  test(
    'fallback answers GET for an unknown path, with global middleware',
    () async {
      (await client.get('/nope/x'))
          .expectStatus(200)
          .expectBody('fallback /nope/x')
          .expectHeader('x-global', 'yes');
    },
  );

  test('a group fallback wins under its prefix', () async {
    (await client.get('/admin/x')).expectBody('admin fallback');
    (await client.get('/admin')).expectBody('admin fallback');
    (await client.get('/administrator')).expectBody('fallback /administrator');
  });

  test('fallback is only for GET and HEAD', () async {
    (await client.post('/nope')).expectStatus(404);
    (await client.delete('/only-post')).expectStatus(405);
  });

  test('a middleware that gives null still ends with an empty 200', () async {
    (await client.get('/forgot')).expectStatus(200).expectBody('');
  });

  group('null middleware warning |', () {
    List<String> logs(void Function() fn) {
      _Capture err = _Capture();
      IOOverrides.runZoned(fn, stderr: () => err);
      return err.lines;
    }

    RouteData route = RouteData(
      method: 'GET',
      path: '/x',
      controllers: <dynamic>[],
    );

    tearDown(() => Env().env.remove('APP_ENV'));

    test('logs once in development', () {
      Env().env['APP_ENV'] = 'development';
      Forgot middleware = Forgot();
      List<String> lines = logs(() {
        warnNullMiddleware(middleware, route);
        warnNullMiddleware(middleware, route);
      });
      expect(lines, hasLength(1));
      expect(lines.first, contains('Forgot on GET /x returned null'));
    });

    test('logs nothing in production', () {
      Env().env['APP_ENV'] = 'production';
      expect(logs(() => warnNullMiddleware(Forgot(), route)), isEmpty);
    });
  });
}

/// keeps the lines written to stderr
class _Capture implements Stdout {
  final List<String> lines = <String>[];

  @override
  void writeln([Object? object = '']) => lines.add('$object');

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
