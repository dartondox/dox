---
icon: lucide/syringe
---

# Dependency injection

The Dox container makes your classes and gives each constructor what it needs, so you never wire classes by hand.

Put `@Inject()` above a class, and `dox_builder` adds it to the container. Then any class can ask for it in its constructor. Dox does not use `dart:mirrors`: all the wiring is generated code.

## Setup

The builder writes `lib/generated/container.g.dart`. Give it to the app once:

```dart title="lib/config/app.dart"
import 'package:my_app/generated/container.g.dart';

AppConfig appConfig = AppConfig(
  container: registerContainer,
  // ...
);
```

Run the builder again after you add a class:

```bash
dart run build_runner build
```

## A full example

A common setup has three layers. A repository reads the database. A service holds the business logic. A controller answers the route. Each one asks for the one below it in its constructor.

The repository needs nothing:

```dart title="lib/app/repositories/user.repository.dart"
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/models/user/user.model.dart';

@Inject()
class UserRepository {
  Future<User?> find(int id) => User().find(id);
}
```

The service asks for the repository:

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

The controller asks for the service:

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

And the route points to the controller:

```dart title="lib/routes/api.dart"
class ApiRouter extends Router {
  @override
  String get prefix => 'api';

  @override
  void register() {
    Route.get('/users/{id}', (UserController c) => c.show);
  }
}
```

That is all. After `dart run build_runner build`, `GET /api/users/5` makes the repository, the service and the controller, and calls `show(5)`.

## Lifetime

By default, `@Inject()` makes one instance per isolate. It is made on first use, and every class that asks for it gets the same one.

If you want a new instance each time it is asked for, use `singleton: false`:

```dart
@Inject(singleton: false)
class ReportBuilder {}
```

Dox runs one server per isolate, and isolates do not share objects. So each isolate has its own instances. Do not keep state in a singleton that all isolates must see. Use the cache or the database for that.

## Constructor parameters

Each constructor parameter is found by its type. Positional and named parameters both work.

If the type is not in the container, an optional parameter keeps its default value, and a nullable parameter gets `null`. Any other parameter stops the build.

### Abstract types

A constructor parameter of an abstract type gets the one container class that implements it:

```dart
abstract class Mailer {}

@Inject()
class SmtpMailer implements Mailer {}

@Inject()
class SignupService {
  SignupService(this.mailer); // gets the SmtpMailer

  final Mailer mailer;
}
```

This works for constructor parameters only. `c.get<Mailer>()` and handler parameters still need the class itself.

## Routes to controller methods

Pass a function that picks the method. Dox finds the controller by the parameter type:

```dart
Route.get('/posts', (PostController c) => c.index);
Route.post('/posts', (PostController c) => c.store);
```

The controller comes from the container. Dox gets it once per isolate, at start, so a request does no extra work. `.name()`, groups and middleware lists work the same:

```dart
Route.get('/posts/{id}', (PostController c) => c.show).name('posts.show');
Route.get('/me', <dynamic>[AuthMiddleware(), (AuthController c) => c.me]);
```

For resource routes, pass the class:

```dart
Route.resource('posts', PostController);
```

The method still gets its parameters as usual: `DoxRequest`, a `@Dto`, path params and bound models. See [Controller: parameters](controller.md#parameters).

## Handler parameters

A controller method (or a plain route function) can ask for any class of the container:

```dart
Route.get('/stats', (StatsService stats) => stats.today());
```

A singleton is read once, at start. A `singleton: false` class is made on each request.

## Route model binding

Often a route gets the id of a model, and the controller loads the model first. Dox can do this for you. Every `@DoxModel` class gets a binder, so when a handler has a parameter of a model type, Dox loads the model by its primary key:

```dart
Route.get('/posts/{post}', (PostController c) => c.show);

@Inject()
class PostController {
  Post show(Post post) => post;
}
```

Dox uses the route param with the name of the model: `{post}` for `Post`, `{blogPost}` for `BlogPost`. When there is no such param, it uses the next route param in order, like `{id}`.

A missing row answers `404`. An `int` key that is not a number also answers `404`, with no database call.

A binder from `Route.bind` wins over this one. See [Routing: route model binding](routing.md#route-model-binding).

## Routers and providers

Routers and providers do not need `@Inject()`. Dox finds every class that extends `Router` and registers its routes at start. It finds every class that extends `DoxProvider` and runs its `setup()` at start, in every isolate. Their constructors get parameters from the container too.

They run in the order of their file path, then the order in the file. If you want to pick the order, list them in `AppConfig`:

```dart
AppConfig appConfig = AppConfig(
  container: registerContainer,
  providers: <DoxProvider>[ORMProvider()], // runs first
  routers: <Router>[ApiRouter()],       // registered first
);
```

A listed class comes first, and the others follow. No class runs twice. A listed provider is also the instance that the container gives.

A provider can add global middleware with `Dox().addGlobalMiddleware(...)` in `setup()`. See [Middleware](middleware.md#global-middleware).

## Using the container in code

Sometimes you need a class in code that the container does not build, like a script. `Dox().ioc` is the container of the current isolate. Use `get` to read a class:

```dart
UserService users = Dox().ioc.get<UserService>();
```

`get` throws when the class is not registered. Use `has` to check first:

```dart
if (Dox().ioc.has<UserService>()) {
  // ...
}
```

You can also add classes by hand. `singleton` makes one instance per isolate, on first use. `factory` makes a new instance on each `get`. `instance` uses the value you give, for example a config object:

```dart
Dox().ioc.singleton<Clock>((IocContainer c) => Clock());
Dox().ioc.factory<Report>((IocContainer c) => Report());
Dox().ioc.instance<MailConfig>(mailConfig);
```

## Testing

In a test you often want a fake in place of a real class. Use `override` before the app starts, and `clearOverrides` at the end:

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

Call `override` before `DoxTestClient.start`, because controllers get their objects once, at start. An override stays when the app registers its classes again.

## Build errors

The build stops with a clear message, with the file and line, when:

- a required parameter has a type that is not in the container,
- a parameter has an abstract type, and two or more classes in the container implement it,
- classes need each other in a circle. The message shows the chain, like `A -> B -> C -> A`,
- `@Inject()` is on an abstract class or a generic class,
- a class has no unnamed constructor.

A private class (like `_AdminRouter`) is not put in the container. The build shows a warning for it. Remove the `_` to add it.

## Details

- Dox finds classes in `lib/` only.
- Two classes with the same name in two files both work. But use the typed route style (`Route.get<C>(...)`) for them. They can not be handler parameters, because Dox can not tell them apart by name.
- A route without a parameter of the model type does not load the model.

### The generated file

`lib/generated/container.g.dart` has one function. Each class gets a factory that calls its constructor. Do not edit it.

```dart title="lib/generated/container.g.dart"
// GENERATED CODE - DO NOT MODIFY BY HAND
// Made by dox_builder. Run `dart run build_runner build`.
// ignore_for_file: type=lint

import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/http/controllers/user.controller.dart' as i1;
import 'package:my_app/app/repositories/user.repository.dart' as i2;
import 'package:my_app/app/services/user.service.dart' as i3;
import 'package:my_app/providers/orm_provider.dart' as i4;
import 'package:my_app/routes/api.dart' as i5;
import 'package:my_app/app/models/user/user.model.dart' as i6;

/// Puts every class of the app into the container: the
/// `@Inject()` classes, routers, providers and model binders.
/// Use it in `AppConfig(container: registerContainer)`.
void registerContainer(IocContainer c) {
  c.singleton<i1.UserController>(
    (IocContainer c) => i1.UserController(c.get<i3.UserService>()),
  );
  c.singleton<i2.UserRepository>((IocContainer c) => i2.UserRepository());
  c.singleton<i3.UserService>(
    (IocContainer c) => i3.UserService(c.get<i2.UserRepository>()),
  );
  c.provider<i4.ORMProvider>((IocContainer c) => i4.ORMProvider());
  c.router<i5.ApiRouter>((IocContainer c) => i5.ApiRouter());
  c.bindModel<i6.User>((String id) {
    int? key = int.tryParse(id);
    if (key == null) return null;
    return i6.User().find(key);
  });
}
```

## See also

- [Controller](controller.md): get services in a controller.
- [Providers](../digging-deeper/providers.md): register services when the app starts.
