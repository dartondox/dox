---
icon: lucide/key-round
---

# Step 5: Login with dox_auth

In this step you add register and login with a JWT token, so only a logged in user can create or change posts.

## 1. Add the package

The `dox_auth` package does the login and the tokens. Add it:

```bash
dart pub add dox_auth
```

## 2. Look at the users table

The template has a user model and a users table. This is the `User` model:

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

The password is in `hidden`, so it is never in the JSON. This is important, because the token holds the user as JSON and anyone can read a JWT.

The server ran this migration at the first start in [step 1](01-create-project.md):

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

`softDeletes()` makes the deleted_at column for the soft delete. The email is unique, so a second register with the same email fails.

## 3. Make the DTOs

Register and login have different input, so make two DTOs:

```bash
dox make:dto RegisterUser
dox make:dto LoginUser
```

Replace the register DTO with this:

```dart title="lib/app/dtos/register_user/register_user.dto.dart"
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

`@Unique` comes from `dox_orm` and reads the database, so it runs after the other rules. The ORM also has a class with the name `Schema`, so the import hides it.

Replace the login DTO with this:

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

## 4. Set up the auth provider

A provider tells the auth package which model to use and how to sign tokens. It runs one time in each isolate at start. Make this file:

```dart title="lib/providers/auth_provider.dart"
import 'package:blog/app/models/user/user.model.dart';
import 'package:blog/config/env.dart';
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';

/// Auth provider
/// --------------------------
/// Sets up JWT login with the User model.
/// Tokens are signed with APP_KEY and last 7 days.
class AppAuthProvider extends DoxProvider {
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

Dox finds the provider, and the code generator adds it to `lib/generated/container.g.dart`.

## 5. Write the auth controller

This controller has the register, login and "who am I" routes:

```dart title="lib/app/http/controllers/auth.controller.dart"
import 'package:blog/app/dtos/login_user/login_user.dto.dart';
import 'package:blog/app/dtos/register_user/register_user.dto.dart';
import 'package:blog/app/models/user/user.model.dart';
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';

@Inject()
class AuthController {
  /// POST /api/auth/register
  Future<DoxResponse> register(RegisterUser body) async {
    User user = User()
      ..name = body.name
      ..email = body.email
      ..password = await Hash.makeAsync(body.password);
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
```

- `Hash.makeAsync()` makes a bcrypt hash of the password on another isolate. Never save a plain password.
- `attempt()` finds the user by email and checks the password. It gives a token, or null.
- `login(user)` gives a token with no password check. Register uses it for the new user.

## 6. Protect the write routes

Read routes stay public, and write routes need a login. Replace the resource route with single routes, and put the write routes in `Route.middleware`:

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
    Route.get('/ping', (ApiController c) => c.pong);

    // Anyone can read posts.
    Route.get('/posts', (PostController c) => c.index);
    Route.get('/posts/{id}', (PostController c) => c.show);

    // Register and log in.
    Route.post('/auth/register', (AuthController c) => c.register);
    Route.post('/auth/login', (AuthController c) => c.login);

    // Only a logged in user can write posts.
    Route.middleware(<dynamic>[AuthMiddleware()], () {
      Route.get('/auth/user', (AuthController c) => c.user);
      Route.post('/posts', (PostController c) => c.store);
      Route.put('/posts/{id}', (PostController c) => c.update);
    });
  }
}
```

`AuthMiddleware` reads the bearer token in the Authorization header and loads the user. A missing or wrong token gets 401. For a public route that still knows the user, use `AuthMiddleware(optional: true)`.

## 7. Run the generator

`dox s` runs the generator. If the server is off, run it one time:

```bash
dart run build_runner build
```

## Check it

Register a user. You get 201 with a token:

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

Register with the same email again. You get 422:

```json
{"email":"The email has already been taken"}
```

Log in with a wrong password. You get 401:

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

Log in with the right password, and keep the token in a shell variable:

```bash
TOKEN=$(curl -s -X POST http://localhost:3000/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"ann@example.com","password":"secret123"}' \
  | sed -E 's/.*"token":"([^"]+)".*/\1/')
echo $TOKEN
```

Make a post with no token. You get 401:

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

Send the same post with the token:

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

Ask who you are:

```bash
curl http://localhost:3000/api/auth/user \
    -H "Authorization: Bearer $TOKEN"
```

```json
{"id":1,"name":"Ann","email":"ann@example.com","created_at":"2026-10-22T14:01:07.827769Z","updated_at":"2026-10-22T14:01:07.827769Z"}
```

The answer has no password, because it is hidden.

## Next steps

- [Step 6: Test](06-test.md): test the API in code.
