import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/testing.dart';
import 'package:test/test.dart';

import '../utils/test_app_key.dart';

const String boundary = 'doxerrboundary';

class Errors extends ExceptionHandler {
  final List<Object> reported = <Object>[];

  @override
  void report(Object error, StackTrace stackTrace) => reported.add(error);
}

bool anyPost(HttpRequest req) => req.method == 'POST';

/// takes over and throws before it writes anything
Future<void> rawNoWrite(DoxRequest req) async {
  req.takeOverResponse();
  throw StateError('before the head');
}

/// takes over, sends part of its answer, then throws
Future<void> rawAfterWrite(DoxRequest req) async {
  req.takeOverResponse();
  HttpResponse res = req.httpRequest.response;
  res.write('part');
  await res.flush();
  throw StateError('after the head');
}

class ErrRouter extends Router {
  @override
  void register() {
    /// a path with a route for GET only, and a `when` fallback for POST
    Route.get('only-get', (DoxRequest req) => 'get');
    Route.fallback(
      (DoxRequest req) => 'fallback note=${req.input('note')}',
      when: anyPost,
    );
    Route.get('raw-no-write', rawNoWrite);
    Route.get('raw-after-write', rawAfterWrite);
  }
}

void main() {
  late DoxTestClient client;
  Errors errors = Errors();

  setUpAll(() async {
    client = await DoxTestClient.start(
      AppConfig(
        appKey: testAppKey,
        globalMiddleware: <dynamic>[const MethodOverride()],
        routers: <Router>[ErrRouter()],
        exceptionHandler: errors,
      ),
    );
  });

  tearDownAll(() async {
    await client.close();
  });

  setUp(() => errors.reported.clear());

  test('withoutMiddleware with no type throws', () {
    expect(
      () => Route.get('x-obj', (DoxRequest r) => 'x').withoutMiddleware(),
      throwsArgumentError,
    );
    expect(
      () => Route.get(
        'x-obj2',
        (DoxRequest r) => 'x',
      ).withoutMiddleware<Object>(),
      throwsArgumentError,
    );
  });

  test(
    'a when fallback after MethodOverride reads a multipart body once',
    () async {
      String body =
          '--$boundary\r\n'
          'Content-Disposition: form-data; name="note"\r\n\r\n'
          'hello\r\n'
          '--$boundary--\r\n';
      TestResponse res = await client.post(
        '/only-get',
        body: utf8.encode(body),
        headers: <String, String>{
          'content-type': 'multipart/form-data; boundary=$boundary',
        },
      );
      res.expectStatus(200).expectBody('fallback note=hello');
    },
  );

  test('takeOverResponse then a throw before any write gets a 500', () async {
    (await client.get('/raw-no-write')).expectStatus(500);
    expect(errors.reported.single, isA<StateError>());
  });

  test('takeOverResponse then a throw after a write still ends', () async {
    TestResponse res = await client
        .get('/raw-after-write')
        .timeout(const Duration(seconds: 5));
    res.expectStatus(200).expectBody('part');
    expect(errors.reported.single, isA<StateError>());
  });
}
