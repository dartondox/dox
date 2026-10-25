# dox_auth example

JWT login for a Dox app: a provider, routes and a controller. The full guide
is on [dartondox.dev](https://dartondox.dev/latest/security/authentication/).

## 1. The provider

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

Dox finds the provider by itself. Run `dart run build_runner build`.
The `User` model must hide its password: `List<String> get hidden => <String>['password'];`.

## 2. Routes

```dart title="lib/routes/api.dart"
Route.post('/auth/login', (AuthController c) => c.login);
Route.get('/auth/user', <dynamic>[AuthMiddleware(), (AuthController c) => c.user]);
```

## 3. Controller

```dart title="lib/app/http/controllers/auth.controller.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/models/user/user.model.dart';

@Inject()
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

## Session login for web pages

Use `SessionAuthDriver()` instead of `JwtAuthDriver` in the guard.
Add `SessionMiddleware()` and `CsrfMiddleware()` to `globalMiddleware`.

```dart title="lib/app/http/controllers/login.controller.dart"
@Inject()
class LoginController {
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
}
```

```dart title="lib/routes/web.dart"
Route.post('/login', (LoginController c) => c.login);
Route.post('/logout', (LoginController c) => c.logout);
Route.get('/dashboard', <dynamic>[AuthMiddleware(redirectTo: '/login'), (PageController c) => c.dashboard]);
```
