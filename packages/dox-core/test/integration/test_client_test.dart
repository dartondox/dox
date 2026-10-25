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

class WebRouter extends Router {
  @override
  String get prefix => 'web';

  @override
  List<dynamic> get middleware => <dynamic>[
    const SessionMiddleware(),
    const CsrfMiddleware(),
  ];

  @override
  void register() {
    Route.get('login', (DoxRequest req) => 'form');
    Route.post('login', (DoxRequest req) {
      req.session.regenerate();
      req.session.put('user', req.input('email'));
      return redirect('/web/me', status: 303);
    });
    Route.get('me', (DoxRequest req) {
      return req.session.get('user') ?? response('guest').statusCode(401);
    });
    Route.post('logout', (DoxRequest req) {
      req.session.invalidate();
      return redirect('/web/login');
    });
    Route.get('flavor', (DoxRequest req) {
      return response('ok').cookie(DoxCookie('flavor', 'x', encrypt: false));
    });
    Route.get('flavor/max-age', (DoxRequest req) {
      return response('ok')
          .cookie(DoxCookie('flavor', 'x', encrypt: false), setExpire: true);
    });
    Route.get('flavor/expires', (DoxRequest req) {
      return response(
        'ok',
      ).header('Set-Cookie', 'flavor=x; Expires=Sat, 01 Jan 2000 00:00:00 GMT');
    });
    Route.put('save', (DoxRequest req) => 'saved');
  }
}

void main() {
  late DoxTestClient client;

  setUpAll(() async {
    client = await DoxTestClient.start(
      AppConfig(
        appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
        routers: <Router>[ClientRouter(), WebRouter()],
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

  group('withSession', () {
    test('log in and out with a session and CSRF', () async {
      DoxTestClient browser = client.withSession();
      Map<String, String> form = <String, String>{'email': 'ann@example.com'};

      // no XSRF-TOKEN cookie yet: the post has no token
      (await browser.post('/web/login', body: form)).expectStatus(419);

      (await browser.get('/web/login')).expectStatus(200);
      expect(
        browser.cookies.keys,
        containsAll(<String>['dox_session', 'XSRF-TOKEN']),
      );

      (await browser.post(
        '/web/login',
        body: form,
      )).expectStatus(303).expectHeader('location', '/web/me');
      (await browser.get('/web/me')).expectBody('ann@example.com');

      // another browser and the plain client have no session
      (await client.withSession().get('/web/me')).expectStatus(401);
      (await client.get('/web/me')).expectStatus(401);

      (await browser.post('/web/logout')).expectStatus(302);
      (await browser.get('/web/me')).expectStatus(401);
    });

    test('sends X-XSRF-TOKEN on PUT, not on GET', () async {
      DoxTestClient browser = client.withSession();
      await browser.get('/web/login');
      (await browser.put('/web/save')).expectStatus(200).expectBody('saved');
      (await client.put('/web/save')).expectStatus(419);
    });

    test('removes a cookie on Max-Age=0 or an old Expires', () async {
      DoxTestClient browser = client.withSession();
      await browser.get('/web/flavor');
      expect(browser.cookies['flavor'], 'x');
      await browser.get('/web/flavor/max-age');
      expect(browser.cookies, isNot(contains('flavor')));
      await browser.get('/web/flavor');
      await browser.get('/web/flavor/expires');
      expect(browser.cookies, isNot(contains('flavor')));
    });

    test('copies share the cookies, the plain client keeps none', () async {
      DoxTestClient browser = client.withSession();
      DoxTestClient copy = browser.withHeaders(<String, String>{'X-Test': 'a'});
      await copy.get('/web/flavor');
      expect(browser.cookies['flavor'], 'x');
      await client.get('/web/flavor');
      expect(client.cookies, isEmpty);
    });
  });
}
