# Routing

Routes can be found in `lib/routes` folder. And `api.dart` is with prefix `/api`.

## Supported routes

=== "GET"

    ```dart
    Route.get(routeName, controller.method)
    ```


=== "POST"

    ```dart
    Route.post(routeName, controller.method)
    ```

=== "PUT"

    ```dart
    Route.put(routeName, controller.method)
    ```

=== "PATCH"

    ```dart
    Route.patch(routeName, controller.method)
    ```

=== "DELETE"

    ```dart
    Route.delete(routeName, controller.method)
    ```

!!! info
    Other supported routes are `COPY`, `HEAD`, `OPTIONS`, `LINK`, `UNLINK`, `PURGE`, `LOCK`, `UNLOCK` and `VIEW`.

## Param route

=== "Route"

    ```dart
    Route.get('/blog/{id}', info);
    Route.get('/blog/{id}/activate', activate);

    ```

=== "Controller"

    ```dart
    info(DoxRequest req, String id) {
        /// your response here
    }

    activate(DoxRequest req, String id) {
        /// your response here
    }
    ```

## Group Routes

=== "Prefix"

    ```dart
    Route.group(prefix, () {
        Route.get(path, controller.method);
        Route.post(path, controller.method);
    });
    ```

=== "Domain"

    ```dart
    Route.domain('dartondox.com', () {
        Route.get(path, controller.method);
        Route.post(path, controller.method);
    });
    ```

=== "Middleware"

    ```dart
    Route.middleware([CustomMiddleware()], () {
        Route.get(path, controller.method);
        Route.post(path, controller.method);
    });
    ```

=== "Websocket"

    ```dart
    Router.websocket('ws', (socket) {
        socket.on('event', controller.intro);
        socket.on('noti', controller.noti);
    });
    ```

## Resource

```dart
Route.resource('blogs', BlogController());
```

=== "index"

    ```
    GET /blogs
    ```

=== "create"

    ```
    GET /blogs/create
    ```

=== "store"

    ```
    POST /blogs
    ```

=== "show"

    ```
    GET /blogs/{id}
    ```

=== "edit"

    ```
    GET /blogs/{id}/edit
    ```

=== "update"

    ```
    PUT|PATCH /blogs/{id}
    ```
    
=== "destroy"

    ```
    DELETE /blogs/{id}
    ```

!!! info
    `index`, `create`, `store`, `show`, `edit`, `update` and `destroy` are controller methods.
    *Check [here](controller.md/#resource-controller) documentation for generating resource controller.*

## Route with callback

```dart
Route.get('/ping', (DoxRequest req) => 'pong');
```

## Route with controller

=== "Route"

    ```dart
    var webController = WebController();
    Route.get('ping', webController.pong);
    /// or 
    Route.get('ping', [webController.pong]);
    ```

=== "Controller"

    ```dart
    class WebController {
        pong(DoxRequest req) async {
            return 'pong';
        }
    }
    ```

## Class based middleware

=== "Route"

    ```dart
    var loggerMiddleware = LoggerMiddleware();
    Route.get('ping', [loggerMiddleware, webController.pong]);
    ```

=== "Middleware"

    ```dart
    class LoggerMiddleware extends DoxMiddleware {
        @override
        handle(DoxRequest req) {
            /// write your logic here

            /// return DoxRequest back to continue next function (controller)
            return req;
        }
    }
    ```

!!! info
    To implement class-based middleware, you can create a new class that extends the `DoxMiddleware` class. Within this new class, you'll need to define a handle method where you can incorporate your custom logic.


## Function middleware

=== "Route"

    ```dart
    Route.get('ping', [authMiddleware, webController.pong]);
    ```

=== "Function"

    ```dart
    authMiddleware(DoxRequest req) {
        /// write your logic here

        /// return DoxRequest back to continue next function (controller)
        return req;
    }
    ```

!!! info
    To create function-based middleware, you can define a function that takes a DoxRequest parameter.

## Route with multi-middleware

=== "Route"

    ```dart
    Route.get('ping', [ loggerMiddleware, authMiddleware, webController.pong ]);
    ```

=== "Class based middleware"

    ```dart
    class LoggerMiddleware extends DoxMiddleware {
        @override
        handle(DoxRequest req) {
            /// write your logic here

            /// return DoxRequest back to continue next function (controller)
            return req;
        }
    }
    ```

=== "Function middleware"

    ```dart
    authMiddleware(DoxRequest req) {
        /// write your logic here

        /// return DoxRequest back to continue next function (controller)
        return req;
    }
    ```

=== "Controller"

    ```dart
    class WebController {
        pong(DoxRequest req) async {
            return 'pong';
        }
    }
    ```