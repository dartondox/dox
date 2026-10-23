# Step 5: Login with dox_auth

This step adds register and login with a JWT token, and only lets a logged in user create or change posts.

## 1. Add the package

```bash
dart pub add dox_auth:^3.0.0-alpha.4
```

## 2. Make the users table

The template already has a `User` model in `lib/app/models/user/user.model.dart`:

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

`password` is in `hidden`, so it is never in the JSON. This matters: the token holds the user as JSON, and anyone can read a JWT.

The `users` table already exists. The template has its migration, and the
server ran it at the first start in [step 1](01-create-project.md):

```dart title="db/migration/2023_07_16_131937700_create_users_table.dart"
class CreateUsersTable extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await schema.create('users', (Table table) {
      table.id();
      table.string('name');
      table.string('email').unique();
      table.string('password');
      table.softDeletes();
      table.timestamps();
    });
  }
  // ...
}
```

`table.softDeletes()` makes the `deleted_at` column that `softDelete: true` needs.
`email` is unique, so a second register with the same email fails.

## 3. Make the DTOs

```bash
dox create:dto RegisterUser
dox create:dto LoginUser
```

```dart title="lib/app/http/dtos/register_user.dto.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_orm/dox_orm.dart' hide Schema;

part 'register_user.dto.g.dart';

@Dto()
class RegisterUser {
  @Trim()
  @Length(min: 2, max: 50)
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

`@Unique` comes from `dox_orm`. It reads the database, so it runs after the other rules.
`dox_orm` also has a class named `Schema`, so the import hides it.

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

## 4. Set up the auth service

A service runs once in every isolate at start. This one tells `dox_auth` which model to use and how to sign tokens:

```dart title="lib/services/auth_service.dart"
import 'package:blog/app/models/user/user.model.dart';
import 'package:blog/config/env.dart';
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';

/// Auth service
/// --------------------------
/// Sets up JWT login with the User model.
/// Tokens are signed with APP_KEY and last 7 days.
class AuthService implements DoxService {
  @override
  void setup() {
    Auth.initialize(
      AuthConfig(
        defaultGuard: 'api',
        guards: <String, AuthGuard>{
          'api': AuthGuard(
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

Add it to the service list:

```dart title="lib/config/services.dart"
import 'package:blog/services/auth_service.dart';
import 'package:blog/services/orm_service.dart';
import 'package:dox_core/dox_core.dart';

/// Services to register on dox
/// -------------------------------
/// Since dox run on multi thread isolate, we need to register
/// below extra services to dox so that dox can
/// register again on new isolate.
List<DoxService> services = <DoxService>[ORMService(), AuthService()];
```

## 5. Write the auth controller

```dart title="lib/app/http/controllers/auth.controller.dart"
import 'package:blog/app/http/dtos/login_user.dto.dart';
import 'package:blog/app/http/dtos/register_user.dto.dart';
import 'package:blog/app/models/user/user.model.dart';
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';

class AuthController {
  /// POST /api/auth/register
  Future<DoxResponse> register(RegisterUser body) async {
    User user = User()
      ..name = body.name
      ..email = body.email
      ..password = Hash.make(body.password);
    await user.save();

    String? token = Auth().login(user);
    return response(<String, dynamic>{
      'token': token,
      'user': user,
    }).statusCode(201);
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

  /// GET /api/auth/user
  User? user(DoxRequest req) {
    return req.auth?.user<User>();
  }
}

AuthController authController = AuthController();
```

- `Hash.make()` makes a bcrypt hash. Never save a plain password.
- `Auth().attempt()` finds the user by email and checks the password. It gives a token, or `null`.
- `Auth().login(user)` gives a token without a password check. Register uses it, because the user was just made.

## 6. Protect the write routes

Replace `Route.resource` with single routes. The routes inside `Route.middleware` need a valid token:

```dart title="lib/routes/api.dart"
import 'package:blog/app/http/controllers/api.controller.dart';
import 'package:blog/app/http/controllers/auth.controller.dart';
import 'package:blog/app/http/controllers/post.controller.dart';
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';

class ApiRouter extends Router {
  @override
  String get prefix => 'api';

  @override
  List<dynamic> get middleware => <dynamic>[];

  @override
  void register() {
    Route.get('/ping', apiController.pong);

    // Anyone can read posts.
    Route.get('/posts', postController.index);
    Route.get('/posts/{id}', postController.show);

    // Register and log in.
    Route.post('/auth/register', authController.register);
    Route.post('/auth/login', authController.login);

    // Only a logged in user can write posts.
    Route.middleware(<dynamic>[AuthMiddleware()], () {
      Route.get('/auth/user', authController.user);
      Route.post('/posts', postController.store);
      Route.put('/posts/{id}', postController.update);
    });
  }
}
```

`AuthMiddleware` reads the `Authorization: Bearer <token>` header and loads the user.
When the token is missing or wrong, it answers `401 Authentication failed`.

## 7. Migrate and generate

```bash
dox migration:run
dart run build_runner build --delete-conflicting-outputs
```

`dox s` runs the migration and the generator for you when it restarts.

## Check it

Register:

```bash
curl -i -X POST http://localhost:3000/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"name":"Ann","email":"ann@example.com","password":"secret123"}'
```

```text
HTTP/1.1 201 Created
content-type: application/json; charset=utf-8
...

{"token":"eyJhbGciOiJIUzI1NiIs...","user":{"id":1,"name":"Ann","email":"ann@example.com","created_at":"2026-10-22T14:01:07.827769Z","updated_at":"2026-10-22T14:01:07.827769Z"}}
```

The same email again gives `422`:

```json
{"email":"The email has already been taken"}
```

A wrong password gives `401`:

```bash
curl -i -X POST http://localhost:3000/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"ann@example.com","password":"wrong"}'
```

```text
HTTP/1.1 401 Unauthorized
...

{"code":"unauthorized","message":"Wrong email or password"}
```

Log in and keep the token in a shell variable:

```bash
TOKEN=$(curl -s -X POST http://localhost:3000/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"ann@example.com","password":"secret123"}' \
  | sed -E 's/.*"token":"([^"]+)".*/\1/')
echo $TOKEN
```

A post without a token is refused:

```bash
curl -i -X POST http://localhost:3000/api/posts \
  -H 'Content-Type: application/json' \
  -d '{"title":"Third post","body":"Written with a token."}'
```

```text
HTTP/1.1 401 Unauthorized
...

{"code":"unauthorized","message":"Authentication failed"}
```

With the token it works:

```bash
curl -i -X POST http://localhost:3000/api/posts \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"title":"Third post","body":"Written with a token."}'
```

```text
HTTP/1.1 201 Created
...

{"id":3,"title":"Third post","body":"Written with a token.","created_at":"2026-10-22T14:01:08.094211Z","updated_at":"2026-10-22T14:01:08.094211Z"}
```

Who am I:

```bash
curl http://localhost:3000/api/auth/user -H "Authorization: Bearer $TOKEN"
```

```json
{"id":1,"name":"Ann","email":"ann@example.com","created_at":"2026-10-22T14:01:07.827769Z","updated_at":"2026-10-22T14:01:07.827769Z"}
```

No `password` in the answer, because it is in `hidden`.

## Next

[Step 6: Test](06-test.md)
