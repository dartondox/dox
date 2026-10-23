# dox_auth example

JWT login for a Dox app: a service, routes and a controller. The full guide
is on [dartondox.dev](https://dartondox.dev/latest/security/authentication/).

## 1. The service

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

Add `AuthService()` to the list in `lib/config/services.dart`.
The `User` model must hide its password: `List<String> get hidden => <String>['password'];`.

## 2. Routes

```dart title="lib/routes/api.dart"
AuthController authController = AuthController();

Route.post('/auth/login', authController.login);
Route.get('/auth/user', <dynamic>[AuthMiddleware(), authController.user]);
```

## 3. Controller

```dart title="lib/app/http/controllers/auth.controller.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/models/user/user.model.dart';

class AuthController {
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

  User? user(DoxRequest req) {
    return req.auth?.user<User>();
  }
}
```

`LoginUser` is a `@Dto` class with `email` and `password`.
Send the token as `Authorization: Bearer <token>`.
