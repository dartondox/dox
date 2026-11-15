---
icon: lucide/key-square
---

# JWT authentication

Let users register and log in, give them a JWT token, protect routes with it, and read the user in a controller.

A JWT token is a good fit for an API that a mobile app or a single page app calls. The client gets the token at login and sends it with every request, so the server needs no session.

## What you need

- A Dox app (`dox create my_app`). A new app has a database (SQLite), a `User` model and a `users` table with `name`, `email` and `password` columns.
- The `dox_auth` package. A new app does not have it. Add it:

```bash
dart pub add dox_auth
```

## 1. Hide the password in the model

The token holds `user.toJson()`, and anyone with the token can read it. So the password hash must be in `hidden`. The model of a new app already does this:

```dart title="lib/app/models/user/user.model.dart"
import 'package:dox_orm/dox_orm.dart';

part 'user.model.g.dart';

@DoxModel(table: 'users', softDelete: true)
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

The provider tells Dox how to make and check tokens, and how to find the user:

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
        defaultGuard: 'api',
        guards: <String, AuthGuard>{
          'api': AuthGuard(
            driver: JwtAuthDriver(
              // APP_KEY signs the tokens. A new key logs every user out.
              secret: SecretKey(env.appKey),
              // a token stops working after this time
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

The secret must be at least 32 bytes. A key from `dox key:generate` has the right length. A shorter secret stops the app in production, and prints a warning in development.

You do not need to register the provider, because Dox finds it by itself. After `dart run build_runner build` it is in `lib/generated/container.g.dart`.

## 3. Write the DTOs

You need one DTO for register and one for login. `@Unique` makes sure the email is not taken yet. It comes from `dox_orm`, so hide the `Schema` class of `dox_orm` in the import.

```dart title="lib/app/dtos/register_user/register_user.dto.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_orm/dox_orm.dart' hide Schema;

part 'register_user.dto.g.dart';

@Dto()
class RegisterUser {
  @Length(min: 2, max: 50)
  @Trim()
  final String name;

  @Trim()
  @Lowercase()
  @Email()
  @Unique('users', column: 'email')
  final String email;

  @MinLength(8)
  final String password;

  const RegisterUser({
    required this.name,
    required this.email,
    required this.password,
  });

  static const DtoSchema<RegisterUser> schema = $RegisterUserDto;
}
```

```dart title="lib/app/dtos/login_user/login_user.dto.dart"
import 'package:dox_core/dox_core.dart';

part 'login_user.dto.g.dart';

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

## 4. Write the controller

The controller makes the user, logs in, and returns the user of a token:

```dart title="lib/app/http/controllers/auth.controller.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/dtos/login_user/login_user.dto.dart';
import 'package:my_app/app/dtos/register_user/register_user.dto.dart';
import 'package:my_app/app/models/user/user.model.dart';

@Inject()
class AuthController {
  /// POST /api/auth/register
  Future<Map<String, dynamic>> register(RegisterUser body) async {
    User user = User()
      ..name = body.name
      ..email = body.email
      ..password = await Hash.makeAsync(body.password);
    await user.save();

    String? token = Auth().login(user);
    return <String, dynamic>{'token': token, 'user': user};
  }

  /// POST /api/auth/login
  Future<Map<String, dynamic>> login(LoginUser body) async {
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

  /// GET /api/auth/me (behind AuthMiddleware)
  User? me(DoxRequest req) {
    return req.auth?.user<User>();
  }

  /// POST /api/auth/logout (behind AuthMiddleware)
  /// By default a JWT is not cancelled on the server. The client deletes
  /// the token, and it still works until `expiresIn` passes. To cancel it,
  /// turn on revocation and call `Auth().revokeToken(req)`.
  Map<String, String> logout(DoxRequest req) {
    return <String, String>{'message': 'Delete the token on the client'};
  }
}
```

`Hash.makeAsync` makes a bcrypt hash of the password. At login, `auth.attempt` finds the user by `email` and checks the password against that hash. It returns `null` if the email or the password is wrong.

## 5. Add the routes

Register and login are open to everyone. Every other route goes inside `AuthMiddleware`. The middleware reads the `Authorization: Bearer <token>` header, checks the token and loads the user from the database. A missing or bad token stops the request with `401`.

```dart title="lib/routes/api.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/http/controllers/auth.controller.dart';

class ApiRouter extends Router {
  @override
  String get prefix => 'api';

  @override
  List<dynamic> get middleware => <dynamic>[];

  @override
  void register() {
    Route.post('/auth/register', (AuthController c) => c.register);
    Route.post('/auth/login', (AuthController c) => c.login);

    Route.middleware(<dynamic>[AuthMiddleware()], () {
      Route.get('/auth/me', (AuthController c) => c.me);
      Route.post('/auth/logout', (AuthController c) => c.logout);
      // put every protected route here
    });
  }
}
```

## 6. Register the DTOs

Dox finds a DTO in the `dtos` list of `AppConfig`. `build_runner` writes this list to `lib/generated/dtos.g.dart`. You add it only once, so skip this step if your `app.dart` already has `dtos: dtos`.

```dart title="lib/config/app.dart"
import 'package:my_app/generated/dtos.g.dart';

AppConfig appConfig = AppConfig(
  dtos: dtos,
  // ...
);
```

## 7. Build and run

```bash
dart run build_runner build --delete-conflicting-outputs
dox serve
```

## Check it

Register a user. You get a token and the user:

```bash
curl -H 'Content-Type: application/json' \
  -d '{"name":"Ann","email":"ann@example.com","password":"secret123"}' \
  http://localhost:3000/api/auth/register
```

```json
{"token":"eyJhbGciOiJIUzI1NiIs...","user":{"id":1,"name":"Ann","email":"ann@example.com","created_at":"...","updated_at":"..."}}
```

If you log in with a wrong password, you get `401`:

```json
{"error":{"code":"unauthorized","message":"Wrong email or password"}}
```

Now log in and use the token:

```bash
TOKEN=$(curl -s -H 'Content-Type: application/json' \
  -d '{"email":"ann@example.com","password":"secret123"}' \
  http://localhost:3000/api/auth/login | jq -r .token)

curl -H "Authorization: Bearer $TOKEN" http://localhost:3000/api/auth/me
```

```json
{"id":1,"name":"Ann","email":"ann@example.com","created_at":"...","updated_at":"..."}
```

Without the header, `/api/auth/me` gives `401 Authentication failed`.

The `{"error": ...}` shape comes from the response handler in [Custom errors](custom-errors.md). Without that handler, the `401` body is `{"code":"unauthorized","message":"Wrong email or password"}`.

## Logout and expiry

By default the server checks only the signature of a JWT, so it can not cancel one token. This is what you can do:

| You want | Do this |
| --- | --- |
| Log out on this device | The client deletes the token. That is all `logout` does. |
| Limit the damage of a stolen token | Keep `expiresIn` short, for example `Duration(hours: 12)`. |
| Log every user out at once | Change `APP_KEY`. Every old token stops working. |
| Block one user | Delete the user. `AuthMiddleware` loads the user from the database on each request, so a deleted user gets `401`. |

If you need to cancel one token, or all tokens of a user, turn on revocation. See [Revoke tokens](../security/authentication.md#revoke-tokens). Or use [access tokens](../security/authentication.md#access-tokens), which you can revoke at any time.

## See also

- [Authentication](../security/authentication.md) for all options of `AuthGuard`, `JwtAuthDriver` and `AuthProvider`
- [Hashing](../security/hashing.md)
- [Middleware](../the-basic/middleware.md)
