// ignore_for_file: depend_on_referenced_packages
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
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

/// Admins live in another table, so the `admin` guard uses its own store.
final Map<int, FakeUser> admins = <int, FakeUser>{};

class FakeAdmin extends FakeUser {
  FakeAdmin([super.id, super.email, super.password]);

  @override
  Future<FakeUser?> find(dynamic arg1, [dynamic arg2]) async => admins[arg1];

  @override
  Future<FakeUser?> getFirst() async {
    for (FakeUser u in admins.values) {
      bool match = true;
      _wheres.forEach((String key, dynamic value) {
        if (u.convertToMap(u)[key] != value) match = false;
      });
      if (match) return u;
    }
    return null;
  }
}

void init({Duration expiresIn = const Duration(hours: 1)}) {
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

        /// same secret on purpose: the guard name must still keep them apart
        'admin': AuthGuard(
          driver: JwtAuthDriver(secret: SecretKey(secret)),
          provider: AuthProvider(model: () => FakeAdmin()),
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
    admins
      ..clear()
      ..[1] = FakeAdmin(1, 'boss@dox.dev', Hash.make('admin-secret'));
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

    test('an unknown email takes about as long as a wrong password', () async {
      // warm up the isolate code path
      await Auth().attempt(<String, dynamic>{
        'email': 'x@dox.dev',
        'password': 'x',
      });

      Stopwatch unknown = Stopwatch()..start();
      await Auth().attempt(<String, dynamic>{
        'email': 'nobody@dox.dev',
        'password': 'secret',
      });
      unknown.stop();

      Stopwatch wrong = Stopwatch()..start();
      await Auth().attempt(<String, dynamic>{
        'email': 'a@dox.dev',
        'password': 'wrong',
      });
      wrong.stop();

      // both run bcrypt. without it an unknown email answers in ~0 ms.
      expect(
        unknown.elapsedMicroseconds,
        greaterThan(wrong.elapsedMicroseconds ~/ 4),
      );
    });

    test('an empty secret is refused', () {
      expect(() => JwtAuthDriver(secret: SecretKey('')), throwsArgumentError);
      expect(() => JwtAuthDriver(secret: SecretKey('  ')), throwsArgumentError);
    });

    test('a short secret stops production and warns in development', () {
      Env().env['APP_ENV'] = 'production';
      expect(
        () => JwtAuthDriver(secret: SecretKey('short')),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError e) => e.message,
            'message',
            allOf(contains('at least 32 bytes'), contains('openssl rand')),
          ),
        ),
      );
      Env().env['APP_ENV'] = 'development';
      expect(
        () => JwtAuthDriver(secret: SecretKey('short')),
        prints(contains('[dox] warning: The JWT secret is 5 bytes')),
      );
      expect(() => JwtAuthDriver(secret: SecretKey(secret)), prints(isEmpty));
      Env().env.remove('APP_ENV');
    });

    test('a user with no stored password cannot log in', () async {
      users[2] = FakeUser(2, 'nopass@dox.dev');
      String? token = await Auth().attempt(<String, dynamic>{
        'email': 'nopass@dox.dev',
        'password': 'dox-no-user',
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

  group('User cache |', () {
    void initCache(Duration? ttl) {
      Auth.initialize(
        AuthConfig(
          defaultGuard: 'web',
          guards: <String, AuthGuard>{
            'web': AuthGuard(
              driver: JwtAuthDriver(
                secret: SecretKey(secret),
                userCacheTtl: ttl,
              ),
              provider: AuthProvider(model: () => FakeUser()),
            ),
          },
        ),
      );
    }

    Future<FakeUser?> userOf(String token) async {
      Auth auth = Auth();
      await auth.verifyToken(bearer(token));
      return auth.user<FakeUser>();
    }

    test('off by default: a deleted user is seen at once', () async {
      initCache(null);
      String token = Auth().login(users[1]!)!;
      expect(await userOf(token), isNotNull);
      users.clear();
      expect(await userOf(token), isNull);
    });

    test('keeps the user for the ttl, then loads it again', () async {
      initCache(Duration(milliseconds: 300));
      String token = Auth().login(users[1]!)!;
      FakeUser? first = await userOf(token);
      users.clear();
      expect(await userOf(token), same(first));
      await Future<void>.delayed(Duration(milliseconds: 400));
      expect(await userOf(token), isNull);
    });

    test('a bad token is still rejected', () async {
      initCache(Duration(minutes: 1));
      String token = Auth().login(users[1]!)!;
      expect(await userOf(token), isNotNull);
      expect(await userOf('$token-bad'), isNull);
    });
  });

  group('Hash rounds |', () {
    test('attempt works with a custom hashRounds', () async {
      users[3] = FakeUser(3, 'low@dox.dev', Hash.make('pw', rounds: 4));
      Auth.initialize(
        AuthConfig(
          defaultGuard: 'web',
          guards: <String, AuthGuard>{
            'web': AuthGuard(
              driver: JwtAuthDriver(secret: SecretKey(secret), hashRounds: 4),
              provider: AuthProvider(model: () => FakeUser()),
            ),
          },
        ),
      );
      expect(
        await Auth().attempt(<String, dynamic>{
          'email': 'low@dox.dev',
          'password': 'pw',
        }),
        isNotNull,
      );
      expect(
        await Auth().attempt(<String, dynamic>{
          'email': 'nobody@dox.dev',
          'password': 'pw',
        }),
        isNull,
      );
    });
  });

  group('JWT expiry |', () {
    test('a token expires after 1 hour by default', () {
      String token = Auth().login(users[1]!)!;
      Map<String, dynamic> payload = JWT.decode(token).payload;
      expect(payload['exp'] - payload['iat'], 3600);
    });

    test('expiresIn can be changed', () {
      init(expiresIn: Duration(minutes: 5));
      String token = Auth().login(users[1]!)!;
      Map<String, dynamic> payload = JWT.decode(token).payload;
      expect(payload['exp'] - payload['iat'], 300);
    });
  });

  group('Named guards |', () {
    test('attempt on a named guard uses its provider', () async {
      Auth admin = Auth(guard: 'admin');
      String? token = await admin.attempt(<String, dynamic>{
        'email': 'boss@dox.dev',
        'password': 'admin-secret',
      });
      expect(token, isNotNull);
      expect(admin.user<FakeUser>()?.email, 'boss@dox.dev');

      /// the default guard does not know this admin
      expect(
        await Auth().attempt(<String, dynamic>{
          'email': 'boss@dox.dev',
          'password': 'admin-secret',
        }),
        isNull,
      );
    });

    test('a token of one guard does not work on another guard', () async {
      String userToken = Auth().login(users[1]!)!;
      String adminToken = Auth(guard: 'admin').login(admins[1]!)!;

      Auth a1 = Auth(guard: 'admin');
      await a1.verifyToken(bearer(userToken));
      expect(a1.isLoggedIn(), isFalse);

      Auth a2 = Auth();
      await a2.verifyToken(bearer(adminToken));
      expect(a2.isLoggedIn(), isFalse);

      Auth a3 = Auth(guard: 'admin');
      await a3.verifyToken(bearer(adminToken));
      expect(a3.user<FakeUser>()?.email, 'boss@dox.dev');
    });

    test('a token with no guard audience is rejected', () async {
      String token = JWT(<String, dynamic>{'id': 1}).sign(SecretKey(secret));
      Auth auth = Auth();
      await auth.verifyToken(bearer(token));
      expect(auth.isLoggedIn(), isFalse);
    });

    test('AuthMiddleware uses its guard', () async {
      String adminToken = Auth(guard: 'admin').login(admins[1]!)!;
      FakeRequest req = bearer(adminToken);
      await AuthMiddleware(guard: 'admin').handle(req);
      Auth auth = req.merged[AUTH_REQUEST_KEY];
      expect(auth.user<FakeUser>()?.email, 'boss@dox.dev');

      expect(
        () => AuthMiddleware().handle(bearer(adminToken)),
        throwsA(isA<UnAuthorizedException>()),
      );
    });

    test('an unknown guard throws', () {
      expect(() => Auth(guard: 'nope').login(users[1]!), throwsArgumentError);
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
