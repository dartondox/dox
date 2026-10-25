// ignore_for_file: depend_on_referenced_packages
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
import 'package:dox_core/testing.dart';
import 'package:test/test.dart';

import 'jwt_auth_test.dart' show FakeUser, secret, users;

class WebRouter extends Router {
  @override
  List<dynamic> get middleware => <dynamic>[const SessionMiddleware()];

  @override
  void register() {
    Route.post('login', (DoxRequest req) async {
      bool ok = await Auth().attemptSession(
        req,
        req.only(<String>['email', 'password']),
      );
      return ok ? 'in' : 'wrong';
    });
    Route.post('logout', (DoxRequest req) {
      Auth().logout(req);
      return 'out';
    });
    Route.get('me', <dynamic>[
      AuthMiddleware(),
      (DoxRequest req) => req.auth?.user<FakeUser>()?.email,
    ]);
    Route.get('page', <dynamic>[
      AuthMiddleware(redirectTo: '/login'),
      (DoxRequest req) => 'page',
    ]);
    Route.get('jwt', (DoxRequest req) {
      Auth(guard: 'api').logout(req);
      return 'no';
    });
  }
}

/// keeps the cookies of every answer, like a browser
class Browser {
  Browser(this.client);

  final DoxTestClient client;
  final Map<String, String> cookies = <String, String>{};

  Future<TestResponse> get(String path) {
    return _keep(client.withCookies(cookies).get(path));
  }

  Future<TestResponse> post(String path, [Object? body]) {
    return _keep(client.withCookies(cookies).post(path, body: body));
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
    users[1] = FakeUser(1, 'a@dox.dev', Hash.make('secret', rounds: 4));
    Auth.initialize(
      AuthConfig(
        defaultGuard: 'web',
        guards: <String, AuthGuard>{
          'web': AuthGuard(
            driver: SessionAuthDriver(hashRounds: 4),
            provider: AuthProvider(model: () => FakeUser()),
          ),
          'api': AuthGuard(
            driver: JwtAuthDriver(secret: SecretKey(secret)),
            provider: AuthProvider(model: () => FakeUser()),
          ),
        },
      ),
    );
    client = await DoxTestClient.start(
      AppConfig(appKey: secret, routers: <Router>[WebRouter()]),
    );
  });

  tearDownAll(() async {
    await client.close();
  });

  test('login keeps the user in the session until logout', () async {
    Browser browser = Browser(client);
    expect((await browser.get('/me')).status, 401);

    TestResponse login = await browser.post('/login', <String, dynamic>{
      'email': 'a@dox.dev',
      'password': 'secret',
    });
    expect(login.body, 'in');
    expect((await browser.get('/me')).body, 'a@dox.dev');

    expect((await browser.post('/logout')).body, 'out');
    expect((await browser.get('/me')).status, 401);
  });

  test('a wrong password does not log in', () async {
    Browser browser = Browser(client);
    TestResponse login = await browser.post('/login', <String, dynamic>{
      'email': 'a@dox.dev',
      'password': 'nope',
    });
    expect(login.body, 'wrong');
    expect((await browser.get('/me')).status, 401);
  });

  test('redirectTo sends a guest to the login page', () async {
    TestResponse res = await client.get('/page');
    expect(res.status, 302);
    expect(res.header('location'), '/login');
  });

  test('session methods on a JWT guard throw', () async {
    expect((await client.get('/jwt')).status, 500);
  });
}
