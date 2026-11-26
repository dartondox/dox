import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/testing.dart';
import 'package:test/test.dart';

import '../utils/test_app_key.dart';

/// keeps every reported error
class Errors extends ExceptionHandler {
  final List<Object> reported = <Object>[];

  @override
  void report(Object error, StackTrace stackTrace) => reported.add(error);
}

dynamic syncThrow(DoxRequest req) {
  throw StateError('sync failure');
}

dynamic bodyRoute(DoxRequest req) => 'body ok';

/// writes the answer itself, with no `next` middleware around
dynamic rawAnswer(DoxRequest req) async {
  req.takeOverResponse();
  HttpResponse res = req.httpRequest.response;
  res.write('raw');
  await res.close();
  return 'ignored';
}

DoxResponse? render(Object error, DoxRequest req) {
  return response('rendered: ${error.runtimeType}').statusCode(299);
}

class PlainRouter extends Router {
  @override
  void register() {
    Route.get('sync', syncThrow).renderErrorsWith(render);
    Route.get('sync-plain', syncThrow);
    Route.get('raw', rawAnswer);
    Route.post('body', bodyRoute).renderErrorsWith(render);
    Route.post('body-plain', bodyRoute);
  }
}

/// no global middleware at all, so no `next` middleware runs
void main() {
  late DoxTestClient client;
  Errors errors = Errors();

  setUpAll(() async {
    client = await DoxTestClient.start(
      AppConfig(
        appKey: testAppKey,
        routers: <Router>[PlainRouter()],
        exceptionHandler: errors,
      ),
    );
  });

  tearDownAll(() async {
    await client.close();
  });

  setUp(errors.reported.clear);

  test('renderErrorsWith gets a sync throw', () async {
    TestResponse res = await client.get('/sync');
    res.expectStatus(299).expectBody('rendered: StateError');
    expect(errors.reported, hasLength(1));
    (await client.get('/sync-plain')).expectStatus(500);
  });

  test('takeOverResponse works with no next middleware', () async {
    (await client.get('/raw')).expectStatus(200).expectBody('raw');
    (await client.send('HEAD', '/raw')).expectStatus(200);
  });

  test('renderErrorsWith gets a body that fails to read', () async {
    /// the native server stops a too big body before Dart, so use a
    /// multipart body that the reader rejects
    Map<String, String> form = <String, String>{
      'content-type': 'multipart/form-data; boundary=abc',
    };
    String bad = '--abc\r\nContent-Disposition: form-data; name="a"\r\n';
    TestResponse res = await client.post('/body', body: bad, headers: form);
    res.expectStatus(299);

    /// a body that is not valid is a 400, and a 400 is not reported
    expect(errors.reported, isEmpty);
    TestResponse plain = await client.post(
      '/body-plain',
      body: bad,
      headers: form,
    );
    expect(plain.status, 400);
  });
}
