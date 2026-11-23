---
icon: lucide/user-lock
---

# Authentication

`dox_auth` lets users register, log in and log out, and it protects routes so only logged in users can use them.

It gives a password login against your user table, three ways to keep a user logged in (access tokens, JWT and sessions), `AuthMiddleware` to protect routes, and `req.auth` to get the user. Password reset, email checks, "remember me" and two-step login are for your app to build, for example with the [two-step login recipe](#change-the-abilities-of-a-token). Rules about who may do what are on the [Authorization](authorization.md) page.

## Setup

These steps start from a new app made with `dox create my_app`. It has a SQLite database, a `User` model and a `users` table with `name`, `email` and `password` columns.

### Choosing a guard

A **guard** is a named way to log in, like `api` or `web`. It has a driver (how the login is kept) and a provider (which model holds the users):

| Your app | Use |
| --- | --- |
| An API for a mobile app, a front end on another domain, or scripts | [Access tokens](#access-tokens). You can revoke each token, give it abilities and renew it. |
| An API where other services check the token with a key | [JWT](#jwt-tokens). The token is signed, so there is no token table. |
| Web pages served by this app (forms, Inertia) | [Session](#session-login-for-web-pages). The browser sends the session cookie. |
| Web pages and an API in one app | [More than one guard](#more-than-one-guard). |

If you are not sure, use access tokens for an API.

### Installing

Run the command, then the migration it writes:

```bash
dox add auth
dox migrate
```

The command adds the `dox_auth` package, the auth config, the provider that loads the config, and the [token table](#creating-the-token-table) migration. It needs the ORM and a `User` model. It never overwrites a file. Without the command, run `dart pub add dox_auth` and write the config and provider below yourself. You always write the DTOs yourself.

### The user model

Put the password in `hidden`, so `toJson()` leaves it out. The model of a new app already does this:

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

The config lists the guards. This config has one guard, `api`, with access tokens:

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

`Auth()` and `AuthMiddleware()` use the `defaultGuard`.

| Option | Default | What it does |
| --- | --- | --- |
| `AuthConfig(defaultGuard:)` | required | the guard to use when no guard is given |
| `AuthConfig(guards:)` | `{}` | the guards, by name |
| `AuthConfig(flags:)` | all off | opt-in behavior. See [Auth flags](authorization.md#auth-flags) |
| `AuthGuard(driver:)` | required | `AccessTokenAuthDriver`, `JwtAuthDriver`, `SessionAuthDriver`, or your own `AuthDriver` |
| `AuthGuard(provider:)` | required | the `AuthProvider` |
| `AuthProvider(model:)` | required | a function that makes a new model, like `() => User()` |
| `AuthProvider(identifierFields:)` | `['email']` | the fields `attempt` searches by |
| `AuthProvider(passwordField:)` | `'password'` | the column with the bcrypt hash |

The options of each driver are in its section: [access tokens](#access-tokens), [JWT](#configuring-the-jwt-guard) and [session](#configuring-the-session-guard).

### Loading the config {#5-load-the-config-when-the-app-starts}

A `DoxProvider` gives the config to `dox_auth` when the app starts. Dox finds it by itself. It is not the `AuthProvider` of the config:

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

Check the register and login body with [DTOs](../the-basic/validation.md). Bad input gets 422, and the controller does not run:

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

An **access token** is an API token that you can revoke at any time. It looks like `oat_12.<secret>`, where `12` is the row id. The table keeps only a SHA-256 hash, so you see the plain token only once.

The [setup](#setup) above already added the `api` guard with `AccessTokenAuthDriver`. Its options:

| Option | Default | What it does |
| --- | --- | --- |
| `table` | `'auth_access_tokens'` | the table of the tokens |
| `connection` | the default connection | the `dox_orm` connection name. Make the table on this connection |
| `expiresIn` | none | how long a new token works |
| `hashRounds` | `10` | the bcrypt cost of your stored hashes, for `attempt` |
| `type` | the guard name | a token works only on a guard with the same type. If you rename a guard, set the old name here |
| `stringIds` | false | true for users with text ids |
| `uuidIds` | false | true for users with uuid ids |
| `throwOnError` | false | true throws a database error in a token check, in place of 401. See [When the database fails](#when-the-database-fails) |

### Creating the token table

`dox add auth` already wrote the migration. To write it yourself, run:

```bash
dox auth:tokens-table --users-table=users
dox migrate
```

`--users-table=users` adds a foreign key with cascade delete, so a deleted user loses its tokens.

| Option of `AccessTokenTables.up` | Flag | Default | What it does |
| --- | --- | --- | --- |
| `table` | none (edit the migration) | `'auth_access_tokens'` | the table name. Use the same name as the driver `table` |
| `uuidIds` | `--uuid` | false | `tokenable_id` is a uuid column |
| `stringIds` | `--string-ids` | false | `tokenable_id` is text. Do not use it with `--uuid` |
| `usersTable` | `--users-table=users` | none | a foreign key from `tokenable_id` to `usersKey` of this table, with cascade delete |
| `usersKey` | `--users-key=uid` | `'id'` | the key column of `usersTable` |

`AccessTokenTables.down(schema, table: 'auth_access_tokens')` drops the table.

!!! warning
    Without `--users-table`, call `revokeAllAccessTokens(user)` when you delete a user. Else old tokens can match a new user with the same id.

`tokenable_type` is the table name of the user model, so a rename of the users table stops old tokens.

### Issuing tokens

The controller makes a token on register and on login:

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

`attempt` finds the user by email and checks the password. It gives a new token with all abilities, or null. `Auth(ip: req.ip())` gives the client ip to the [login throttle](#login-throttle).

### Protecting the API routes

Add `AuthMiddleware()` to a route. A request with no good token gets 401. Also put a [rate limit](rate-limiting.md) on register and login, to slow down password guesses:

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
    Route.get('/auth/me', <dynamic>[
      AuthMiddleware(),
      (AuthController c) => c.me,
    ]);
    Route.post('/auth/logout', <dynamic>[
      AuthMiddleware(),
      (AuthController c) => c.logout,
    ]);
  }
}
```

Run `dart run build_runner build` again, then start the app with `dox s`.

### Sending the token

The client sends the token in the `Authorization` header:

```bash
# log in, and keep the token in TOKEN
curl -X POST localhost:3000/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"ada@example.com","password":"secret-pass"}'
# 200 {"token":"oat_2.OTAG...","user":{"id":1,...}}
TOKEN='oat_2.OTAG...'

curl localhost:3000/api/auth/me -H "Authorization: Bearer $TOKEN"
# 200 {"id":1,"name":"Ada","email":"ada@example.com",...}

curl localhost:3000/api/auth/me
# 401 {"code":"unauthorized","message":"Authentication failed"}
```

### Token abilities {#abilities}

An **ability** is a name like `posts:read` on a token. Give the abilities when you make the token. The default is `*`, which means all abilities:

```dart
AccessToken token = await auth.createAccessToken(
  auth.user<User>()!,
  name: 'script',
  abilities: <String>['posts:read'],
  expiresIn: const Duration(days: 90),
);
```

Check an ability with `tokenCan`. It is true when the token has the ability or `*`, and always false for a session or JWT login:

```dart
if (!(req.auth as Auth).tokenCan('posts:read')) {
  throw ForbiddenHttpException();
}
```

!!! warning
    `AuthMiddleware` only checks that the token is good. Check the ability on each route that needs one. Guard the routes that make or renew tokens with an ability like `tokens:manage`, so a leaked script token can not make new tokens.

To replace all abilities of a token, use `setAccessTokenAbilities`:

```dart
await auth.setAccessTokenAbilities(token, <String>['posts:read']);
```

### Listing and revoking tokens

A revoked token is deleted from the table, so it stops at once:

```dart
await Auth().accessTokens(user);          // all tokens, newest first
await Auth().revokeAccessToken(user, id); // false when no such token
await Auth().revokeAllAccessTokens(user); // all tokens, gives how many
await Auth().revokeToken(req);            // the token of this request
```

Expired tokens stay in the table. Delete them from a [scheduled task](../digging-deeper/scheduler.md):

```dart
int deleted = await Auth().pruneExpiredAccessTokens();
```

### The token object

An `AccessToken` has these fields. `token.toJson()` has no hash and no plain token, so you can send a token list to the client:

| Field | What it is |
| --- | --- |
| `id` | the row id |
| `value` | the plain token. Set only by `createAccessToken` and `rotateAccessToken` |
| `name`, `type` | the name and the type |
| `tokenableType` | the table name of the user model |
| `tokenableId` | the user id: an integer, or a string with `stringIds` or `uuidIds` |
| `abilities` | the list of abilities |
| `lastUsedAt`, `expiresAt`, `createdAt`, `updatedAt` | times, in UTC |
| `user` | the user. Null in `accessTokens(user)` |
| `can(ability)`, `cannot(ability)` | checks one ability (`*` passes every check) |
| `toJson()` | the token without the hash and the plain value |

`currentAccessToken` on the `Auth` of a request gives the token of that request.

### Rotating tokens {#rotate-a-token}

`rotateAccessToken` renews a token before it expires. The new token has the same user, name and abilities, and the old token stops at once:

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

A token can be rotated only once. A second rotate, or a rotate of a revoked or expired token, throws an `UnAuthorizedException` (401). Give `name` or `expiresIn` to change them on the new token.

If a client sends requests in parallel, give a short `grace`, so the old token works a few seconds more. A stolen old token also works in that time:

```dart
rotateAccessToken(token, grace: const Duration(seconds: 10))
```

Each rotate gives a full new life, so a client that rotates again and again stays logged in. To set a limit, keep the first login time yourself.

### A token table without `rotated_at`

An old token table without the `rotated_at` column works for all but rotate. Stop `dox s`, run `dox make:migration add_rotated_at_to_auth_access_tokens`, put this in the new file, then run `dox migrate`:

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

## JWT tokens

A **JWT** is a signed token. The server keeps no list of tokens, so a token works until it expires, unless you turn on [revocation](#revoke-tokens). The user is loaded from the database on each request, by the id in the token. For a walkthrough, see the [JWT auth guide](../guides/jwt-auth.md).

### Configuring the JWT guard

Use `JwtAuthDriver`. `secret` signs the tokens and must be at least 32 bytes, so `APP_KEY` works:

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

| Option | Default | What it does |
| --- | --- | --- |
| `secret` | required | the key that signs tokens, at least 32 bytes |
| `algorithm` | `JWTAlgorithm.HS256` | the signing algorithm. A token with another algorithm is rejected |
| `expiresIn` | `Duration(hours: 1)` | how long a token is valid |
| `issuer` | none | the `iss` claim. When set, the check also reads it |
| `hashRounds` | `10` | the bcrypt cost of your stored hashes |
| `userCacheTtl` | off | keep the user of a token in memory for this time. See [Caching the user](#caching-the-user) |
| `previousSecrets` | none | old secrets to check tokens after a key change. With none and `secret` set to `APP_KEY`, Dox uses `AppConfig.previousKeys`. `[]` turns it off |
| `minimalPayload` | false | put only the user id (the `sub` claim) in new tokens |
| `revocation` | false | turn on token revocation |
| `revocationStore` | the default store | the cache store for revoked tokens |

A token keeps the guard name in its `aud` claim, so it works only on its own guard.

### Issuing JWT tokens

The controller and routes are the same as for [access tokens](#issuing-tokens), with two changes. On register, `Auth().login(user)` gives a token with no password check:

```dart
String? token = Auth().login(user);
```

On logout, revoke the token. This needs `revocation: true`:

```dart
await Auth().revokeToken(req);
```

`attempt` checks the password and gives a JWT. To read the token of a request yourself, use `JwtAuthDriver.bearerToken(req)`.

### Small tokens

Anyone can read the payload of a JWT, because it is signed, not secret. By default the token holds the user (`toJson()` without the `hidden` fields). Set `minimalPayload: true`, so the token holds only the user id, and load the user with `req.auth?.user<User>()`.

### Revoking tokens {#revoke-tokens}

Turn on revocation to let logout stop a token at once. The driver keeps revoked tokens in a [cache store](../digging-deeper/cache.md):

```dart
JwtAuthDriver(
  secret: SecretKey(env.appKey),
  revocation: true,
  revocationStore: 'auth',
)
```

`revokeToken` logs out one token. `revokeAllTokens` logs a user out on all devices, for example after a password change or a ban. Tokens made after the call still work:

```dart
await Auth().revokeToken(req);     // the bearer token of this request
await Auth().revokeAllTokens(id);  // all tokens of this user
```

With revocation off, these methods throw a `StateError`. When the store can not be read, the token is checked without it, and Dox prints a warning one time.

!!! warning
    Give auth its own cache store, like `redis` with its own prefix, and never flush it. A flush brings revoked tokens back until they expire.

### Caching the user

`userCacheTtl` keeps the user in memory for that time, so a request makes no query. Each isolate has its own cache. After a ban or a change to the user, drop it from the cache with `forgetUser`. This needs revocation:

```dart
JwtAuthDriver(
  secret: SecretKey(env.appKey),
  revocation: true,
  userCacheTtl: const Duration(minutes: 1),
);

await Auth().forgetUser(user.id);
```

### Changing the secret {#change-the-jwt-secret}

New tokens are signed with `secret`, and old tokens are also checked with the old secrets. If the secret is `APP_KEY`, follow [Rotating the key](encryption.md#change-the-key-key-rotation). For a separate JWT secret, give the old one to the driver:

```dart
JwtAuthDriver(
  secret: SecretKey(env.jwtSecret),
  previousSecrets: <JWTKey>[SecretKey(env.jwtOldSecret)],
)
```

Remove the old secret when `expiresIn` has passed. To log out everyone, change the secret and keep no old secrets.

!!! warning
    Never keep a leaked secret. A person who has it can make tokens.

Another service that checks the tokens needs the HMAC key, `driver.signingKey`. Dox makes it from `secret` with the label `dox:jwt`.

## Session login for web pages

For web pages, keep the login in the session. The browser sends the session cookie. This needs `SessionMiddleware` and `CsrfMiddleware`. See [Session](../the-basic/session.md) and [CSRF protection](csrf.md).

### Configuring the session guard

Use `SessionAuthDriver`. Its only option is `hashRounds`, the bcrypt cost of your stored hashes (default 10):

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

The session keeps only the user id, so a deleted user is logged out on the next request.

!!! warning
    With the default cookie session driver, an old copy of the cookie works until the session `lifetime` ends. If logout must end old cookies, use the cache session driver.

### Logging in

`attemptSession` checks the password and keeps the user id in the session. `loginSession` logs a user in with no password check. `logout` removes the login and all session data. Login and logout also give the session a new id and a new CSRF token.

This controller answers JSON, for a front end with axios or Inertia:

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

  /// POST /login: check the email and password, keep the login.
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

For an HTML form, answer with a redirect. The method then returns `Future<DoxResponse>`. See [CSRF protection](csrf.md#html-forms) for the form token:

```dart
if (!ok) {
  req.session.flashErrors(<String, dynamic>{
    'email': 'Wrong email or password',
  });
  return back(req);
}
return redirect('/dashboard');
```

### Adding the routes

Put the session and CSRF middleware on the web router only, so the API routes have no session:

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
    Route.get('/me', <dynamic>[
      AuthMiddleware(),
      (SessionController c) => c.me,
    ]);
    Route.post('/logout', <dynamic>[
      AuthMiddleware(),
      (SessionController c) => c.logout,
    ]);
  }
}
```

### Redirecting guests

Send a guest to the login page in place of 401 with `redirectTo`:

```dart
AuthMiddleware(redirectTo: '/login')
```

With the `jsonNoRedirect` [flag](authorization.md#auth-flags), a JSON client gets 401 and no redirect.

### Ending sessions when the password changes {#end-other-sessions-when-the-password-changes}

By default a session stays logged in after a password change, so a stolen session still works. Turn on the `endSessionsOnPasswordChange` [flag](authorization.md#auth-flags). A password change then ends all sessions of the user on their next request through `AuthMiddleware`:

```dart title="lib/config/auth.dart"
AuthConfig authConfig = AuthConfig(
  defaultGuard: 'web',
  guards: guards,
  flags: const AuthFlags(endSessionsOnPasswordChange: true),
);
```

This also ends the current session. To keep it when your app changes the password, call `updateSessionPasswordHash` after `save()`. Give a fully loaded user, because a user with no password column ends the session:

```dart
user.password = await Hash.makeAsync(newPassword);
await user.save();
Auth().updateSessionPasswordHash(req, user);
```

A session made while the flag was off gets its check on its first request. To end all old sessions at once, change `APP_KEY` with no `previousKeys`, or clear the cache session store.

### Logging out other devices

`logoutOtherDevices` ends all other sessions of the user and keeps this one. It checks the password from a form, and needs a session guard and the flag above:

```dart
/// POST /logout-others: end the sessions on other devices.
Future<Map<String, bool>> logoutOthers(
    DoxRequest req, ConfirmPassword body) async {
  await (req.auth as Auth).logoutOtherDevices(req, body.password);
  return <String, bool>{'done': true};
}
```

`ConfirmPassword` is a DTO with one `password` field. A wrong password throws an `UnAuthorizedException` (401, code `wrong_password`). Put a rate limit on the route, like on a login.

## Protecting routes

### More than one guard

One app can have many kinds of login, like a session for web pages, tokens for the API, and admins in their own table. Each guard has its own driver and user model:

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

Pick a guard by name with `guard`:

```dart
String? token = await Auth(guard: 'admin').attempt(credentials);

Route.get('/admin', <dynamic>[
  AuthMiddleware(guard: 'admin'),
  (AdminController c) => c.index,
]);
```

To accept many guards on a route, use `guards`. The first guard with a good login sets `req.auth`:

```dart
Route.get('/me', <dynamic>[
  AuthMiddleware(guards: <String>['web', 'api']),
  (UserController c) => c.me,
]);
```

A token of one guard does not work on another guard. Give each user model its own token table, with `table` on the driver and in the migration: `AccessTokenTables.up(schema, table: 'admin_access_tokens')`.

### Optional login

`AuthMiddleware(optional: true)` sets `req.auth` when the login is good, and lets guests through with `req.auth` as null:

```dart
Route.get('/posts', <dynamic>[
  AuthMiddleware(optional: true),
  (PostController c) => c.index,
]);
```

A database error in a token check then goes on as a guest and is reported. With the session driver, it gives 500.

### Pages for guests only

`GuestMiddleware` sends a logged-in user to `redirectTo`. With no `redirectTo`, the answer is 403. Give `guard` to check another guard:

```dart
Route.get('/login', <dynamic>[
  GuestMiddleware(redirectTo: '/dashboard'),
  (PageController c) => c.login,
]);
```

### Getting the logged in user

After `AuthMiddleware`, `req.auth` holds the login. It is null for a guest:

```dart
User? user = req.auth?.user<User>();
dynamic id = req.auth?.id();                  // the primary key
bool loggedIn = req.auth?.isLoggedIn() ?? false;
Map<String, dynamic>? json = req.auth?.toJson(); // no hidden fields
```

`id()` works also when the key is in `hidden`. On `Auth`, `check()` is the same as `isLoggedIn()`, and `guest()` is the opposite. For `tokenCan`, `currentAccessToken` and `revokeToken`, cast it: `req.auth as Auth`.

### Setting the user yourself

In your own middleware, set the user with `setUser`. Then `req.auth` gives this user:

```dart
Auth(guard: 'api').setUser(req, user);
```

## Login throttle {#login-throttle}

Limit failed logins, to stop password guesses on one account. The throttle is off by default. Turn it on in your auth provider, because it is static and each isolate must set it:

```dart title="lib/providers/auth_provider.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
import 'package:my_app/config/auth.dart';

class AppAuthProvider extends DoxProvider {
  @override
  void setup() {
    Auth.initialize(authConfig);
    Auth.throttle = LoginThrottle();
  }
}
```

| Option | Default | What it does |
| --- | --- | --- |
| `maxAttempts` | `5` | failed logins allowed per login field and ip |
| `decay` | `Duration(minutes: 1)` | how long the count is kept, from the first failed login |
| `store` | the default store | the cache store for the counts |

After `maxAttempts` failed logins for the same email and ip, the next try throws `LoginThrottledException` (429) until `decay` has passed. Its `retryAfter` gives the time to wait. A good login clears the count.

!!! warning
    Always give the ip with `Auth(ip: req.ip())`. Without an ip, the count is per account only, so anyone can lock an account. `attemptSession` takes the ip from the request.

With many isolates or servers, use a shared store, like `LoginThrottle(store: 'redis')`. The throttle does not stop many tries sent at the same time, so also keep a `RateLimit` on the login route.

## Password hashing {#password-hash-cost}

Passwords use bcrypt with cost 10. If you raise it, set the cost for new hashes and on the driver, so a login for an unknown email takes as long as a wrong password:

```dart
Hash.rounds = 12;
JwtAuthDriver(secret: SecretKey(env.appKey), hashRounds: 12);
SessionAuthDriver(hashRounds: 12);
AccessTokenAuthDriver(hashRounds: 12);
```

Old hashes keep their cost and still work. Hash them again on the next good login:

```dart
if (Auth.needsRehash(user.password!)) {
  user.password = await Hash.makeAsync(password);
  await user.save();
  // with a session login and the endSessionsOnPasswordChange flag:
  // Auth().updateSessionPasswordHash(req, user);
}
```

`Auth.needsRehash(hash, rounds: 12)` checks against another cost. `Auth.hashCost(hash)` gives the cost of a hash, or null. bcrypt reads at most 72 bytes, so limit the length in the DTO. See [Hashing](hashing.md).

## Recipes

### Logging in with another field

`attempt` searches the user by `identifierFields` and checks the column in `passwordField`. Change them for a username login, or a hash in another column:

```dart
AuthProvider(
  model: () => User(),
  identifierFields: <String>['username'],
  passwordField: 'password_hash',
)
```

### Checking a password only

`once` checks the password like `attempt`, but makes no token and does not touch the session. It gives true or false:

```dart
bool ok = await Auth(ip: req.ip()).once(credentials);
```

### Users with uuid or text ids

Access tokens keep the user id in `tokenable_id`, a big integer by default. Use the same choice in the migration and on the driver:

- uuid ids: `dox auth:tokens-table --uuid` and `AccessTokenAuthDriver(uuidIds: true)`.
- text ids: `dox auth:tokens-table --string-ids` and `AccessTokenAuthDriver(stringIds: true)`.

Session and JWT guards need nothing for this.

### Two-step login (2FA) {#change-the-abilities-of-a-token}

A two-step login asks for a password, then for a code. Your app makes and checks the code. `dox_auth` helps with tokens:

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
  Future<Map<String, dynamic>> verify(
      DoxRequest req, TwoFactorCode body) async {
    Auth auth = req.auth as Auth;
    AccessToken token = auth.currentAccessToken!;
    if (!token.abilities.contains('2fa:pending')) {
      throw ForbiddenHttpException();
    }
    if (!_codeIsGood(auth.user<User>()!, body.code)) {
      throw UnAuthorizedException(message: 'Wrong code');
    }
    // a new token with the expiresIn of the driver. It has 2fa:pending.
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

`verify` checks `abilities.contains('2fa:pending')`, not `tokenCan`, because `tokenCan` is also true for `*`. Rotate first, then set the abilities, so no token has `*` when a step fails.

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

!!! warning
    A route without `requireTwoFactor` still takes a step-one token. Register must give no token, and every other place that gives a token must also do both steps.

### Checking a login with no request {#check-a-login-with-no-request}

Code with no request, like a [Socket.IO](../packages/socketio.md#log-in-a-socket) login, can check a token or a session. Both give null when the login is not good:

```dart
User? user = await Auth(guard: 'api').userFromToken(token);
User? user = await Auth(guard: 'web').userFromSession(session);
```

`userFromToken` works for JWT and access token guards. Give the token without the `Bearer ` prefix. For `userFromSession`, load the session with `SessionMiddleware().fromCookie(value)`. See [Session](../the-basic/session.md#other-cases).

### Writing your own guard

To log users in your own way, like with an API key in a header, extend `AuthDriver` and return the user from `verifyToken`. This driver finds the user by a SHA-256 hash of the key, with the `crypto` package:

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
  Future<Model<dynamic>?> attempt(
      Map<String, dynamic> credentials, String guard) async => null;

  /// no token to make: the key is the token
  @override
  String? createToken(Map<String, dynamic>? userPayload, String guard) =>
      null;
}
```

Add it as a guard, and use the guard on the route:

```dart
'key': AuthGuard(
  driver: ApiKeyAuthDriver(),
  provider: AuthProvider(model: () => User()),
),

Route.get('/me', <dynamic>[
  AuthMiddleware(guard: 'key'),
  (DoxRequest req) => req.auth?.user<User>(),
]);
```

Make each key long and random, like `openssl rand -hex 32`. Then SHA-256 is safe. Do not use bcrypt here, because you can not search by a bcrypt hash.

For a password login in your driver, `AuthDriver.checkCredentials(credentials, guard, rounds)` gives the user when the password matches. `AuthDriver.reportError(error, stackTrace)` sends an error to the exception handler of the app.

### When the database fails

When the database fails in an access token check, the request gets 401 and the error is reported. Many clients take 401 as "logged out". Turn on `throwOnError` to throw the error:

```dart
AccessTokenAuthDriver(
  expiresIn: const Duration(days: 30),
  throwOnError: true,
)
```

The error then goes to your [exception handler](../the-basic/errors.md), which answers 500. To answer 503, so the client tries again, catch the database errors in `render`:

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
      return HttpStatusException(503,
          headers: <String, String>{'retry-after': '5'});
    }
    return super.render(error, req);
  }
}
```

`SqliteException` comes from the `sqlite3` package (`dart pub add sqlite3`). Set the handler with `exceptionHandler: const AppExceptionHandler()` in `AppConfig`.

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
    String email = 'test-${DateTime.now().microsecondsSinceEpoch}@a.com';
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

To act as a user with no HTTP login, make a token with `await Auth().createAccessToken(user)`, then use `client.withToken(token.value!)`. For a session app, use `client.withSession()`, which keeps cookies and sends the CSRF token. See [Testing](../digging-deeper/testing.md).

## Problems

The status codes: 401 means the user is not logged in. 403 means the user may not do this, like a missing ability or a failed [policy](authorization.md). 419 is a session request with no CSRF token. 429 is too many failed logins.

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
| `419` `CSRF token mismatch` | A session POST without the CSRF token. | See [CSRF protection](csrf.md). |
| `403` `Already logged in` | `GuestMiddleware` with no `redirectTo`, for a logged-in user. | Set `redirectTo`, or log out first. |
| `401` `wrong_password` | `logoutOtherDevices` with a wrong password. | Show an error on the form. |
| `Bad state: logoutOtherDevices() needs the endSessionsOnPasswordChange flag` | `logoutOtherDevices` with the flag off. | Turn the [flag](#end-other-sessions-when-the-password-changes) on. |

## Next steps

- [Authorization](authorization.md): decide what a user can do.
- [JWT authentication](../guides/jwt-auth.md): register, login and logout, step by step.
- [Step 5: Authentication](../tutorial/05-auth.md): auth in the tutorial app.
