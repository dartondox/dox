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

#### 1. Setup auth service

Create auth service file `lib/services/auth_service.dart`.

```dart
class AuthService implements DoxService {
  @override
  void setup() {
    Auth.initialize(AuthConfig(
      /// default auth guard
      defaultGuard: 'web',

      /// list of auth guards
      guards: <String, AuthGuard>{
        'web': AuthGuard(
          driver: JwtAuthDriver(secret: SecretKey(Env.get('APP_KEY'))),
          provider: AuthProvider(
            model: () => User(),
          ),
        ),
      },
    ));
  }
}

```

#### 2. Register into dox `app/config/services.dart`

```dart
List<DoxService> services = <DoxService>[
  ... /// other services
  AuthService,
];
```


#### 3. Register auth middleware

Register `AuthMiddleware()` in route.

```dart
Route.get('/auth/user', <dynamic>[
  AuthMiddleware(), 
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
  IAuth? auth = req.auth;
  if (auth?.isLoggedIn() == true) {
    return auth?.user();
  }
  throw UnAuthorizedException();
}
```