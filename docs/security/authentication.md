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

Add the service to the list:

```dart title="lib/config/services.dart"
List<DoxService> services = <DoxService>[
  AuthService(),
];
```

## 3. Add the routes

`AuthMiddleware` protects a route.
When the token is missing or not valid, the request stops with `401 Authentication failed`.

```dart title="lib/routes/api.dart"
AuthController authController = AuthController();

Route.post('/auth/register', authController.register);
Route.post('/auth/login', authController.login);
Route.get('/auth/user', <dynamic>[AuthMiddleware(), authController.user]);
```

## 4. Write the controller

```dart title="lib/app/http/controllers/auth.controller.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/models/user/user.model.dart';

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
| `await Auth().attempt(credentials)` | finds the user and checks the password. Gives a token, or `null` |
| `Auth().login(user)` | gives a token for this user, with no password check |
| `user<T>()` | the user after `attempt` or `login` |
| `isLoggedIn()` | `true` when there is a user |

`attempt` searches only by the fields in `identifierFields`.
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
| `secret` | required | the key that signs tokens, like `SecretKey(env.appKey)` |
| `algorithm` | `JWTAlgorithm.HS256` | the signing algorithm |
| `expiresIn` | `null` | how long a token is valid. `null` means it never expires |
| `issuer` | `null` | the `iss` claim |

## Things to know

!!! warning "Set `expiresIn`"
    Without `expiresIn`, a token never expires.
    A stolen token then works forever.
    Set a duration, for example `Duration(days: 7)`.

- **The token is not secret.** Its payload is `user.toJson()`. Anyone with the token can read it. Keep private columns in `hidden`.
- **You can not cancel one token.** There is no token list on the server. A token works until it expires. If you change the `secret` (your `APP_KEY`), all tokens stop working.
- **Only the default guard is used.** `Auth()` and `AuthMiddleware` always use `defaultGuard`. Other guards in `guards` are not read.
- **The user is loaded on each request.** `AuthMiddleware` reads the user id from the token and runs `find(id)`. A deleted user can not log in, even with a valid token.
- **Hash passwords** with `Hash.make()` before you save them. See [Hashing](hashing.md).
