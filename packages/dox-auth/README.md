# dox_auth

Login for Dox apps. It checks an email and a password and gives back a JWT token.

[![pub package](https://img.shields.io/pub/v/dox_auth.svg)](https://pub.dev/packages/dox_auth)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/dartondox/dox/blob/develop/LICENSE)

Part of [Dox](https://dartondox.dev), a web backend framework for Dart, like Laravel.
Source code: [github.com/dartondox/dox](https://github.com/dartondox/dox).

## Install

```bash
dart pub add dox_auth
```

Dox 3.x is in alpha (`3.0.0-alpha.x`). The API can still change before the stable release.

A new app made with `dox create` already has it.

## Use it

Set it up in a service:

```dart
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';

class AuthService implements DoxService {
  @override
  void setup() {
    Auth.initialize(AuthConfig(
      defaultGuard: 'web',
      guards: <String, AuthGuard>{
        'web': AuthGuard(
          driver: JwtAuthDriver(
            secret: SecretKey(Env.get('APP_KEY')),
            expiresIn: const Duration(days: 7),
          ),
          provider: AuthProvider(model: () => User()),
        ),
      },
    ));
  }
}
```

Log in, and protect a route:

```dart
String? token = await Auth().attempt(<String, dynamic>{
  'email': 'ada@example.com',
  'password': 'secret',
}); // null when the email or password is wrong

Route.get('/auth/user', <dynamic>[AuthMiddleware(), authController.user]);
```

After `AuthMiddleware`, `req.auth?.user<User>()` is the logged in user.

## Features

- JWT driver (`JwtAuthDriver`) with a secret, algorithm, expiry and issuer.
- `Auth().attempt(credentials)` finds the user and checks the bcrypt hash.
- `Auth().login(user)` gives a token with no password check.
- `AuthMiddleware` answers `401` when the token is missing or not valid.
- The user is loaded from the database on each request with `dox_orm`.

Things to know: set `expiresIn`, or a token never expires.
There is no server list of tokens, so you can not cancel one token.
Only the default guard is used.

## Documentation

- [Authentication](https://dartondox.dev/latest/security/authentication/)
- [Guide: JWT auth](https://dartondox.dev/latest/guides/jwt-auth/)
- [API reference](https://pub.dev/documentation/dox_auth/latest/)

## License

MIT. See [LICENSE](https://github.com/dartondox/dox/blob/develop/LICENSE).
