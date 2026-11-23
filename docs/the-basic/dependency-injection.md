---
icon: lucide/syringe
---

# Dependency injection

The Dox container makes your classes and gives each constructor what it needs, so you never wire classes by hand.

Put `@Inject()` above a class, and `dox_builder` adds it to the **container**. Then any class can ask for it in its constructor.

## Setup

The builder writes `lib/generated/container.g.dart`. Give it to the app one time:

```dart title="lib/config/app.dart"
import 'package:my_app/generated/container.g.dart';

AppConfig appConfig = AppConfig(
  container: registerContainer,
);
```

Run the builder again after you add a class:

```bash
dart run build_runner build
```

Do not edit the generated file. Dox finds classes in `lib/` only.

## A full example

A repository reads the database, a service holds the business logic, and a controller answers the route. Each one asks for the one below it:

```dart title="lib/app/repositories/user.repository.dart"
@Inject()
class UserRepository {
  Future<User?> find(int id) => User().find(id);
}
```

```dart title="lib/app/services/user.service.dart"
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
@Inject()
class UserController {
  UserController(this.service);

  final UserService service;

  Future<User> show(int id) => service.show(id);
}
```

```dart title="lib/routes/api.dart"
Route.get('/users/{id}', (UserController c) => c.show);
```

GET /api/users/5 makes the repository, the service and the controller, and calls `show(5)`.

## Lifetime

`@Inject()` makes one instance for each isolate, on first use. For a new instance each time, use `singleton: false`:

```dart
@Inject(singleton: false)
class ReportBuilder {}
```

Isolates do not share objects. Keep state that all isolates must see in the cache or the database.

## Constructor parameters

Dox finds each constructor parameter by its type. Positional and named parameters both work. If the type is not in the container, an optional parameter keeps its default, and a nullable parameter gets null.

### Abstract types

A parameter of an abstract type gets the one container class that implements it:

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

This works for constructor parameters only. `get<Mailer>()` and handler parameters need the class itself.

## Routes to controller methods

Pass a function that picks the method. Dox finds the controller by the parameter type, one time for each isolate at start:

```dart
Route.get('/posts', (PostController c) => c.index);
Route.resource('posts', PostController);
```

See [Controller: parameters](controller.md#parameters).

## Handler parameters

A controller method or a route function can ask for any class of the container:

```dart
Route.get('/stats', (StatsService stats) => stats.today());
```

Dox reads a singleton one time, at start, and makes a `singleton: false` class on each request.

## Route model binding

Every `@DoxModel` class gets a binder. A handler parameter of a model type gets the model, loaded by its primary key:

```dart
Route.get('/posts/{post}', (PostController c) => c.show);

@Inject()
class PostController {
  Post show(Post post) => post;
}
```

Dox uses the route param with the name of the model, like `{post}` for `Post` or `{blogPost}` for `BlogPost`. Else it uses the next route param, like `{id}`. A missing row gives 404.

A binder from `Route.bind` wins. See [Routing: route model binding](routing.md#route-model-binding).

## Routers and providers

Dox finds every class that extends `Router` or `DoxProvider`, with no `@Inject()`. It registers the routes and runs `setup()` of each provider at start, in every isolate. Their constructors also get parameters from the container.

They run in the order of their file path. To pick the order, list them in `AppConfig`. The others follow:

```dart
AppConfig appConfig = AppConfig(
  container: registerContainer,
  providers: <DoxProvider>[ORMProvider()], // runs first
  routers: <Router>[ApiRouter()],          // registered first
);
```

A provider can add global middleware. See [Middleware](middleware.md#global-middleware).

## Using the container in code

`Dox().ioc` is the container of the current isolate. Get a class:

```dart
UserService users = Dox().ioc.get<UserService>();
```

`get` throws when the class is not in the container. Check first with `has`:

```dart
if (Dox().ioc.has<UserService>()) {
  // ...
}
```

### Adding classes by hand

`singleton` makes one instance on first use, `factory` makes a new one on each `get`, and `instance` uses the value you give:

```dart
Dox().ioc.singleton<Clock>((IocContainer c) => Clock());
Dox().ioc.factory<Report>((IocContainer c) => Report());
Dox().ioc.instance<MailConfig>(mailConfig);
```

## Testing

Put a fake in place of a real class with `override`, before the app starts. Remove it with `clearOverrides`:

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

## Build errors

The build stops with the file and line when:

- a required parameter has a type that is not in the container,
- two or more container classes implement the abstract type of a parameter,
- classes need each other in a circle, like `A -> B -> C -> A`,
- `@Inject()` is on an abstract class or a generic class,
- a class has no unnamed constructor.

A private class (like `_AdminRouter`) is not put in the container, and the build shows a warning. Two classes with the same name can not be handler parameters.

## Next steps

- [Controller](controller.md): get services in a controller.
- [Providers](../digging-deeper/providers.md): run code when the app starts.
