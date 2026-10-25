---
icon: lucide/syringe
---

# Dependency injection

Dox has a container. It makes your classes and gives each constructor what it needs.
You do not register classes by hand.
Put `@Inject()` above a class, and `dox_builder` adds it to the container.
Dox does not use `dart:mirrors`. All the wiring is generated code.

## A full example

A repository reads the database. A service holds the business logic. A controller answers the route.

```dart title="lib/app/repositories/user.repository.dart"
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/models/user/user.model.dart';

@Inject()
class UserRepository {
  Future<User?> find(int id) => User().find(id);
}
```

```dart title="lib/app/services/user.service.dart"
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/models/user/user.model.dart';
import 'package:my_app/app/repositories/user.repository.dart';

@Inject()
class UserService {
  UserService(this.users);

  final UserRepository users;

  Future<User> show(int id) async {
    User? user = await users.find(id);
    if (user == null) throw NotFoundHttpException();
    return user;
  }
}
```

```dart title="lib/app/http/controllers/user.controller.dart"
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/models/user/user.model.dart';
import 'package:my_app/app/services/user.service.dart';

@Inject()
class UserController {
  UserController(this.service);

  final UserService service;

  Future<User> show(int id) => service.show(id);
}
```

```dart title="lib/routes/api.dart"
class ApiRouter extends Router {
  @override
  String get prefix => 'api';

  @override
  void register() {
    Route.get<UserController>('/users/{id}', (UserController c) => c.show);
  }
}
```

Run the builder:

```bash
dart run build_runner build
```

It writes `lib/generated/container.g.dart`. Give it to the app once:

```dart title="lib/config/app.dart"
import 'package:my_app/generated/container.g.dart';

AppConfig appConfig = AppConfig(
  container: registerContainer,
  // ...
);
```

That is all. `GET /api/users/5` makes the repository, the service and the controller, and calls `show(5)`.

## The generated file

`lib/generated/container.g.dart` has one function. Each class gets a factory that calls its constructor.

```dart title="lib/generated/container.g.dart"
// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/http/controllers/user.controller.dart' as i1;
import 'package:my_app/app/repositories/user.repository.dart' as i2;
import 'package:my_app/app/services/user.service.dart' as i3;
import 'package:my_app/routes/api.dart' as i4;
import 'package:my_app/services/orm_service.dart' as i5;
import 'package:my_app/app/models/user/user.model.dart' as i6;

void registerContainer(IocContainer c) {
  c.singleton<i1.UserController>(
    (IocContainer c) => i1.UserController(c.get<i3.UserService>()),
  );
  c.singleton<i2.UserRepository>((IocContainer c) => i2.UserRepository());
  c.singleton<i3.UserService>(
    (IocContainer c) => i3.UserService(c.get<i2.UserRepository>()),
  );
  c.router<i4.ApiRouter>((IocContainer c) => i4.ApiRouter());
  c.service<i5.ORMService>((IocContainer c) => i5.ORMService());
  c.bindModel<i6.User>((String id) {
    int? key = int.tryParse(id);
    if (key == null) return null;
    return i6.User().find(key);
  });
}
```

Do not edit it. Run the builder again after you add a class.

## Lifetime

- `@Inject()`: one instance per isolate. It is made on first use.
- `@Inject(singleton: false)`: a new instance each time it is asked for.

Dox runs one server per isolate. Isolates do not share objects.
So each isolate runs `registerContainer` and has its own instances.
Do not keep state in a singleton that all isolates must see. Use the cache or the database for that.

## Constructor parameters

Each constructor parameter is found by its type.

- Positional and named parameters both work.
- An optional parameter whose type is not in the container keeps its default value.
- A nullable parameter whose type is not in the container gets `null`.
- Any other parameter whose type is not in the container stops the build.

## Routes to controller methods

Give the controller type, then a function that picks the method:

```dart
Route.get<PostController>('/posts', (PostController c) => c.index);
Route.post<PostController>('/posts', (PostController c) => c.store);
Route.put<PostController>('/posts/{id}', (PostController c) => c.update);
Route.delete<PostController>('/posts/{id}', (PostController c) => c.destroy);
```

The controller comes from the container. Dox gets it once per isolate, at start. A request does no extra work.
`.name()`, groups and middleware lists work the same:

```dart
Route.get<PostController>('/posts/{id}', (PostController c) => c.show).name('posts.show');
Route.get<AuthController>('/me', <dynamic>[AuthMiddleware(), (AuthController c) => c.me]);
```

You can leave out `<PostController>`. Dox then finds the controller by the parameter type: `Route.get('/posts', (PostController c) => c.index)`.

For resource routes, pass the class:

```dart
Route.resource('posts', PostController);
```

The method still gets its parameters as usual: `DoxRequest`, a `@Dto`, path params and bound models.
See [Controller: parameters](controller.md#parameters).

## Handler parameters

A controller method (or a plain route function) can ask for any class of the container:

```dart
Route.get('/stats', (StatsService stats) => stats.today());
```

A singleton is read once, at start. A `singleton: false` class is made on each request.

## Route model binding

Every `@DoxModel` class gets a binder in `lib/generated/container.g.dart`.
When a handler has a parameter of a model type, Dox loads the model by its primary key.

```dart
Route.get<PostController>('/posts/{post}', (PostController c) => c.show);

@Inject()
class PostController {
  Post show(Post post) => post;
}
```

- The route param with the name of the model is used: `{post}` for `Post`, `{blogPost}` for `BlogPost`.
- When there is no such param, the next route param in order is used, like `{id}`.
- A missing row answers `404`.
- An `int` key that is not a number answers `404`, with no database call.
- A route without a parameter of the model type does not load the model.
- A binder from `Route.bind` wins over this one. See [Routing: route model binding](routing.md#route-model-binding).

## Routers and services

You do not need `@Inject()` on them.

- Every class that extends `Router` is found. Its routes are registered at start.
- Every class that implements `DoxService` is found. Its `setup()` runs at start, in every isolate.

Their constructors get parameters from the container too.

They run in the order of their file path, then the order in the file.
To pick the order, list them in `AppConfig`:

```dart
AppConfig appConfig = AppConfig(
  container: registerContainer,
  services: <DoxService>[ORMService()], // runs first
  routers: <Router>[ApiRouter()],       // registered first
);
```

A listed class comes first. The others follow. No class runs twice.
A listed service is also the instance that the container gives.

## Use the container in code

`Dox().ioc` is the container of the current isolate.

```dart
UserService users = Dox().ioc.get<UserService>();
```

| Method | What it does |
| --- | --- |
| `get<T>()` | the instance of `T`. Throws when `T` is not registered. |
| `has<T>()` | `true` when `T` is registered |
| `singleton<T>(factory)` | one instance per isolate, made on first use |
| `factory<T>(factory)` | a new instance on each `get` |
| `instance<T>(value)` | `value` is the instance, eg. a config object |
| `override<T>(value)` | replace `T`, eg. with a fake in a test |
| `clearOverrides()` | remove every override |

## Tests

Replace a class with a fake before the app starts:

```dart
setUpAll(() async {
  Dox().ioc.override<UserRepository>(FakeUserRepository());
  client = await DoxTestClient.start(appConfig);
});

tearDownAll(() async {
  await client.close();
  Dox().ioc.clearOverrides();
});
```

An override stays when the app registers its classes again.
Call it before `DoxTestClient.start`. Controllers get their objects once, at start.

## Build errors

The build stops with a clear message when:

- a required parameter has a type that is not in the container,
- classes need each other in a circle. The message shows the chain, like `A -> B -> C -> A`,
- `@Inject()` is on an abstract class or a generic class,
- a class has no unnamed constructor.

## Limits

- Dox finds classes in `lib/` only.
- The container is keyed by the class. It does not map an interface to a class.
- Two classes with the same name in two files both work. But use the typed route style (`Route.get<C>(...)`) for them. They can not be handler parameters, because Dox can not tell them apart by name.
