// ignore_for_file: depend_on_referenced_packages
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_auth/src/hash.dart';
import 'package:dox_orm/dox_orm.dart';
import 'package:test/test.dart';

const String secret = '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt';

/// In-memory users, so the tests do not need a database.
final Map<int, FakeUser> users = <int, FakeUser>{};

class FakeUser extends Model<FakeUser> {
  int? id;
  String? email;
  String? password;

  final Map<String, dynamic> _wheres = <String, dynamic>{};

  FakeUser([this.id, this.email, this.password]) {
    hidden = <String>['password'];
  }

  @override
  Map<String, dynamic> convertToMap(dynamic i) {
    return <String, dynamic>{'id': id, 'email': email, 'password': password};
  }

  @override
  Future<FakeUser?> find(dynamic arg1, [dynamic arg2]) async {
    return users[arg1];
  }

  @override
  QueryBuilder<FakeUser> where(String arg1, [dynamic arg2, dynamic arg3]) {
    _wheres[arg1] = arg2;
    return this;
  }

  @override
  Future<FakeUser?> getFirst() async {
    for (FakeUser u in users.values) {
      bool match = true;
      _wheres.forEach((String key, dynamic value) {
        if (u.convertToMap(u)[key] != value) match = false;
      });
      if (match) return u;
    }
    return null;
  }
}

/// Small request stub. Only `header` and `merge` are used by dox_auth.
class FakeRequest implements IDoxRequest {
  final Map<String, String> _headers;
  final Map<String, dynamic> merged = <String, dynamic>{};

  FakeRequest([this._headers = const <String, String>{}]);

  @override
  String? header(String key) => _headers[key];

  @override
  void merge(Map<String, dynamic> values) => merged.addAll(values);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

FakeRequest bearer(String? token) {
  return FakeRequest(<String, String>{'Authorization': 'Bearer $token'});
}

void init({Duration? expiresIn}) {
  Auth.initialize(
    AuthConfig(
      defaultGuard: 'web',
      guards: <String, AuthGuard>{
        'web': AuthGuard(
          driver: JwtAuthDriver(
            secret: SecretKey(secret),
            expiresIn: expiresIn,
          ),
          provider: AuthProvider(model: () => FakeUser()),
        ),
      },
    ),
  );
}

void main() {
  setUp(() {
    users
      ..clear()
      ..[1] = FakeUser(1, 'a@dox.dev', Hash.make('secret'));
    init();
  });

  group('JwtAuthDriver |', () {
    test('login issues a token with the user payload and no hidden fields', () {
      String? token = Auth().login(users[1]!);
      expect(token, isNotNull);
      JWT jwt = JWT.verify(token!, SecretKey(secret));
      expect(jwt.payload['id'], 1);
      expect(jwt.payload['email'], 'a@dox.dev');
      expect(jwt.payload.containsKey('password'), isFalse);
    });

    test('verifyToken finds the user for a good token', () async {
      String token = Auth().login(users[1]!)!;
      Auth auth = Auth();
      await auth.verifyToken(bearer(token));
      expect(auth.isLoggedIn(), isTrue);
      expect(auth.user<FakeUser>()?.email, 'a@dox.dev');
      expect(auth.toJson()?['id'], 1);
    });

    test('verifyToken with no header is not logged in', () async {
      Auth auth = Auth();
      await auth.verifyToken(FakeRequest());
      expect(auth.isLoggedIn(), isFalse);
      expect(auth.user<FakeUser>(), isNull);
    });

    test('verifyToken with an invalid token is not logged in', () async {
      Auth auth = Auth();
      await auth.verifyToken(bearer('not-a-jwt'));
      expect(auth.isLoggedIn(), isFalse);
    });

    test(
      'verifyToken with a token signed by another secret is rejected',
      () async {
        String token = JWT(<String, dynamic>{'id': 1})
            .sign(SecretKey('other-secret'));
        Auth auth = Auth();
        await auth.verifyToken(bearer(token));
        expect(auth.isLoggedIn(), isFalse);
      },
    );

    test('verifyToken with an expired token is rejected', () async {
      init(expiresIn: Duration(seconds: 1));
      String token = Auth().login(users[1]!)!;
      await Future<void>.delayed(Duration(seconds: 2));
      Auth auth = Auth();
      await auth.verifyToken(bearer(token));
      expect(auth.isLoggedIn(), isFalse);
    });

    test('verifyToken for a deleted user is not logged in', () async {
      String token = Auth().login(users[1]!)!;
      users.clear();
      Auth auth = Auth();
      await auth.verifyToken(bearer(token));
      expect(auth.isLoggedIn(), isFalse);
    });

    test('attempt with right credentials returns a token', () async {
      Auth auth = Auth();
      String? token = await auth.attempt(<String, dynamic>{
        'email': 'a@dox.dev',
        'password': 'secret',
      });
      expect(token, isNotNull);
      expect(auth.isLoggedIn(), isTrue);
    });

    test('attempt with wrong password returns null', () async {
      Auth auth = Auth();
      String? token = await auth.attempt(<String, dynamic>{
        'email': 'a@dox.dev',
        'password': 'wrong',
      });
      expect(token, isNull);
      expect(auth.isLoggedIn(), isFalse);
    });

    test('attempt with unknown email returns null', () async {
      String? token = await Auth().attempt(<String, dynamic>{
        'email': 'nobody@dox.dev',
        'password': 'secret',
      });
      expect(token, isNull);
    });

    test('attempt without a password returns null', () async {
      String? token = await Auth().attempt(<String, dynamic>{
        'email': 'a@dox.dev',
      });
      expect(token, isNull);
    });

    test('attempt with only a password returns null', () async {
      String? token = await Auth().attempt(<String, dynamic>{
        'password': 'secret',
      });
      expect(token, isNull);
    });

    test('attempt with a non-string password returns null', () async {
      String? token = await Auth().attempt(<String, dynamic>{
        'email': 'a@dox.dev',
        'password': 123,
      });
      expect(token, isNull);
    });
  });

  group('AuthMiddleware |', () {
    test('rejects a request with no token', () async {
      expect(
        () => AuthMiddleware().handle(FakeRequest()),
        throwsA(isA<UnAuthorizedException>()),
      );
    });

    test('rejects a request with a bad token', () async {
      expect(
        () => AuthMiddleware().handle(bearer('bad.token.here')),
        throwsA(isA<UnAuthorizedException>()),
      );
    });

    test('accepts a request with a good token and merges auth', () async {
      String token = Auth().login(users[1]!)!;
      FakeRequest req = bearer(token);
      IDoxRequest res = await AuthMiddleware().handle(req);
      expect(res, same(req));
      Auth auth = req.merged[AUTH_REQUEST_KEY];
      expect(auth.user<FakeUser>()?.id, 1);
    });

    test('UnAuthorizedException is a 401', () {
      UnAuthorizedException e = UnAuthorizedException();
      expect(e.code, 401);
      expect(e.errorCode, 'unauthorized');
    });
  });
}
