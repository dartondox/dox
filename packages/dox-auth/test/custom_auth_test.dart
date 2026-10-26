// ignore_for_file: depend_on_referenced_packages
// Imports both packages on purpose: they must not give ambiguous names.
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
import 'package:dox_core/testing.dart';
import 'package:dox_orm/dox_orm.dart';
import 'package:test/test.dart';

import 'jwt_auth_test.dart' show FakeUser, secret, users;

/// A custom driver: `Authorization: Bearer <api key>` gives the user.
/// The test users have no api_key column, so the email is the key here.
class ApiKeyAuthDriver extends AuthDriver {
  @override
  Future<Model<dynamic>?> verifyToken(IDoxRequest req, String guard) async {
    String header = req.header('Authorization') ?? '';
    if (!header.startsWith('Bearer ')) return null;
    Model<dynamic> model = AuthEngine().guard(guard).provider.model();
    return await model.where('email', header.substring(7).trim()).getFirst();
  }

  @override
  Future<Model<dynamic>?> attempt(
    Map<String, dynamic> credentials,
    String guard,
  ) async {
    return null;
  }

  @override
  String? createToken(Map<String, dynamic>? userPayload, String guard) => null;
}

/// Own middleware that sets the user with `Auth().setUser`.
class HeaderUserMiddleware implements IDoxMiddleware {
  @override
  Future<dynamic> handle(IDoxRequest req) async {
    FakeUser? user = users[int.tryParse(req.header('x-user') ?? '')];
    if (user == null) throw UnAuthorizedException();
    Auth(guard: 'api').setUser(req, user);
    return req;
  }
}

/// A route with no AuthMiddleware: req.auth is null.
Map<String, dynamic> openRoute(DoxRequest req) {
  return <String, dynamic>{
    'auth': req.auth == null ? 'none' : 'set',
    'all': req.all(),
  };
}

class ApiRouter extends Router {
  @override
  void register() {
    Route.get('key', <dynamic>[
      AuthMiddleware(guard: 'api'),
      (DoxRequest req) => req.auth?.user<FakeUser>()?.email,
    ]);
    Route.get('own', <dynamic>[
      HeaderUserMiddleware(),
      (DoxRequest req) => req.auth?.user<FakeUser>()?.email,
    ]);
    Route.get('open', openRoute);
    Route.post('open', openRoute);
  }
}

void main() {
  late DoxTestClient client;

  setUpAll(() async {
    users[1] = FakeUser(1, 'a@dox.dev', 'x');
    Auth.initialize(
      AuthConfig(
        defaultGuard: 'api',
        guards: <String, AuthGuard>{
          'api': AuthGuard(
            driver: ApiKeyAuthDriver(),
            provider: AuthProvider(model: () => FakeUser()),
          ),
        },
      ),
    );
    client = await DoxTestClient.start(
      AppConfig(appKey: secret, routers: <Router>[ApiRouter()]),
    );
  });

  tearDownAll(() async {
    await client.close();
  });

  test('a custom driver guard sets req.auth through AuthMiddleware', () async {
    TestResponse res = await client.withToken('a@dox.dev').get('/key');
    expect(res.body, 'a@dox.dev');

    TestResponse bad = await client.withToken('nope').get('/key');
    expect(bad.status, 401);
  });

  test('Auth().setUser in own middleware sets req.auth', () async {
    TestResponse res = await client
        .withHeaders(<String, String>{'x-user': '1'})
        .get('/own');
    expect(res.body, 'a@dox.dev');
    expect((await client.get('/own')).status, 401);
  });

  test('a client field can not set req.auth', () async {
    // this was the input key of req.auth before
    TestResponse res = await client.get('/open?dox_authentication_instance=x');
    res.expectStatus(200).expectJson(<String, dynamic>{
      'auth': 'none',
      'all': <String, dynamic>{'dox_authentication_instance': 'x'},
    });
    TestResponse posted = await client.post(
      '/open',
      body: <String, dynamic>{'dox_authentication_instance': 'x'},
    );
    posted.expectStatus(200).expectJson(containsPair('auth', 'none'));
  });
}
