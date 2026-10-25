import 'package:dox_core/dox_core.dart';
import 'package:dox_core/testing.dart';
import 'package:test/test.dart';

const SessionConfig cacheSession = SessionConfig(
  driver: 'cache',
  store: 'memory',
  cookie: 'cache_session',
);

void sessionRoutes() {
  Route.get('put', (DoxRequest req) {
    req.session.put('name', req.input('name'));
    return 'ok';
  });
  Route.get('get', (DoxRequest req) {
    return <String, dynamic>{
      'name': req.session.get('name'),
      'message': req.session.get('message'),
      'has': req.session.has('name'),
    };
  });
  Route.get('flash', (DoxRequest req) {
    req.session.flash('message', 'Saved');
    return 'ok';
  });
  Route.get('id', (DoxRequest req) => req.session.token);
  Route.get('regenerate', (DoxRequest req) {
    req.session.regenerate();
    return req.session.token;
  });
  Route.get('forget', (DoxRequest req) {
    req.session.forget('name');
    return req.session.all();
  });
  Route.get(
    'pull',
    (DoxRequest req) => <String, dynamic>{
      'value': req.session.pull('name'),
      'after': req.session.get('name'),
    },
  );
  Route.get('invalidate', (DoxRequest req) {
    req.session.invalidate();
    return req.session.all();
  });
  Route.get('untouched', (DoxRequest req) => 'ok');
  Route.get('big', (DoxRequest req) {
    req.session.put('big', 'x' * 5000);
    return 'ok';
  });
}

class SessionRouter extends Router {
  @override
  List<dynamic> get middleware => <dynamic>[const SessionMiddleware()];

  @override
  void register() {
    sessionRoutes();
    Route.middleware(
      <dynamic>[
        const CsrfMiddleware(except: <String>['/api/*', '/hook']),
      ],
      () {
        Route.get('form', (DoxRequest req) {
          return <String, dynamic>{
            'errors': req.session.errors,
            'email': req.session.old('email'),
            'password': req.session.old('password'),
          };
        });
        Route.post('form', (DoxRequest req) async {
          await req.validateSchema(
            v.object(<String, Schema<Object?>>{
              'email': v.string().email(),
              'password': v.string().min(8),
            }),
          );
          return 'saved';
        });
        Route.post('save', (DoxRequest req) => 'saved');
        Route.post('api/save', (DoxRequest req) => 'saved');
        Route.post('hook', (DoxRequest req) => 'saved');
      },
    );
  }
}

class CacheSessionRouter extends Router {
  @override
  String get prefix => 'cache';

  @override
  List<dynamic> get middleware => <dynamic>[
    const SessionMiddleware(cacheSession),
  ];

  @override
  void register() => sessionRoutes();
}

class NoSessionRouter extends Router {
  @override
  String get prefix => 'plain';

  @override
  void register() {
    Route.get('session', (DoxRequest req) => req.session.get('x'));
  }
}

/// a client that keeps the cookies of every answer, like a browser
class Browser {
  Browser(this.client);

  final DoxTestClient client;
  final Map<String, String> cookies = <String, String>{};

  Future<TestResponse> get(String path, {Map<String, String>? headers}) {
    return _keep(client.withCookies(cookies).get(path, headers: headers));
  }

  Future<TestResponse> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) {
    return _keep(
      client.withCookies(cookies).post(path, body: body, headers: headers),
    );
  }

  Future<TestResponse> _keep(Future<TestResponse> pending) async {
    TestResponse res = await pending;
    cookies.addAll(res.cookies);
    return res;
  }
}

void main() {
  late DoxTestClient client;

  setUpAll(() async {
    client = await DoxTestClient.start(
      AppConfig(
        appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
        routers: <Router>[
          SessionRouter(),
          CacheSessionRouter(),
          NoSessionRouter(),
        ],
      ),
    );
  });

  tearDownAll(() async {
    await client.close();
  });

  for (String prefix in <String>['', '/cache']) {
    String driver = prefix.isEmpty ? 'cookie' : 'cache';
    String cookie = prefix.isEmpty ? 'dox_session' : 'cache_session';

    group('$driver driver', () {
      test('put and get across requests', () async {
        Browser browser = Browser(client);
        TestResponse put = await browser.get('$prefix/put?name=Ann');
        put.expectStatus(200);
        expect(put.cookies[cookie], isNotNull);
        expect(put.header('set-cookie'), contains('SameSite=Lax'));
        expect(put.header('set-cookie'), contains('HttpOnly'));
        (await browser.get('$prefix/get')).expectJson(<String, dynamic>{
          'name': 'Ann',
          'message': null,
          'has': true,
        });
        // another browser has its own session
        (await Browser(client).get('$prefix/get'))
            .expectJson(containsPair('name', null));
      });

      test('no cookie when the session is not used or not changed', () async {
        Browser browser = Browser(client);
        TestResponse first = await browser.get('$prefix/untouched');
        expect(first.cookies, isEmpty);
        expect(first.header('set-cookie'), isNull);
        await browser.get('$prefix/put?name=Ann');
        TestResponse read = await browser.get('$prefix/get');
        expect(read.header('set-cookie'), isNull);
      });

      test('flash lives for one request', () async {
        Browser browser = Browser(client);
        await browser.get('$prefix/flash');
        (await browser.get('$prefix/get'))
            .expectJson(containsPair('message', 'Saved'));
        (await browser.get('$prefix/get'))
            .expectJson(containsPair('message', null));
      });

      test('forget, pull and invalidate', () async {
        Browser browser = Browser(client);
        await browser.get('$prefix/put?name=Ann');
        (await browser.get('$prefix/pull'))
            .expectJson(<String, dynamic>{'value': 'Ann', 'after': null});
        await browser.get('$prefix/put?name=Bob');
        (await browser.get('$prefix/forget')).expectJson(<String, dynamic>{});
        await browser.get('$prefix/put?name=Bob');
        (await browser.get('$prefix/invalidate'))
            .expectJson(<String, dynamic>{});
        (await browser.get('$prefix/get'))
            .expectJson(containsPair('name', null));
      });

      test('regenerate gives a new id and token, and keeps the data', () async {
        Browser browser = Browser(client);
        await browser.get('$prefix/put?name=Ann');
        String oldCookie = browser.cookies[cookie]!;
        String oldToken = (await browser.get('$prefix/id')).body;
        TestResponse res = await browser.get('$prefix/regenerate');
        expect(res.body, isNot(oldToken));
        expect(browser.cookies[cookie], isNot(oldCookie));
        (await browser.get('$prefix/get'))
            .expectJson(containsPair('name', 'Ann'));
        if (driver == 'cache') {
          // the old id is gone from the store
          (await client
                  .withCookies(<String, String>{cookie: oldCookie})
                  .get('$prefix/get'))
              .expectJson(containsPair('name', null));
        }
      });
    });
  }

  test('a changed session cookie is a new empty session', () async {
    (await client
            .withCookies(<String, String>{'dox_session': 'not-valid'})
            .get('/get'))
        .expectStatus(200)
        .expectJson(containsPair('name', null));
  });

  test('the cookie driver stops a session that is too big', () async {
    (await client.get('/big')).expectStatus(500);
    (await client.get('/cache/big')).expectStatus(200);
  });

  test('req.session without the middleware is an error', () async {
    (await client.get('/plain/session')).expectStatus(500);
  });

  group('csrf', () {
    test('a post without the token gets 419', () async {
      (await client.post('/save', body: <String, dynamic>{}))
          .expectStatus(419)
          .expectJson(containsPair('code', 'csrf_token_mismatch'));
    });

    test('the token in the body or a header passes', () async {
      Browser browser = Browser(client);
      TestResponse page = await browser.get('/form');
      String token = page.cookies[CsrfMiddleware.cookieName]!;
      // page scripts must read it: no HttpOnly
      expect(
        page.header('set-cookie'),
        contains('XSRF-TOKEN=$token; Max-Age=7200; Path=/; SameSite=Lax'),
      );
      (await browser.post(
        '/save',
        body: '_token=$token',
        headers: <String, String>{
          'content-type': 'application/x-www-form-urlencoded',
        },
      )).expectStatus(200).expectBody('saved');
      (await browser.post(
        '/save',
        body: <String, dynamic>{},
        headers: <String, String>{'X-XSRF-TOKEN': token},
      )).expectStatus(200);
      (await browser.post(
        '/save',
        body: <String, dynamic>{},
        headers: <String, String>{'X-CSRF-TOKEN': token},
      )).expectStatus(200);
      (await browser.post(
        '/save',
        body: <String, dynamic>{},
        headers: <String, String>{'X-CSRF-TOKEN': 'wrong'},
      )).expectStatus(419);
    });

    test('excluded paths are not checked', () async {
      (await client.post(
        '/api/save',
        body: <String, dynamic>{},
      )).expectStatus(200);
      (await client.post('/hook', body: <String, dynamic>{})).expectStatus(200);
    });
  });

  group('validation errors', () {
    Future<(Browser, String)> start() async {
      Browser browser = Browser(client);
      TestResponse page = await browser.get('/form');
      return (browser, page.cookies[CsrfMiddleware.cookieName]!);
    }

    test('a form post redirects back with errors and old input', () async {
      var (Browser browser, String token) = await start();
      TestResponse res = await browser.post(
        '/form',
        body: '_token=$token&email=nope&password=short',
        headers: <String, String>{
          'content-type': 'application/x-www-form-urlencoded',
          'referer': '/form',
        },
      );
      res.expectStatus(302).expectHeader('location', '/form');
      TestResponse page = await browser.get('/form');
      expect(page.json['errors'], containsPair('email', isA<String>()));
      expect(page.json['errors'], contains('password'));
      expect(page.json['email'], 'nope');
      expect(page.json['password'], isNull);
      // the errors are flash data: gone on the next request
      (await browser.get('/form'))
          .expectJson(containsPair('errors', <String, dynamic>{}));
    });

    test('back() goes to / with no Referer', () async {
      var (Browser browser, String token) = await start();
      (await browser.post(
        '/form',
        body: '_token=$token&email=nope',
        headers: <String, String>{
          'content-type': 'application/x-www-form-urlencoded',
        },
      )).expectStatus(302).expectHeader('location', '/');
    });

    test('a JSON request still gets 422 JSON', () async {
      var (Browser browser, String token) = await start();
      (await browser.post(
        '/form',
        body: <String, dynamic>{'email': 'nope', 'password': 'short'},
        headers: <String, String>{'X-XSRF-TOKEN': token},
      )).expectStatus(422).expectJson(contains('email'));
    });

    test('an Inertia request is redirected', () async {
      var (Browser browser, String token) = await start();
      (await browser.post(
        '/form',
        body: <String, dynamic>{'email': 'nope', 'password': 'short'},
        headers: <String, String>{
          'X-XSRF-TOKEN': token,
          'X-Inertia': 'true',
          'X-Requested-With': 'XMLHttpRequest',
          'referer': '/form',
        },
      )).expectStatus(302).expectHeader('location', '/form');
    });
  });
}
