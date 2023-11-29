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
        show(DoxRequest req, String id) async {}

        /// GET /resource/{id}/edit
        edit(DoxRequest req, String id) async {}

        /// PUT|PATCH /resource/{id}
        update(DoxRequest req, String id) async {}

        /// DELETE /resource/{id}
        destroy(DoxRequest req, String id) async {}
    }
    ```