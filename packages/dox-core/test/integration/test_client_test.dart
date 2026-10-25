import 'package:dox_core/dox_core.dart';
import 'package:dox_core/testing.dart';
import 'package:test/test.dart';

Map<String, dynamic> echo(DoxRequest req) {
  return <String, dynamic>{
    'method': req.method,
    'body': req.body,
    'query': req.query,
    'auth': req.header('authorization'),
    'x': req.header('x-test'),
  };
}

class ClientRouter extends Router {
  @override
  void register() {
    Route.get('/ping', (DoxRequest req) => 'pong');
    Route.get('/echo', echo);
    Route.post('/echo', echo);
    Route.put('/echo', echo);
    Route.patch('/echo', echo);
    Route.delete('/echo', echo);
    Route.get('/old', (DoxRequest req) {
      return response('').statusCode(302).header('Location', '/ping');
    });
  }
}

void main() {
  late DoxTestClient client;

  setUpAll(() async {
    client = await DoxTestClient.start(
      AppConfig(
        appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
        routers: <Router>[ClientRouter()],
      ),
    );
  });

  tearDownAll(() async {
    await client.close();
  });

  test('get a text answer', () async {
    TestResponse res = await client.get('/ping');
    expect(res.status, 200);
    expect(res.body, 'pong');
    res.expectStatus(200).expectBody('pong');
  });

  test('a query in the path', () async {
    (await client.get('/echo?page=2'))
        .expectJson(containsPair('query', <String, dynamic>{'page': '2'}));
  });

  test('post, put, patch and delete send JSON', () async {
    Map<String, dynamic> body = <String, dynamic>{'title': 'Hi'};
    for (String method in <String>['POST', 'PUT', 'PATCH', 'DELETE']) {
      TestResponse res = switch (method) {
        'POST' => await client.post('/echo', body: body),
        'PUT' => await client.put('/echo', body: body),
        'PATCH' => await client.patch('/echo', body: body),
        _ => await client.delete('/echo', body: body),
      };
      res
          .expectStatus(200)
          .expectHeader('content-type', contains('application/json'))
          .expectJson(containsPair('method', method))
          .expectJson(containsPair('body', body));
    }
  });

  test('withToken and withHeaders make a copy', () async {
    DoxTestClient ann = client.withToken('abc').withHeaders(<String, String>{
      'X-Test': 'yes',
    });
    (await ann.get('/echo'))
        .expectJson(containsPair('auth', 'Bearer abc'))
        .expectJson(containsPair('x', 'yes'));
    (await client.get('/echo')).expectJson(containsPair('auth', null));
  });

  test('headers of one request', () async {
    (await client.get(
      '/echo',
      headers: <String, String>{'X-Test': 'once'},
    )).expectJson(containsPair('x', 'once'));
  });

  test('redirects are not followed', () async {
    (await client.get('/old'))
        .expectStatus(302)
        .expectHeader('location', '/ping');
  });

  test('a wrong status fails the test', () async {
    TestResponse res = await client.get('/nothing');
    expect(res.status, 404);
    expect(() => res.expectStatus(200), throwsA(isA<TestFailure>()));
  });
}
