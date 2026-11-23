---
icon: lucide/gamepad-2
---

# Controller

A controller holds the code that answers a route, so your route files stay short.

## Writing controllers

### Basic controllers

Make a controller with the CLI. It writes `lib/app/http/controllers/blog.controller.dart` with an empty `index` method:

```bash
dox make:controller Blog
```

Fill in the method:

```dart title="lib/app/http/controllers/blog.controller.dart"
import 'package:dox_core/dox_core.dart';

@Inject()
class BlogController {
  String index(DoxRequest req) {
    return 'all blogs';
  }
}
```

Then point a route to it:

```dart title="lib/routes/api.dart"
Route.get('/blogs', (BlogController c) => c.index);
```

`@Inject()` puts the controller in the container, so its constructor can ask for services. Run `dart run build_runner build` after you add one. See [Dependency injection](dependency-injection.md).

### Static methods

A static method works when the controller needs nothing from the container:

```dart
class AppController {
  static String ping(DoxRequest req) {
    return 'pong';
  }
}

Route.get('/ping', AppController.ping);
```

### Plain functions

A plain function works too:

```dart
String listBlog(DoxRequest req) {
  return 'all blogs';
}

Route.get('/blogs', listBlog);
```

## Resource controllers

A **resource controller** has the 7 methods that `Route.resource` uses. Make one with `-r`:

```bash
dox make:controller Blog -r
```

```dart title="lib/app/http/controllers/blog.controller.dart"
/// Route: Route.resource('path', BlogController);
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

Register it with one route. `Route.resource` skips the methods you delete:

```dart title="lib/routes/api.dart"
Route.resource('blogs', BlogController);
```

See [Routing: resource routes](routing.md#resource-routes).

### API resource controllers

Make a resource controller with no `create` and `edit`, for an API with no form pages:

```bash
dox make:controller Blog --api
```

### Resource controllers for a model

Fill the methods with code for one model:

```bash
dox make:controller Blog --model=Blog
```

```dart title="lib/app/http/controllers/blog.controller.dart"
@Inject()
class BlogController {
  Future<dynamic> index(DoxRequest req) async {
    return Blog().all();
  }

  Future<dynamic> store(DoxRequest req) async {
    return Blog().create(req.body);
  }

  Future<dynamic> show(DoxRequest req, Blog blog) async {
    return blog;
  }

  Future<dynamic> update(DoxRequest req, Blog blog) async {
    await blog.update(req.body);
    return blog;
  }

  Future<dynamic> destroy(DoxRequest req, Blog blog) async {
    await blog.delete();
  }

  // ... create and edit
}
```

[Route model binding](dependency-injection.md#route-model-binding) loads the model by the `{id}`, and no row answers 404. `create()` and `update()` take only the columns in the `fillable` list of the model, so add your columns there first.

You can use `--api` and `--model` together. `dox make:model Blog -r` makes the model and this controller in one step.

## Parameters

A controller method asks for what it needs by type, and Dox fills each parameter:

```dart
Route.put('/teams/{teamId}/users/{id}', (UserController c) => c.update);

@Inject()
class UserController {
  Future<User> update(int teamId, int id, UpdateUser body) async { ... }
}
```

These types work:

| Parameter type | Dox gives |
| --- | --- |
| `DoxRequest` | the request |
| a `@Dto` class | the checked body or query. See [Validation](validation.md). |
| `String`, `int`, `double`, `num`, `bool` | the path params, in the order of the route |
| the same types with `?` | an optional path param (`{id?}`). null when it is not in the URL. |
| a `@DoxModel` class | the model, loaded by the route param. See [route model binding](dependency-injection.md#route-model-binding). |
| an `@Inject()` class | the instance from the [container](dependency-injection.md#handler-parameters) |

The parameters can be in any order. The first path param parameter gets the first `{...}` in the route. These rules apply:

- At most one `@Dto` parameter.
- Only positional parameters.
- A catch-all `{path*}` param is a string.
- The same rules work for static methods and plain functions.

The server does not start when a parameter type is not in the list, or when the method has more path params than the route.

### Path param types

Dox changes the text from the URL into the type. Text that does not fit gets 404:

- `int`: "42" is 42. "abc" or "4.5" gives 404.
- `double`, `num`: "4.5" is 4.5.
- `bool`: true or 1 is true. false or 0 is false. Any other text gives 404.

Dox checks path params before the DTO.

## Next steps

- [Response](response.md): return a string, a map, a model, a file and more.
- [Dependency injection](dependency-injection.md): give services to a controller.
- [Request](request.md): read the input.
