import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import '../utils/start_http_server.dart';

class Person {
  Person(this.id);
  final String id;
}

class TeapotException implements Exception {}

/// keeps what it reported, and answers [TeapotException] with 418
class TestExceptionHandler extends ExceptionHandler {
  TestExceptionHandler();

  final List<Object> reported = <Object>[];

  @override
  void report(Object error, StackTrace stackTrace) {
    reported.add(error);
  }

  @override
  dynamic render(Object error, HttpRequest req) {
    if (error is TeapotException) {
      return response(<String, String>{'tea': 'yes'}).statusCode(418);
    }
    if (error is ArgumentError) throw StateError('handler broke');
    return super.render(error, req);
  }
}

Future<Person?> findPerson(String id) async {
  return id == '404' ? null : Person(id);
}

TestExceptionHandler handler = TestExceptionHandler();

int get port => Dox().server.httpServer.port;

Future<(int, String)> get(String path) async {
  HttpClient client = HttpClient();
  try {
    HttpClientRequest req = await client.get('localhost', port, path);
    HttpClientResponse res = await req.close();
    return (res.statusCode, await utf8.decodeStream(res));
  } finally {
    client.close();
  }
}

void main() {
  setUpAll(() async {
    Route.bind<Person>('person', findPerson);
    Route.get('/people/{person}', (DoxRequest req, Person person) {
      return <String, String>{'id': person.id};
    });
    Route.get('/people/{person}/raw', (DoxRequest req) {
      return <String, String>{'id': req.bound<Person>('person').id};
    });
    Route.get('/people/{person}/posts/{page}', (Person person, int page) {
      return <String, Object>{'id': person.id, 'page': page};
    });
    Route.get('/fail/teapot', (DoxRequest req) => throw TeapotException());
    Route.get('/fail/boom', (DoxRequest req) => throw StateError('db host x'));
    Route.get('/fail/broken', (DoxRequest req) => throw ArgumentError('x'));
    Route.get('/fail/missing', (DoxRequest req) {
      throw NotFoundHttpException(message: 'no post');
    });
    Route.get('/fail/gone', (DoxRequest req) {
      throw NotFoundHttpException(
        message: <String, String>{'error': 'not_found'},
      );
    });
    Route.get('/fail/invalid', (DoxRequest req) {
      throw ValidationException(message: <String, String>{'name': 'required'});
    });
    await startHttpServer(
      AppConfig(
        appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
        serverPort: 0,
        totalIsolate: 1,
        exceptionHandler: handler,
      ),
    );
  });

  tearDownAll(() async {
    await Dox().server.close();
  });

  setUp(handler.reported.clear);

  group('route binding |', () {
    test('typed controller parameter gets the bound value', () async {
      expect(await get('/people/7'), (200, '{"id":"7"}'));
    });

    test('req.bound reads the bound value', () async {
      expect(await get('/people/8/raw'), (200, '{"id":"8"}'));
    });

    test('bound and plain path params together', () async {
      expect(await get('/people/9/posts/2'), (200, '{"id":"9","page":2}'));
    });

    test('binder that gives null answers 404', () async {
      (int, String) res = await get('/people/404');
      expect(res.$1, 404);
      expect(jsonDecode(res.$2), <String, String>{
        'code': 'not_found',
        'message': 'Not Found',
      });
    });
  });

  group('exception handler |', () {
    test('custom render', () async {
      expect(await get('/fail/teapot'), (418, '{"tea":"yes"}'));
      expect(handler.reported.single, isA<TeapotException>());
    });

    test('http exceptions keep status and shape, not reported', () async {
      expect(await get('/fail/missing'), (
        404,
        '{"code":"not_found","message":"no post"}',
      ));
      expect(await get('/fail/invalid'), (422, '{"name":"required"}'));
      // a map message is sent as JSON, with the status of the exception
      expect(await get('/fail/gone'), (404, '{"error":"not_found"}'));
      expect(
        (await get('/no/route')).$2,
        '{"code":"not_found","message":"GET /no/route not found"}',
      );
      expect(handler.reported, isEmpty);
    });

    test('unknown error is 500 and hides details in production', () async {
      Env().env['APP_ENV'] = 'production';
      try {
        expect(await get('/fail/boom'), (
          500,
          '{"code":"server_error","message":"Server Error"}',
        ));
      } finally {
        Env().env.remove('APP_ENV');
      }
      expect(handler.reported.single, isA<StateError>());
    });

    test('unknown error shows its text in development', () async {
      Env().env['APP_ENV'] = 'development';
      try {
        (int, String) res = await get('/fail/boom');
        expect(res.$1, 500);
        expect(res.$2, contains('db host x'));
      } finally {
        Env().env.remove('APP_ENV');
      }
    });

    test('a render that throws still sends the default answer', () async {
      expect(await get('/fail/broken'), (
        500,
        '{"code":"server_error","message":"Server Error"}',
      ));
    });
  });
}
