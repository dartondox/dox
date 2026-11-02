---
icon: lucide/user-lock
---

# Authentication

This page shows how to log users in with `dox_auth` and protect routes with a JWT token, an access token or a session.

`dox_auth` checks an email and a password against your user table.
It gives back a JWT token, or an [access token](#access-tokens) with `AccessTokenAuthDriver`.
The client sends this token in the `Authorization` header.
`AuthMiddleware` reads the token and loads the user from the database.

## Install

```bash
dart pub add dox_auth
```

A new app made with the `dox` CLI already has it.

## 1. Hide the password in the model

By default, the token holds the user data as JSON (`toJson()`), and anyone can read a JWT.
So the password hash must never be in `toJson()`.
Put it in `hidden`.
For a token that holds only the user id, see [Small tokens](#small-tokens).

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

The `Bearer` prefix can be in any case, so `bearer <token>` also works.
`JwtAuthDriver.bearerToken(req)` gives the token of a request.

## Read the user

After `AuthMiddleware`, `req.auth` holds the login.

| Code | What it gives |
| --- | --- |
| `req.auth` | an `IAuth?`. `null` when the route has no `AuthMiddleware`. It is kept apart from the input, so a query or body field can not set it |
| `req.auth?.isLoggedIn()` | `true` when a user is loaded |
| `req.auth?.guest()` | `true` when nobody is logged in |
| `req.auth?.id()` | the primary key of the user, or `null`. It works when the key is in `hidden` |
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
| `Auth(ip: req.ip())` | gives the client ip to `attempt`, for the [login throttle](#login-throttle) |
| `await Auth().revokeToken(req)` | revokes the bearer token of this request (a JWT logout). Needs [revocation](#revoke-tokens) |
| `await Auth().revokeAllTokens(id)` | revokes all tokens of this user made before now. Needs [revocation](#revoke-tokens) |
| `await Auth().forgetUser(id)` | drops this user from the `userCacheTtl` cache. Needs [revocation](#revoke-tokens) |
| `Auth.needsRehash(hash)` | `true` when the hash was not made with the cost of `Hash.rounds`. See [Password hash cost](#password-hash-cost) |
| `Auth.hashCost(hash)` | the bcrypt cost of a hash, or `null` when it is not a bcrypt hash |
| `user<T>()` | the user after `attempt` or `login` |
| `isLoggedIn()` | `true` when there is a user |
| `guest()` | `true` when there is no user |
| `id()` | the primary key of the user, or `null` for a guest |

`attempt` searches only by the fields in `identifierFields`. It runs bcrypt also when no user is found, or when the user has no password, so the answer time does not tell whether an email has an account.
It returns `null` when the password is not a `String`, when no identifier is given, when an identifier is not a string or a number (a map or a list from the body), or when the password does not match.

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
| `secret` | required | the key that signs tokens, like `SecretKey(env.appKey)`. An empty key throws `ArgumentError`. A key shorter than 32 bytes also throws in production, and prints a warning in development, local, test and testing. Make one with `dox key:generate`. For a separate JWT secret (not `APP_KEY`), `openssl rand -hex 32` also works. Dox does not sign with this text as it is: the HMAC key is made from it with HKDF-SHA256 and the label `dox:jwt`. Another service that checks the tokens needs that key: `driver.signingKey` |
| `algorithm` | `JWTAlgorithm.HS256` | the signing algorithm. A token with another algorithm in its header is rejected |
| `expiresIn` | `Duration(hours: 1)` | how long a token is valid |
| `issuer` | `null` | the `iss` claim. When set, `verifyToken` also checks it |
| `hashRounds` | `10` | the bcrypt cost of your stored hashes. Use the same value as `Hash.rounds` |
| `userCacheTtl` | `null` (off) | keep the user of a token in memory for this time. See below |
| `previousSecrets` | `null` | old secrets, only to check tokens after a key change. `null` with `secret` = `APP_KEY`: the old keys come from `AppConfig.previousKeys`. `[]` turns it off. See below |
| `minimalPayload` | `false` | put only the user id (the `sub` claim) in new tokens. See [Small tokens](#small-tokens) |
| `revocation` | `false` | turn on token revocation. See [Revoke tokens](#revoke-tokens) |
| `revocationStore` | `null` | the cache store for revoked tokens. `null` is the default app store |

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

### Small tokens

By default, a token holds the user (`toJson()`, `hidden` fields left out), plus the `iat`, `exp` and `jti` claims.
Anyone can read a JWT payload.
The safer choice is a small token:

```dart
JwtAuthDriver(secret: SecretKey(env.appKey), minimalPayload: true)
```

The token then holds only the user id (the `sub` claim).
Load the user with `req.auth?.user<User>()`, not from the token.
A front end that reads user fields from the token must then get the user from the API.

## Revoke tokens

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
With revocation on, the JWT driver keeps revoked tokens in the app cache (`Cache()` of `dox_core`).
A revoked token stops working at once:

```dart
await Auth().revokeToken(req);     // revoke the bearer token of this request (a JWT logout)
await Auth().revokeAllTokens(id);  // revoke all tokens of a user, eg. after a password change or a ban
await Auth().forgetUser(id);       // drop the user from `userCacheTtl`, eg. after a ban
```

- With revocation off, these three methods throw a `StateError`. So no one thinks a token is revoked when it is not.
- With revocation off, `verifyToken` never reads the cache.
- `Auth().logout(req)` is the session logout. For a JWT, use `revokeToken`.
- A revoked token stays on the deny-list only until it expires.
- `revokeAllTokens` keeps tokens made after the call. A token made in the same second as the call also still works.
- A token with no `jti` claim can not go on the deny-list, so `revokeToken` does nothing for it. `revokeAllTokens` still stops it when it has an `iat` claim. Tokens from `JwtAuthDriver` have one.
- The `revokeAllTokens` time comes from the server clock. Keep server clocks in sync (NTP).
- Give auth its own store, and never flush it. For example, a `redis` store with its own prefix. A flush of this store (`Cache().flush()`), or a `memory` store with `max_size` that drops old keys, brings revoked tokens back until they expire.
- Cost: `verifyToken` reads this store on every request, also with `userCacheTtl`. It is one `many()` call: one round trip on `redis` and `memory`. On the `file` store (the default) it is 2 or 3 file reads per request. Use `memory` for one isolate, or `redis` for many isolates or servers.
- When the store can not be read, the token is checked with only the signature and `exp`, and a warning is printed once. So a cache outage does not log everyone out. But revoked tokens work until the store is back.

## Access tokens

Access tokens are API tokens that you can revoke at any time.
They are like AdonisJS access tokens or Laravel Sanctum tokens.
They are opt-in. Session and JWT guards do not change.

A token looks like `oat_12.<secret>`.
The table keeps only a SHA-256 hash of the secret.
You see the plain token once, when you make it.
A token works until it expires or you revoke it.

### 1. Add the guard

```dart title="lib/config/auth.dart"
'api': AuthGuard(
  driver: AccessTokenAuthDriver(), // table: 'auth_access_tokens', expiresIn: null (no end)
  provider: AuthProvider(model: () => User()),
),
```

`AccessTokenAuthDriver` options:

| Option | Default | What it does |
| --- | --- | --- |
| `table` | `'auth_access_tokens'` | The table of the tokens. |
| `connection` | the default connection | The `dox_orm` connection name. |
| `expiresIn` | `null` (no end) | How long a new token works. |
| `hashRounds` | `10` | The bcrypt cost, for `attempt`. |
| `type` | the guard name | The type of the tokens. A token works only on a guard with the same type. |
| `stringIds` | `false` | `true` for users with text ids. Text ids are compared exactly. Use the same value in the migration. For uuid ids, see `uuidIds`. |
| `uuidIds` | `false` | `true` for users with uuid ids. A uuid is kept and compared in lower case. Use the same value in the migration. |

### 2. Add the table

Run `dox auth:tokens-table`. It writes a migration in `db/migration` that makes the `auth_access_tokens` table. Then run `dox migrate`.

```bash
dox auth:tokens-table
dox migrate
```

`auth:tokens-table` is a [package command](../digging-deeper/package-commands.md) of `dox_auth`. It does not overwrite: when a `create_access_tokens_table` migration is already there, it prints so and stops.

Flags:

- `--uuid`: for users with uuid ids (`uuidIds: true`).
- `--string-ids`: for users with text ids (`stringIds: true`).
- `--users-table=users`: adds a foreign key to this table (`usersTable:`).
- `--users-key=uid`: the key column of the users table, when it is not `id` (`usersKey:`).

For other options, like `table:`, edit the migration file. The migration it writes looks like this. You can also write it by hand. `AccessTokenTables` makes the table.

```dart title="db/migration/2026_11_02_000000000_create_access_tokens_table.dart"
// ignore_for_file: file_names
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_migration/dox_migration.dart';

/// The auth_access_tokens table of dox_auth.
class CreateAccessTokensTable extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await AccessTokenTables.up(schema);
  }

  @override
  Future<void> down(Schema schema) async {
    await AccessTokenTables.down(schema);
  }
}
```

`AccessTokenTables.up` options:

| Option | Default | What it does |
| --- | --- | --- |
| `table` | `'auth_access_tokens'` | The table name. Use the same name as the driver `table`. |
| `stringIds` | `false` | `false`: `tokenable_id` is an unsigned big int, like Sanctum and AdonisJS. `true`: it is text, for users with text ids. Use the same value as the driver `stringIds`. For uuid ids, see `uuidIds`. |
| `uuidIds` | `false` | `true`: `tokenable_id` is a uuid column (`UUID` on Postgres), for users with uuid ids. Then `usersTable` works with a uuid id. Set `uuidIds: true` on the driver too. |
| `usersTable` | none | Adds a foreign key from `tokenable_id` to `usersKey` of this table, with cascade delete. Then the tokens of a deleted user are deleted too. The two id columns must have the same type. |
| `usersKey` | `'id'` | The key column of `usersTable`, for the foreign key. |

With `usersTable`, use one token table per user model. If you have more than one user model (like users and admins), give each model its own token table, with `table:` on the driver and in the migration. With one shared table, the foreign key fails for admin tokens, and deleting a user also deletes the tokens of the admin with the same id.

The migration makes the table on the default connection.
If the driver uses another connection, like `AccessTokenAuthDriver(connection: 'other')`, make the table on that connection.

The table has these columns: `id`, `tokenable_type`, `tokenable_id`, `type`, `name`, `hash`, `abilities`, `last_used_at`, `expires_at`, `created_at`, `updated_at`.

### 3. Make and revoke tokens

```dart
// log in with a password: a new token with all abilities, or null
String? token = await Auth(guard: 'api').attempt(credentials);

// or make a token for a user
AccessToken token = await Auth(guard: 'api').createAccessToken(
  user,
  name: 'cli', // at most 255 characters
  abilities: <String>['posts:read'], // default: ['*'] (all)
  expiresIn: const Duration(days: 30), // default: the driver expiresIn
);
return <String, dynamic>{'token': token.value}; // shown only once

await Auth(guard: 'api').accessTokens(user);           // all tokens of the user, newest first
await Auth(guard: 'api').revokeAccessToken(user, id);  // false when the user has no such token
await Auth(guard: 'api').revokeAllAccessTokens(user);  // eg. after a password change
await Auth(guard: 'api').revokeToken(req);             // logout: revoke the token of this request
await Auth(guard: 'api').pruneExpiredAccessTokens();   // delete expired tokens, eg. from a scheduled job
```

In a route behind `AuthMiddleware`, `(req.auth as Auth).revokeToken(req)` uses the token that was already checked. So it does not check the token again.

`accessTokens` gives `AccessToken` objects. `token.toJson()` has no hash and no plain token, so you can send it to the client.

### 4. Protect routes and check abilities

The client sends `Authorization: Bearer oat_12.<secret>`.
Protect the route with `AuthMiddleware(guard: 'api')`.
Then check the abilities of the token:

```dart
Auth auth = req.auth as Auth;
if (!auth.tokenCan('posts:write')) {
  throw ForbiddenHttpException();
}
auth.currentAccessToken; // the AccessToken of this request
```

- A token fails (401) when its format is bad, the secret is wrong, it is expired, it was revoked, its user is gone, it has another type, or it was made for a guard with another user table.
- `tokenable_type` is the table name of the user model. If you rename the users table, the old tokens stop working.
- A revoked token is deleted from the table, so it stops working at once.
- A database error also fails the check (401). The error goes to `AppConfig.exceptionHandler`.
- Each token has a `type`. By default it is the guard name. So two access token guards do not take each other's tokens. If you rename a guard, set `AccessTokenAuthDriver(type: 'old-name')` to keep its tokens working.
- A token `name` over 255 characters throws an `ArgumentError`. Nothing is written.
- Pass a user of the guard's model. For admins, use `Auth(guard: 'admin').createAccessToken(admin)`. A user of another model throws an `ArgumentError`.
- On Postgres a uuid is stored in lower case. With `uuidIds`, the driver keeps and compares uuids in lower case too. On other databases, keep uuids in lower case in the users table.
- When you delete a user, call `revokeAllAccessTokens(user)` too, or use `usersTable` in the migration. Then old tokens can never match a new user with the same id.
- `tokenCan` is `false` when there is no access token. So a session or JWT login never passes it.
- `last_used_at` is written at most once a minute per token. So a busy token does not write on every request. If this write fails, the error is reported and the request goes on.
- `Auth().login(user)` throws a `StateError` with this driver. Use `createAccessToken`.
- Expired tokens stay in the table until you call `pruneExpiredAccessTokens()`.
- To check a token without a request, like in Socket.IO, use `Auth(guard: 'api').userFromToken(token)`. See [Check a login with no request](#check-a-login-with-no-request). The driver method behind it is `check(token, guard)`, an instance method of `AccessTokenAuthDriver`.

## Login throttle

The login throttle limits failed logins per account and ip. It is off by default.
Turn it on in `register()` or `boot()` of a provider.
`Auth.throttle` is static, so each isolate has its own copy. If you set it in `main()` before the server starts, only the first isolate throttles.

```dart
Auth.throttle = LoginThrottle(maxAttempts: 5, decay: Duration(minutes: 1));

// JWT: pass the client ip
String? token = await Auth(ip: req.ip()).attempt(credentials);

// session: the ip comes from the request
bool ok = await Auth().attemptSession(req, credentials);
```

- After `maxAttempts` failed logins for the same login field (eg. the email) and ip, the next try throws `LoginThrottledException` (429) until `decay` has passed. Its `retryAfter` says how long to wait.
- A good login clears the count. The login field is trimmed and lower case, so `A@x.com` and `a@x.com` share one count.
- The counts live in the app cache. Pick a store with `LoginThrottle(store: 'redis')`. Use a shared store like `redis` for many isolates or servers.
- Without an ip, `attempt` counts per account only. Then anyone can lock an account for `decay`. So pass the ip.
- `attemptSession` sends a `Retry-After` header with the 429. `attempt` has no request, so catch `LoginThrottledException` and set the header from `retryAfter` if you need it.
- A burst of parallel tries can get a few more than `maxAttempts`, because the check and the count are separate cache steps.

## Password hash cost

Passwords use bcrypt with cost 10 by default. Each step up doubles the time of a login.
To raise it, set the cost for new hashes and tell the driver.
Then a login for an unknown email takes as long as a wrong password:

```dart
Hash.rounds = 12;
JwtAuthDriver(secret: SecretKey(env.appKey), hashRounds: 12);
SessionAuthDriver(hashRounds: 12);
```

Old hashes keep their own cost, so they still work. Hash them again on the next good login:

```dart
if (Auth.needsRehash(user.password!)) {
  user.password = Hash.make(password);
  await user.save();
}
```

`Auth.needsRehash(hash, rounds: 12)` checks against another cost.

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

A public page can still know the user. `AuthMiddleware(optional: true)` sets `req.auth` when the login is good, and lets guests through too.
A guest, or a bad or expired token, goes on with `req.auth` as `null`.
A database error also goes on as a guest, and it is reported.

Login and register pages are for guests only. `GuestMiddleware` lets only guests through.
A logged-in user goes to `redirectTo`. With no `redirectTo`, the answer is `403` with the code `already_logged_in`.

```dart
Route.get('/posts', <dynamic>[AuthMiddleware(optional: true), (PostController c) => c.index]);
Route.get('/login', <dynamic>[GuestMiddleware(redirectTo: '/dashboard'), (PageController c) => c.login]);
```

Both take `guard:`, like `AuthMiddleware(guard: 'admin')`.

| Method | What it does |
| --- | --- |
| `await Auth().attemptSession(req, credentials)` | checks the password like `attempt`, and keeps the user id in the session. Gives `true` or `false` |
| `Auth().loginSession(req, user)` | keeps this user in the session, with no password check |
| `Auth().logout(req)` | removes the login and all session data. For a JWT, use [`revokeToken`](#revoke-tokens) |

- Login and logout give the session a new id and a new CSRF token. So an id that someone saw before the login is of no use.
- With the default `cookie` session driver, all session data sits in the cookie. So an old copy of the cookie still works after logout, until the session `lifetime` ends. If logout must really end old cookies, use the `cache` session driver, like `SessionConfig(driver: 'cache', store: 'redis')`.
- The session keeps only the user id. `AuthMiddleware` loads the user from the database on each request, so a deleted user is logged out.
- These methods throw a `StateError` on a guard that does not use `SessionAuthDriver`.
- `SessionAuthDriver` has one option, `hashRounds` (default `10`), like `JwtAuthDriver`.

## Check a login with no request

Code that has no request, like a [Socket.IO](../packages/socketio.md#log-in-a-socket) login, can check a token or a session itself:

```dart
User? user = await Auth(guard: 'api').userFromToken(token);
User? user = await Auth(guard: 'web').userFromSession(session);
```

- `userFromToken` runs the same checks as a request with a `Bearer` header. For a JWT: signature, algorithm, guard, `exp` and [revocation](#revoke-tokens). For an [access token](#access-tokens): the hash, the type, the user table, `expires_at` and revocation. Give the token with no `Bearer ` prefix. A missing, bad, expired, revoked or changed token gives `null`. It needs a guard with `JwtAuthDriver` or `AccessTokenAuthDriver`.
- With an access token, `currentAccessToken` and `tokenCan` work on the same `Auth` after `userFromToken`.
- `userCacheTtl` is a cache, not a check. With it on, a deleted or banned user can still connect until the cache time ends, unless `forgetUser` runs.
- `userFromSession` gives the user of a session, or `null`. Load the session with `SessionMiddleware().fromCookie(value)`. See [Session](../the-basic/session.md#load-a-session-with-no-request). It needs a guard with `SessionAuthDriver`.
- Both throw a `StateError` on a guard with the wrong driver.

## Things to know

- **The token is not secret.** By default, anyone with the token can read `user.toJson()`. Keep private columns in `hidden`, or use [small tokens](#small-tokens).
- **By default, you can not cancel one token.** A token works until it expires. Turn on [revocation](#revoke-tokens) to cancel one token, or all tokens of a user. Without revocation, to end all tokens, change the `secret` (your `APP_KEY`) with no old secrets. See [Change the JWT secret](#change-the-jwt-secret). Or use [access tokens](#access-tokens): they live in a table, and you can revoke them at any time.
- **The user is loaded on each request**, by the id in the token. A deleted user can not log in, even with a valid token.
- **`userCacheTtl` skips that query.** With `Duration(seconds: 30)`, a deleted or changed user is seen only after 30 seconds. Each isolate has its own cache. Requests in that time share one user object, so do not change it per request.
- **Login does not block the server.** `attempt` runs bcrypt in another isolate.
- **Hash passwords** before you save them. See [Hashing](hashing.md).
