# Middleware

Middleware is code that runs before the controller. Use it for checks like login, logging or rate limits.

## How it works

A middleware gets the request. It then does one of these:

- **Return the request.** Dox goes on to the next middleware, then to the controller.
- **Return something else** (a `String`, a `Map`, a `response(...)`). Dox sends it as the response. The controller does not run.
- **Throw an exception**, like `NotFoundHttpException()`. Dox sends the error response. See [Response: errors](response.md#errors).

A middleware can be `async`. Dox waits for it.

## Class based middleware

Create one with the CLI. It writes `lib/app/http/middleware/logger.middleware.dart`.

```bash
dox create:middleware Logger
```

```dart title="lib/app/http/middleware/logger.middleware.dart"
import 'package:dox_core/dox_core.dart';

class LoggerMiddleware implements IDoxMiddleware { // (1)!
  @override
  dynamic handle(IDoxRequest req) { // (2)!
    print('${req.method} ${req.uri.path}');
    return req; // (3)!
  }
}
```

1.  `IDoxMiddleware` is the interface for a class middleware. Dox calls its `handle` method.
2.  `handle` gets the request. It can be `async`. Dox waits for it.
3.  Return the request to go on to the next middleware, then the controller.
    Return anything else, like `response(...)`, and Dox sends that as the response.

Then put it on a route:

```dart title="lib/routes/api.dart"
Route.get('/ping', <dynamic>[LoggerMiddleware(), webController.pong]);
```

!!! note
    `handle` takes an `IDoxRequest`, not a `DoxRequest`. This is the type that `IDoxMiddleware` asks for.

## Function based middleware

A function that takes a `DoxRequest` also works as middleware.

```dart title="lib/app/http/middleware/api_key.middleware.dart"
import 'package:dox_core/dox_core.dart';

dynamic apiKeyMiddleware(DoxRequest req) {
  if (req.header('X-Api-Key') != 'secret') {
    return response(<String, String>{'message': 'Unauthorized'}).statusCode(401);
  }
  return req;
}
```

```dart title="lib/routes/api.dart"
Route.get('/ping', <dynamic>[apiKeyMiddleware, webController.pong]);
```

## Many middleware on one route

Put them in the list before the controller. They run from left to right.
You can mix class and function middleware.

```dart
Route.get('/ping', <dynamic>[
  LoggerMiddleware(),
  apiKeyMiddleware,
  webController.pong, // the controller is always last
]);
```

## Middleware for a group of routes

```dart
Route.middleware(<dynamic>[LoggerMiddleware()], () {
  Route.get('/me', controller.me);
  Route.post('/logout', controller.logout);
});
```

## Middleware for a router or for all routes

For one router, set its `middleware` list:

```dart title="lib/routes/api.dart"
class ApiRouter extends Router {
  @override
  String get prefix => 'api';

  @override
  List<dynamic> get middleware => <dynamic>[LoggerMiddleware()];

  @override
  void register() {
    // every route here runs LoggerMiddleware
  }
}
```

For all routes, set `globalMiddleware` in the app config:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  globalMiddleware: <dynamic>[LogMiddleware(enabled: true)],
  // ...
);
```

The order is: global middleware, then router middleware, then group middleware, then route middleware.

```mermaid
flowchart LR
    Q["Request"] --> G["Global<br>globalMiddleware"]
    G --> R["Router<br>middleware getter"]
    R --> P["Group<br>Route.middleware"]
    P --> T["Route<br>list before the controller"]
    T --> C["Controller"]
    C --> S["Response"]
    G & R & P & T -.->|"returns a value or throws"| S
```

!!! tip "Built-in middleware"
    - `LogMiddleware` from `dox_core` writes one JSON log line per request. Body fields and headers whose name has `password`, `secret`, `token`, `authorization`, `cookie` or `api_key` in it are logged as `[REDACTED]`. Change the list with `redact:`.
    - `AuthMiddleware` from `dox_auth` checks the JWT token. See [Authentication](../security/authentication.md).
