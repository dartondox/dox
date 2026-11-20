import 'dart:async';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/testing.dart';
import 'package:test/test.dart';

import '../utils/test_app_key.dart';

/// adds a header after the controller, like `ETag` changes the answer
Future<DoxResponse> after(DoxRequest req, Next next) async {
  DoxResponse res = await next();
  return res.header('x-after', 'yes');
}

/// counts the answers it sees
class CountingHandler extends ResponseHandlerInterface {
  int calls = 0;

  @override
  DoxResponse handle(DoxResponse res) {
    calls++;
    return res;
  }
}

/// keeps every reported error
class Errors extends ExceptionHandler {
  final List<Object> reported = <Object>[];

  @override
  void report(Object error, StackTrace stackTrace) => reported.add(error);
}

/// adds a header on every route, to check it is taken out
class Tag implements IDoxMiddleware {
  const Tag();

  @override
  dynamic handle(IDoxRequest req) {
    req.httpRequest.response.headers.set('x-tag', 'yes');
    return req;
  }
}

/// throws on `?fail=1`
dynamic failing(DoxRequest req) {
  if (req.input('fail') == '1') throw StateError('middleware failed');
  return req;
}

/// writes the answer itself
Future<String> rawAnswer(DoxRequest req) async {
  req.takeOverResponse();
  HttpResponse res = req.httpRequest.response;
  res.headers.contentType = ContentType.text;
  res.write('raw');
  await res.close();
  return 'ignored';
}

/// takes over, then throws before it ends the answer
Future<void> rawThenThrow(DoxRequest req) async {
  req.takeOverResponse();
  HttpResponse res = req.httpRequest.response;
  res.write('partial');
  await res.close();
  throw StateError('late failure');
}

bool isRpc(HttpRequest req) {
  return req.method == 'POST' && req.headers.value('x-kind') == 'rpc';
}

DoxResponse? rpcErrors(Object error, DoxRequest req) {
  if (req.input('own') == '1') {
    req.takeOverResponse();
    HttpResponse res = req.httpRequest.response;
    res.headers.set('x-rpc-status', '13');
    res.close();
    return null;
  }
  if (req.input('default') == '1') return null;
  return response('rpc error: $error').statusCode(299);
}

class HooksRouter extends Router {
  @override
  List<dynamic> get middleware => <dynamic>[after, const Tag()];

  @override
  void register() {
    Route.get('raw', rawAnswer);
    Route.get('raw-throw', rawThenThrow);
    Route.get('plain', (DoxRequest req) => 'plain');

    Route.fallback((DoxRequest req) => 'page fallback');
    Route.fallback((DoxRequest req) => 'rpc fallback', when: isRpc);
    Route.post('known', (DoxRequest req) => 'known');

    Route.get('slow', slow).withoutMiddleware<RequestTimeout>();
    Route.get('slow-timed', slow);
    Route.get('untagged', (DoxRequest req) => 'ok').withoutMiddleware<Tag>();

    Route.post('rpc', <dynamic>[
      failing,
      (DoxRequest req) => 'rpc ok',
    ]).renderErrorsWith(rpcErrors);
    Route.post('no-renderer', <dynamic>[failing, (DoxRequest req) => 'ok']);
  }
}

Future<String> slow(DoxRequest req) async {
  await Future<void>.delayed(const Duration(milliseconds: 300));
  return 'slow done';
}

void main() {
  late DoxTestClient client;
  CountingHandler counter = CountingHandler();
  Errors errors = Errors();

  setUpAll(() async {
    client = await DoxTestClient.start(
      AppConfig(
        appKey: testAppKey,
        globalMiddleware: <dynamic>[
          const RequestTimeout(Duration(milliseconds: 100)),
        ],
        routers: <Router>[HooksRouter()],
        responseHandler: counter,
        exceptionHandler: errors,
      ),
    );
  });

  tearDownAll(() async {
    await client.close();
  });

  setUp(() {
    counter.calls = 0;
    errors.reported.clear();
  });

  group('takeOverResponse', () {
    test('Dox sends nothing after the handler', () async {
      TestResponse res = await client.get('/raw');
      res.expectStatus(200).expectBody('raw');
      expect(res.headers['x-after'], isNull);
      expect(counter.calls, 0);
    });

    test('an error after it is reported, and not sent', () async {
      TestResponse res = await client.get('/raw-throw');
      res.expectStatus(200).expectBody('partial');
      expect(errors.reported.single, isA<StateError>());
      expect(counter.calls, 0);
    });

    test('other routes still get the response handler', () async {
      (await client.get('/plain')).expectBody('plain');
      expect(counter.calls, 1);
    });
  });

  group('Route.fallback when', () {
    test('answers any method when it gives true', () async {
      (await client.post(
        '/pkg.Service/Method',
        headers: <String, String>{'x-kind': 'rpc'},
      )).expectBody('rpc fallback');
    });

    test('other requests keep 404 and the plain fallback', () async {
      (await client.post('/pkg.Service/Method')).expectStatus(404);
      (await client.get('/nothing')).expectBody('page fallback');
    });

    test('a route still wins', () async {
      (await client.post(
        '/known',
        headers: <String, String>{'x-kind': 'rpc'},
      )).expectBody('known');
    });
  });

  group('withoutMiddleware', () {
    test('a route skips a global RequestTimeout', () async {
      (await client.get('/slow')).expectStatus(200).expectBody('slow done');
      (await client.get('/slow-timed')).expectStatus(503);
    });

    test('takes out router middleware of the type', () async {
      TestResponse res = await client.get('/untagged');
      res.expectBody('ok');
      expect(res.headers['x-tag'], isNull);
      expect((await client.get('/plain')).headers['x-tag'], 'yes');
    });
  });

  group('renderErrorsWith', () {
    test('a middleware error goes to the route renderer', () async {
      TestResponse res = await client.post('/rpc?fail=1');
      res.expectStatus(299).expectBody(contains('middleware failed'));
      expect(errors.reported.single, isA<StateError>());
    });

    test('null gives the default answer', () async {
      (await client.post('/rpc?fail=1&default=1')).expectStatus(500);
    });

    test('the renderer can send the answer itself', () async {
      TestResponse res = await client.post('/rpc?fail=1&own=1');
      res.expectStatus(200).expectHeader('x-rpc-status', '13');
      expect(counter.calls, 0);
    });

    test('routes without one keep the default answer', () async {
      (await client.post('/no-renderer?fail=1')).expectStatus(500);
      (await client.post('/rpc')).expectBody('rpc ok');
    });
  });

  test('showErrors follows APP_ENV', () {
    addTearDown(() => Env().env.remove('APP_ENV'));
    Env().env['APP_ENV'] = 'production';
    expect(showErrors(), isFalse);
    Env().env['APP_ENV'] = 'local';
    expect(showErrors(), isTrue);
  });
}
