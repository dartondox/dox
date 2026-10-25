import 'package:dox_core/dox_core.dart';
import 'package:dox_core/router/route_data.dart';
import 'package:dox_core/testing.dart';
import 'package:test/test.dart';

List<String> calls = <String>[];

class Around implements IDoxNextMiddleware {
  @override
  Future<DoxResponse> handle(DoxRequest req, Next next) async {
    calls.add('around before');
    DoxResponse res = await next();
    calls.add('around after');
    return res.header('X-Around', '${res.status ?? 200}');
  }
}

/// turns a 302 after a form post into a 303, like Inertia needs
class SeeOther implements IDoxNextMiddleware {
  @override
  Future<DoxResponse> handle(DoxRequest req, Next next) async {
    DoxResponse res = await next();
    if (res.status == 302 && req.httpRequest.method != 'GET') {
      res.statusCode(303);
    }
    return res;
  }
}

Future<DoxResponse> timer(DoxRequest req, Next next) async {
  DoxResponse res = await next();
  return res.header('X-Function', 'yes');
}

dynamic stop(DoxRequest req, Next next) => 'stopped';

dynamic before(DoxRequest req) {
  calls.add('before');
  return req;
}

class NextRouter extends Router {
  @override
  void register() {
    Route.get('/order', <dynamic>[
      Around(),
      before,
      (DoxRequest req) {
        calls.add('controller');
        return 'ok';
      },
    ]);
    Route.post('/save', <dynamic>[
      SeeOther(),
      (DoxRequest req) => redirect('/done'),
    ]);
    Route.get('/missing', <dynamic>[
      Around(),
      (DoxRequest req) => throw NotFoundHttpException(),
    ]);
    Route.get('/function', <dynamic>[timer, (DoxRequest req) => 'ok']);
    Route.get('/stop', <dynamic>[stop, (DoxRequest req) => 'ok']);
    Route.get('/plain', <dynamic>[before, (DoxRequest req) => 'plain']);
  }
}

void main() {
  late DoxTestClient client;

  setUpAll(() async {
    client = await DoxTestClient.start(
      AppConfig(
        appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
        routers: <Router>[NextRouter()],
      ),
    );
  });

  tearDownAll(() async {
    await client.close();
  });

  setUp(calls.clear);

  test('the after part runs after the controller', () async {
    (await client.get('/order'))
        .expectStatus(200)
        .expectBody('ok')
        .expectHeader('x-around', '200');
    expect(calls, <String>[
      'around before',
      'before',
      'controller',
      'around after',
    ]);
  });

  test('the after part can change the status: 302 to 303', () async {
    (await client.post(
      '/save',
      body: <String, dynamic>{},
    )).expectStatus(303).expectHeader('location', '/done');
  });

  test('the after part sees the response of a thrown error', () async {
    (await client.get('/missing'))
        .expectStatus(404)
        .expectHeader('x-around', '404')
        .expectJson(containsPair('code', 'not_found'));
  });

  test('a function middleware with next', () async {
    (await client.get('/function'))
        .expectBody('ok')
        .expectHeader('x-function', 'yes');
  });

  test('a next middleware can stop early', () async {
    (await client.get('/stop')).expectBody('stopped');
  });

  test('a route with no next middleware does not use the chain', () async {
    (await client.get('/plain')).expectBody('plain');
    RouteData route = Route().routes.firstWhere(
      (RouteData r) => r.path == '/plain',
    );
    expect(route.usesNext, isFalse);
  });
}
