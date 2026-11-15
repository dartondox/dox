---
icon: lucide/layers
---

# Middleware

Middleware is code that runs before the controller, and if you want, after it too.

Use it for checks like login, logging or rate limits, or to change the response. For example, an auth middleware checks the user. If the user is not logged in, it sends an error, and the controller never runs.

## Defining middleware

Make a middleware with the CLI:

```bash
dox make:middleware Logger
```

It writes `lib/app/http/middleware/logger.middleware.dart`. Write your code in `handle`:

```dart title="lib/app/http/middleware/logger.middleware.dart"
import 'package:dox_core/dox_core.dart';

class LoggerMiddleware implements IDoxMiddleware {
  @override
  dynamic handle(IDoxRequest req) {
    print('${req.method} ${req.uri.path}');
    return req; // go on to the next middleware
  }
}
```

`handle` takes an `IDoxRequest`, not a `DoxRequest`. It can be `async`, and Dox waits for it. A middleware does one of these:

- **Return the request.** Dox goes on to the next middleware, then to the controller.
- **Return something else** (a `String`, a `Map`, a `response(...)`). Dox sends it as the response. The controller does not run.
- **Throw an exception**, like `NotFoundHttpException()`. Dox sends the error response. See [Response: errors](response.md#errors).

!!! warning
    Do not forget `return req`. A middleware that returns `null` ends the request with an empty `200`, and the controller does not run.
    When `APP_ENV` is `development` or `local`, Dox prints a warning the first time a middleware does this.

### Function middleware

A function that takes a `DoxRequest` also works as middleware. This one checks an API key:

```dart title="lib/app/http/middleware/api_key.middleware.dart"
import 'package:dox_core/dox_core.dart';

dynamic apiKeyMiddleware(DoxRequest req) {
  String apiKey = Env.get<String>('API_KEY');
  String given = req.header('X-Api-Key') ?? '';
  if (apiKey.isEmpty || !Hash.equals(given, apiKey)) {
    return response(<String, String>{'message': 'Unauthorized'}).statusCode(401);
  }
  return req;
}
```

The key comes from the `API_KEY` env variable, not from the code. Use `Hash.equals` and not `==` to compare secrets. It takes the same time for every wrong key, so the time does not tell an attacker how much of the key was right.

## Registering middleware

### On a route

Put the middleware in a list before the controller. They run from left to right, and you can mix class and function middleware:

```dart
Route.get('/ping', <dynamic>[
  LoggerMiddleware(),
  apiKeyMiddleware,
  (WebController c) => c.pong, // the controller is always last
]);
```

### On a group of routes

Use `Route.middleware` to run a middleware for many routes:

```dart
Route.middleware(<dynamic>[LoggerMiddleware()], () {
  Route.get('/me', (AuthController c) => c.me);
  Route.post('/logout', (AuthController c) => c.logout);
});
```

### On a router

For all routes of one router, set its `middleware` list:

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

### Global middleware

For all routes, set `globalMiddleware` in the app config:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  globalMiddleware: <dynamic>[
    LogMiddleware(enabled: env.appEnv != 'production'),
  ],
  // ...
);
```

A package can add global middleware from the `setup()` of its provider, with `Dox().addGlobalMiddleware(...)`. It runs before the app's `globalMiddleware`:

```dart
class AuditProvider extends DoxProvider {
  @override
  Future<void> setup() async {
    Dox().addGlobalMiddleware(AuditMiddleware());
  }
}
```

### The order

Middleware runs in this order: package middleware from providers, then the app's global middleware, then router middleware, then group middleware, then route middleware. If one returns a value or throws, the rest do not run:

```mermaid
flowchart LR
    G["Global"] --> R["Router"] --> P["Group"] --> T["Route"] --> C["Controller"]
```

## Run code after the controller

Sometimes you want to change the response after the controller made it. For this, a middleware can get a `next` function. `await next()` runs the rest of the middleware and the controller, and gives you the response. Change it, then return it:

```dart title="lib/app/http/middleware/see_other.middleware.dart"
import 'package:dox_core/dox_core.dart';

/// a redirect after a form post becomes 303, so the browser does a GET
class SeeOtherMiddleware implements IDoxNextMiddleware {
  @override
  Future<DoxResponse> handle(DoxRequest req, Next next) async {
    // before the controller
    DoxResponse res = await next();
    // after the controller
    if (res.status == 302 && req.httpRequest.method != 'GET') {
      res.statusCode(303);
    }
    return res;
  }
}
```

The response from `next()` is always a `DoxResponse`, so you can use all its methods, like `statusCode(...)` and `header(...)`. Read the status with `res.status` (`null` means 200) and the headers with `res.headers`.

If the controller throws an error, `next()` does not throw. It gives the error response from the [ExceptionHandler](errors.md), like a `404` or a `422`. So the code after `next()` always runs. To stop early, return a response and do not call `next()`.

A function works too. It takes the request and `next`:

```dart
Future<DoxResponse> timerMiddleware(DoxRequest req, Next next) async {
  Stopwatch watch = Stopwatch()..start();
  DoxResponse res = await next();
  return res.header('X-Time', '${watch.elapsedMilliseconds}ms');
}
```

## Run code after the answer is sent

Some work should not make the client wait, like logs, metrics or cleanup. A middleware can do it in a `terminate` method, which runs after the answer has gone to the client. Implement `IDoxTerminableMiddleware`:

```dart title="lib/app/http/middleware/metrics.middleware.dart"
import 'package:dox_core/dox_core.dart';

class MetricsMiddleware implements IDoxMiddleware, IDoxTerminableMiddleware {
  @override
  dynamic handle(IDoxRequest req) => req; // before the controller

  @override
  void terminate(DoxRequest req, DoxResponse res) {
    // the answer is already sent
    print('${req.method} ${req.uri.path} ${res.status}');
  }
}
```

`res.status` is the status that was sent, also for an error answer. `terminate` can be `async`. An error in it goes to `ExceptionHandler.report`, and it never changes the answer.

### From any code, with `AfterResponse`

A middleware must be on the route. If you want to add work after the answer from any code (a controller, a service, a package), use `AfterResponse`. The code does not need the request.

It is off by default. Turn it on in the `setup()` of a provider. `setup()` runs in every isolate, so each isolate turns it on:

```dart title="lib/providers/app_provider.dart"
@override
void setup() {
  AfterResponse.enable();
}
```

Then add work anywhere in the request:

```dart
AfterResponse.run(() => mailer.sendWelcome(user));
```

The work runs after the answer is sent, one after the other. An error in it goes to `ExceptionHandler.report`, so it never reaches the client.

The work is not saved anywhere. When the server stops, work that did not run yet is lost. So use a [queue](../digging-deeper/queue.md) for work that must run. To run a queue job this way, see `dispatchAfterResponse()` in [Queue](../digging-deeper/queue.md#dispatching-jobs).

## Built-in middleware

### Request id

When you look for one request in your logs, an id helps. `RequestId` gives each request an id. It is sent back in the `X-Request-Id` header, and you can read it as `req.requestId`:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  globalMiddleware: <dynamic>[
    const RequestId(),
    LogMiddleware(enabled: true),
  ],
  // ...
);
```

Put `RequestId` before `LogMiddleware`, so each log line gets `http.request_id`. The default `ExceptionHandler.report` prints the id with the error. In your own `report`, read `ExceptionHandler.requestId`.

When the client (or a proxy) sends a safe `X-Request-Id`, Dox keeps it. Else it makes a new one. `RequestId(trustClient: false)` always makes a new one.

### ETag and 304 Not Modified

If a client asks for the same data again and nothing changed, you can save bandwidth. `ETag` adds an `ETag` header to GET and HEAD answers. When the client sends the same ETag back in `If-None-Match`, Dox answers `304 Not Modified` with no body:

```dart
Route.get('/posts', <dynamic>[const ETag(), (PostController c) => c.index]);
```

It works on `200` answers with a body in memory: a `String`, a `Map`, a `List` or a model. Files and streams are not touched. The controller still runs, so a `304` saves bandwidth, not server time.

### Request timeout

A slow route should not keep the client waiting forever. `.timeout` answers `503 Service Unavailable` when the middleware after it and the controller take too long:

```dart
Route.get('/report', (ReportController c) => c.show)
    .timeout(Duration(seconds: 30));
```

This is the same as the `RequestTimeout` middleware. For every route, add `RequestTimeout(...)` to `globalMiddleware`:

```dart
Route.get('/report', <dynamic>[
  RequestTimeout(Duration(seconds: 30)),
  (ReportController c) => c.show,
]);
```

The answer is the normal error JSON:

```json
{"code": "request_timeout", "message": "The request took too long"}
```

Dart can not stop a running Future, so the controller keeps running in the background. Its late result is dropped, so nothing is sent twice.

### Server timing

When a page is slow, you want to see where the time goes. `ServerTiming` adds a `Server-Timing` header, and the browser dev tools show it in the Network tab, under Timing:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  globalMiddleware: <dynamic>[
    if (Env.get<String>('APP_ENV') == 'development') const ServerTiming(),
  ],
  // ...
);
```

!!! warning "Development or trusted clients only"
    The header tells every client how long your code takes. An attacker can use that, for example to guess if an email has an account. `ServerTiming` is off unless you add it. Turn it on in development, or only for clients you trust.

It always sends two times, in milliseconds. `handler` is the time in the controller. `total` is the time of the middleware after `ServerTiming` and the controller.

To add your own time to the current request, use `add`. You do not pass the request:

```dart
ServerTiming.add('db', Duration(milliseconds: 4));
```

`measure` runs a function and adds the time it took, also when it throws:

```dart
String html = await ServerTiming.measure('render', () => view.render());
```

The header looks like this:

```
Server-Timing: db;dur=4.10;desc="3 calls", handler;dur=12.34, total;dur=13.02
```

When you `add` the same name again, the times are added together, and the text shows the count, like `"3 calls"`. Pass `description:` to set your own text.

#### Timing database queries

To add the time of every database query, listen to the queries once, in `setup()` of a provider. The listener runs inside the request that made the query, so `add` finds that request:

```dart title="lib/providers/query_timing_provider.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_orm/dox_orm.dart'; // SqlQueryBuilder and QueryEvent

void onQuery(QueryEvent event) {
  ServerTiming.add('db', event.time);
}

/// Dox finds every DoxProvider class,
/// see lib/generated/container.g.dart.
class QueryTimingProvider extends DoxProvider {
  @override
  void setup() {
    SqlQueryBuilder().listen(onQuery);
  }
}
```

The header then shows the total query time and the count, like `db;dur=4.10;desc="3 calls"`. See [Listen to queries](../database/index.md#listen-to-queries).

Each `listen` call adds the listener again. If `setup()` runs a second time (for example in tests), each query is counted twice. Call `SqlQueryBuilder().removeListener(onQuery)` first, or when you are done.

### More middleware

Dox has more middleware on other pages:

- `LogMiddleware` from `dox_core` logs one line per request. See [Details](#logmiddleware) for its options.
- `AuthMiddleware` from `dox_auth` checks the JWT token. `AuthMiddleware(optional: true)` lets guests through too. `GuestMiddleware` lets only guests through, for login pages. See [Authentication](../security/authentication.md).
- `RateLimit` answers `429` when a client sends too many requests. See [Rate limiting](../security/rate-limiting.md).
- `SecurityHeaders` adds safe headers like `X-Frame-Options` to every answer. See [Security headers](../security/security-headers.md).
- `SessionMiddleware` gives each request a session. See [Session](session.md).
- `CsrfMiddleware` stops cross site request forgery. See [CSRF protection](../security/csrf.md).
- `ValidateSignature` checks signed urls. See [Signed URLs](../security/signed-urls.md).
- `MethodOverride` lets HTML forms send `PUT`, `PATCH` and `DELETE`. See [Routing](routing.md#forms-with-put-patch-and-delete).

## Details

This section is for special cases. Most apps do not need it.

### LogMiddleware

- It follows `LoggerConfig`: `enabled`, `level` and `prettyPrint`. If the logger is off, `LogMiddleware(enabled: true)` does not turn logs on. `enabled: false` turns only the request logs off. Leave it unset to follow the logger.
- With `prettyPrint` it prints colored text. Without it, it prints one JSON line with `status`, `message`, `network.client.ip`, `http.method`, `http.url`, `http.request_id` and `payload`.
- The `filter` can change `status`, `message` and the other fields. It can not change `timestamp` or `logger`, because `Logger` sets them.
- Headers are logged only with `withHeader: true`.
- Body fields and headers whose name has a word like `password`, `secret`, `token`, `authorization`, `cookie` or `api_key` in it (upper or lower case) are logged as `[REDACTED]`. Change the list with `redact:`.
- The new project turns it off when `APP_ENV` is `production`.

### Other cases

- A route with no `next` or `terminate` middleware pays nothing extra for these features.
- A class can implement only `IDoxTerminableMiddleware`, with no `handle`.
- `AfterResponse` work runs in the order it was added. The next one starts only when the one before it ends, so work that never ends blocks the rest for that request. Outside a request, or when it is off, the work runs soon, after the current code.
- `Dox().addGlobalMiddleware` skips a second add of the same middleware. The list is cleared at each start, before the providers run, so add it from `setup()`. Use a top-level function or a `const` instance. `dox route:list` does not run providers, so it does not show this middleware.
- A safe `X-Request-Id` is 1 to 128 characters of `A-Z a-z 0-9 . _ -`. A new id is 32 hex characters.
- `ETag` skips an answer that already has an `ETag` header or `Cache-Control: no-store`. The ETag is weak (`W/"..."`), made from a fast 64-bit hash of the body. It is not a secure hash.
- `RequestTimeout` sends `503`, not `504`, because `504 Gateway Timeout` is what a proxy sends. `503` says the app itself gave up.
- `ServerTiming` names may only have letters, digits and ``!#$%&'*+-.^_`|~``. Other characters become `_`, and an empty name is ignored. One answer keeps at most 32 names, plus `handler` and `total`.
- A time you add named `total` or `handler` is sent as `app_total` or `app_handler`, so it does not change the built-in times.
- If the answer already has a `Server-Timing` header, the times are added after it.
- Without `ServerTiming`, or outside a request, `add` and `measure` do nothing. The cost is one small lookup.
