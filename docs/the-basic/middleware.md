# Middleware

Middleware serves as a connector between routes and controllers, and its significance lies in bolstering the security, scalability, and adaptability of RESTful services.

## Class based middleware

=== "Create"

    ```bash
    dox create:middleware Logger
    ```

######
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

=== "Route"

    ```dart
    var loggerMiddleware = LoggerMiddleware();
    Route.get('ping', [loggerMiddleware, webController.pong]);
    ```

## Function based middleware

If you prefer not to use class-based middleware, you have the option to create middleware functions and apply them to the route.


######
=== "Middleware"

    ```dart
    authMiddleware(DoxRequest req) {
        /// write your logic here

        /// return DoxRequest back to continue next function (controller)
        return req;
    }
    ```

=== "Route"

    ```dart
    Route.get('ping', [ authMiddleware, webController.pong ]);
    ```

## Route with multi-middleware

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

=== "Route"

    ```dart
    Route.get('ping', [ loggerMiddleware, authMiddleware, webController.pong ]);
    ```

!!! info
    You can also combine class-based and function-based middleware.