---
icon: lucide/user-lock
---

# Authentication

This page shows how to let users register, log in and log out, and how to protect routes.
Follow it from the top. At the end of each way, your app has working auth.

`dox_auth` gives you:

- a password login against your user table (bcrypt hashes)
- three ways to keep a user logged in: access tokens, JWT tokens and sessions
- `AuthMiddleware`, which protects a route and loads the user
- `req.auth`, the logged-in user in your controller
- a login throttle, and tools to revoke and renew tokens

`dox_auth` has no password reset, no email check, no "remember me" and no two-step login (2FA).
Your app builds these. The tools on this page help, for example the [two-step login recipe](#change-the-abilities-of-a-token).
Who may do what (roles, "may this user edit this post") is on the [Authorization](authorization.md) page.

## Which one do I need?

| Your app | Use | Why |
| --- | --- | --- |
| An API for a mobile app, a front end on another domain, or scripts | [Access tokens](#access-tokens) | You can revoke each token at any time, give it abilities, and renew it. The token is checked in a database table. |
| An API where other services must check the token with a key | [JWT](#jwt-tokens) | The token is signed. There is no token table. It works until it expires, unless you turn on revocation. |
| Web pages served by this app (forms, Inertia) | [Session](#session-login-for-web-pages) | The browser sends the session cookie. The client does nothing. |
| Web pages and an API in one app | [More than one guard](#more-than-one-guard) | A session guard for the pages, a token guard for the API. |

Not sure? For an API, use access tokens.

Two words used on this page:

- A **guard** is a named way to log in, like `api` or `web`. It says how the login is kept (access token, JWT or session) and which model holds the users.
- An **ability** is a name like `posts:read` on an access token. It says what the token may do.

## Set it up

These steps start from a new app made with `dox create my_app`.
It has a SQLite database, a `User` model and a `users` table with `name`, `email` and `password` columns.
Do these steps once, then follow one of the ways below.

### 1. Add the package

A new app does not have `dox_auth`. Add it:

```bash
dart pub add dox_auth
```

### 2. Check the user model

The password hash must never leave the server. Put it in `hidden`, so `toJson()` leaves it out.
The model of a new app already does this:

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

### 3. Add the input checks

These DTOs check the body of the register and login requests. Bad input gets `422`, and the controller does not run. See [Validation](../the-basic/validation.md).

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

### 4. Add the auth config

The config lists the guards. Each guard has a driver (how the login is kept) and an `AuthProvider` (which model holds the users).
This config has one guard, `api`, with access tokens. The [JWT](#jwt-tokens) and [session](#session-login-for-web-pages) ways give their own version of this file.

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

`Auth()` and `AuthMiddleware()` use `defaultGuard`. All options are in the [reference](#reference).

### 5. Load the config when the app starts

This class gives the config to `dox_auth` when the app starts.
It is a `DoxProvider` (a class that Dox runs at startup). It is not the `AuthProvider` of step 4.

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

You do not register it by hand. Dox finds every `DoxProvider`.

### 6. Run the code generator

It writes the DTO code and adds `AppAuthProvider` to `lib/generated/container.g.dart`.

```bash
dart run build_runner build
dart analyze
```

Do not start `dox s` yet. The first way below makes a migration first.

## Access tokens

An access token is an API token that you can revoke at any time.
It is like an AdonisJS access token or a Laravel Sanctum token.

- A token looks like `oat_12.<secret>`. `12` is the row id in the token table.
- The table keeps only a SHA-256 hash of the secret. You see the plain token once, when you make it.
- A token works until it expires or you revoke it.
- Each token has abilities. The default is `*` (all abilities).

The [setup](#set-it-up) above already added the `api` guard with `AccessTokenAuthDriver`.

### 1. Add the token table

```bash
dox auth:tokens-table --users-table=users
dox migrate
```

`dox auth:tokens-table` writes a migration in `db/migration`. `dox migrate` adds it to `db/migration/migrations.dart`, runs it, and makes the `auth_access_tokens` table.

The migration it writes looks like this:

```dart
// ignore_for_file: file_names
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_migration/dox_migration.dart';

/// The auth_access_tokens table of dox_auth.
class CreateAccessTokensTable extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await AccessTokenTables.up(schema, usersTable: 'users');
  }

  @override
  Future<void> down(Schema schema) async {
    await AccessTokenTables.down(schema);
  }
}
```

`--users-table=users` adds a foreign key with cascade delete. So when you delete a user, the tokens of the user are deleted too.
The command does not overwrite: when a `create_access_tokens_table` migration is already there, it prints so and stops.
For users with uuid or text ids, see [Users with uuid or text ids](#users-with-uuid-or-text-ids). All flags are in the [reference](#accesstokentablesup-and-dox-authtokens-table).

### 2. Write the auth controller

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

- `Hash.makeAsync` runs bcrypt in another isolate, so it does not block the server. See [Hashing](hashing.md).
- `attempt` finds the user by email and checks the password. It gives a new token with all abilities (`*`), or `null`. It runs bcrypt in another isolate too.
- `Auth(ip: req.ip())` gives the client ip to the [login throttle](#login-throttle).

### 3. Add the routes

`AuthMiddleware()` protects a route. A request with no good token stops with `401`.
A [rate limit](rate-limiting.md) on register and login slows down password guessing.

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

Run the generator again, then start the app:

```bash
dart run build_runner build
dox s
```

### 4. Try it

The client sends the token in the `Authorization` header: `Authorization: Bearer oat_12.<secret>`.
The word `Bearer` can be in any case.
Run these in a second terminal. Where a step says "keep it in", copy the token from the answer into a shell variable.

```bash
# make an account
curl -X POST localhost:3000/api/auth/register -H 'Content-Type: application/json' \
  -d '{"name":"Ada","email":"ada@example.com","password":"secret-pass"}'
# 201 {"token":"oat_1.c79C...","user":{"id":1,"name":"Ada","email":"ada@example.com",...}}

# a wrong password
curl -X POST localhost:3000/api/auth/login -H 'Content-Type: application/json' \
  -d '{"email":"ada@example.com","password":"wrong-pass"}'
# 401 {"code":"unauthorized","message":"Wrong email or password"}

# log in, and keep the token in TOKEN
curl -X POST localhost:3000/api/auth/login -H 'Content-Type: application/json' \
  -d '{"email":"ada@example.com","password":"secret-pass"}'
# 200 {"token":"oat_2.OTAG...","user":{"id":1,...}}
TOKEN='oat_2.OTAG...'

curl localhost:3000/api/auth/me -H "Authorization: Bearer $TOKEN"
# 200 {"id":1,"name":"Ada","email":"ada@example.com",...}

curl localhost:3000/api/auth/me
# 401 {"code":"unauthorized","message":"Authentication failed"}

# log out
curl -X POST localhost:3000/api/auth/logout -H "Authorization: Bearer $TOKEN"
# 200 {"logged_out":true}
curl localhost:3000/api/auth/me -H "Authorization: Bearer $TOKEN"
# 401 {"code":"unauthorized","message":"Authentication failed"}
```

The password is never in an answer, because it is in `hidden`.
The ids (`oat_1`, `oat_2`, ...) count up in your table, so yours may differ.

Your app has a working login. The next part adds script tokens, abilities and token renewal. You can skip it until you need it.

## More with access tokens

### Abilities

`createAccessToken(user, abilities: <String>['posts:read'])` gives a token that can do only these things.
The default is `<String>['*']`: all abilities. `attempt` always gives `*`.

Check an ability in the controller, after `AuthMiddleware`:

```dart
Auth auth = req.auth as Auth;
if (!auth.tokenCan('posts:write')) {
  throw ForbiddenHttpException();
}
auth.currentAccessToken; // the AccessToken of this request
```

- `tokenCan` is `true` when the token has the ability, or `*`.
- `tokenCan` is `false` when there is no access token. So a session or JWT login never passes it.
- A route with no `tokenCan` check takes every good token, whatever its abilities. Check an ability on each route that needs one.
- A token without the ability gets `403`. A request with no good token gets `401` from `AuthMiddleware`.

### Script tokens

Users can make extra tokens, for example for a script that only reads posts.
This controller lists, makes and revokes them. Each action needs the `tokens:manage` ability.
A login token has `*`, so it passes. A script token does not, so a leaked script token can not make new tokens.

```dart title="lib/app/http/controllers/token.controller.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/models/user/user.model.dart';

@Inject()
class TokenController {
  /// GET /api/tokens: all tokens of the user, newest first.
  Future<List<AccessToken>> index(DoxRequest req) async {
    Auth auth = _manager(req);
    return auth.accessTokens(auth.user<User>()!);
  }

  /// POST /api/tokens: a token for a script. It can only read posts.
  Future<Map<String, dynamic>> store(DoxRequest req) async {
    Auth auth = _manager(req);
    AccessToken token = await auth.createAccessToken(
      auth.user<User>()!,
      name: 'script',
      abilities: <String>['posts:read'],
      expiresIn: const Duration(days: 90),
    );
    return <String, dynamic>{'token': token.value};
  }

  /// DELETE /api/tokens/{id}: revoke one token of the user.
  Future<Map<String, bool>> destroy(DoxRequest req, int id) async {
    Auth auth = _manager(req);
    if (!await auth.revokeAccessToken(auth.user<User>()!, id)) {
      throw NotFoundHttpException();
    }
    return <String, bool>{'revoked': true};
  }

  /// The Auth of the request, when its token may manage tokens.
  Auth _manager(DoxRequest req) {
    Auth auth = req.auth as Auth;
    if (!auth.tokenCan('tokens:manage')) {
      throw ForbiddenHttpException();
    }
    return auth;
  }
}
```

A route that needs the `posts:read` ability:

```dart title="lib/app/http/controllers/post.controller.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';

@Inject()
class PostController {
  /// GET /api/posts: needs a token with the posts:read ability.
  List<String> index(DoxRequest req) {
    if (!(req.auth as Auth).tokenCan('posts:read')) {
      throw ForbiddenHttpException();
    }
    return <String>['Hello'];
  }
}
```

In `lib/routes/api.dart`, add the imports at the top:

```dart
import 'package:my_app/app/http/controllers/post.controller.dart';
import 'package:my_app/app/http/controllers/token.controller.dart';
```

And add the routes at the end of `register()`:

```dart
Route.get('/tokens', <dynamic>[AuthMiddleware(), (TokenController c) => c.index]);
Route.post('/tokens', <dynamic>[AuthMiddleware(), (TokenController c) => c.store]);
Route.delete('/tokens/{id}', <dynamic>[
  AuthMiddleware(),
  (TokenController c) => c.destroy,
]);
Route.get('/posts', <dynamic>[AuthMiddleware(), (PostController c) => c.index]);
```

Run `dart run build_runner build`. `dox s` restarts by itself.

`/auth/me` and `/auth/logout` have no ability check, so a script token can call them too. That is fine: it sees its own user, and its logout revokes only itself.

Try it. Log in first and keep the token in `TOKEN`, like above.

```bash
# make a script token, and keep it in SCRIPT_TOKEN
curl -X POST localhost:3000/api/tokens -H "Authorization: Bearer $TOKEN"
# 200 {"token":"oat_4.pwwK..."}
SCRIPT_TOKEN='oat_4.pwwK...'

curl localhost:3000/api/posts -H "Authorization: Bearer $SCRIPT_TOKEN"
# 200 ["Hello"]

# the script token may not manage tokens
curl -X POST localhost:3000/api/tokens -H "Authorization: Bearer $SCRIPT_TOKEN"
# 403 {"code":"forbidden","message":"Forbidden"}

# list the tokens, then revoke the script token (id 4)
curl localhost:3000/api/tokens -H "Authorization: Bearer $TOKEN"
# 200 [{"id":4,"name":"script","type":"api","abilities":["posts:read"],...},...]
curl -X DELETE localhost:3000/api/tokens/4 -H "Authorization: Bearer $TOKEN"
# 200 {"revoked":true}
curl localhost:3000/api/posts -H "Authorization: Bearer $SCRIPT_TOKEN"
# 401 {"code":"unauthorized","message":"Authentication failed"}
```

### List and revoke tokens

```dart
await Auth().accessTokens(user);           // all tokens of the user, newest first, expired ones too
await Auth().revokeAccessToken(user, id);  // false when the user has no token with this id
await Auth().revokeAllAccessTokens(user);  // all tokens of the user, eg. after a password change
await Auth().revokeToken(req);             // the token of this request (a logout)
await Auth().pruneExpiredAccessTokens();   // delete expired tokens, eg. from a scheduled job
```

- A revoked token is deleted from the table, so it stops working at once.
- `token.toJson()` has no hash and no plain token, so you can send it to the client. `GET /api/tokens` above does this.
- On the `Auth` of `AuthMiddleware`, `(req.auth as Auth).revokeToken(req)` uses the token that was already checked. It does not check it again.
- Expired tokens stay in the table until you call `pruneExpiredAccessTokens()`. Run it from a [scheduled task](../digging-deeper/scheduler.md).

### Rotate a token

Rotate a token to renew it before it expires.
`rotateAccessToken` makes a new token in place of an old one.
The new token has the same user, name and abilities as the old one.

Add this method to `AuthController`:

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

And this route at the end of `register()` in `lib/routes/api.dart`:

```dart
Route.post('/auth/refresh', <dynamic>[
  AuthMiddleware(),
  (AuthController c) => c.refresh,
]);
```

Run `dart run build_runner build`. The `tokens:manage` check keeps a script token from renewing itself.

Try it. Log in first and keep the token in `TOKEN`.

```bash
curl -X POST localhost:3000/api/auth/refresh -H "Authorization: Bearer $TOKEN"
# 200 {"token":"oat_6.-qAk...","expires_at":"2026-12-11T04:43:15.701944Z"}
NEW_TOKEN='oat_6.-qAk...'

curl localhost:3000/api/auth/me -H "Authorization: Bearer $TOKEN"
# 401 {"code":"unauthorized","message":"Authentication failed"}
curl localhost:3000/api/auth/me -H "Authorization: Bearer $NEW_TOKEN"
# 200 {"id":1,"name":"Ada",...}
```

`grace` is how long the old token still works. The default is zero: the old token ends at once, like above.
You need a grace only when one client sends requests in parallel. Then a request that is on the way with the old token does not fail.
Keep it short, a few seconds: `rotateAccessToken(token, grace: const Duration(seconds: 10))`.
If the old token ends sooner than `grace`, it keeps its own end.

The rules:

- A token can be rotated only once. A second rotate of the same token throws an `UnAuthorizedException` (`401`, `The access token was already rotated.`). This is also true in the grace time. Nothing is made.
- A revoked or expired token is refused the same way: `401` with `The access token is revoked or does not exist.` or `The access token is expired.`
- When two rotates of one token run at the same time, only one works.
- It runs in one transaction. When it fails, nothing is changed.
- `expiresIn:` sets how long the new token works. `null` (the default) gives the `expiresIn` of the driver. When that is `null` too, the new token has no end.
- `name:` gives the new token another name. `null` keeps the old name.
- A token of another guard, or a negative `grace`, throws an `ArgumentError`.

Safety notes:

- A longer `grace` gives a stolen old token more time. In that time it works on every route, also the token routes, so it can make new tokens. Only rotate refuses it. Keep `grace` short, or zero.
- Each rotate gives a full new life. So a client that rotates again and again stays logged in forever. A rotated token has a new `createdAt` and no link to the first token. To set a limit, keep the first login time yourself. For example, save it in a column, or in the token name with `rotateAccessToken(token, name: ...)`. Or ask for the password again after some time.

Rotate needs the `rotated_at` column. A table made by `dox auth:tokens-table` has it.

#### A token table without `rotated_at`

A token table without the `rotated_at` column works for everything except rotate.
`rotateAccessToken` then throws a `StateError` that names the column:

```text
Bad state: The table 'auth_access_tokens' has no rotated_at column. rotate() needs it. Add it in a new migration: ...
```

To add the column:

1. Stop `dox s` if it runs. It runs new migrations when it restarts. It would run the new, still empty file, and then the column is never added.
2. Make a migration:

    ```bash
    dox make:migration add_rotated_at_to_auth_access_tokens
    ```

3. Paste this into the new file in `db/migration` (its name starts with the date and time):

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

4. Run `dox migrate`, then start `dox s` again.

## JWT tokens

A JWT is a signed token. The server keeps no list of tokens.
The token works until it expires, unless you turn on [revocation](#revoke-tokens).
The user is still loaded from the database on each request, by the id in the token.

Do the [setup](#set-it-up) first. This way needs no token table.

### 1. Change the guard

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

- `secret` signs the tokens. `APP_KEY` is fine: it must be at least 32 bytes. A new app has it in `.env`. `dox key:generate` makes a new one.
- `expiresIn` is how long a token works. The default is one hour.
- `minimalPayload` and `revocation` are off by default. See [Small tokens](#small-tokens) and [Revoke tokens](#revoke-tokens).

### 2. Write the auth controller

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

    String? token = Auth().login(user);
    return response(<String, dynamic>{
      'token': token,
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
    await Auth().revokeToken(req);
    return <String, bool>{'logged_out': true};
  }
}
```

`Auth().login(user)` gives a token with no password check. `attempt` checks the password first.

### 3. Add the routes

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

    Route.post('/auth/register', <dynamic>[
      RateLimit(max: 5, name: 'register'),
      (AuthController c) => c.register,
    ]);
    Route.post('/auth/login', <dynamic>[
      RateLimit(max: 5, name: 'login'),
      (AuthController c) => c.login,
    ]);
    Route.get('/auth/me', <dynamic>[AuthMiddleware(), (AuthController c) => c.me]);
    Route.post('/auth/logout', <dynamic>[
      AuthMiddleware(),
      (AuthController c) => c.logout,
    ]);
  }
}
```

Run `dart run build_runner build`, then `dox s`.

### 4. Try it

```bash
curl -X POST localhost:3000/api/auth/register -H 'Content-Type: application/json' \
  -d '{"name":"Ada","email":"ada@example.com","password":"secret-pass"}'
# 201 {"token":"eyJhbGciOiJIUzI1NiIs...","user":{"id":1,"name":"Ada",...}}

# log in, and keep the token in TOKEN
curl -X POST localhost:3000/api/auth/login -H 'Content-Type: application/json' \
  -d '{"email":"ada@example.com","password":"secret-pass"}'
# 200 {"token":"eyJhbGciOiJIUzI1NiIs...","user":{"id":1,"name":"Ada",...}}
TOKEN='eyJhbGciOiJIUzI1NiIs...'

curl localhost:3000/api/auth/me -H "Authorization: Bearer $TOKEN"
# 200 {"id":1,"name":"Ada","email":"ada@example.com",...}

curl -X POST localhost:3000/api/auth/logout -H "Authorization: Bearer $TOKEN"
# 200 {"logged_out":true}

curl localhost:3000/api/auth/me -H "Authorization: Bearer $TOKEN"
# 401 {"code":"unauthorized","message":"Authentication failed"}
```

If Ada already has an account from another way, `register` answers `422`. Then just log in.
For a longer JWT walkthrough, see the [JWT auth guide](../guides/jwt-auth.md).

### Small tokens

By default, a token holds the user (`toJson()`, `hidden` fields left out), plus the `iat`, `exp` and `jti` claims.
Anyone can read a JWT payload. It is signed, not secret.
`minimalPayload: true` is the safer choice. The token then holds only the user id (the `sub` claim).
Load the user with `req.auth?.user<User>()`, not from the token.
A front end that reads user fields from the token must then get the user from the API.

### Revoke tokens

By default, a token works until it expires. There is no server list of tokens.
Turn on revocation to stop a token before it expires:

```dart
JwtAuthDriver(
  secret: SecretKey(env.appKey),
  revocation: true,
  revocationStore: 'auth',
)
```

Each token has a random id (the `jti` claim).
With revocation on, the driver keeps revoked tokens in the app cache (`Cache()` of `dox_core`).
A revoked token stops working at once:

```dart
await Auth().revokeToken(req);     // revoke the bearer token of this request (a logout)
await Auth().revokeAllTokens(id);  // revoke all tokens of a user, eg. after a password change or a ban
await Auth().forgetUser(id);       // drop the user from `userCacheTtl`, eg. after a ban
```

- With revocation off, these three methods throw a `StateError`. So no one thinks a token is revoked when it is not.
- With revocation off, a token check never reads the cache.
- A revoked token stays on the deny-list only until it expires.
- `revokeAllTokens` keeps tokens made after the call. A token made in the same second as the call also still works, because `iat` is in whole seconds.
- A token with no `jti` claim can not go on the deny-list, so `revokeToken` does nothing for it. `revokeAllTokens` still stops it when it has an `iat` claim. Tokens from `JwtAuthDriver` have one.
- The `revokeAllTokens` time comes from the server clock. Keep server clocks in sync (NTP).
- Give auth its own [cache store](../digging-deeper/cache.md), and never flush it. For example, a `redis` store with its own prefix. Pick it with `revocationStore`. With no `revocationStore`, the default app store is used. A flush of this store (`Cache().flush()`), or a `memory` store with `max_size` that drops old keys, brings revoked tokens back until they expire.
- Cost: a token check reads this store on every request, also with `userCacheTtl`. It is one `many()` call: one round trip on `redis` and `memory`. On the `file` store (the default) it is 2 or 3 file reads per request. Use `memory` for one isolate, or `redis` for many isolates or servers. A `memory` store is seen by one isolate only.
- When the store can not be read, the token is checked with only the signature and `exp`, and a warning is printed once. So a cache outage does not log everyone out. But revoked tokens work until the store is back.

### Change the JWT secret

New tokens are always signed with `secret`.
A token is checked with `secret` first, then with each old secret.
Only a wrong signature moves on to the next secret. An expired token fails at once.

- **The secret is `APP_KEY`** (`SecretKey(env.appKey)`): follow [Change the key](encryption.md#change-the-key-key-rotation). The old keys in `AppConfig.previousKeys` are used. You need nothing more.
- **A separate JWT secret**: give the old one to the driver.

    ```dart
    JwtAuthDriver(
      secret: SecretKey(env.jwtSecret),
      previousSecrets: <JWTKey>[SecretKey(env.jwtOldSecret)],
    )
    ```

Remove the old secret once `expiresIn` has passed. Then every old token has expired anyway.
Do not keep a leaked secret: anyone who has it can make tokens.
To log out everyone at once, change the secret and keep no old secrets.

## Session login for web pages

For web pages, keep the login in the session instead of a token.
The browser sends the session cookie, so the client does nothing.
It needs `SessionMiddleware` and `CsrfMiddleware`. See [Session](../the-basic/session.md) and [CSRF protection](csrf.md).

Do the [setup](#set-it-up) first. This way needs no token table.

### 1. Change the guard

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

### 2. Write the controller

This controller answers JSON, for a front end with axios or Inertia.
axios sends the CSRF token by itself. For HTML forms, see [CSRF protection](csrf.md#html-forms).

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

For a form post, answer with a redirect instead. The method then returns `Future<DoxResponse>`:

```dart
if (!ok) {
  req.session.flashErrors(<String, dynamic>{'email': 'Wrong email or password'});
  return back(req);
}
return redirect('/dashboard');
```

### 3. Add the routes

The session and CSRF middleware go on the web router only. The API routes stay without a session.

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

To send a guest to the login page instead of a `401`, use `AuthMiddleware(redirectTo: '/login')`.
With the `jsonNoRedirect` [flag](authorization.md#auth-flags) on, a JSON or XHR client gets a `401` and no redirect.

Run `dart run build_runner build`, then `dox s`.

### 4. Try it

A browser keeps the cookies by itself. With curl, keep them in a file, and send the `XSRF-TOKEN` cookie back in the `X-XSRF-TOKEN` header.
Ada must have an account. Make one with `POST /register` (same body as below, plus `name`), or use the one from another way.

```bash
# the first request gives the session and XSRF-TOKEN cookies
curl -c jar.txt localhost:3000/ping
XSRF=$(grep XSRF-TOKEN jar.txt | cut -f7)

curl -b jar.txt -c jar.txt -X POST localhost:3000/login -H "X-XSRF-TOKEN: $XSRF" \
  -H 'Content-Type: application/json' -d '{"email":"ada@example.com","password":"secret-pass"}'
# 200 {"id":1,"name":"Ada","email":"ada@example.com",...}

XSRF=$(grep XSRF-TOKEN jar.txt | cut -f7)   # login gives a new CSRF token
curl -b jar.txt localhost:3000/me
# 200 {"id":1,"name":"Ada",...}

curl -b jar.txt -c jar.txt -X POST localhost:3000/logout -H "X-XSRF-TOKEN: $XSRF"
# 200 {"logged_out":true}

curl -b jar.txt localhost:3000/me
# 401 {"code":"unauthorized","message":"Authentication failed"}
```

A `POST` with no CSRF token gets `419` (`csrf_token_mismatch`).

### End other sessions when the password changes

By default, a session stays logged in after the user changes the password.
So a stolen session still works.
Turn on the `endSessionsOnPasswordChange` [flag](authorization.md#auth-flags) to fix this.
The session then keeps a fingerprint of the password hash.
When the hash changes, the session ends on its next request.
The flag is off by default.

```dart title="lib/config/auth.dart"
AuthConfig authConfig = AuthConfig(
  defaultGuard: 'web',
  guards: guards,
  flags: const AuthFlags(endSessionsOnPasswordChange: true),
);
```

A password change now ends all sessions of the user, also the current one.
When your app changes the password itself, keep the current session with `updateSessionPasswordHash`.
Call it after `save()`:

```dart
user.password = await Hash.makeAsync(newPassword);
await user.save();
Auth().updateSessionPasswordHash(req, user);
```

A [rehash on login](#password-hash-cost) changes the hash too.
Call `updateSessionPasswordHash` after that `save()` as well.

Pass a fully loaded user to `updateSessionPasswordHash` and `loginSession`.
A model from a `select()` with no password column looks like a user with no password.
The session then ends on the next request.
The user must be the user of the session. Another user throws an `ArgumentError`.
The password column must give the same value on every read.
A hook or cast that makes a new value each time ends every session.

#### Log out other devices

`logoutOtherDevices` ends all other sessions of the user and keeps this one.
It checks the password, hashes it again and saves the user.
It needs a session guard and the flag.

```dart
/// POST /logout-others: end the sessions on other devices.
Future<Map<String, bool>> logoutOthers(DoxRequest req) async {
  await (req.auth as Auth).logoutOtherDevices(req, req.input('password'));
  return <String, bool>{'done': true};
}
```

- A wrong password throws an `UnAuthorizedException` with status `401` and code `wrong_password`. Catch it to show an error on your form.
- Without the flag, it throws a `StateError` and changes nothing.
- When a model hook stops `save()`, it throws a `StateError`. The sessions do not change.
- When `save()` throws, the old hash is put back on the model and the error is thrown again.
- It checks a password, so put a limit on the route, like on a login. See [Login throttle](#login-throttle) and [Rate limiting](rate-limiting.md).

#### Sessions made before the flag

A session made while the flag was off has no fingerprint.
It is not logged out.
Its first request with the flag on stores the fingerprint.
Until then, a password change does not end it.
So a session stolen before you turned the flag on can stay.

To end all old sessions once, change `APP_KEY` and do not put the old key in `previousKeys`.
This also breaks other data made with the old key, like encrypted values and JWTs.
With the `cache` session driver, you can clear the session store instead.

A fingerprint made with a key in `previousKeys` still works.
When you remove that key from `previousKeys`, sessions that still hold such a fingerprint are logged out.

## Test it

`DoxTestClient` runs your app in the test. `withToken` sends `Authorization: Bearer <token>`.
This test is for the [access token](#access-tokens) way. It also works for [JWT](#jwt-tokens).
The test uses the database of `.env`, so it runs the migrations first.

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

Run it with `dart test`.

To act as a user with no HTTP login, make a token in the test: `await Auth().createAccessToken(user)`, then `client.withToken(token.value!)`.
For a session app, use `client.withSession()`. It keeps cookies and sends the CSRF token, like a browser. See [Testing](../digging-deeper/testing.md).

## Common tasks

### More than one guard

Each guard has its own driver and its own user model. For example, a session for web pages, access tokens for the API, and admins in their own table. `Admin` is a model of your own, like `User`:

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

Pick the guard by name:

```dart
String? token = await Auth(guard: 'admin').attempt(credentials);

Route.get('/admin', <dynamic>[AuthMiddleware(guard: 'admin'), (AdminController c) => c.index]);

// try the guards in order, like Laravel auth:web,api
Route.get('/me', <dynamic>[AuthMiddleware(guards: <String>['web', 'api']), (UserController c) => c.me]);
```

- With `guards:`, the first guard with a good login sets `req.auth`.
- Set `guard:` or `guards:`, not both. Both, or an empty list, throws an `ArgumentError`.
- A JWT keeps the guard name in its `aud` claim, and an access token keeps its `type`. So a token of one guard does not work on another guard.
- Give each user model its own token table, with `table:` on the driver and in the migration (`AccessTokenTables.up(schema, table: 'admin_access_tokens')`). With one shared table and `usersTable`, the foreign key fails for admin tokens, and deleting a user also deletes the tokens of the admin with the same id.
- Pass a user of the guard's model: `Auth(guard: 'admin').createAccessToken(admin)`. A user of another model throws an `ArgumentError`.

### Pages for everyone and pages for guests

A public page can still know the user. `AuthMiddleware(optional: true)` sets `req.auth` when the login is good, and lets guests through too.
Login and register pages are for guests only. `GuestMiddleware` lets only guests through.

```dart
Route.get('/posts', <dynamic>[AuthMiddleware(optional: true), (PostController c) => c.index]);
Route.get('/login', <dynamic>[GuestMiddleware(redirectTo: '/dashboard'), (PageController c) => c.login]);
```

- With `optional: true`, a guest, or a bad, expired or revoked token, goes on with `req.auth` as `null`.
- With the JWT and access token drivers, a database error also goes on as a guest, and it is reported. With `AccessTokenAuthDriver(throwOnError: true)` it is thrown instead (see [When the database fails](#when-the-database-fails)).
- With the session driver, a database error is not caught, so the answer is `500`.
- `redirectTo` is not used when `optional: true`.
- `GuestMiddleware` sends a logged-in user to `redirectTo`. With no `redirectTo`, the answer is `403` with the code `already_logged_in`.
- Both take `guard:`, like `AuthMiddleware(guard: 'admin')`.
- `req.can()` of [Authorization](authorization.md) also works on a page with `optional: true`.

### Two-step login (2FA) {#change-the-abilities-of-a-token}

A two-step login asks for a password, then for a code (from a mail or an app).
`dox_auth` does not make or check the code: your app does that.
`setAccessTokenAbilities` helps: it replaces the abilities of a token. The plain token stays the same.

This flow replaces the normal `attempt()` login of the [access token way](#access-tokens). An app has one login flow.

How it works:

1. Step one checks the password with `once()`. It gives a token with only `2fa:pending`. The token works 10 minutes.
2. Step two checks the code. Then it rotates the token, and gives the new token the abilities of a full login (`*`, like `attempt()` gives). The client gets the new token with a full life. The step-one token ends at once.
3. Each route that needs the second step uses the `requireTwoFactor` middleware. A `*` token passes it, a `2fa:pending` token does not.

Add the DTO for the code:

```dart title="lib/app/dtos/two_factor_code/two_factor_code.dto.dart"
import 'package:dox_core/dox_core.dart';

part 'two_factor_code.dto.g.dart';

@Dto()
class TwoFactorCode {
  @Length(min: 6, max: 6)
  final String code;

  const TwoFactorCode({required this.code});

  static const DtoSchema<TwoFactorCode> schema = $TwoFactorCodeDto;
}
```

Add the controller with both steps:

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

- `verify` checks `abilities.contains('2fa:pending')`, not `tokenCan`, because `tokenCan` is also `true` for `*`. So only a step-one token can do step two.
- The order matters: `rotateAccessToken` first, then `setAccessTokenAbilities` on the new token. Rotate copies `2fa:pending` to the new token. When a step fails, no token has `*`: the user logs in again.
- After step two, the step-one token stops working. A copy of it, taken before step two, is of no use.
- Rotate needs the `rotated_at` column. A table made by `dox auth:tokens-table` has it. Without it, step two fails and the step-one token stays `2fa:pending`. See [A token table without `rotated_at`](#a-token-table-without-rotated_at).

Add a middleware that needs the second step:

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

Then change the app in these steps:

1. In `AuthController.register`, give no token: the user logs in with the two steps after register. Replace the method with:

    ```dart
    /// POST /api/auth/register: make an account. Log in after it.
    Future<DoxResponse> register(RegisterUser body) async {
      User user = User()
        ..name = body.name
        ..email = body.email
        ..password = await Hash.makeAsync(body.password);
      await user.save();
      return response(<String, dynamic>{'user': user}).statusCode(201);
    }
    ```

2. In `lib/routes/api.dart`, add the imports at the top:

    ```dart
    import 'package:my_app/app/http/controllers/two_factor.controller.dart';
    import 'package:my_app/app/http/middleware/two_factor.middleware.dart';
    ```

3. In `register()` of `lib/routes/api.dart`, change the login route to the new controller, and add the step-two route under it. This removes the normal login. You can delete `AuthController.login`.

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

    The rate limit slows down guessing of the code from one ip. It is not enough alone: your code check must also make each code expire, and limit the wrong tries per user.

4. Add `requireTwoFactor` after `AuthMiddleware()` on each route of a logged-in user:

    ```dart
    Route.get('/auth/me', <dynamic>[
      AuthMiddleware(),
      requireTwoFactor,
      (AuthController c) => c.me,
    ]);
    ```

    For many routes, use a group: `Route.middleware(<dynamic>[AuthMiddleware(), requireTwoFactor], () { ... });`.

5. Run `dart run build_runner build`.

Things to know:

- A route without `requireTwoFactor` still takes a step-one token. `AuthMiddleware` only checks that the token is good. The routes with a `tokenCan` check (like `/tokens` and `/auth/refresh`) refuse it too, because it has no `*`.
- A [script token](#script-tokens) has no `2fa:pending`, so it passes `requireTwoFactor`. Its own abilities still limit it. Only a full login token can make one, because `/tokens` needs `tokens:manage`.
- Any other place in your app that gives a token must also give a step-one token, or check the code first.
- `tokenCan` on the same `Auth` sees new abilities at once. The next requests read them from the table.
- `setAccessTokenAbilities` throws an `UnAuthorizedException` (`401`) when the token is gone (revoked). It does not check the expiry. A token of another guard throws an `ArgumentError`. It works on a token table without the `rotated_at` column too.

Try it, with the code check of your app in place:

```bash
# step one, and keep the token in PENDING
curl -X POST localhost:3000/api/auth/login -H 'Content-Type: application/json' \
  -d '{"email":"ada@example.com","password":"secret-pass"}'
# 200 {"token":"oat_7.Ab1x...","two_factor":true}
PENDING='oat_7.Ab1x...'

curl localhost:3000/api/auth/me -H "Authorization: Bearer $PENDING"
# 403 {"code":"forbidden","message":"Forbidden"}

# step two, and keep the new token in TOKEN
curl -X POST localhost:3000/api/auth/two-factor -H "Authorization: Bearer $PENDING" \
  -H 'Content-Type: application/json' -d '{"code":"123456"}'
# 200 {"token":"oat_8.Zq9p..."}
TOKEN='oat_8.Zq9p...'

curl localhost:3000/api/auth/me -H "Authorization: Bearer $TOKEN"
# 200 {"id":1,"name":"Ada",...}
curl localhost:3000/api/auth/me -H "Authorization: Bearer $PENDING"
# 401 {"code":"unauthorized","message":"Authentication failed"}
```

### When the database fails

The access token check reads the database. When the database fails, the default is to fail closed:
the check gives no user, the request gets `401`, and the error goes to the `report` of your [exception handler](../the-basic/errors.md).

But a `401` tells many clients "you are logged out". A short database problem then logs users out.
Turn on `throwOnError` to stop this:

```dart title="lib/config/auth.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:my_app/app/models/user/user.model.dart';

AuthConfig authConfig = AuthConfig(
  defaultGuard: 'api',
  guards: <String, AuthGuard>{
    'api': AuthGuard(
      driver: AccessTokenAuthDriver(
        expiresIn: const Duration(days: 30),
        throwOnError: true,
      ),
      provider: AuthProvider(model: () => User()),
    ),
  },
);
```

With `throwOnError: true`, an error in a token check is thrown. This is a database error, a token row that can not be read, or a guard that is not set up.
It goes to your exception handler. The default answer is `500`.
In production the `500` body is only `{"code":"server_error","message":"Server Error"}`. When `APP_ENV` is `development` or `local`, the error text is sent instead.

To answer `503`, so the client tries again, catch the database error in `render`.
Each database has its own error class. On SQLite (the default database of a new app), the class is in the `sqlite3` package. Add it:

```bash
dart pub add sqlite3
```

Make a new file for the handler:

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

On Postgres or MySQL only, drop the `sqlite3` package, its import and `error is SqliteException`.
Then set the handler in `lib/config/app.dart`. Add the import at the top, and `exceptionHandler` in `AppConfig`:

```dart title="lib/config/app.dart"
import 'package:my_app/app/exception_handler.dart';

AppConfig appConfig = AppConfig(
  exceptionHandler: const AppExceptionHandler(),
  // ... the other settings stay
);
```

The answer is then `503` with a `Retry-After: 5` header and `{"code":"service_unavailable","message":"Service Unavailable"}`.

- `throwOnError` also counts for `AuthMiddleware(optional: true)`: a database error is thrown, not turned into a guest.
- A failed `last_used_at` write is never thrown. It is reported, and the request goes on.

### Check a login with no request

Code that has no request, like a [Socket.IO](../packages/socketio.md#log-in-a-socket) login, can check a token or a session itself:

```dart
User? user = await Auth(guard: 'api').userFromToken(token);
User? user = await Auth(guard: 'web').userFromSession(session);
```

- `userFromToken` runs the same checks as a request with a `Bearer` header. For a JWT: signature, algorithm, guard, `exp` and [revocation](#revoke-tokens). For an [access token](#access-tokens): the hash, the type, the user table, `expires_at` and revocation. Give the token with no `Bearer ` prefix. A missing, bad, expired, revoked or changed token gives `null`. It needs a guard with `JwtAuthDriver` or `AccessTokenAuthDriver`.
- With an access token, `currentAccessToken` and `tokenCan` work on the same `Auth` after `userFromToken`. The driver method behind it is `check(token, guard)`, an instance method of `AccessTokenAuthDriver`.
- `userCacheTtl` is a cache, not a check. With it on, a deleted or banned user can still connect until the cache time ends, unless `forgetUser` runs.
- `userFromSession` gives the user of a session, or `null`. Load the session with `SessionMiddleware().fromCookie(value)`. See [Session](../the-basic/session.md#load-a-session-with-no-request). It needs a guard with `SessionAuthDriver`.

### Your own guard (API key)

You can check the user in your own way, like an API key in the header.
Write a driver: extend `AuthDriver` and return the user from `verifyToken`.
`AuthMiddleware` and `req.auth` then work as with the other drivers.

The table stores a SHA-256 hash of each key in an `api_key_hash` column, not the key itself.
So a leak of the table does not leak the keys.
The example uses the `crypto` package (`dart pub add crypto`).

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

Add it as a guard, and use the guard in the route:

```dart
'key': AuthGuard(
  driver: ApiKeyAuthDriver(),
  provider: AuthProvider(model: () => User()),
),

Route.get('/me', <dynamic>[AuthMiddleware(guard: 'key'), (DoxRequest req) => req.auth?.user<User>()]);
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

### Log in with another field

`attempt` searches by the fields in `identifierFields` of the `AuthProvider`, and checks the column in `passwordField`:

```dart
AuthProvider(
  model: () => User(),
  identifierFields: <String>['username'],
  passwordField: 'password_hash',
)
```

`attempt` runs bcrypt also when no user is found, or when the user has no password. So the answer time does not tell whether an email has an account.
It returns `null` when the password is not a `String`, when no identifier is given, when an identifier is not a string or a number (a map or a list from the body), or when the password does not match.

### Users with uuid or text ids

Access tokens keep the user id in the `tokenable_id` column. By default it is an unsigned big int, like Sanctum and AdonisJS.

- **uuid ids:** `dox auth:tokens-table --uuid` and `AccessTokenAuthDriver(uuidIds: true)`. `tokenable_id` is then a uuid column (`UUID` on Postgres), so `--users-table` works with a uuid id. A uuid is kept and compared in lower case, like Postgres does. On other databases, keep uuids in lower case in the users table.
- **text ids:** `dox auth:tokens-table --string-ids` and `AccessTokenAuthDriver(stringIds: true)`. Text ids are compared exactly.

Use the same choice in the migration and on the driver. Session and JWT guards need nothing for this.

### Login throttle

The login throttle limits failed logins per account and ip. It is off by default.
Turn it on where the config is loaded:

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

- After `maxAttempts` failed logins for the same login field (eg. the email) and ip, the next try throws `LoginThrottledException` (`429`) until `decay` has passed. Its `retryAfter` says how long to wait.
- A good login clears the count. The login field is trimmed and lower case, so `A@x.com` and `a@x.com` share one count.
- The counts live in the app cache. Pick a store with `LoginThrottle(store: 'redis')`. Use a shared store like `redis` for many isolates or servers.
- `Auth.throttle` is static, so each isolate has its own copy. Set it in `setup()` or `boot()` of a provider. If you set it in `main()` before the server starts, only the first isolate throttles.
- Without an ip, `attempt` counts per account only. Then anyone can lock an account for `decay`. So pass the ip: `Auth(ip: req.ip())`. `attemptSession` takes the ip from the request.
- `attemptSession` sends a `Retry-After` header with the `429`. `attempt` has no request, so catch `LoginThrottledException` and set the header from `retryAfter` if you need it.
- `once` counts like `attempt`.
- Parallel tries are not stopped. The limit is checked before a failed try is counted, so tries that run at the same time all pass the check. A burst of parallel wrong logins can all run, far past `maxAttempts`. In a test, 50 parallel wrong logins with `maxAttempts: 5` all ran. The throttle works for tries that come one after another. To stop fast parallel guessing, also put `RateLimit` on the login route, like the routes on this page do.

### Password hash cost

Passwords use bcrypt with cost 10 by default. Each step up doubles the time of a login.
To raise it, set the cost for new hashes and tell the driver.
Then a login for an unknown email takes as long as a wrong password:

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

With the [`endSessionsOnPasswordChange` flag](#end-other-sessions-when-the-password-changes), a new hash ends the other sessions of the user.
Call `updateSessionPasswordHash` to keep the current one.

`Auth.needsRehash(hash, rounds: 12)` checks against another cost. `Auth.hashCost(hash)` gives the cost of a hash.
bcrypt reads at most 72 bytes. A longer password throws an `ArgumentError`, so limit the length in the DTO.

### 401 or 403?

- `401` (`unauthorized`): the user is not logged in. There is no token, or it is bad, expired or revoked. `AuthMiddleware` gives it. The client should log in again.
- `403` (`forbidden`): the user is logged in, but may not do this. A missing [ability](#abilities), a failed [gate or policy](authorization.md), or `GuestMiddleware` for a logged-in user. Logging in again does not help.
- `419` (`csrf_token_mismatch`): a session request with no CSRF token. See [CSRF protection](csrf.md).
- `429`: too many failed logins. See [Login throttle](#login-throttle).

## Problems

| Error | Cause | Fix |
| --- | --- | --- |
| `LateInitializationError: Field 'config' has not been initialized.` | `Auth.initialize` did not run. `AppAuthProvider` is missing, or the generator did not run. | Add [`AppAuthProvider`](#5-load-the-config-when-the-app-starts), then run `dart run build_runner build`. |
| `401` `Authentication failed` | No `Authorization` header, a bad, expired or revoked token, a deleted user, or a token of another guard. | Send `Authorization: Bearer <token>`. Log in again. |
| `401` `Wrong email or password` | Your login controller: `attempt` gave `null`. | Check the email and password. |
| `403` `Forbidden` | Your controller: the token does not have the ability. | Use a token with the ability. See [Abilities](#abilities). |
| `Invalid argument (guard): no auth guard with this name: "admin"` | `Auth(guard: ...)` or `AuthMiddleware(guard: ...)` with a name that is not in `guards`. | Fix the name, or add the guard. |
| `Bad state: The auth guard 'api' does not use SessionAuthDriver. Use attempt() and login() for a token, and revokeToken() to log out.` | `logout`, `attemptSession` or `loginSession` on a token guard. | Use `revokeToken(req)` to log out a token. |
| `Bad state: The auth guard 'api' does not use AccessTokenAuthDriver.` | An access token method on a JWT or session guard. | Use `Auth(guard: ...)` of a guard with `AccessTokenAuthDriver`. |
| `Bad state: The auth guard 'web' does not use JwtAuthDriver.` | `revokeAllTokens`, `forgetUser` or `userFromToken` on a session guard, or `revokeToken` on a session guard. | Use them on a JWT guard. A session logs out with `logout(req)`. |
| `Bad state: AccessTokenAuthDriver makes tokens with Auth().createAccessToken(user), not login().` | `Auth().login(user)` on an access token guard. | Use `createAccessToken(user)`. |
| `Bad state: revokeToken needs token revocation. Turn it on with JwtAuthDriver(revocation: true).` | `revokeToken`, `revokeAllTokens` or `forgetUser` on a JWT guard without revocation. The text names the method. | Set `revocation: true`. See [Revoke tokens](#revoke-tokens). |
| `Bad state: The table 'auth_access_tokens' has no rotated_at column. ...` | `rotateAccessToken` on a token table without the `rotated_at` column. | Add the column. See [A token table without `rotated_at`](#a-token-table-without-rotated_at). |
| `401` `The access token was already rotated.` | A second rotate of the same token. | Use the new token. Rotate it, not the old one. |
| `401` `The access token is expired.` | Rotate of an expired token. | Log in again. |
| `401` `The access token is revoked or does not exist.` | Rotate or change abilities of a revoked token. | Log in again. |
| `Invalid argument(s) (secret): The JWT secret is empty. Set APP_KEY (run `dox key:generate`).` | `JwtAuthDriver` with an empty secret. | Set `APP_KEY`. |
| `Invalid argument(s) (secret): The JWT secret is <n> bytes. It must be at least 32 bytes. ...` | A short secret. In `development`, `local`, `test` and `testing` it is only a warning. | Run `dox key:generate`. |
| `Invalid argument(s) (password): The password is too long. bcrypt takes at most 72 bytes.` | `Hash.make` or `Hash.makeAsync` with a longer password. | Limit the length in the DTO. |
| `Invalid argument(s): Set guard or a non-empty guards list, not both.` | `AuthMiddleware(guard: ..., guards: ...)`, or `guards: []`. | Set one of them. |
| `429` `Too many login attempts. Try again in <n> seconds.` | The [login throttle](#login-throttle). | Wait `retryAfter`. |
| `419` `CSRF token mismatch` | A session `POST` without the CSRF token. | Send the `X-XSRF-TOKEN` header or the `_token` field. See [CSRF protection](csrf.md). |
| `403` `Already logged in` | `GuestMiddleware` with no `redirectTo`, for a logged-in user. | Set `redirectTo`, or log out first. |
| `401` `The password does not match the current password.` (`wrong_password`) | `logoutOtherDevices` with a wrong password. | Show an error on the form. |
| `Bad state: logoutOtherDevices() needs the endSessionsOnPasswordChange flag` | `logoutOtherDevices` with the flag off. | Turn the flag on. See [End other sessions](#end-other-sessions-when-the-password-changes). |

## Good to know

Access tokens:

- A token fails (`401`) when its format is bad, the secret is wrong, it is expired, it was revoked, its user is gone, it has another type, or it was made for a guard with another user table.
- `tokenable_type` is the table name of the user model. If you rename the users table, the old tokens stop working.
- Each token has a `type`. By default it is the guard name. So two access token guards do not take each other's tokens. If you rename a guard, set `AccessTokenAuthDriver(type: 'old-name')` to keep its tokens working.
- A token `name` over 255 characters throws an `ArgumentError`. Nothing is written.
- When you delete a user, call `revokeAllAccessTokens(user)` too, or use `--users-table` (`usersTable:`) in the migration. Then old tokens can never match a new user with the same id.
- The migration makes the table on the default connection. If the driver uses another connection, like `AccessTokenAuthDriver(connection: 'other')`, make the table on that connection.
- `last_used_at` is written at most once a minute per token. So a busy token does not write on every request. If this write fails, the error is reported and the request goes on.
- On MySQL, `expires_at` is kept to the second: MySQL rounds the time. So a token can stop working up to half a second before or after its exact time.

JWT:

- **The token is not secret.** By default, anyone with the token can read `user.toJson()`. Keep private columns in `hidden`, or use [small tokens](#small-tokens).
- **The user is loaded on each request**, by the id in the token. A deleted user can not log in, even with a valid token.
- **`userCacheTtl` skips that query.** With `Duration(seconds: 30)`, a deleted or changed user is seen only after 30 seconds, unless `forgetUser` runs. Each isolate has its own cache. Requests in that time share one user object, so do not change it per request.
- Dox does not sign with the `secret` text as it is. The HMAC key is made from it with HKDF-SHA256 and the label `dox:jwt`. Another service that checks the tokens needs that key: `driver.signingKey`.
- `JwtAuthDriver.bearerToken(req)` gives the token of a request.

Sessions:

- Login and logout give the session a new id and a new CSRF token. So an id that someone saw before the login is of no use.
- With the default `cookie` session driver, all session data sits in the cookie. So an old copy of the cookie still works after logout, until the session `lifetime` ends. If logout must really end old cookies, use the `cache` session driver, like `SessionConfig(driver: 'cache', store: 'redis')`.
- The session keeps only the user id. `AuthMiddleware` loads the user from the database on each request, so a deleted user is logged out.

## Reference

### `AuthConfig` and `AuthGuard`

| Option | Default | What it does |
| --- | --- | --- |
| `AuthConfig(defaultGuard:)` | required | the guard that `Auth()` and the middleware use when no guard is given |
| `AuthConfig(guards:)` | `{}` | the guards, by name |
| `AuthConfig(flags:)` | `AuthFlags()` (all off) | opt-in behaviors. See [Auth flags](authorization.md#auth-flags) |
| `AuthGuard(driver:)` | required | `AccessTokenAuthDriver`, `JwtAuthDriver`, `SessionAuthDriver`, or your own `AuthDriver` |
| `AuthGuard(provider:)` | required | the `AuthProvider`: which model holds the users |

### `AuthProvider`

| Option | Default | What it does |
| --- | --- | --- |
| `model` | required | a function that makes a new model, like `() => User()` |
| `identifierFields` | `['email']` | the fields `attempt` searches by |
| `passwordField` | `'password'` | the column with the bcrypt hash |

### `Auth`

| Method | What it does |
| --- | --- |
| `Auth.initialize(AuthConfig)` | sets the config. Call it once, in a `DoxProvider` |
| `Auth(guard: 'admin')` | uses another guard from `guards`. Without `guard`, it uses `defaultGuard` |
| `Auth(ip: req.ip())` | gives the client ip to `attempt`, for the [login throttle](#login-throttle) |
| `Auth.throttle` | the [login throttle](#login-throttle). `null` (off) by default |
| `await attempt(credentials)` | finds the user and checks the password. Gives a token (a JWT, or an access token with all abilities), or `null` |
| `await once(credentials)` | checks the password like `attempt`. Gives `true` or `false`. It makes no token and does not touch the session. The user is logged in for this `Auth` only |
| `login(user)` | gives a JWT for this user, with no password check |
| `setUser(req, user)` | sets this user on `req.auth`, with no token and no password check. For your own auth middleware |
| `user<T>()` | the user after `attempt`, `once` or `login` |
| `isLoggedIn()`, `check()` | `true` when there is a user |
| `guest()` | `true` when there is no user |
| `id()` | the primary key of the user, or `null`. It works when the key is in `hidden` |
| `await userFromToken(token)` | the user of a JWT or access token, with no request. See [Check a login with no request](#check-a-login-with-no-request) |
| `await userFromSession(session)` | the user of a session, with no request |
| `await attemptSession(req, credentials)` | checks the password like `attempt`, and keeps the user id in the session. Gives `true` or `false`. Session guard only |
| `loginSession(req, user)` | keeps this user in the session, with no password check. Session guard only |
| `logout(req)` | removes the session login and all session data. Session guard only |
| `await logoutOtherDevices(req, password)` | checks the password, hashes it again, and ends all other sessions of the user. Session guard and the `endSessionsOnPasswordChange` flag only. See [End other sessions](#end-other-sessions-when-the-password-changes) |
| `updateSessionPasswordHash(req, user)` | keeps the current session logged in after your app changed the password. Needs the `endSessionsOnPasswordChange` flag |
| `await revokeToken(req)` | revokes the bearer token of this request. JWT (needs [revocation](#revoke-tokens)) or access token |
| `await revokeAllTokens(id)` | revokes all JWTs of this user made before the current second. Needs [revocation](#revoke-tokens) |
| `await forgetUser(id)` | drops this user from the `userCacheTtl` cache. Needs [revocation](#revoke-tokens) |
| `await createAccessToken(user, name:, abilities:, expiresIn:)` | a new access token. `token.value` is the plain token. `abilities` default to `['*']`, `expiresIn` to the driver `expiresIn` |
| `await rotateAccessToken(token, grace:, name:, expiresIn:)` | a new access token in place of `token`. See [Rotate a token](#rotate-a-token) |
| `await setAccessTokenAbilities(token, abilities)` | replaces the whole abilities list of a token. See [Two-step login](#change-the-abilities-of-a-token) |
| `await accessTokens(user)` | all access tokens of the user, newest first |
| `await revokeAccessToken(user, id)` | deletes one access token of the user. `false` when the user has no such token |
| `await revokeAllAccessTokens(user)` | deletes all access tokens of the user. Gives how many |
| `await pruneExpiredAccessTokens()` | deletes the expired tokens of the table. Gives how many |
| `currentAccessToken` | the `AccessToken` of this request, or `null` |
| `tokenCan(ability)` | `true` when the access token of this request has the ability, or `*` |
| `Auth.needsRehash(hash)` | `true` when the hash was not made with the cost of `Hash.rounds`. See [Password hash cost](#password-hash-cost) |
| `Auth.hashCost(hash)` | the bcrypt cost of a hash, or `null` when it is not a bcrypt hash |

### `req.auth`

After `AuthMiddleware`, `req.auth` holds the login.

| Code | What it gives |
| --- | --- |
| `req.auth` | an `IAuth?`. `null` for a guest, and on a route with no `AuthMiddleware`. A query or body field can not set it |
| `req.auth as Auth` | the `Auth`, for `tokenCan`, `currentAccessToken` and `revokeToken` |
| `req.auth?.isLoggedIn()` | `true` when a user is loaded |
| `req.auth?.id()` | the primary key of the user, or `null` |
| `req.auth?.user<User>()` | the user model |
| `req.auth?.toJson()` | the user as a map, without `hidden` fields |

### `AccessTokenAuthDriver`

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

### `AccessTokenTables.up` and `dox auth:tokens-table`

| Option | Flag | Default | What it does |
| --- | --- | --- | --- |
| `table` | none (edit the migration) | `'auth_access_tokens'` | the table name. Use the same name as the driver `table` |
| `uuidIds` | `--uuid` | `false` | `tokenable_id` is a uuid column (`UUID` on Postgres) |
| `stringIds` | `--string-ids` | `false` | `tokenable_id` is text. Do not use it with `--uuid` |
| `usersTable` | `--users-table=users` | none | adds a foreign key from `tokenable_id` to `usersKey` of this table, with cascade delete. The two id columns must have the same type |
| `usersKey` | `--users-key=uid` | `'id'` | the key column of `usersTable`. Alone, the flag prints a warning and does nothing |

`AccessTokenTables.down(schema, table: 'auth_access_tokens')` drops the table. Pass the same `table` as in `up`.

The table has these columns: `id`, `tokenable_type`, `tokenable_id`, `type`, `name`, `hash`, `abilities`, `last_used_at`, `expires_at`, `rotated_at`, `created_at`, `updated_at`.
There is an index on `expires_at`. The time columns are `DATETIME` on MySQL, so a token can expire after 2038.
`auth:tokens-table` is a [package command](../digging-deeper/package-commands.md) of `dox_auth`. The same flag twice is an error: it writes nothing and exits with code 1.

### `AccessToken`

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

### `JwtAuthDriver`

| Option | Default | What it does |
| --- | --- | --- |
| `secret` | required | the key that signs tokens, like `SecretKey(env.appKey)`. An empty key throws `ArgumentError`. A key shorter than 32 bytes also throws in production, and prints a warning in development, local, test and testing. Make one with `dox key:generate`. For a separate JWT secret (not `APP_KEY`), `openssl rand -hex 32` also works |
| `algorithm` | `JWTAlgorithm.HS256` | the signing algorithm. A token with another algorithm in its header is rejected |
| `expiresIn` | `Duration(hours: 1)` | how long a token is valid |
| `issuer` | `null` | the `iss` claim. When set, the check also reads it |
| `hashRounds` | `10` | the bcrypt cost of your stored hashes. Use the same value as `Hash.rounds` |
| `userCacheTtl` | `null` (off) | keep the user of a token in memory for this time |
| `previousSecrets` | `null` | old secrets, only to check tokens after a key change. `null` with `secret` = `APP_KEY`: the old keys come from `AppConfig.previousKeys`. `[]` turns it off. See [Change the JWT secret](#change-the-jwt-secret) |
| `minimalPayload` | `false` | put only the user id (the `sub` claim) in new tokens. See [Small tokens](#small-tokens) |
| `revocation` | `false` | turn on token revocation. See [Revoke tokens](#revoke-tokens) |
| `revocationStore` | `null` | the cache store for revoked tokens. `null` is the default app store |

The token keeps the guard name in its `aud` claim.

### `SessionAuthDriver`

| Option | Default | What it does |
| --- | --- | --- |
| `hashRounds` | `10` | the bcrypt cost of your stored hashes |

### `AuthMiddleware` and `GuestMiddleware`

| Option | Default | What it does |
| --- | --- | --- |
| `AuthMiddleware(guard:)` | `defaultGuard` | the guard to check |
| `AuthMiddleware(guards:)` | none | several guards, tried in order. Do not set `guard` too |
| `AuthMiddleware(redirectTo:)` | none (`401`) | send a guest to this page instead of a `401` |
| `AuthMiddleware(optional:)` | `false` | let guests through too. See [Pages for everyone and pages for guests](#pages-for-everyone-and-pages-for-guests) |
| `GuestMiddleware(guard:)` | `defaultGuard` | the guard to check |
| `GuestMiddleware(redirectTo:)` | none (`403`) | send a logged-in user to this page instead of a `403` |

### `LoginThrottle`

| Option | Default | What it does |
| --- | --- | --- |
| `maxAttempts` | `5` | failed logins allowed per login field and ip. Less than 1 throws an `ArgumentError` |
| `decay` | `Duration(minutes: 1)` | how long the count is kept, from the first failed login |
| `store` | `null` | the cache store for the counts. `null` is the default app store |
