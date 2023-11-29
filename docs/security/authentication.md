# Authentication

## Installation

=== "YAML"

    ```yaml
    dependencies:
    ...
    dox_auth: <latest>
    ```
=== "CLI"

    ```bash
    dart pub add dox_auth
    ```

Package link : [https://pub.dev/packages/dox_auth](https://pub.dev/packages/dox_auth)

---

## Usage

#### 1. Setup auth config

Create auth config file `lib/config/auth.dart`.

```dart
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
import 'package:poc_app/models/user/user.model.dart';

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

#### 2. Register auth config

Modify `bin/server.dart` to add auth config

```dart
Dox().initialize(Config());
Dox().setAuthConfig(AuthConfig());
```

#### 3. Register auth middleware

Register `doxAuthMiddleware` in route.

```dart
Route.get('/auth/user', <dynamic>[
  doxAuthMiddleware, 
  authController.user
]);
```

#### 4. Attempt Login

Use auth package in controller to attempt login.

```dart
class AuthController {
    login() {
        Map<String, dynamic> credentials = req.only(<String>['email', 'password']);
        Auth auth = Auth();
        String? token = await auth.attempt(credentials);
        if(token != null) {
            User? user = auth.user<User>();
            return user;
        }
        return response("unauthorized").statusCode(401);
    }
}
```

#### 5. Verify or Fetch User

Verify logged in user or fetch user information.

```dart
Future<dynamic> fetchUser(DoxRequest req) async {
  Auth? auth = req.auth<Auth>();
  if (auth?.isLoggedIn() == true) {
    return auth?.user();
  }
  throw UnAuthorizedException();
}
```