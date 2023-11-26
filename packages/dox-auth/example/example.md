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
