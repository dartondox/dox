# Controller

## Class based controller

```bash
dox create:controller Blog
```

=== "Route"

    ```dart
    AppController controller = AppController()
    Route.get('/ping', controller.ping);
    ```

=== "Controller"

    ```dart
    class AppController {
        ping(DoxRequest req) {
            return 'pong';
        }
    }
    ```

!!! info "with static method"
    You can also use as static method in the controller.

=== "Route"

    ```dart
    Route.get('/ping', AppController.ping);
    ```

=== "Controller"

    ```dart
    class AppController {
        static ping(DoxRequest req) {
            return 'pong';
        }
    }
    ```

## Function based controller

=== "Route"

    ```dart
    Route.get('/ping', listBlog);
    ```

=== "Controller"

    ```dart
    listBlog(DoxRequest req) {
        return 'pong';
    }
    ```

## Resource controller

=== "Create"

    ```bash
    dox create:controller Blog -r
    ```
######
=== "Sample"

    ```dart
    import 'package:dox_core/dox_core.dart';

    class BlogController {
        /// GET /resource
        index(DoxRequest req) async {}

        /// GET /resource/create
        create(DoxRequest req) async {}

        /// POST /resource
        store(DoxRequest req) async {}

        /// GET /resource/{id}
        show(DoxRequest req, int id) async {}

        /// GET /resource/{id}/edit
        edit(DoxRequest req, int id) async {}

        /// PUT|PATCH /resource/{id}
        update(DoxRequest req, int id) async {}

        /// DELETE /resource/{id}
        destroy(DoxRequest req, int id) async {}
    }
    ```
## Parameters

A controller asks for what it needs by **type**. Dox fills each parameter.

```dart
Route.put('/teams/{teamId}/users/{id}', controller.update);

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

Rules:

- The order of parameters is free. Path params are matched by position: the first path-param parameter gets the first `{...}` in the route.
- `DoxRequest` is not needed. Add it only when you use it.
- At most one `@Dto` parameter.
- Only positional parameters. Named and `[optional]` parameters are not supported.
- A catch-all `{path*}` param is a `String`.
- The same rules work for static methods and plain functions.

**Path param types.** Text from the URL is converted:

- `int`: `"42"` is `42`. `"abc"` or `"4.5"` answers `404 Not Found`: no such page.
- `double`, `num`: `"4.5"` is `4.5`.
- `bool`: `true`, `1` / `false`, `0`.
- Any other text answers `404` too.
- Path params are checked first. When one is wrong, the DTO is not checked.

**Checked at start.** The server does not start when:

- a parameter type is not in the list above, and not a `@Dto` (did you run `dart run build_runner build`?),
- the method has more path-param parameters than the route has `{...}` params.

!!! info "Why types, not names?"
    Dox reads the parameter types of your method once, when the routes are registered at start. It needs no `dart:mirrors`.
    So `update(int teamId, int id)` works by position, not by the names `teamId` and `id`.
