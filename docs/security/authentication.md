---
icon: lucide/user-lock
---

# Authentication

This page shows how to log users in with `dox_auth` and protect routes with a JWT token or a session.

`dox_auth` checks an email and a password against your user table.
It gives back a JWT token.
The client sends this token in the `Authorization` header.
`AuthMiddleware` reads the token and loads the user from the database.

## Install

```bash
dart pub add dox_auth
```

A new app made with the `dox` CLI already has it.

## 1. Hide the password in the model

The token holds the user data as JSON, and anyone can read a JWT.
So the password hash must never be in `toJson()`.
Put it in `hidden`:

```dart title="lib/app/models/user/user.model.dart"
import 'package:dox_orm/dox_orm.dart';

part 'user.model.g.dart';

@DoxModel(table: 'users')
class User extends UserGenerator {
  @override
  List<String> get hidden => <String>['password'];

  @Column()
  String? name;

  @Column()
  String? email;

  @Column()
  String? password;
}
```

## 2. Set up the auth provider

```dart title="lib/providers/auth_provider.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/models/user/user.model.dart';
import 'package:my_app/config/env.dart';

class AppAuthProvider extends DoxProvider {
  @override
  void setup() {
    Auth.initialize(
      AuthConfig(
        defaultGuard: 'web',
        guards: <String, AuthGuard>{
          'web': AuthGuard(
            driver: JwtAuthDriver(
              secret: SecretKey(env.appKey),
              expiresIn: const Duration(days: 7),
            ),
            provider: AuthProvider(model: () => User()),
          ),
        },
      ),
    );
  }
}
```

Dox finds the provider by itself. Run `dart run build_runner build` and it is in `lib/generated/container.g.dart`.

## 3. Add the routes

`AuthMiddleware` protects a route.
When the token is missing or not valid, the request stops with `401 Authentication failed`.
Put these routes in `register()` of the `ApiRouter`. Its prefix is `api`, so the paths start with `/api`.
A [rate limit](rate-limiting.md) on login and register slows down password guessing.

```dart title="lib/routes/api.dart"
Route.post('/auth/register', <dynamic>[
  RateLimit(max: 5, name: 'register'),
  (AuthController c) => c.register,
]);
Route.post('/auth/login', <dynamic>[
  RateLimit(max: 5, name: 'login'),
  (AuthController c) => c.login,
]);
Route.get('/auth/user', <dynamic>[AuthMiddleware(), (AuthController c) => c.user]);
```

## 4. Write the controller

```dart title="lib/app/http/controllers/auth.controller.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/models/user/user.model.dart';

@Inject()
class AuthController {
  /// Make an account and log in.
  Future<dynamic> register(RegisterUser body) async {
    User user = User();
    user.name = body.name;
    user.email = body.email;
    user.password = await Hash.makeAsync(body.password);
    await user.save();

    String? token = Auth().login(user);
    return <String, dynamic>{'token': token, 'user': user};
  }

  /// Check the email and password. Give a token.
  Future<dynamic> login(LoginUser body) async {
    Auth auth = Auth();
    String? token = await auth.attempt(<String, dynamic>{
      'email': body.email,
      'password': body.password,
    });
    if (token == null) {
      throw UnAuthorizedException(message: 'Wrong email or password');
    }
    return <String, dynamic>{'token': token, 'user': auth.user<User>()};
  }

  /// The logged in user.
  User? user(DoxRequest req) {
    return req.auth?.user<User>();
  }
}
```

`RegisterUser` and `LoginUser` are `@Dto` classes. See [Validation](../the-basic/validation.md).

## 5. Send the token from the client

```http
GET /api/auth/user
Authorization: Bearer <token>
```

## Read the user

After `AuthMiddleware`, `req.auth` holds the login.

| Code | What it gives |
| --- | --- |
| `req.auth` | an `IAuth?`. `null` when the route has no `AuthMiddleware` |
| `req.auth?.isLoggedIn()` | `true` when a user is loaded |
| `req.auth?.user<User>()` | the user model |
| `req.auth?.toJson()` | the user as a map, without `hidden` fields |

## The `Auth` class

| Method | What it does |
| --- | --- |
| `Auth.initialize(AuthConfig)` | sets the config. Call it once, in a provider |
| `Auth(guard: 'admin')` | uses another guard from `guards`. Without `guard`, it uses `defaultGuard` |
| `await Auth().attempt(credentials)` | finds the user and checks the password. Gives a token, or `null` |
| `Auth().login(user)` | gives a token for this user, with no password check |
| `Auth().setUser(req, user)` | sets this user on `req.auth`, with no token and no password check. For your own auth middleware |
| `user<T>()` | the user after `attempt` or `login` |
| `isLoggedIn()` | `true` when there is a user |

`attempt` searches only by the fields in `identifierFields`. It runs bcrypt also when no user is found, or when the user has no password, so the answer time does not tell whether an email has an account.
It returns `null` when the password is not a `String`, when no identifier is given, or when the password does not match.

## Options

### `AuthProvider`

| Option | Default | What it does |
| --- | --- | --- |
| `model` | required | a function that makes a new model, like `() => User()` |
| `identifierFields` | `['email']` | the fields `attempt` searches by |
| `passwordField` | `'password'` | the column with the bcrypt hash |

### `JwtAuthDriver`

| Option | Default | What it does |
| --- | --- | --- |
| `secret` | required | the key that signs tokens, like `SecretKey(env.appKey)`. An empty key throws `ArgumentError`. A key shorter than 32 bytes also throws in production, and prints a warning in development, local and test. Make one with `dox key:generate`. For a separate JWT secret (not `APP_KEY`), `openssl rand -hex 32` also works |
| `algorithm` | `JWTAlgorithm.HS256` | the signing algorithm |
| `expiresIn` | `Duration(hours: 1)` | how long a token is valid |
| `issuer` | `null` | the `iss` claim. When set, `verifyToken` also checks it |
| `hashRounds` | `10` | the bcrypt cost of your stored hashes. Use the same value as `Hash.rounds` |
| `userCacheTtl` | `null` (off) | keep the user of a token in memory for this time. See below |

## More than one guard

Each guard has its own driver and its own user model.
For example, users and admins in two tables:

```dart
AuthConfig(
  defaultGuard: 'web',
  guards: <String, AuthGuard>{
    'web': AuthGuard(
      driver: JwtAuthDriver(secret: SecretKey(env.appKey)),
      provider: AuthProvider(model: () => User()),
    ),
    'admin': AuthGuard(
      driver: JwtAuthDriver(secret: SecretKey(env.appKey)),
      provider: AuthProvider(model: () => Admin()),
    ),
  },
);
```

Pick the guard by name:

```dart
String? token = await Auth(guard: 'admin').attempt(credentials);

Route.get('/admin', <dynamic>[AuthMiddleware(guard: 'admin'), (AdminController c) => c.index]);
```

The token keeps the guard name in its `aud` claim.
So a token from the `web` guard does not work on the `admin` guard, even with the same secret.
An unknown guard name throws an `ArgumentError`.

## Custom guard (API key)

You can check the user in your own way, like an API key in the header.
Write a driver: extend `AuthDriver` and return the user from `verifyToken`.
`AuthMiddleware` and `req.auth` then work as with the other drivers.

The table stores a SHA-256 hash of each key in an `api_key_hash` column, not the key itself.
So a leak of the table does not leak the keys.
The example uses the `crypto` package (`dart pub add crypto`).

```dart
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
import 'package:dox_orm/dox_orm.dart';

/// `Authorization: Bearer <api key>` gives the user with this key.
class ApiKeyAuthDriver extends AuthDriver {
  @override
  Future<Model<dynamic>?> verifyToken(IDoxRequest req, String guard) async {
    String header = req.header('Authorization') ?? '';
    if (!header.startsWith('Bearer ')) return null;
    String key = header.substring(7).trim();
    String hash = sha256.convert(utf8.encode(key)).toString();
    Model<dynamic> model = AuthEngine().guard(guard).provider.model();
    return await model.where('api_key_hash', hash).getFirst();
  }

  /// no password login for this guard
  @override
  Future<Model<dynamic>?> attempt(Map<String, dynamic> credentials, String guard) async => null;

  /// no token to make: the key is the token
  @override
  String? createToken(Map<String, dynamic>? userPayload, String guard) => null;
}
```

Add it as a guard, and use the guard in the route:

```dart
'api': AuthGuard(
  driver: ApiKeyAuthDriver(),
  provider: AuthProvider(model: () => User()),
),

Route.get('/me', <dynamic>[AuthMiddleware(guard: 'api'), (DoxRequest req) => req.auth?.user<User>()]);
```

Make each key long and random, like `openssl rand -hex 32`. Then a fast hash like SHA-256 is safe. Do not use bcrypt here: you can not search by a bcrypt hash.

If you already have your own middleware, set the user with `Auth().setUser(req, user)`.
It needs no token and no password check. `req.auth` then gives this user:

```dart
User? user = await keys.userForKey(key);
if (user == null) throw UnAuthorizedException();
Auth(guard: 'api').setUser(req, user);
return req;
```

## Session login for web pages

For web pages, keep the login in the session instead of a token.
The browser sends the session cookie, so the client does nothing.
It needs `SessionMiddleware` and `CsrfMiddleware`. See [Session](../the-basic/session.md).

Use `SessionAuthDriver` in the guard:

```dart
'web': AuthGuard(
  driver: SessionAuthDriver(),
  provider: AuthProvider(model: () => User()),
),
```

Log in and log out with the request:

```dart
Future<dynamic> login(DoxRequest req, LoginUser body) async {
  bool ok = await Auth().attemptSession(req, <String, dynamic>{
    'email': body.email,
    'password': body.password,
  });
  if (!ok) {
    req.session.flashErrors(<String, dynamic>{'email': 'Wrong email or password'});
    return back(req);
  }
  return redirect('/dashboard');
}

DoxResponse logout(DoxRequest req) {
  Auth().logout(req);
  return redirect('/');
}
```

Send guests to the login page instead of a `401`:

```dart
Route.get('/dashboard', <dynamic>[AuthMiddleware(redirectTo: '/login'), (PageController c) => c.dashboard]);
```

| Method | What it does |
| --- | --- |
| `await Auth().attemptSession(req, credentials)` | checks the password like `attempt`, and keeps the user id in the session. Gives `true` or `false` |
| `Auth().loginSession(req, user)` | keeps this user in the session, with no password check |
| `Auth().logout(req)` | removes the login and all session data |

- Login and logout give the session a new id and a new CSRF token. So an id that someone saw before the login is of no use.
- With the default `cookie` session driver, all session data sits in the cookie. So an old copy of the cookie still works after logout. The server also does not check its age, so a copied cookie works until `APP_KEY` changes. If logout must really end old cookies, use the `cache` session driver, like `SessionConfig(driver: 'cache', store: 'redis')`.
- The session keeps only the user id. `AuthMiddleware` loads the user from the database on each request, so a deleted user is logged out.
- These methods throw a `StateError` on a guard that does not use `SessionAuthDriver`.
- `SessionAuthDriver` has one option, `hashRounds` (default `10`), like `JwtAuthDriver`.

## Things to know

- **The token is not secret.** Anyone with the token can read `user.toJson()`. Keep private columns in `hidden`.
- **You can not cancel one token.** A token works until it expires. If you change the `secret` (your `APP_KEY`), all tokens stop working.
- **The user is loaded on each request**, by the id in the token. A deleted user can not log in, even with a valid token.
- **`userCacheTtl` skips that query.** With `Duration(seconds: 30)`, a deleted or changed user is seen only after 30 seconds. Each isolate has its own cache. Requests in that time share one user object, so do not change it per request.
- **Login does not block the server.** `attempt` runs bcrypt in another isolate.
- **Hash passwords** before you save them. See [Hashing](hashing.md).
