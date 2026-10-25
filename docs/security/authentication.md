# Authentication

This page shows how to log users in with `dox_auth` and protect routes with a JWT token.

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

## 2. Set up the auth service

```dart title="lib/services/auth_service.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/models/user/user.model.dart';
import 'package:my_app/config/env.dart';

class AuthService implements DoxService {
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

Dox finds the service by itself. Run `dart run build_runner build` and it is in `lib/generated/container.g.dart`.

## 3. Add the routes

`AuthMiddleware` protects a route.
When the token is missing or not valid, the request stops with `401 Authentication failed`.

```dart title="lib/routes/api.dart"

Route.post<AuthController>('/auth/register', (AuthController c) => c.register);
Route.post<AuthController>('/auth/login', (AuthController c) => c.login);
Route.get<AuthController>('/auth/user', <dynamic>[AuthMiddleware(), (AuthController c) => c.user]);
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
    user.password = Hash.make(body.password);
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
GET /auth/user
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
| `Auth.initialize(AuthConfig)` | sets the config. Call it once, in a service |
| `Auth(guard: 'admin')` | uses another guard from `guards`. Without `guard`, it uses `defaultGuard` |
| `await Auth().attempt(credentials)` | finds the user and checks the password. Gives a token, or `null` |
| `Auth().login(user)` | gives a token for this user, with no password check |
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
| `secret` | required | the key that signs tokens, like `SecretKey(env.appKey)`. An empty key throws `ArgumentError`. A key shorter than 32 bytes also throws in production, and prints a warning in development, local and test. Make one with `dox key:generate` or `openssl rand -hex 32` |
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

Route.get<AdminController>('/admin', <dynamic>[AuthMiddleware(guard: 'admin'), (AdminController c) => c.index]);
```

The token keeps the guard name in its `aud` claim.
So a token from the `web` guard does not work on the `admin` guard, even with the same secret.
An unknown guard name throws an `ArgumentError`.

## Things to know

- **The token is not secret.** Anyone with the token can read `user.toJson()`. Keep private columns in `hidden`.
- **You can not cancel one token.** A token works until it expires. If you change the `secret` (your `APP_KEY`), all tokens stop working.
- **The user is loaded on each request**, by the id in the token. A deleted user can not log in, even with a valid token.
- **`userCacheTtl` skips that query.** With `Duration(seconds: 30)`, a deleted or changed user is seen only after 30 seconds. Each isolate has its own cache. Requests in that time share one user object, so do not change it per request.
- **Login does not block the server.** `attempt` runs bcrypt in another isolate.
- **Hash passwords** before you save them. See [Hashing](hashing.md).
