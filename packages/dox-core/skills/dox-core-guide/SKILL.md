---
name: dox-core-guide
description: How to build HTTP features in a Dox (Dart backend) app with dox_core. Use it when you add or change routes, routers, controllers, DTOs (request validation), serializers, responses, HTTP errors, middleware, providers, services, typed env config (lib/config/env.dart), dox CLI commands, or HTTP tests with DoxTestClient.
---

# Dox core guide

`dox_core` is the HTTP part of Dox: router, controllers, request input, DTO validation,
serializers, responses, middleware, the container and the typed env.

Full docs: https://dartondox.dev/llms-full.txt. Read them before you guess an API.
Do not invent class or method names. Copy the style of the code that is already in the app.

The examples use the package name `my_app`. Use the `name:` of the app's `pubspec.yaml`.
The examples use a `Post` model. The model and its migration come from the
`dox-orm-guide` and `dox-migration-guide` skills.

## Project layout

| Path | What goes there |
| --- | --- |
| `lib/app/http/controllers/` | Controllers. File `<name>.controller.dart`, class `<Name>Controller`. |
| `lib/app/http/middleware/` | Middleware. File `<name>.middleware.dart`. |
| `lib/app/serializers/` | Serializers (the JSON shape of a response). File `<name>.serializer.dart`. |
| `lib/app/dtos/<name>/` | DTOs (checked input). File `<name>.dto.dart`. |
| `lib/app/services/`, `lib/app/repositories/` | Services and repositories with `@Inject()`, when a controller gets long. |
| `lib/config/` | Config. `app.dart` is the `AppConfig`. `env.dart` is the typed env. |
| `lib/routes/` | Routers. `api.dart` (prefix `api`) and `web.dart` (no prefix). |
| `lib/providers/` | Providers: code that sets up a service in every isolate. |
| `lib/generated/` | Made by build_runner. Never edit. |
| `bin/server.dart` | Starts the server. |
| `test/` | Tests. |

## Make files with the CLI

Use the `dox` CLI to make new files. It puts each file in the right folder with the right name.

```bash
dox make:controller Post          # lib/app/http/controllers/post.controller.dart
dox make:controller Post -r       # resource controller: index, create, store, show, edit, update, destroy
dox make:dto SavePost             # lib/app/dtos/save_post/save_post.dto.dart
dox make:serializer Post          # lib/app/serializers/post.serializer.dart
dox make:middleware ApiKey        # lib/app/http/middleware/api_key.middleware.dart
```

Other commands:

- `dox s`: dev server with hot reload. It also runs build_runner in watch mode.
- `dox build_runner:build`: run the code generator once.
- `dox key:generate`: write a new `APP_KEY` to `.env`.
- `dox env:check`: check `.env` against `lib/config/env.dart`.
- `dox build`: build the native binaries for production.
- `dox help`: list all commands. Newer CLI versions have more commands. Check `dox help` before you use one.

Never use `dart run` or `dox s` in production. Use `dox build`.

## Code generation

Dox does not use reflection. `dox_builder` writes the wiring code.
Run the generator after you add or change any of these:

- a class with `@Inject()` (controllers, services, repositories)
- a `Router` or a `DoxProvider`
- a DTO (`@Dto`)
- `lib/config/env.dart`

```bash
dart run build_runner build
```

`dox s` runs it for you while it runs.
Never edit `*.g.dart` files or anything in `lib/generated/`.

## Routes

A router extends `Router` and adds routes in `register()`.
Dox finds every `Router` class after the generator runs. Do not add routers to a list.

```dart
// lib/routes/api.dart
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/http/controllers/post.controller.dart';

class ApiRouter extends Router {
  @override
  String get prefix => 'api';

  @override
  List<dynamic> get middleware => <dynamic>[];

  @override
  void register() {
    Route.get('/posts', (PostController c) => c.index);       // GET /api/posts
    Route.post('/posts', (PostController c) => c.store);
    Route.get('/posts/{id}', (PostController c) => c.show);
    Route.put('/posts/{id}', (PostController c) => c.update);
    Route.delete('/posts/{id}', (PostController c) => c.destroy);
  }
}
```

More route tools:

```dart
Route.resource('posts', PostController);          // all 7 CRUD routes, names like posts.index
Route.resource('photos', PhotoController, parameter: 'photo'); // {photo} instead of {id}, for Route.bind
Route.group('/admin', () {                       // prefix for every route inside
  Route.get('/stats', (AdminController c) => c.stats);
});
Route.middleware(<dynamic>[ApiKeyMiddleware()], () {  // middleware for every route inside
  Route.post('/posts', (PostController c) => c.store);
});
Route.get('/users/{id}', (UserController c) => c.show).name('users.show');
route('users.show', params: <String, Object>{'id': 5}); // '/users/5'
route('users.show', params: <String, Object>{'id': 5, 'tab': 'a'}); // '/users/5?tab=a'
route('users.show', params: <String, Object>{'id': 5}, absolute: true); // APP_URL + '/users/5'
Route.get('/users/{id}', (UserController c) => c.show).where('id', '[0-9]+');
Route.get('/posts/{page?}', (int? page) => 'page ${page ?? 1}'); // optional param
Route.health('/health');                          // answers 200 {"status": "ok"}
```

- `Route.resource` skips a method that the controller does not have.
- A `route()` param that is not in the path goes to the query string. When `params` and `query` have the same key, `query` wins.
- Do not add the same method and path twice.

## Controllers

Put `@Inject()` above the class. Dox makes it and fills its constructor from the container.
A route points to a method: `(PostController c) => c.index`.

A controller method asks for what it needs by **type**:

| Parameter type | Dox gives |
| --- | --- |
| `DoxRequest` | the request. Add it only when you use it. |
| a `@Dto` class | the checked body (or query for `GET`, `HEAD`, `DELETE`). At most one. |
| `String`, `int`, `double`, `num`, `bool` | the path params, in the order of the route |
| the same types with `?` | an optional path param (`{id?}`) |
| a `@DoxModel` class | the model, loaded by the route param. No row answers `404`. |
| an `@Inject()` class | the instance from the container |

- Only positional parameters. No named or `[optional]` parameters.
- `/posts/abc` answers `404` when the param is `int id`.

Services hold the business logic. The constructor asks for them:

```dart
// lib/app/services/post.service.dart
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/models/post/post.model.dart';

@Inject()
class PostService {
  Future<Post> find(int id) async {
    Post? post = await Post().find(id);
    if (post == null) throw NotFoundHttpException();
    return post;
  }
}
```

```dart
@Inject()
class PostController {
  PostController(this.posts);

  final PostService posts;

  Future<Post> show(int id) => posts.find(id);
}
```

## Request input

Check input with a DTO (next section). For raw, unchecked values, ask for `DoxRequest` and use
`req.input('name')`, `req.all()`, `req.only(...)`, `req.header(...)`, `req.cookie(...)`, `req.file(...)`.
The full list is in `references/request.md` next to this file.

## DTOs (validation)

```bash
dox make:dto SavePost
```

A field that is not nullable is required. A nullable field is optional.
The input key is the field name in snake_case: `firstName` reads `first_name`.

```dart
// lib/app/dtos/save_post/save_post.dto.dart
import 'package:dox_core/dox_core.dart';

part 'save_post.dto.g.dart';

@Dto()
class SavePost {
  @Trim()
  @Length(min: 3, max: 100)
  final String title;

  @Trim()
  @MinLength(10)
  final String body;

  @In(<String>['draft', 'published'])
  final String? status;

  const SavePost({required this.title, required this.body, this.status});

  static const DtoSchema<SavePost> schema = $SavePostDto;
}
```

- Ask for the DTO as a controller parameter. Bad input gets `422`, and the method does not run.
- `await req.validate<SavePost>()` checks inside a method instead.
- An empty string counts as missing. Add `@AllowEmpty()` to keep `""`.
- JSON is strict: `"18"` is not an `int`. `@Dto(coerce: true)` converts text.
- Use `Maybe<T>` for PATCH, to tell "missing" from "null": `body.bio.isPresent`.
- Cross-field checks: add `void validate(DtoErrors errors)` and call `errors.add('field', 'message')`.
- Rule list: `@Email`, `@Url`, `@Uuid`, `@Regex`, `@In`, `@Min`, `@Max`, `@Range`, `@MinItems`,
  `@Confirmed`, `@RequiredIf`, `@Image`, `@MaxSize('5MB')`, `@Mimes`, `@Unique`, `@Exists` and more.
  Every rule is at https://dartondox.dev/latest/the-basic/validation-rules/.
- `lib/config/app.dart` passes `dtos: dtos` (from `lib/generated/dtos.g.dart`). Keep it.

## Serializers

A serializer sets the JSON shape. It works for one value, a `List<T>` or `null`.

```dart
// lib/app/serializers/post.serializer.dart
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/models/post/post.model.dart';

class PostSerializer extends Serializer<Post> {
  PostSerializer(super.data);

  @override
  Map<String, dynamic> convert(Post m) {
    return <String, dynamic>{
      'id': m.id,
      'title': m.title,
      'created_at': m.createdAt?.toIso8601String(),
    };
  }
}
```

A `List<dynamic>` is not a `List<T>`, so it gives `null`. Call `.cast<T>()` first.

## Responses and errors

Return a value from the controller. Dox turns it into the response:
a `String` is text; a `Map`, `List`, model or serializer is JSON; a `File` is streamed.

```dart
return response(PostSerializer(post)).statusCode(201);
return response(<String, String>{'ok': 'yes'}).header('X-Request-Id', 'abc');
return response('ok').cookie(DoxCookie('theme', 'dark'));
return redirect('/login');
```

Throw an HTTP exception to answer with an error:

| Exception | Status |
| --- | --- |
| `BadRequestException()` | 400 |
| `NotFoundHttpException()` | 404 |
| `ValidationException()` | 422 |
| `TooManyRequestsException()` | 429 |
| `InternalErrorException()` | 500 |

`throw NotFoundHttpException(message: 'Post not found');` gives
`404` with `{"code":"not_found","message":"Post not found"}`.
For another status, extend `IHttpException` and set `code`, `errorCode` and `message`.
Any other error gives `500`. The error text is only sent when `APP_ENV` is `development` or `local`.

Errors are JSON by default. For a browser app, set `AppConfig(htmlErrors: true)`.
Then a request that does not want JSON (no JSON `Accept`, not XHR) gets a small HTML page with the status.
In `development` or `local` it also shows the error text and the stack trace.
JSON clients, validation errors and answers from `ExceptionHandler.render` do not change.
To make your own page, set `errorPage: (int status, Object error, StackTrace stack, bool debug) => '...'`. Escape every value.

## Recipe: a new API endpoint

Goal: `POST /api/posts` checks the input, saves a post and answers with JSON.
It needs a `Post` model with `title` and `body` (see `dox-orm-guide`).

1. Make the files: `dox make:controller Post`, `dox make:dto SavePost`, `dox make:serializer Post`.
2. Write the DTO and the serializer as shown above.
3. Write the controller:

```dart
// lib/app/http/controllers/post.controller.dart
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/dtos/save_post/save_post.dto.dart';
import 'package:my_app/app/models/post/post.model.dart';
import 'package:my_app/app/serializers/post.serializer.dart';

@Inject()
class PostController {
  Future<PostSerializer> index(DoxRequest req) async {
    return PostSerializer(await Post().all());
  }

  Future<DoxResponse> store(SavePost input) async {
    Post post = Post()
      ..title = input.title
      ..body = input.body;
    await post.save();
    return response(PostSerializer(post)).statusCode(201);
  }

  Future<PostSerializer> show(int id) async {
    Post? post = await Post().find(id);
    if (post == null) throw NotFoundHttpException();
    return PostSerializer(post);
  }
}
```

4. Add the routes in `lib/routes/api.dart`, inside `register()`. Import the controller at the top.
5. Run `dart run build_runner build`. It adds the controller to the container and makes the DTO code.

## Middleware

```bash
dox make:middleware ApiKey
```

Return `req` to go on. Return a response (or throw) to stop the request.
A middleware that returns `null` ends the request with an empty `200`. Always `return req`.

```dart
// lib/app/http/middleware/api_key.middleware.dart
import 'package:dox_core/dox_core.dart';
import 'package:my_app/config/env.dart';

class ApiKeyMiddleware implements IDoxMiddleware {
  @override
  dynamic handle(IDoxRequest req) {
    String key = env.apiKey ?? '';
    String given = req.header('X-Api-Key') ?? '';
    if (key.isEmpty || !Hash.equals(given, key)) {
      return response(<String, String>{'message': 'Unauthorized'})
          .statusCode(401);
    }
    return req;
  }
}
```

This reads `env.apiKey`. Add `String? get apiKey;` to `AppEnv` first (see "Config and env").

Where to put it:

- One route: `Route.get('/posts', <dynamic>[ApiKeyMiddleware(), (PostController c) => c.index]);`
- A group: `Route.middleware(<dynamic>[ApiKeyMiddleware()], () { ... });`
- All routes of a router: return it from the `middleware` getter of the router.
- All routes of the app: add it to `globalMiddleware` in `lib/config/app.dart`.

To run code after the controller, implement `IDoxNextMiddleware`:

```dart
class TimerMiddleware implements IDoxNextMiddleware {
  @override
  Future<DoxResponse> handle(DoxRequest req, Next next) async {
    Stopwatch watch = Stopwatch()..start();
    DoxResponse res = await next();
    return res.header('X-Time', '${watch.elapsedMilliseconds}ms');
  }
}
```

## Config and env

Read env values from the typed `env` of `lib/config/env.dart`, like `env.appPort`.
Never call `Env.get()` on a hot path, and never put secrets in code.

To add a key:

1. Add a getter to `AppEnv` in `lib/config/env.dart`.
   The key is the getter name in UPPER_SNAKE case: `apiKey` reads `API_KEY`.
2. Add the key to `.env.example` (and to your `.env`).
3. Run `dart run build_runner build`.

```dart
String get appName => 'dox';   // default 'dox'
int get appPort => 3000;       // int, default 3000
String get appKey;             // required: a missing key stops the app at start
String? get apiKey;            // optional: null when missing
Duration get cacheTtl => const Duration(minutes: 5); // CACHE_TTL=5m
List<String> get corsOrigins => <String>[];          // CORS_ORIGINS=a.com,b.com
```

- A real environment variable wins over `.env`.
- In tests, `.env.testing` is read on top of `.env`.
- `APP_KEY` must be 32 characters. Make one with `dox key:generate`.
- `lib/config/app.dart` holds the `AppConfig`: port, isolates, global middleware,
  container, DTOs, cache, CORS and logger.

## Providers

A provider sets up a service in every isolate, because isolates do not share memory.
Code in `bin/server.dart` only runs in the first isolate.
Write a class that extends `DoxProvider` in `lib/providers/`, with `setup()`
(runs at start in every isolate) and an optional `shutdown()`. `lib/providers/orm_provider.dart` is an example.
Dox finds every `DoxProvider` after `dart run build_runner build`. Do not register it by hand.

## Cache

`Cache()` is in `dox_core`. Stores are in `lib/config/cache.dart`.

```dart
await Cache().put('foo', 'bar', duration: Duration(minutes: 10));
dynamic foo = await Cache().get('foo');
```

Values must be JSON types. The `dox-cache-guide` skill has the full API.

## Testing

`DoxTestClient` from `package:dox_core/testing.dart` starts the app inside the test, on a free port.
Run the migrations first when a route uses the database.

```dart
// test/post_test.dart
import 'package:dox_core/testing.dart';
import 'package:dox_migration/dox_migration.dart';
import 'package:my_app/config/app.dart';
import 'package:my_app/config/database.dart';
import 'package:test/test.dart';

import '../db/migration/migrations.dart';

void main() {
  late DoxTestClient client;

  setUpAll(() async {
    await Migrator(
      migrations: migrations,
      config: databaseConfig.getConnectionConfig(),
    ).migrate();
    client = await DoxTestClient.start(appConfig);
  });

  tearDownAll(() async {
    await client.close();
  });

  test('POST /api/posts saves a post', () async {
    TestResponse res = await client.post(
      '/api/posts',
      body: <String, dynamic>{'title': 'Hello', 'body': 'My first post.'},
    );
    res.expectStatus(201).expectJson(containsPair('title', 'Hello'));
  });

  test('POST /api/posts with bad input gives 422', () async {
    TestResponse res = await client.post(
      '/api/posts',
      body: <String, dynamic>{'title': 'Hi'},
    );
    res.expectStatus(422);
  });
}
```

- A `Map` body is sent as JSON.
- `headers: <String, String>{'X-Api-Key': 'key'}` sends headers on one request.
- `client.withToken(token)` sends `Authorization: Bearer <token>` on every request.
- `client.withSession()` keeps cookies and sends the CSRF token, like a browser.
- `res.status`, `res.body`, `res.json`, `res.header('content-type')` read the response.
- `expectStatus`, `expectJson`, `expectBody`, `expectHeader` fail the test and can be chained.
- `dart test` needs a `.env` with `APP_KEY`. Without it: `cp .env.example .env`, then `dox key:generate`.

## Style

The app lints ask for types everywhere (`always_specify_types`).
Write `List<String> names = <String>[];`, not `var names = [];`.
Do not use `dart:mirrors`. Dox builds to native code, which has no mirrors.

## Before you finish

```bash
dart run build_runner build
dart format .
dart analyze
dart test
```

`dart analyze` must show no issues.
