---
icon: lucide/user-lock
---

# Authentication

`dox_auth` lets users register, log in and log out, and it protects routes so only logged in users can use them.

It gives you a password login against your user table, three ways to keep a user logged in (access tokens, JWT and sessions), `AuthMiddleware` to protect routes, and `req.auth` to get the user in your controller.

`dox_auth` has no password reset, no email check, no "remember me" and no two-step login (2FA). Your app builds these, and the tools on this page help, for example the [two-step login recipe](#change-the-abilities-of-a-token). Rules about who may do what are on the [Authorization](authorization.md) page.

## Choosing a guard

A **guard** is a named way to log in, like `api` or `web`. It says how the login is kept and which model holds the users. Pick the guard driver that fits your app:

| Your app | Use |
| --- | --- |
| An API for a mobile app, a front end on another domain, or scripts | [Access tokens](#access-tokens). You can revoke each token, give it abilities and renew it. |
| An API where other services check the token with a key | [JWT](#jwt-tokens). The token is signed, so there is no token table. |
| Web pages served by this app (forms, Inertia) | [Session](#session-login-for-web-pages). The browser sends the session cookie. |
| Web pages and an API in one app | [More than one guard](#more-than-one-guard). |

If you are not sure, use access tokens for an API.

## Setup

These steps start from a new app made with `dox create my_app`. It has a SQLite database, a `User` model and a `users` table with `name`, `email` and `password` columns.

### Installing

Run `dox add auth`, then run the migration it writes:

```bash
dox add auth
```

The command adds the `dox_auth` package, writes the auth config, writes the provider that loads the config, and writes the [token table](#creating-the-token-table) migration. Run `dox migrate` after it. It needs the ORM and a `User` model, which a new app has. It never overwrites a file, so it is safe to run twice.

If you do not use the command, add the package with `dart pub add dox_auth` and write the config and provider below yourself. The command does not write the DTOs, so you always add them yourself.

### The user model

The password hash must never leave the server. So put it in `hidden`, and `toJson()` leaves it out. The model of a new app already does this:

```dart title="lib/app/models/user/user.model.dart"
import 'package:dox_orm/dox_orm.dart';

part 'user.model.g.dart';

@DoxModel(table: 'users', softDelete: true)
class User extends UserGenerator {
  @override
  List<String> get fillable => <String>['name', 'email', 'password'];

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

### Configuration {#4-add-the-auth-config}

The config lists the guards. Each guard has a driver (how the login is kept) and an `AuthProvider` (which model holds the users). This config has one guard, `api`, with access tokens:

```dart title="lib/config/auth.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:my_app/app/models/user/user.model.dart';

AuthConfig authConfig = AuthConfig(
  defaultGuard: 'api',
  guards: <String, AuthGuard>{
    'api': AuthGuard(
      driver: AccessTokenAuthDriver(expiresIn: const Duration(days: 30)),
      provider: AuthProvider(model: () => User()),
    ),
  },
);
```

`Auth()` and `AuthMiddleware()` use the `defaultGuard`. All options are in the [reference](#reference).

### Loading the config {#5-load-the-config-when-the-app-starts}

A `DoxProvider` gives the config to `dox_auth` when the app starts. Dox finds every `DoxProvider` by itself, so you do not register it. Do not mix it up with the `AuthProvider` of the config:

```dart title="lib/providers/auth_provider.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
import 'package:my_app/config/auth.dart';

class AppAuthProvider extends DoxProvider {
  @override
  void setup() {
    Auth.initialize(authConfig);
  }
}
```

### Validating the input {#3-add-the-input-checks}

You should check the register and login body with [DTOs](../the-basic/validation.md). Bad input then gets a `422`, and the controller does not run:

```dart title="lib/app/dtos/auth/auth.dto.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_orm/dox_orm.dart' hide Schema;

part 'auth.dto.g.dart';

/// The body of a register request.
@Dto()
class RegisterUser {
  @Trim()
  @Length(min: 1, max: 255)
  final String name;

  @Trim()
  @Lowercase()
  @Email()
  @Unique('users', column: 'email')
  final String email;

  /// bcrypt reads at most 72 bytes
  @Length(min: 8, max: 72)
  final String password;

  const RegisterUser({
    required this.name,
    required this.email,
    required this.password,
  });

  static const DtoSchema<RegisterUser> schema = $RegisterUserDto;
}

/// The body of a login request.
@Dto()
class LoginUser {
  @Trim()
  @Lowercase()
  @Email()
  final String email;

  final String password;

  const LoginUser({required this.email, required this.password});

  static const DtoSchema<LoginUser> schema = $LoginUserDto;
}
```

Then run the code generator. It writes the DTO code and adds `AppAuthProvider` to `lib/generated/container.g.dart`:

```bash
dart run build_runner build
```

## Access tokens

An access token is an API token that you can revoke at any time. A token looks like `oat_12.<secret>`, where `12` is the row id in the token table. The table keeps only a SHA-256 hash of the secret, so you see the plain token only once, when you make it.

The [setup](#setup) above already added the `api` guard with `AccessTokenAuthDriver`.

### Creating the token table

The tokens live in the `auth_access_tokens` table. `dox add auth` already wrote its migration. If you set up by hand, write it with this command:

```bash
dox auth:tokens-table --users-table=users
dox migrate
```

`--users-table=users` adds a foreign key with cascade delete, so when you delete a user, the user's tokens are deleted too. For users with uuid or text ids, see [Users with uuid or text ids](#users-with-uuid-or-text-ids).

### Issuing tokens

The controller makes a token on register and on login. `Hash.makeAsync` and `attempt` run bcrypt in another isolate, so they do not block the server:

```dart title="lib/app/http/controllers/auth.controller.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/dtos/auth/auth.dto.dart';
import 'package:my_app/app/models/user/user.model.dart';

@Inject()
class AuthController {
  /// POST /api/auth/register: make an account and give a token.
  Future<DoxResponse> register(RegisterUser body) async {
    User user = User()
      ..name = body.name
      ..email = body.email
      ..password = await Hash.makeAsync(body.password);
    await user.save();

    AccessToken token = await Auth().createAccessToken(user, name: 'login');
    return response(<String, dynamic>{
      'token': token.value,
      'user': user,
    }).statusCode(201);
  }

  /// POST /api/auth/login: check the email and password, give a token.
  Future<Map<String, dynamic>> login(DoxRequest req, LoginUser body) async {
    Auth auth = Auth(ip: req.ip());
    String? token = await auth.attempt(<String, dynamic>{
      'email': body.email,
      'password': body.password,
    });
    if (token == null) {
      throw UnAuthorizedException(message: 'Wrong email or password');
    }
    return <String, dynamic>{'token': token, 'user': auth.user<User>()};
  }

  /// GET /api/auth/me: the logged-in user.
  User? me(DoxRequest req) {
    return req.auth?.user<User>();
  }

  /// POST /api/auth/logout: the token of this request stops working.
  Future<Map<String, bool>> logout(DoxRequest req) async {
    await (req.auth as Auth).revokeToken(req);
    return <String, bool>{'logged_out': true};
  }
}
```

`attempt` finds the user by email and checks the password. It gives a new token with all abilities, or `null` when the login is wrong. `Auth(ip: req.ip())` gives the client ip to the [login throttle](#login-throttle).

### Protecting the API routes

Add `AuthMiddleware()` to a route to protect it. A request with no good token stops with a `401`. You should also put a [rate limit](rate-limiting.md) on register and login, because it slows down password guessing:

```dart title="lib/routes/api.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/http/controllers/api.controller.dart';
import 'package:my_app/app/http/controllers/auth.controller.dart';

class ApiRouter extends Router {
  @override
  String get prefix => 'api';

  @override
  List<dynamic> get middleware => <dynamic>[];

  @override
  void register() {
    Route.get('/ping', (ApiController c) => c.pong);

    // for guests
    Route.post('/auth/register', <dynamic>[
      RateLimit(max: 5, name: 'register'),
      (AuthController c) => c.register,
    ]);
    Route.post('/auth/login', <dynamic>[
      RateLimit(max: 5, name: 'login'),
      (AuthController c) => c.login,
    ]);

    // for logged-in users
    Route.get('/auth/me', <dynamic>[AuthMiddleware(), (AuthController c) => c.me]);
    Route.post('/auth/logout', <dynamic>[
      AuthMiddleware(),
      (AuthController c) => c.logout,
    ]);
  }
}
```

Run `dart run build_runner build` again, then start the app with `dox s`.

### Sending the token

The client sends the token in the `Authorization` header. You can try the flow with curl:

```bash
# log in, and keep the token in TOKEN
curl -X POST localhost:3000/api/auth/login -H 'Content-Type: application/json' \
  -d '{"email":"ada@example.com","password":"secret-pass"}'
# 200 {"token":"oat_2.OTAG...","user":{"id":1,...}}
TOKEN='oat_2.OTAG...'

curl localhost:3000/api/auth/me -H "Authorization: Bearer $TOKEN"
# 200 {"id":1,"name":"Ada","email":"ada@example.com",...}

curl localhost:3000/api/auth/me
# 401 {"code":"unauthorized","message":"Authentication failed"}
```

### Token abilities {#abilities}

An **ability** is a name like `posts:read` on a token. It says what the token may do. Sometimes you want a token that can do only a few things, for example a token for a script that only reads posts. Give the abilities when you make the token. The default is `*`, which means all abilities:

```dart
AccessToken token = await auth.createAccessToken(
  auth.user<User>()!,
  name: 'script',
  abilities: <String>['posts:read'],
  expiresIn: const Duration(days: 90),
);
```

Check an ability in the controller with `tokenCan`. It is `true` when the token has the ability or `*`:

```dart
if (!(req.auth as Auth).tokenCan('posts:read')) {
  throw ForbiddenHttpException();
}
```

`AuthMiddleware` only checks that the token is good. So a route with no `tokenCan` check takes every token, and you must check the ability on each route that needs one. `tokenCan` is always `false` for a session or JWT login.

You should also guard the routes that make or renew tokens with an ability like `tokens:manage`. A login token has `*`, so it passes. A script token does not, so a leaked script token can not make new tokens.

### Listing and revoking tokens

Use these methods to manage the tokens of a user. A revoked token is deleted from the table, so it stops working at once:

```dart
await Auth().accessTokens(user);           // all tokens of the user, newest first, expired ones too
await Auth().revokeAccessToken(user, id);  // false when the user has no token with this id
await Auth().revokeAllAccessTokens(user);  // all tokens of the user, eg. after a password change
await Auth().revokeToken(req);             // the token of this request (a logout)
```

`token.toJson()` has no hash and no plain token, so you can send a token list to the client.

Expired tokens stay in the table until you delete them. Run `pruneExpiredAccessTokens` from a [scheduled task](../digging-deeper/scheduler.md):

```dart
await Auth().pruneExpiredAccessTokens();   // delete expired tokens, eg. from a scheduled job
```

### Rotating tokens {#rotate-a-token}

Rotate a token to renew it before it expires. `rotateAccessToken` makes a new token with the same user, name and abilities, and the old token stops working at once:

```dart
/// POST /api/auth/refresh: a new token in place of the token of this
/// request. The old token stops working at once.
Future<Map<String, dynamic>> refresh(DoxRequest req) async {
  Auth auth = req.auth as Auth;
  if (!auth.tokenCan('tokens:manage')) {
    throw ForbiddenHttpException();
  }
  AccessToken next = await auth.rotateAccessToken(auth.currentAccessToken!);
  return <String, dynamic>{
    'token': next.value,
    'expires_at': next.expiresAt?.toIso8601String(),
  };
}
```

A token can be rotated only once. A second rotate, or a rotate of a revoked or expired token, throws an `UnAuthorizedException` (`401`).

If one client sends requests in parallel, a request that is still on the way with the old token would fail. In that case give a short `grace`, so the old token works a few more seconds. Keep it short, because a stolen old token works on every route in that time:

```dart
rotateAccessToken(token, grace: const Duration(seconds: 10))
```

Each rotate gives the token a full new life. So a client that rotates again and again stays logged in forever. If you want a limit, keep the first login time yourself, or ask for the password again after some time.

## JWT tokens

A JWT is a signed token. The server keeps no list of tokens, so a token works until it expires, unless you turn on [revocation](#revoke-tokens). The user is still loaded from the database on each request, by the id in the token. This way needs no token table.

For a longer walkthrough, see the [JWT auth guide](../guides/jwt-auth.md).

### Configuring the JWT guard

Change the guard driver to `JwtAuthDriver`:

```dart title="lib/config/auth.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:my_app/app/models/user/user.model.dart';
import 'package:my_app/config/env.dart';

AuthConfig authConfig = AuthConfig(
  defaultGuard: 'api',
  guards: <String, AuthGuard>{
    'api': AuthGuard(
      driver: JwtAuthDriver(
        secret: SecretKey(env.appKey),
        expiresIn: const Duration(days: 7),
        // the token holds only the user id
        minimalPayload: true,
        // lets logout stop a token before it expires
        revocation: true,
      ),
      provider: AuthProvider(model: () => User()),
    ),
  },
);
```

`secret` signs the tokens. `APP_KEY` is fine, because it must be at least 32 bytes. `dox key:generate` makes a new one. `expiresIn` is one hour by default.

### Issuing JWT tokens

The controller and routes are the same as for [access tokens](#issuing-tokens), with two changes. On register, `Auth().login(user)` gives a token with no password check:

```dart
String? token = Auth().login(user);
```

On logout, revoke the token. This needs `revocation: true`:

```dart
await Auth().revokeToken(req);
```

Login with `attempt` works the same: it checks the password and gives a JWT.

### Small tokens

Anyone can read a JWT payload, because it is signed, not secret. By default the token holds the user (`toJson()` without `hidden` fields). You should set `minimalPayload: true`, so the token holds only the user id (the `sub` claim). Then load the user with `req.auth?.user<User>()`, not from the token.

### Revoking tokens {#revoke-tokens}

By default a JWT works until it expires. Turn on revocation if you want logout to stop a token at once. The driver then keeps revoked tokens in a [cache store](../digging-deeper/cache.md):

```dart
JwtAuthDriver(
  secret: SecretKey(env.appKey),
  revocation: true,
  revocationStore: 'auth',
)
```

Use `revokeToken` for a logout:

```dart
await Auth().revokeToken(req);     // revoke the bearer token of this request (a logout)
```

Use `revokeAllTokens` to log a user out everywhere, for example after a password change or a ban:

```dart
await Auth().revokeAllTokens(id);  // revoke all tokens of a user, eg. after a password change or a ban
```

Give auth its own cache store, like `redis` with its own prefix, and never flush it. A flush brings revoked tokens back until they expire. With revocation off, these methods throw a `StateError`, so no one thinks a token is revoked when it is not.

### Changing the secret {#change-the-jwt-secret}

Sometimes you must change the signing secret. New tokens are always signed with `secret`, and old tokens are checked with the old secrets too.

If the secret is `APP_KEY`, follow [Change the key](encryption.md#change-the-key-key-rotation). The old keys in `AppConfig.previousKeys` are used, so you need nothing more.

If you use a separate JWT secret, give the old one to the driver:

```dart
JwtAuthDriver(
  secret: SecretKey(env.jwtSecret),
  previousSecrets: <JWTKey>[SecretKey(env.jwtOldSecret)],
)
```

Remove the old secret once `expiresIn` has passed. To log out everyone at once, change the secret and keep no old secrets. Never keep a leaked secret, because anyone who has it can make tokens.

## Session login for web pages

For web pages, keep the login in the session instead of a token. The browser sends the session cookie, so the client does nothing. This needs `SessionMiddleware` and `CsrfMiddleware`. See [Session](../the-basic/session.md) and [CSRF protection](csrf.md).

### Configuring the session guard

Use `SessionAuthDriver`:

```dart title="lib/config/auth.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:my_app/app/models/user/user.model.dart';

AuthConfig authConfig = AuthConfig(
  defaultGuard: 'web',
  guards: <String, AuthGuard>{
    'web': AuthGuard(
      driver: SessionAuthDriver(),
      provider: AuthProvider(model: () => User()),
    ),
  },
);
```

### Logging in

`attemptSession` checks the password and keeps the user id in the session. `loginSession` logs a user in with no password check. `logout` removes the login and all session data. Login and logout also give the session a new id and a new CSRF token.

This controller answers JSON, for a front end with axios or Inertia. axios sends the CSRF token by itself:

```dart title="lib/app/http/controllers/session.controller.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/dtos/auth/auth.dto.dart';
import 'package:my_app/app/models/user/user.model.dart';

@Inject()
class SessionController {
  /// POST /register: make an account and log in.
  Future<DoxResponse> register(DoxRequest req, RegisterUser body) async {
    User user = User()
      ..name = body.name
      ..email = body.email
      ..password = await Hash.makeAsync(body.password);
    await user.save();

    Auth().loginSession(req, user);
    return response(user).statusCode(201);
  }

  /// POST /login: check the email and password, keep the login in the session.
  Future<User?> login(DoxRequest req, LoginUser body) async {
    Auth auth = Auth();
    bool ok = await auth.attemptSession(req, <String, dynamic>{
      'email': body.email,
      'password': body.password,
    });
    if (!ok) {
      throw UnAuthorizedException(message: 'Wrong email or password');
    }
    return auth.user<User>();
  }

  /// GET /me: the logged-in user.
  User? me(DoxRequest req) {
    return req.auth?.user<User>();
  }

  /// POST /logout: remove the login and all session data.
  Map<String, bool> logout(DoxRequest req) {
    Auth().logout(req);
    return <String, bool>{'logged_out': true};
  }
}
```

For an HTML form, answer with a redirect instead. The method then returns `Future<DoxResponse>`. See [CSRF protection](csrf.md#html-forms) for the form token:

```dart
if (!ok) {
  req.session.flashErrors(<String, dynamic>{'email': 'Wrong email or password'});
  return back(req);
}
return redirect('/dashboard');
```

### Adding the routes

Put the session and CSRF middleware on the web router only, so the API routes stay without a session:

```dart title="lib/routes/web.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/http/controllers/session.controller.dart';
import 'package:my_app/app/http/controllers/web.controller.dart';

class WebRouter extends Router {
  @override
  List<dynamic> get middleware => <dynamic>[
    const SessionMiddleware(),
    const CsrfMiddleware(),
  ];

  @override
  void register() {
    Route.get('/ping', (WebController c) => c.pong);

    Route.post('/register', <dynamic>[
      RateLimit(max: 5, name: 'register'),
      (SessionController c) => c.register,
    ]);
    Route.post('/login', <dynamic>[
      RateLimit(max: 5, name: 'login'),
      (SessionController c) => c.login,
    ]);
    Route.get('/me', <dynamic>[AuthMiddleware(), (SessionController c) => c.me]);
    Route.post('/logout', <dynamic>[
      AuthMiddleware(),
      (SessionController c) => c.logout,
    ]);
  }
}
```

### Redirecting guests

On web pages you often want to send a guest to the login page instead of a `401`. Use `redirectTo` for this:

```dart
AuthMiddleware(redirectTo: '/login')
```

With the `jsonNoRedirect` [flag](authorization.md#auth-flags) on, a JSON or XHR client gets a `401` and no redirect.

### Ending sessions when the password changes {#end-other-sessions-when-the-password-changes}

By default, a session stays logged in after the user changes the password, so a stolen session still works. Turn on the `endSessionsOnPasswordChange` [flag](authorization.md#auth-flags) to fix this. A password change then ends all sessions of the user on their next request through `AuthMiddleware`:

```dart title="lib/config/auth.dart"
AuthConfig authConfig = AuthConfig(
  defaultGuard: 'web',
  guards: guards,
  flags: const AuthFlags(endSessionsOnPasswordChange: true),
);
```

This also ends the current session. If your app changes the password itself, keep the current session with `updateSessionPasswordHash` after `save()`:

```dart
user.password = await Hash.makeAsync(newPassword);
await user.save();
Auth().updateSessionPasswordHash(req, user);
```

Pass a fully loaded user. A user from a `select()` with no password column looks like a user with no password, so the session ends.

### Logging out other devices

`logoutOtherDevices` ends all other sessions of the user and keeps this one. It checks the password, so it needs the password from a form. It needs a session guard and the flag above:

```dart
/// POST /logout-others: end the sessions on other devices.
Future<Map<String, bool>> logoutOthers(DoxRequest req, ConfirmPassword body) async {
  await (req.auth as Auth).logoutOtherDevices(req, body.password);
  return <String, bool>{'done': true};
}
```

`ConfirmPassword` is a DTO with one `password` field, like `LoginUser`. A wrong password throws an `UnAuthorizedException` (`401`, code `wrong_password`). Because it checks a password, put a rate limit on the route, like on a login.

## Protecting routes

### More than one guard

Sometimes one app needs more than one kind of login. For example, a session for web pages, access tokens for the API, and admins in their own table. Each guard has its own driver and its own user model:

```dart title="lib/config/auth.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:my_app/app/models/admin/admin.model.dart';
import 'package:my_app/app/models/user/user.model.dart';

AuthConfig authConfig = AuthConfig(
  defaultGuard: 'web',
  guards: <String, AuthGuard>{
    'web': AuthGuard(
      driver: SessionAuthDriver(),
      provider: AuthProvider(model: () => User()),
    ),
    'api': AuthGuard(
      driver: AccessTokenAuthDriver(),
      provider: AuthProvider(model: () => User()),
    ),
    'admin': AuthGuard(
      driver: AccessTokenAuthDriver(table: 'admin_access_tokens'),
      provider: AuthProvider(model: () => Admin()),
    ),
  },
);
```

Pick a guard by name with `guard:`:

```dart
String? token = await Auth(guard: 'admin').attempt(credentials);

Route.get('/admin', <dynamic>[AuthMiddleware(guard: 'admin'), (AdminController c) => c.index]);
```

To accept more than one guard on a route, use `guards:`. The first guard with a good login sets `req.auth`:

```dart
// try the guards in order
Route.get('/me', <dynamic>[AuthMiddleware(guards: <String>['web', 'api']), (UserController c) => c.me]);
```

A token of one guard does not work on another guard. Give each user model its own token table, with `table:` on the driver and in the migration (`AccessTokenTables.up(schema, table: 'admin_access_tokens')`).

### Optional login

A public page may still want to know the user. `AuthMiddleware(optional: true)` sets `req.auth` when the login is good, and lets guests through with `req.auth` as `null`:

```dart
Route.get('/posts', <dynamic>[AuthMiddleware(optional: true), (PostController c) => c.index]);
```

### Pages for guests only

Login and register pages are for guests only. `GuestMiddleware` sends a logged-in user to `redirectTo`. With no `redirectTo`, the answer is a `403`:

```dart
Route.get('/login', <dynamic>[GuestMiddleware(redirectTo: '/dashboard'), (PageController c) => c.login]);
```

### Getting the logged in user

After `AuthMiddleware`, `req.auth` holds the login. It is `null` for a guest:

```dart
User? user = req.auth?.user<User>();
```

`req.auth?.id()` gives the primary key of the user. For `tokenCan` and `currentAccessToken`, cast it: `req.auth as Auth`.

## Login throttle {#login-throttle}

You should limit failed logins, because it stops password guessing on one account. The login throttle is off by default. Turn it on in your auth provider:

```dart title="lib/providers/auth_provider.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
import 'package:my_app/config/auth.dart';

class AppAuthProvider extends DoxProvider {
  @override
  void setup() {
    Auth.initialize(authConfig);
    // 5 failed logins a minute. Change it with maxAttempts: and decay:
    Auth.throttle = LoginThrottle();
  }
}
```

After `maxAttempts` failed logins for the same email and ip, the next try throws `LoginThrottledException` (`429`) until `decay` has passed. A good login clears the count.

Always pass the ip with `Auth(ip: req.ip())`. Without an ip, the count is per account only, so anyone can lock an account. `attemptSession` takes the ip from the request.

The counts live in the app cache. If you run many isolates or servers, use a shared store with `LoginThrottle(store: 'redis')`. The throttle does not stop many tries sent at the same time, so also keep a `RateLimit` on the login route.

## Password hashing {#password-hash-cost}

Passwords use bcrypt with cost 10 by default. Each step up doubles the time of a login. If you raise it, set the cost for new hashes and tell the driver, so a login for an unknown email takes as long as a wrong password:

```dart
Hash.rounds = 12;
JwtAuthDriver(secret: SecretKey(env.appKey), hashRounds: 12);
SessionAuthDriver(hashRounds: 12);
AccessTokenAuthDriver(hashRounds: 12);
```

Old hashes keep their own cost, so they still work. Hash them again on the next good login:

```dart
if (Auth.needsRehash(user.password!)) {
  user.password = await Hash.makeAsync(password);
  await user.save();
  // with a session login and the endSessionsOnPasswordChange flag:
  // Auth().updateSessionPasswordHash(req, user);
}
```

bcrypt reads at most 72 bytes. A longer password throws an `ArgumentError`, so limit the length in the DTO. See [Hashing](hashing.md).

## Recipes

### Logging in with another field

`attempt` searches the user by `identifierFields` and checks the column in `passwordField`. Change them if your users log in with a username, or the hash is in another column:

```dart
AuthProvider(
  model: () => User(),
  identifierFields: <String>['username'],
  passwordField: 'password_hash',
)
```

### Users with uuid or text ids

Access tokens keep the user id in the `tokenable_id` column, which is a big int by default. If your users have other ids, use the same choice in the migration and on the driver:

- uuid ids: `dox auth:tokens-table --uuid` and `AccessTokenAuthDriver(uuidIds: true)`.
- text ids: `dox auth:tokens-table --string-ids` and `AccessTokenAuthDriver(stringIds: true)`.

Session and JWT guards need nothing for this.

### Two-step login (2FA) {#change-the-abilities-of-a-token}

A two-step login asks for a password, then for a code from a mail or an app. Your app makes and checks the code. `dox_auth` helps with tokens:

1. Step one checks the password with `once()`, and gives a short token with only the `2fa:pending` ability.
2. Step two checks the code, rotates the token, and gives the new token all abilities with `setAccessTokenAbilities`.
3. Each route that needs the second step uses a middleware that refuses `2fa:pending` tokens.

The controller with both steps:

```dart title="lib/app/http/controllers/two_factor.controller.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/dtos/auth/auth.dto.dart';
import 'package:my_app/app/dtos/two_factor_code/two_factor_code.dto.dart';
import 'package:my_app/app/models/user/user.model.dart';

@Inject()
class TwoFactorController {
  /// POST /api/auth/login, step one: check the password. The token
  /// works 10 minutes, and only for step two.
  Future<Map<String, dynamic>> login(DoxRequest req, LoginUser body) async {
    Auth auth = Auth(ip: req.ip());
    bool ok = await auth.once(<String, dynamic>{
      'email': body.email,
      'password': body.password,
    });
    if (!ok) {
      throw UnAuthorizedException(message: 'Wrong email or password');
    }
    AccessToken token = await auth.createAccessToken(
      auth.user<User>()!,
      name: 'login',
      abilities: <String>['2fa:pending'],
      expiresIn: const Duration(minutes: 10),
    );
    // send the code to the user here, for example by mail
    return <String, dynamic>{'token': token.value, 'two_factor': true};
  }

  /// POST /api/auth/two-factor, step two: check the code. Give a new
  /// token for a full login. The step-one token ends.
  Future<Map<String, dynamic>> verify(DoxRequest req, TwoFactorCode body) async {
    Auth auth = req.auth as Auth;
    AccessToken token = auth.currentAccessToken!;
    if (!token.abilities.contains('2fa:pending')) {
      throw ForbiddenHttpException();
    }
    if (!_codeIsGood(auth.user<User>()!, body.code)) {
      throw UnAuthorizedException(message: 'Wrong code');
    }
    // a new token with the expiresIn of the driver. It still has 2fa:pending.
    AccessToken full = await auth.rotateAccessToken(token);
    // all abilities, like a normal login
    await auth.setAccessTokenAbilities(full, <String>['*']);
    return <String, dynamic>{'token': full.value};
  }

  /// Check the code with your own two-step code. Make each code expire,
  /// and limit the wrong tries per user.
  bool _codeIsGood(User user, String code) {
    throw UnimplementedError('check the two-step code');
  }
}
```

`verify` checks `abilities.contains('2fa:pending')`, not `tokenCan`, because `tokenCan` is also `true` for `*`. Rotate first, then set the abilities, so no token ever has `*` when a step fails.

The middleware for the routes of a logged-in user. Put it after `AuthMiddleware()`:

```dart title="lib/app/http/middleware/two_factor.middleware.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';

/// Lets a request through only when its token did the second step.
/// Put it after AuthMiddleware.
dynamic requireTwoFactor(DoxRequest req) {
  Auth? auth = req.auth as Auth?;
  if (auth == null || auth.currentAccessToken == null) {
    throw UnAuthorizedException();
  }
  if (auth.currentAccessToken!.abilities.contains('2fa:pending')) {
    throw ForbiddenHttpException();
  }
  return req;
}
```

Use `TwoFactorController.login` as the login route, and add the step-two route with a rate limit:

```dart
Route.post('/auth/login', <dynamic>[
  RateLimit(max: 5, name: 'login'),
  (TwoFactorController c) => c.login,
]);
Route.post('/auth/two-factor', <dynamic>[
  RateLimit(max: 5, name: 'two-factor'),
  AuthMiddleware(),
  (TwoFactorController c) => c.verify,
]);
```

A route without `requireTwoFactor` still takes a step-one token. Register must give no token, and any other place that gives a token must also do both steps.

### Checking a login with no request {#check-a-login-with-no-request}

Code that has no request, like a [Socket.IO](../packages/socketio.md#log-in-a-socket) login, can check a token or a session itself. Both give `null` when the login is not good:

```dart
User? user = await Auth(guard: 'api').userFromToken(token);
User? user = await Auth(guard: 'web').userFromSession(session);
```

`userFromToken` runs the same checks as a request, for JWT and access token guards. Give the token without the `Bearer ` prefix. For `userFromSession`, load the session with `SessionMiddleware().fromCookie(value)`. See [Session](../the-basic/session.md#other-cases).

### Writing your own guard

Sometimes you want to log users in your own way, like with an API key in a header. Write a driver: extend `AuthDriver` and return the user from `verifyToken`. `AuthMiddleware` and `req.auth` then work as with the other drivers.

This driver finds the user by a SHA-256 hash of the key, so a leak of the table does not leak the keys. It uses the `crypto` package:

```dart title="lib/app/auth/api_key_auth_driver.dart"
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dox_auth/dox_auth.dart';
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

Add it as a guard, and use the guard on the route:

```dart
'key': AuthGuard(
  driver: ApiKeyAuthDriver(),
  provider: AuthProvider(model: () => User()),
),

Route.get('/me', <dynamic>[AuthMiddleware(guard: 'key'), (DoxRequest req) => req.auth?.user<User>()]);
```

Make each key long and random, like `openssl rand -hex 32`. Then a fast hash like SHA-256 is safe. Do not use bcrypt here, because you can not search by a bcrypt hash.

If you already have your own middleware, set the user with `Auth().setUser(req, user)`. Then `req.auth` gives this user:

```dart
Auth(guard: 'api').setUser(req, user);
```

### When the database fails

The access token check reads the database. When the database fails, the request gets a `401` by default, and the error is reported. But many clients take a `401` as "you are logged out", so a short database problem logs users out. Turn on `throwOnError` to throw the error instead:

```dart
AccessTokenAuthDriver(
  expiresIn: const Duration(days: 30),
  throwOnError: true,
)
```

The error then goes to your [exception handler](../the-basic/errors.md), which answers `500` by default. To answer `503`, so the client tries again, catch the database errors in `render`:

```dart title="lib/app/exception_handler.dart"
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_orm/dox_orm.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

class AppExceptionHandler extends ExceptionHandler {
  const AppExceptionHandler();

  @override
  dynamic render(Object error, HttpRequest req) {
    // a database error: ask the client to try again
    if (error is SqliteException ||
        error is PgException ||
        error is MysqlException) {
      return HttpStatusException(503, headers: <String, String>{'retry-after': '5'});
    }
    return super.render(error, req);
  }
}
```

`SqliteException` comes from the `sqlite3` package (`dart pub add sqlite3`). On Postgres or MySQL only, drop it. Set the handler with `exceptionHandler: const AppExceptionHandler()` in `AppConfig`.

## Testing {#test-it}

`DoxTestClient` runs your app in the test, and `withToken` sends `Authorization: Bearer <token>`. This test works for access tokens and JWT. It uses the database of `.env`, so it runs the migrations first:

```dart title="test/auth_test.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_core/testing.dart';
import 'package:dox_migration/dox_migration.dart';
import 'package:my_app/config/app.dart';
import 'package:my_app/config/database.dart';
import 'package:test/test.dart';

import '../db/migration/migrations.dart';

void main() {
  late DoxTestClient client;

  setUpAll(() async {
    Dox().initialize(appConfig);
    await Migrator(
      migrations: migrations,
      config: databaseConfig.getConnectionConfig(),
    ).migrate();
    client = await DoxTestClient.start(appConfig);
  });

  tearDownAll(() async {
    await client.close();
  });

  test('register, then use the token', () async {
    String email = 'test-${DateTime.now().microsecondsSinceEpoch}@example.com';
    TestResponse register = await client.post(
      '/api/auth/register',
      body: <String, dynamic>{
        'name': 'Test',
        'email': email,
        'password': 'secret-pass',
      },
    );
    register.expectStatus(201);
    String token = register.json['token'] as String;

    TestResponse me = await client.withToken(token).get('/api/auth/me');
    me.expectStatus(200);
    expect(me.json['email'], email);
    expect(me.json.containsKey('password'), isFalse);
  });

  test('no token gives 401', () async {
    (await client.get('/api/auth/me')).expectStatus(401);
  });
}
```

To act as a user with no HTTP login, make a token in the test with `await Auth().createAccessToken(user)`, then use `client.withToken(token.value!)`. For a session app, use `client.withSession()`, which keeps cookies and sends the CSRF token. See [Testing](../digging-deeper/testing.md).

## Problems

| Error | Cause | Fix |
| --- | --- | --- |
| `LateInitializationError: Field 'config' has not been initialized.` | `Auth.initialize` did not run. `AppAuthProvider` is missing, or the generator did not run. | Add [`AppAuthProvider`](#5-load-the-config-when-the-app-starts), then run `dart run build_runner build`. |
| `401` `Authentication failed` | No `Authorization` header, a bad, expired or revoked token, a deleted user, or a token of another guard. | Send `Authorization: Bearer <token>`. Log in again. |
| `403` `Forbidden` | The token does not have the ability. | Use a token with the ability. See [Token abilities](#abilities). |
| `Invalid argument (guard): no auth guard with this name: "admin"` | A guard name that is not in `guards`. | Fix the name, or add the guard. |
| `Bad state: The auth guard 'api' does not use SessionAuthDriver. ...` | `logout`, `attemptSession` or `loginSession` on a token guard. | Use `revokeToken(req)` to log out a token. |
| `Bad state: The auth guard 'api' does not use AccessTokenAuthDriver.` | An access token method on a JWT or session guard. | Use a guard with `AccessTokenAuthDriver`. |
| `Bad state: The auth guard 'web' does not use JwtAuthDriver.` | `revokeAllTokens`, `forgetUser`, `userFromToken` or `revokeToken` on a session guard. | A session logs out with `logout(req)`. |
| `Bad state: AccessTokenAuthDriver makes tokens with Auth().createAccessToken(user), not login().` | `Auth().login(user)` on an access token guard. | Use `createAccessToken(user)`. |
| `Bad state: revokeToken needs token revocation. ...` | A revoke method on a JWT guard without revocation. | Set `revocation: true`. See [Revoking tokens](#revoke-tokens). |
| `Bad state: The table 'auth_access_tokens' has no rotated_at column. ...` | `rotateAccessToken` on an old token table. | Add the column. See [A token table without `rotated_at`](#a-token-table-without-rotated_at). |
| `401` `The access token was already rotated.` | A second rotate of the same token. | Rotate the new token, not the old one. |
| `401` `The access token is expired.` or `is revoked or does not exist.` | Rotate of an expired or revoked token. | Log in again. |
| `Invalid argument(s) (secret): The JWT secret is empty. ...` | `JwtAuthDriver` with an empty secret. | Set `APP_KEY` with `dox key:generate`. |
| `Invalid argument(s) (secret): The JWT secret is <n> bytes. ...` | A secret shorter than 32 bytes. In `development`, `local`, `test` and `testing` it is only a warning. | Run `dox key:generate`. |
| `Invalid argument(s) (password): The password is too long. ...` | A password longer than 72 bytes. | Limit the length in the DTO. |
| `Invalid argument(s): Set guard or a non-empty guards list, not both.` | `AuthMiddleware` with both `guard` and `guards`, or `guards: []`. | Set one of them. |
| `429` `Too many login attempts. ...` | The [login throttle](#login-throttle). | Wait `retryAfter`. |
| `419` `CSRF token mismatch` | A session `POST` without the CSRF token. | See [CSRF protection](csrf.md). |
| `403` `Already logged in` | `GuestMiddleware` with no `redirectTo`, for a logged-in user. | Set `redirectTo`, or log out first. |
| `401` `wrong_password` | `logoutOtherDevices` with a wrong password. | Show an error on the form. |
| `Bad state: logoutOtherDevices() needs the endSessionsOnPasswordChange flag` | `logoutOtherDevices` with the flag off. | Turn the [flag](#end-other-sessions-when-the-password-changes) on. |

## Details

### 401, 403, 419 and 429

- `401`: the user is not logged in. The client should log in again.
- `403`: the user is logged in, but may not do this, like a missing ability or a failed [policy](authorization.md).
- `419`: a session request with no CSRF token.
- `429`: too many failed logins.

### Access tokens

- `attempt` always gives a token with `*`.
- `revokeToken(req)` on the `Auth` of `AuthMiddleware` uses the token that was already checked.
- `last_used_at` is written at most once a minute per token. A failed write is reported and the request goes on.
- `tokenable_type` is the table name of the user model. If you rename the users table, old tokens stop working.
- Each token has a `type`, which is the guard name. If you rename a guard, set `AccessTokenAuthDriver(type: 'old-name')` to keep its tokens.
- When you delete a user without `--users-table`, call `revokeAllAccessTokens(user)`, so old tokens can not match a new user with the same id.
- The migration makes the table on the default connection. For `AccessTokenAuthDriver(connection: 'other')`, make it on that connection.
- `rotateAccessToken` runs in one transaction. When two rotates of one token run at the same time, only one works. `expiresIn:` and `name:` change the new token.
- A uuid is kept and compared in lower case. Text ids are compared exactly.
- A token name over 255 characters throws an `ArgumentError`.
- On MySQL, `expires_at` is rounded to the second.

### A token table without `rotated_at`

A token table without the `rotated_at` column works for everything except rotate. To add it, stop `dox s`, run `dox make:migration add_rotated_at_to_auth_access_tokens`, and put this in the new file. Then run `dox migrate`:

```dart
// ignore_for_file: file_names
import 'package:dox_migration/dox_migration.dart';

class AddRotatedAtToAuthAccessTokens extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await schema.table('auth_access_tokens', (Table t) {
      t.dateTimeTz('rotated_at').nullable();
    });
  }

  @override
  Future<void> down(Schema schema) async {
    await schema.table('auth_access_tokens', (Table t) {
      t.dropColumn('rotated_at');
    });
  }
}
```

### JWT

- A token is checked with `secret` first, then with each old secret. An expired token fails at once.
- The token keeps the guard name in its `aud` claim, so a token of one guard does not work on another.
- `userCacheTtl` keeps the user in memory for this time and skips the query. A deleted or changed user is seen only after it ends, unless `forgetUser(id)` runs. Each isolate has its own cache.
- With revocation on, each token check reads the revocation store. Use `memory` for one isolate, or `redis` for many. When the store can not be read, the token is checked without it, and a warning is printed once.
- A revoked token stays on the deny list only until it expires. `revokeAllTokens` keeps tokens made after the call. It uses the server clock, so keep clocks in sync.
- The HMAC key is made from `secret` with HKDF-SHA256 and the label `dox:jwt`. Another service that checks the tokens needs `driver.signingKey`.
- `JwtAuthDriver.bearerToken(req)` gives the token of a request.

### Sessions

- The session keeps only the user id. `AuthMiddleware` loads the user on each request, so a deleted user is logged out.
- With the default `cookie` session driver, an old copy of the cookie works until the session `lifetime` ends. If logout must end old cookies, use the `cache` session driver.
- With `endSessionsOnPasswordChange`, a session made while the flag was off gets its fingerprint on its first checked request. To end all old sessions at once, change `APP_KEY` without `previousKeys`, or clear the `cache` session store.
- The password column must give the same value on every read, or every session ends.
- A rehash on login also changes the hash, so call `updateSessionPasswordHash` after it.

### Other cases

- `attempt` runs bcrypt also when no user is found, so the answer time does not tell if an email has an account.
- `once` checks the password like `attempt`, but makes no token and does not touch the session.
- With `optional: true`, a database error in the JWT or access token check goes on as a guest and is reported. With the session driver, it gives a `500`.
- `Auth.throttle` is static, so set it in a provider. If you set it in `main()`, only the first isolate throttles.
- `Auth.needsRehash(hash, rounds: 12)` checks against another cost. `Auth.hashCost(hash)` gives the cost of a hash.

### Reference

#### `AuthConfig` and `AuthGuard`

| Option | Default | What it does |
| --- | --- | --- |
| `AuthConfig(defaultGuard:)` | required | the guard that `Auth()` and the middleware use when no guard is given |
| `AuthConfig(guards:)` | `{}` | the guards, by name |
| `AuthConfig(flags:)` | `AuthFlags()` (all off) | opt-in behaviors. See [Auth flags](authorization.md#auth-flags) |
| `AuthGuard(driver:)` | required | `AccessTokenAuthDriver`, `JwtAuthDriver`, `SessionAuthDriver`, or your own `AuthDriver` |
| `AuthGuard(provider:)` | required | the `AuthProvider`: which model holds the users |

#### `AuthProvider`

| Option | Default | What it does |
| --- | --- | --- |
| `model` | required | a function that makes a new model, like `() => User()` |
| `identifierFields` | `['email']` | the fields `attempt` searches by |
| `passwordField` | `'password'` | the column with the bcrypt hash |

#### `Auth`

| Method | What it does |
| --- | --- |
| `Auth.initialize(AuthConfig)` | sets the config. Call it once, in a `DoxProvider` |
| `Auth(guard: 'admin')` | uses another guard from `guards`. Without `guard`, it uses `defaultGuard` |
| `Auth(ip: req.ip())` | gives the client ip to `attempt`, for the [login throttle](#login-throttle) |
| `Auth.throttle` | the [login throttle](#login-throttle). `null` (off) by default |
| `await attempt(credentials)` | finds the user and checks the password. Gives a token (a JWT, or an access token with all abilities), or `null` |
| `await once(credentials)` | checks the password like `attempt`. Gives `true` or `false`. It makes no token and does not touch the session |
| `login(user)` | gives a JWT for this user, with no password check |
| `setUser(req, user)` | sets this user on `req.auth`, with no token and no password check |
| `user<T>()` | the user after `attempt`, `once` or `login` |
| `isLoggedIn()`, `check()` | `true` when there is a user |
| `guest()` | `true` when there is no user |
| `id()` | the primary key of the user, or `null`. It works when the key is in `hidden` |
| `await userFromToken(token)` | the user of a JWT or access token, with no request |
| `await userFromSession(session)` | the user of a session, with no request |
| `await attemptSession(req, credentials)` | checks the password and keeps the user id in the session. Gives `true` or `false`. Session guard only |
| `loginSession(req, user)` | keeps this user in the session, with no password check. Session guard only |
| `logout(req)` | removes the session login and all session data. Session guard only |
| `await logoutOtherDevices(req, password)` | checks the password and ends all other sessions of the user. Needs the `endSessionsOnPasswordChange` flag |
| `updateSessionPasswordHash(req, user)` | keeps the current session logged in after your app changed the password |
| `await revokeToken(req)` | revokes the bearer token of this request. JWT (needs [revocation](#revoke-tokens)) or access token |
| `await revokeAllTokens(id)` | revokes all JWTs of this user made before the current second. Needs revocation |
| `await forgetUser(id)` | drops this user from the `userCacheTtl` cache. Needs revocation |
| `await createAccessToken(user, name:, abilities:, expiresIn:)` | a new access token. `token.value` is the plain token. `abilities` default to `['*']`, `expiresIn` to the driver `expiresIn` |
| `await rotateAccessToken(token, grace:, name:, expiresIn:)` | a new access token in place of `token`. See [Rotating tokens](#rotate-a-token) |
| `await setAccessTokenAbilities(token, abilities)` | replaces the whole abilities list of a token |
| `await accessTokens(user)` | all access tokens of the user, newest first |
| `await revokeAccessToken(user, id)` | deletes one access token of the user. `false` when the user has no such token |
| `await revokeAllAccessTokens(user)` | deletes all access tokens of the user. Gives how many |
| `await pruneExpiredAccessTokens()` | deletes the expired tokens of the table. Gives how many |
| `currentAccessToken` | the `AccessToken` of this request, or `null` |
| `tokenCan(ability)` | `true` when the access token of this request has the ability, or `*` |
| `Auth.needsRehash(hash)` | `true` when the hash was not made with the cost of `Hash.rounds` |
| `Auth.hashCost(hash)` | the bcrypt cost of a hash, or `null` when it is not a bcrypt hash |

#### `req.auth`

| Code | What it gives |
| --- | --- |
| `req.auth` | an `IAuth?`. `null` for a guest, and on a route with no `AuthMiddleware`. A query or body field can not set it |
| `req.auth as Auth` | the `Auth`, for `tokenCan`, `currentAccessToken` and `revokeToken` |
| `req.auth?.isLoggedIn()` | `true` when a user is loaded |
| `req.auth?.id()` | the primary key of the user, or `null` |
| `req.auth?.user<User>()` | the user model |
| `req.auth?.toJson()` | the user as a map, without `hidden` fields |

#### `AccessTokenAuthDriver`

| Option | Default | What it does |
| --- | --- | --- |
| `table` | `'auth_access_tokens'` | the table of the tokens |
| `connection` | the default connection | the `dox_orm` connection name |
| `expiresIn` | `null` (no end) | how long a new token works |
| `hashRounds` | `10` | the bcrypt cost of your stored hashes, for `attempt` |
| `type` | the guard name | the type of the tokens. A token works only on a guard with the same type |
| `stringIds` | `false` | `true` for users with text ids. Use the same value in the migration |
| `uuidIds` | `false` | `true` for users with uuid ids. Use the same value in the migration |
| `throwOnError` | `false` | `true`: an error in a token check is thrown, not turned into a `401`. See [When the database fails](#when-the-database-fails) |

#### `AccessTokenTables.up` and `dox auth:tokens-table`

| Option | Flag | Default | What it does |
| --- | --- | --- | --- |
| `table` | none (edit the migration) | `'auth_access_tokens'` | the table name. Use the same name as the driver `table` |
| `uuidIds` | `--uuid` | `false` | `tokenable_id` is a uuid column (`UUID` on Postgres) |
| `stringIds` | `--string-ids` | `false` | `tokenable_id` is text. Do not use it with `--uuid` |
| `usersTable` | `--users-table=users` | none | adds a foreign key from `tokenable_id` to `usersKey` of this table, with cascade delete. The two id columns must have the same type |
| `usersKey` | `--users-key=uid` | `'id'` | the key column of `usersTable` |

`AccessTokenTables.down(schema, table: 'auth_access_tokens')` drops the table. The table has these columns: `id`, `tokenable_type`, `tokenable_id`, `type`, `name`, `hash`, `abilities`, `last_used_at`, `expires_at`, `rotated_at`, `created_at`, `updated_at`. `auth:tokens-table` is a [package command](../digging-deeper/package-commands.md) of `dox_auth`, and it never overwrites a migration that is already there.

#### `AccessToken`

| Field | What it is |
| --- | --- |
| `id` | the row id |
| `value` | the plain token. Only set by `createAccessToken` and `rotateAccessToken`. It is not kept |
| `name`, `type` | the name and the type |
| `tokenableType` | the table name of the user model |
| `tokenableId` | the user id: an `int`, or a `String` with `stringIds` or `uuidIds` |
| `abilities` | the list of abilities |
| `lastUsedAt`, `expiresAt`, `createdAt`, `updatedAt` | times, in UTC |
| `user` | the user. Set by `createAccessToken` and by a token check. `null` in `accessTokens(user)` |
| `can(ability)`, `cannot(ability)` | checks one ability (`*` passes every check) |
| `toJson()` | the token without the hash and the plain value |

#### `JwtAuthDriver`

| Option | Default | What it does |
| --- | --- | --- |
| `secret` | required | the key that signs tokens, like `SecretKey(env.appKey)`. It must be at least 32 bytes |
| `algorithm` | `JWTAlgorithm.HS256` | the signing algorithm. A token with another algorithm in its header is rejected |
| `expiresIn` | `Duration(hours: 1)` | how long a token is valid |
| `issuer` | `null` | the `iss` claim. When set, the check also reads it |
| `hashRounds` | `10` | the bcrypt cost of your stored hashes. Use the same value as `Hash.rounds` |
| `userCacheTtl` | `null` (off) | keep the user of a token in memory for this time |
| `previousSecrets` | `null` | old secrets, only to check tokens after a key change. `null` with `secret` = `APP_KEY`: the old keys come from `AppConfig.previousKeys`. `[]` turns it off |
| `minimalPayload` | `false` | put only the user id (the `sub` claim) in new tokens |
| `revocation` | `false` | turn on token revocation |
| `revocationStore` | `null` | the cache store for revoked tokens. `null` is the default app store |

#### `SessionAuthDriver`

| Option | Default | What it does |
| --- | --- | --- |
| `hashRounds` | `10` | the bcrypt cost of your stored hashes |

#### `AuthMiddleware` and `GuestMiddleware`

| Option | Default | What it does |
| --- | --- | --- |
| `AuthMiddleware(guard:)` | `defaultGuard` | the guard to check |
| `AuthMiddleware(guards:)` | none | several guards, tried in order. Do not set `guard` too |
| `AuthMiddleware(redirectTo:)` | none (`401`) | send a guest to this page instead of a `401`. Not used with `optional` |
| `AuthMiddleware(optional:)` | `false` | let guests through too |
| `GuestMiddleware(guard:)` | `defaultGuard` | the guard to check |
| `GuestMiddleware(redirectTo:)` | none (`403`) | send a logged-in user to this page instead of a `403` |

#### `LoginThrottle`

| Option | Default | What it does |
| --- | --- | --- |
| `maxAttempts` | `5` | failed logins allowed per login field and ip |
| `decay` | `Duration(minutes: 1)` | how long the count is kept, from the first failed login |
| `store` | `null` | the cache store for the counts. `null` is the default app store |
