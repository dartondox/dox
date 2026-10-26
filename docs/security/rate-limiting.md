---
icon: lucide/timer
---

# Rate limiting

`RateLimit` is a middleware that stops a client that sends too many requests.
Use it on login, sign up and other routes that bots like to hammer.

## Limit a route

```dart title="lib/routes/api.dart"
Route.post('/auth/login', <dynamic>[
  RateLimit(max: 5, per: Duration(minutes: 1)),
  (AuthController c) => c.login,
]);
```

Each client (by ip) can now send 5 login requests per minute. The 6th request gets:

```text
HTTP/1.1 429 Too Many Requests
Retry-After: 42
X-RateLimit-Limit: 5
X-RateLimit-Remaining: 0

{"code":"too_many_requests","message":"Too Many Requests"}
```

- `Retry-After` is the number of seconds until the client can try again.
- Every answer, also a normal one, has `X-RateLimit-Limit` and `X-RateLimit-Remaining`.
- The error goes through your `exceptionHandler` and `responseHandler`, like any other error. So it has the same JSON shape as your other errors.

The defaults are `max: 60` and `per: Duration(minutes: 1)`.

## Limit every route

Put it in `globalMiddleware`:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  globalMiddleware: <dynamic>[
    RateLimit(max: 120),
  ],
  // ...
);
```

## Count by user, not by ip

`key` picks who is counted. The default is `req.ip()`.
The key is any `String`. For example, count by user id after `AuthMiddleware`:

```dart
Route.get('/reports', <dynamic>[
  AuthMiddleware(),
  RateLimit(
    max: 100,
    key: (DoxRequest req) => '${req.auth?.user<User>()?.id ?? req.ip()}',
  ),
  (ReportController c) => c.index,
]);
```

!!! warning "Use a key the client can not choose"
    Do not count by a raw header, like `req.header('X-Api-Key')`.
    A client can send a new value with each request and get a new count each time.
    Count by a value that you checked first, like the id of the logged in user.

!!! warning "Behind a proxy"
    Behind Caddy, nginx or a load balancer, every request comes from the proxy ip.
    Then all clients share one count. Add the proxy to `AppConfig.trustedProxies`, so `req.ip()` is the real client ip.
    See [App config](../reference/app-config.md).

## Two limits on the same key

Two `RateLimit` with the same `max` and `per` share one counter for the same key. Give each one a `name` to keep them apart:

```dart
Route.post('/auth/login', <dynamic>[
  RateLimit(max: 5, name: 'login'),
  (AuthController c) => c.login,
]);
Route.post('/auth/register', <dynamic>[
  RateLimit(max: 5, name: 'register'),
  (AuthController c) => c.register,
]);
```

## Where the counts live

The counts are kept in the [cache](../digging-deeper/cache.md):

- When the default cache store is **Redis**, the counts are in Redis. All isolates and all servers share them. Use this in production.
- Else the counts are in **memory**. Each isolate has its own counts. With 4 isolates a client can send up to 4 x `max` requests.
  This is also true for the default `file` store of a new app.

To use one store by name, pass `store`:

```dart
RateLimit(max: 10, store: 'redis')
```

## How it counts

It is a fixed window. With `per: Duration(minutes: 1)` the count starts at 0 at the start of each minute.
So a client can send `max` requests at the end of one minute and `max` more at the start of the next.
That is fine for most apps. For a hard limit, use a smaller window.

## See also

- [Middleware](../the-basic/middleware.md)
- [Security headers](security-headers.md)
- [Production checklist](../reference/production-checklist.md)
