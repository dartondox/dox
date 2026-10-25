# Controller

A controller holds the code that answers a route. It can be a class method, a static method or a plain function.

## Class based controller

Make one with the CLI:

```bash
dox create:controller Blog
```

It writes `lib/app/http/controllers/blog.controller.dart`.

```dart title="lib/app/http/controllers/blog.controller.dart"
import 'package:dox_core/dox_core.dart';

@Inject()
class BlogController {
  String index(DoxRequest req) {
    return 'all blogs';
  }
}
```

```dart title="lib/routes/api.dart"
Route.get<BlogController>('/blogs', (BlogController c) => c.index);
```

`@Inject()` puts the controller in the container. Run `dart run build_runner build` after you add one.
The constructor can ask for services and repositories. See [Dependency injection](dependency-injection.md).

### Static method

```dart
class AppController {
  static String ping(DoxRequest req) {
    return 'pong';
  }
}

Route.get('/ping', AppController.ping);
```

## Function based controller

```dart
String listBlog(DoxRequest req) {
  return 'all blogs';
}

Route.get('/blogs', listBlog);
```

## Resource controller

A resource controller has the 7 methods that `Route.resource` uses.

Make one with the CLI:

```bash
dox create:controller Blog -r
```

```dart title="lib/app/http/controllers/blog.controller.dart"
import 'package:dox_core/dox_core.dart';

@Inject()
class BlogController {
  /// GET /resource
  Future<dynamic> index(DoxRequest req) async {}

  /// GET /resource/create
  Future<dynamic> create(DoxRequest req) async {}

  /// POST /resource
  Future<dynamic> store(DoxRequest req) async {}

  /// GET /resource/{id}
  Future<dynamic> show(DoxRequest req, int id) async {}

  /// GET /resource/{id}/edit
  Future<dynamic> edit(DoxRequest req, int id) async {}

  /// PUT|PATCH /resource/{id}
  Future<dynamic> update(DoxRequest req, int id) async {}

  /// DELETE /resource/{id}
  Future<dynamic> destroy(DoxRequest req, int id) async {}
}
```

```dart title="lib/routes/api.dart"
Route.resource('blogs', BlogController);
```

You can delete methods you do not need. `Route.resource` skips them.
See [Routing: resource routes](routing.md#resource-routes).

## Parameters

A controller asks for what it needs by **type**. Dox fills each parameter.

```dart
Route.put<UserController>('/teams/{teamId}/users/{id}', (UserController c) => c.update);

class UserController {
  Future<User> update(int teamId, int id, UpdateUser body) async { ... }
}
```

| Parameter type | Dox gives |
| --- | --- |
| `DoxRequest` | the request |
| a `@Dto` class | the checked body or query. See [Validation](validation.md). |
| `String`, `int`, `double`, `num`, `bool` | the path params, in the order of the route |
| the same types with `?` | an optional path param (`{id?}`). `null` when it is not in the URL. |
| a `@DoxModel` class | the model, loaded by the route param. See [route model binding](dependency-injection.md#route-model-binding). |
| an `@Inject()` class | the instance from the [container](dependency-injection.md#handler-parameters) |

Rules:

- The order of parameters is free. Path params are matched by position: the first path-param parameter gets the first `{...}` in the route.
- `DoxRequest` is not needed. Add it only when you use it.
- At most one `@Dto` parameter.
- Only positional parameters. Named and `[optional]` parameters are not supported.
- A catch-all `{path*}` param is a `String`.
- The same rules work for static methods and plain functions.
- Dox reads the parameter types once, at start. It does not use `dart:mirrors`.

**Path param types.** Dox converts the text from the URL:

- `int`: `"42"` is `42`. `"abc"` or `"4.5"` answers `404 Not Found`.
- `double`, `num`: `"4.5"` is `4.5`.
- `bool`: `true` or `1` is `true`. `false` or `0` is `false`.
- Any other text answers `404` too.
- Path params are checked first. When one is wrong, the DTO is not checked.

**Checked at start.** The server does not start when:

- a parameter type is not in the list above (did you run `dart run build_runner build`?),
- the method has more path-param parameters than the route has `{...}` params.

## What to return

Return a `String`, a `Map`, a model, a `File` and more. See [Response](response.md).
