---
icon: lucide/layers
---

# Middleware

Middleware is code that runs before the controller, and if you want, after it too.

## Making a middleware

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

`handle` can be async. Return the request to go on. Return any other value to send it as the response, or throw an exception to send an error. Then the controller does not run.

!!! warning
    Do not forget `return req`. A middleware that returns null ends the request with an empty 200.

### Function middleware

A function that takes a `DoxRequest` also works as middleware:

```dart title="lib/app/http/middleware/api_key.middleware.dart"
dynamic apiKeyMiddleware(DoxRequest req) {
  String apiKey = Env.get<String>('API_KEY');
  String given = req.header('X-Api-Key') ?? '';
  if (apiKey.isEmpty || !Hash.equals(given, apiKey)) {
    return response(<String, String>{'message': 'Unauthorized'})
        .statusCode(401);
  }
  return req;
}
```

Compare secrets with `Hash.equals`, not `==`, so the time does not tell an attacker how much of the key was right.

## Registering middleware

### On a route

Put the middleware in a list before the controller. They run from left to right:

```dart
Route.get('/ping', <dynamic>[
  LoggerMiddleware(),
  apiKeyMiddleware,
  (WebController c) => c.pong, // the controller is always last
]);
```

### On a group of routes

Run a middleware for many routes:

```dart
Route.middleware(<dynamic>[LoggerMiddleware()], () {
  Route.get('/me', (AuthController c) => c.me);
  Route.post('/logout', (AuthController c) => c.logout);
});
```

### On a router

Run a middleware for all routes of one router:

```dart title="lib/routes/api.dart"
class ApiRouter extends Router {
  @override
  List<dynamic> get middleware => <dynamic>[LoggerMiddleware()];

  @override
  void register() {
    // every route here runs LoggerMiddleware
  }
}
```

### Global middleware

Run a middleware for all routes:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  globalMiddleware: <dynamic>[
    LogMiddleware(enabled: env.appEnv != 'production'),
  ],
);
```

### Global middleware from a package

A package adds a global middleware in the `setup()` of its provider. It runs before the global middleware of the app:

```dart
class AuditProvider extends DoxProvider {
  @override
  Future<void> setup() async {
    Dox().addGlobalMiddleware(AuditMiddleware());
  }
}
```

A second add of the same middleware is skipped, so use a top-level function or a const instance.

### Skip a middleware on one route

Take every middleware of a type out of one route, also a global one:

```dart
Route.post('/events', (EventController c) => c.stream)
    .withoutMiddleware<RequestTimeout>();
```

It also takes out the subtypes of the type, so use a specific type.

### The order

Middleware runs in this order. If one returns a value or throws, the rest do not run:

<ol class="dox-flow" aria-label="The order of middleware">
  <li><strong>Package</strong><span>from a provider</span></li>
  <li><strong>Global</strong><span>all routes</span></li>
  <li><strong>Router</strong><span>one router</span></li>
  <li><strong>Group</strong><span>a route group</span></li>
  <li><strong>Route</strong><span>one route</span></li>
  <li class="dox-flow__end"><strong>Controller</strong><span>handles the request</span></li>
</ol>

## Run code after the controller

Implement `IDoxNextMiddleware` to change the response. `await next()` runs the rest of the middleware and the controller:

```dart title="lib/app/http/middleware/see_other.middleware.dart"
class SeeOtherMiddleware implements IDoxNextMiddleware {
  @override
  Future<DoxResponse> handle(DoxRequest req, Next next) async {
    DoxResponse res = await next();
    if (res.status == 302 && req.httpRequest.method != 'GET') {
      res.statusCode(303);
    }
    return res;
  }
}
```

If the controller throws, `next()` gives the error response from the [ExceptionHandler](errors.md), so the code after it always runs.

A function works too:

```dart
Future<DoxResponse> timerMiddleware(DoxRequest req, Next next) async {
  Stopwatch watch = Stopwatch()..start();
  DoxResponse res = await next();
  return res.header('X-Time', '${watch.elapsedMilliseconds}ms');
}
```

## Run code after the answer is sent

Implement `IDoxTerminableMiddleware` for work that must not make the client wait, like logs or metrics:

```dart title="lib/app/http/middleware/metrics.middleware.dart"
class MetricsMiddleware
    implements IDoxMiddleware, IDoxTerminableMiddleware {
  @override
  dynamic handle(IDoxRequest req) => req;

  @override
  void terminate(DoxRequest req, DoxResponse res) {
    print('${req.method} ${req.uri.path} ${res.status}');
  }
}
```

An error in `terminate` goes to `ExceptionHandler.report`. It never changes the answer.

### From any code

`AfterResponse` adds work after the answer from a controller, a service or a package. Turn it on in the `setup()` of a provider:

```dart title="lib/providers/app_provider.dart"
@override
void setup() {
  AfterResponse.enable();
}
```

Then add work anywhere in the request. The work runs in the order you add it:

```dart
AfterResponse.run(() => mailer.sendWelcome(user));
```

Work that did not run yet is lost when the server stops. For work that must run, use a [queue](../digging-deeper/queue.md#dispatching-jobs).

`AfterResponse.disable()` turns it off again, for tests. `AfterResponse.enabled` tells if it is on.

## Built-in middleware

### Request id

`RequestId` gives each request an id. It is sent in the `X-Request-Id` header, and you read it as `req.requestId`:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  globalMiddleware: <dynamic>[
    const RequestId(),
    LogMiddleware(),
  ],
);
```

Put it before `LogMiddleware`, so each log line gets the id. Dox keeps a safe id from the client. `RequestId(trustClient: false)` always makes a new one.

To make an id yourself, call `RequestId.make()`. It gives 32 hex characters.

### ETag and 304 Not Modified

`ETag` answers 304 with no body when the client already has the same data:

```dart
Route.get('/posts',
    <dynamic>[const ETag(), (PostController c) => c.index]);
```

It works on 200 answers with a body in memory. The controller still runs, so it saves bandwidth, not server time.

To make a weak ETag yourself, use `ETag.of(bytes)`. `ETag.matches(ifNoneMatch, tag)` tells if the header of the client has the tag.

### Request timeout

Answer 503 when the route takes too long:

```dart
Route.get('/report', (ReportController c) => c.show)
    .timeout(Duration(seconds: 30));
```

For every route, add the `RequestTimeout` middleware to `globalMiddleware`:

```dart
RequestTimeout(Duration(seconds: 30))
```

Dart can not stop a running Future, so the controller keeps running and its late result is dropped. A global timeout also ends long streams. See [Skip a middleware on one route](#skip-a-middleware-on-one-route).

### Server timing

`ServerTiming` adds a `Server-Timing` header. The browser dev tools show it in the Network tab:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  globalMiddleware: <dynamic>[
    if (Env.get<String>('APP_ENV') == 'development') const ServerTiming(),
  ],
);
```

!!! warning "Development or trusted clients only"
    The header tells every client how long your code takes. An attacker can use it, for example to guess if an email has an account.

It sends the time in the controller as `handler` and the full time as `total`. Add your own time to the current request:

```dart
ServerTiming.add('db', Duration(milliseconds: 4));
```

Run a function and add the time it took:

```dart
String html = await ServerTiming.measure('render', () => view.render());
```

The header then looks like this. A name you add again adds up, with a count:

```
Server-Timing: db;dur=4.10;desc="3 calls", handler;dur=12.34, total;dur=13.02
```

#### Timing database queries

Add the time of every query in the `setup()` of a provider:

```dart title="lib/providers/query_timing_provider.dart"
import 'package:dox_orm/dox_orm.dart';

void onQuery(QueryEvent event) {
  ServerTiming.add('db', event.time);
}

class QueryTimingProvider extends DoxProvider {
  @override
  void setup() {
    SqlQueryBuilder().listen(onQuery);
  }
}
```

See [Listen to queries](../database/index.md#listen-to-queries).

### Log requests

`LogMiddleware` logs one line for each request. It follows the logger config. These are its options:

| Option | What it does |
| --- | --- |
| `enabled` | false turns the request logs off. Not set: follow the logger. |
| `withHeader` | true also logs the headers. |
| `redact` | Fields and headers whose name has one of these words are logged as `[REDACTED]`. Default: `LogMiddleware.defaultRedact` (password, secret, token, cookie and more). |
| `filter` | A function that changes the line before it is logged. |

```dart
LogMiddleware(withHeader: true, redact: <String>['password', 'pin'])
```

### More middleware

Other pages have more middleware:

- `AuthMiddleware` and `GuestMiddleware` check the login. See [Authentication](../security/authentication.md).
- `RateLimit` answers 429 for too many requests. See [Rate limiting](../security/rate-limiting.md).
- `SecurityHeaders` adds safe headers. See [Security headers](../security/security-headers.md).
- `SessionMiddleware` gives each request a session. See [Session](session.md).
- `CsrfMiddleware` stops cross site request forgery. See [CSRF protection](../security/csrf.md).
- `ValidateSignature` checks signed URLs. See [Signed URLs](../security/signed-urls.md).
- `MethodOverride` lets HTML forms send PUT, PATCH and DELETE. See [Routing](routing.md#forms-with-put-patch-and-delete).

## Next steps

- [Routing](routing.md): add middleware to routes and groups.
- [Rate limiting](../security/rate-limiting.md): limit the requests of a client.
- [CORS](../security/cors.md): let other origins call your API.
