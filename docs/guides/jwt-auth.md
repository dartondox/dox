# JWT authentication

Let users register and log in, give them a JWT token, protect routes with it, and read the user in a controller.

## What you need

- A Dox app with a database and a `users` table with `name`, `email` and `password` columns.
- The `dox_auth` package: `dart pub add dox_auth`. A new app has it.
- `build_runner` for the DTOs.

## 1. Hide the password in the model

The token holds `user.toJson()`. Anyone with the token can read it. So the password hash must be in `hidden`.

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

Dox finds the service by itself. Run `dart run build_runner build` and it is in `lib/container.g.dart`.

## 3. Write the DTOs

`@Unique` makes sure the email is not taken. It comes from `dox_orm`, so hide its `Schema` class.

```dart title="lib/app/http/dtos/register_user.dto.dart"
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

```dart title="lib/app/http/dtos/login_user.dto.dart"
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

```dart title="lib/app/http/controllers/auth.controller.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/http/dtos/login_user.dto.dart';
import 'package:my_app/app/http/dtos/register_user.dto.dart';
import 'package:my_app/app/models/user/user.model.dart';

@Inject()
class AuthController {
  /// POST /api/auth/register
  Future<Map<String, dynamic>> register(RegisterUser body) async {
    User user = User()
      ..name = body.name
      ..email = body.email
      ..password = Hash.make(body.password);
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
  /// A JWT can not be cancelled on the server. The client deletes the
  /// token. The token still works until `expiresIn` passes.
  Map<String, String> logout(DoxRequest req) {
    return <String, String>{'message': 'Delete the token on the client'};
  }
}
```

`Hash.make` makes a bcrypt hash. `auth.attempt` finds the user by `email` and checks the password against that hash.

## 5. Add the routes

`AuthMiddleware` reads the `Authorization: Bearer <token>` header, checks the token and loads the user from the database.
A missing or bad token stops the request with `401`.

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
    Route.post<AuthController>('/auth/register', (AuthController c) => c.register);
    Route.post<AuthController>('/auth/login', (AuthController c) => c.login);

    Route.middleware(<dynamic>[AuthMiddleware()], () {
      Route.get<AuthController>('/auth/me', (AuthController c) => c.me);
      Route.post<AuthController>('/auth/logout', (AuthController c) => c.logout);
      // put every protected route here
    });
  }
}
```

## 6. Build and run

```bash
dart run build_runner build --delete-conflicting-outputs
dox serve
```

## Check it

Register:

```bash
curl -H 'Content-Type: application/json' \
  -d '{"name":"Ann","email":"ann@example.com","password":"secret123"}' \
  http://localhost:3000/api/auth/register
```

```json
{"token":"eyJhbGciOiJIUzI1NiIs...","user":{"id":1,"name":"Ann","email":"ann@example.com","created_at":"...","updated_at":"..."}}
```

Log in with a wrong password. You get `401`:

```json
{"error":{"code":"unauthorized","message":"Wrong email or password"}}
```

Log in and use the token:

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

!!! note "The error shape"
    The `{"error": ...}` shape comes from the response handler in [Custom errors](custom-errors.md).
    Without it, the `401` body is only the message.

## Logout and expiry

The server can not cancel one JWT. It checks only the signature. This is what you can do:

| You want | Do this |
| --- | --- |
| Log out on this device | The client deletes the token. That is all `logout` does. |
| Limit the damage of a stolen token | Keep `expiresIn` short, for example `Duration(hours: 12)`. |
| Log every user out at once | Change `APP_KEY`. Every old token stops working. |
| Block one user | Delete or disable the user. `AuthMiddleware` loads the user from the database on each request, so a deleted user gets `401`. |

For a real "log out everywhere" button, add a `token_version` column to `users`, put it in the token, and compare the two in a middleware after `AuthMiddleware`.

## See also

- [Authentication](../security/authentication.md) for all options of `AuthGuard`, `JwtAuthDriver` and `AuthProvider`
- [Hashing](../security/hashing.md)
- [Middleware](../the-basic/middleware.md)
