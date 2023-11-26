<img src="https://raw.githubusercontent.com/dartondox/assets/main/dox-logo.png" width="70" />

## Dox Auth

Dox Auth is an authentication package for dox framework. Currently it support JWT driver and support only with Dox Query Builder(ORM)

## Usage

1. Create auth config

```dart
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
import 'package:dox/models/user/user.model.dart';

class AuthConfig extends AuthConfigInterface {
  @override
  String get defaultGuard => 'web';

  @override
  Map<String, Guard> get guards => <String, Guard>{
        'web': Guard(
          driver: JwtDriver(
            secret: SecretKey(Env.get('APP_KEY')),
          ),
          provider: Provider(
            model: () => User(),
          ),
        ),
      };
}
```

2. Modify `bin/server.dart` to add auth config

```dart
Dox dox = Dox();
await dox.initialize(config);
dox.setAuthConfig(AuthConfig());
```

3. Attempt Login

```dart
Map<String, dynamic> credentials = req.only(<String>['email', 'password']);

Auth auth = Auth();
String? token = await auth.attempt(credentials);
User? user = auth.user<User>();
```

4. Register `doxAuthMiddleware` in route

```dart
 Route.get('/auth/user', <dynamic>[doxAuthMiddleware, authController.user]);
```

5. Verify Logged In or Fetch User information

```dart
Future<dynamic> fetchUser(DoxRequest req) async {
  Auth? auth = req.auth<Auth>();
  if (auth?.isLoggedIn() == true) {
    return auth?.user();
  }
  throw UnAuthorizedException();
}
```

### Expired In

```dart
JwtDriver(
  secret: SecretKey(Env.get('APP_KEY')),
  expiresIn: Duration(hours: 5),
),
```

### Issuer

```dart
JwtDriver(
  secret: SecretKey(Env.get('APP_KEY')),
  issuer: 'https://dartondox.dev',
),
```

### Algorithm

```dart
JwtDriver(
  secret: SecretKey(Env.get('APP_KEY')),
  algorithm: JWTAlgorithm.HS256,
),
```

*for more information about algorithm please visit [dart jsonwebstoken](https://pub.dev/packages/dart_jsonwebtoken)*

## Documentation

For detailed information about the framework and its functionalities, refer to the [Dox Documentation](https://dartondox.dev).

## Security Vulnerabilities

Dox take the security of our framework seriously. If you identify any security vulnerabilities in our application, please notify us immediately by sending an email to support@dartondox.dev. We appreciate your responsible disclosure and will respond promptly to address and resolve any identified security issues. Your cooperation helps us maintain the integrity and safety of our software for all users.

## Contributing

We welcome contributions from the community! If you'd like to contribute to the Dox Auth, please fork the repo and PR to us.

## License

This project is licensed under the [MIT License](LICENSE).

## Community

<a href="https://discord.gg/pBfWrsvBSV"><img src="https://img.shields.io/badge/Discord-7289DA?style=for-the-badge&logo=discord&logoColor=white"></a>
