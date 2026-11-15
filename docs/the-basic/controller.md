---
icon: lucide/gamepad-2
---

# Controller

A controller holds the code that answers a route, so your route files stay short.

You could write all your code in route closures. But when an app grows, it is easier to group the code for one topic, like blogs, in one class. A controller can be a class method, a static method or a plain function.

## Writing controllers

### Basic controllers

Make a controller with the CLI:

```bash
dox make:controller Blog
```

It writes `lib/app/http/controllers/blog.controller.dart` with an empty `index` method. Fill it in:

```dart title="lib/app/http/controllers/blog.controller.dart"
import 'package:dox_core/dox_core.dart';

@Inject()
class BlogController {
  String index(DoxRequest req) {
    return 'all blogs';
  }
}
```

Then point a route to the method:

```dart title="lib/routes/api.dart"
Route.get('/blogs', (BlogController c) => c.index);
```

`@Inject()` puts the controller in the container. Run `dart run build_runner build` after you add one. The constructor can ask for services and repositories. See [Dependency injection](dependency-injection.md).

### Static methods

If a controller needs nothing from the container, a static method also works:

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

Most models need the same routes: list, show, create, update and delete. A resource controller has the 7 methods that `Route.resource` uses, so one line of routes covers all of them.

Make one with `-r`:

```bash
dox make:controller Blog -r
```

```dart title="lib/app/http/controllers/blog.controller.dart"
import 'package:dox_core/dox_core.dart';

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
  /// delete() gives the number of rows it deleted, so 0 is a 404:
  /// `if (await Blog().where('id', id).delete() == 0) throw NotFoundHttpException();`
  Future<dynamic> destroy(DoxRequest req, int id) async {}
}
```

Register it with one route:

```dart title="lib/routes/api.dart"
Route.resource('blogs', BlogController);
```

You can delete the methods you do not need, because `Route.resource` skips them. See [Routing: resource routes](routing.md#resource-routes).

### API resource controllers

An API has no form pages. So `--api` makes the resource controller without `create` and `edit`:

```bash
dox make:controller Blog --api
```

### Resource controllers for a model

If the controller works with one model, use `--model`. It fills the methods with model code:

```bash
dox make:controller Blog --model=Blog
```

```dart title="lib/app/http/controllers/blog.controller.dart"
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/models/blog/blog.model.dart';

/// Route: Route.resource('path', BlogController);
@Inject()
class BlogController {
  /// GET /resource
  Future<dynamic> index(DoxRequest req) async {
    return Blog().all();
  }

  /// GET /resource/create
  Future<dynamic> create(DoxRequest req) async {}

  /// POST /resource
  /// create() takes only the fillable columns of Blog.
  /// Set fillable in the Blog model first. While it is empty, this throws.
  Future<dynamic> store(DoxRequest req) async {
    return Blog().create(req.body);
  }

  /// GET /resource/{id}
  /// Dox loads blog by the {id}. No row answers 404.
  Future<dynamic> show(DoxRequest req, Blog blog) async {
    return blog;
  }

  /// GET /resource/{id}/edit
  Future<dynamic> edit(DoxRequest req, Blog blog) async {
    return blog;
  }

  /// PUT|PATCH /resource/{id}
  /// update() takes only the fillable columns of Blog.
  /// Set fillable in the Blog model first. While it is empty, this throws.
  Future<dynamic> update(DoxRequest req, Blog blog) async {
    await blog.update(req.body);
    return blog;
  }

  /// DELETE /resource/{id}
  Future<dynamic> destroy(DoxRequest req, Blog blog) async {
    await blog.delete();
  }
}
```

`show`, `edit`, `update` and `destroy` take the model. [Route model binding](dependency-injection.md#route-model-binding) loads it by the `{id}`.

`create()` and `update()` take only the columns in the model's `fillable` list, so add your columns there first.

You can use `--api` and `--model` together. And `dox make:model Blog -r` makes the model and this controller in one step.

## Parameters

A controller method asks for what it needs by **type**, and Dox fills each parameter:

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
| the same types with `?` | an optional path param (`{id?}`). `null` when it is not in the URL. |
| a `@DoxModel` class | the model, loaded by the route param. See [route model binding](dependency-injection.md#route-model-binding). |
| an `@Inject()` class | the instance from the [container](dependency-injection.md#handler-parameters) |

You can put the parameters in any order. Path params are matched by position: the first path-param parameter gets the first `{...}` in the route. `DoxRequest` is not needed, so add it only when you use it.

There are a few rules:

- At most one `@Dto` parameter.
- Only positional parameters. Named and `[optional]` parameters are not supported.
- A catch-all `{path*}` param is a `String`.
- The same rules work for static methods and plain functions.

### Path param types

Dox converts the text from the URL to the type you ask for. If the text does not fit the type, the client gets `404 Not Found`:

- `int`: `"42"` is `42`. `"abc"` or `"4.5"` answers `404`.
- `double`, `num`: `"4.5"` is `4.5`.
- `bool`: `true` or `1` is `true`. `false` or `0` is `false`. Any other text answers `404`.

Path params are checked first. When one is wrong, the DTO is not checked.

## Returning a response

Return a `String`, a `Map`, a model, a `File` and more. See [Response](response.md).

## Details

- Dox reads the parameter types once, at start. It does not use `dart:mirrors`.
- The server does not start when a parameter type is not in the list above (did you run `dart run build_runner build`?), or when the method has more path-param parameters than the route has `{...}` params.
