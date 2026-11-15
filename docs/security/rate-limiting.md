---
icon: lucide/timer
---

# Rate limiting

`RateLimit` is a middleware that stops a client that sends too many requests.

You should use it on login, sign up and other routes that bots like to hammer.

## Limiting a route

Add `RateLimit` to the route. The defaults are `max: 60` and `per: Duration(minutes: 1)`:

```dart title="lib/routes/api.dart"
Route.post('/auth/login', <dynamic>[
  RateLimit(max: 5, per: Duration(minutes: 1)),
  (AuthController c) => c.login,
]);
```

Now each client (by ip) can send 5 login requests per minute. The 6th request gets a `429`:

```text
HTTP/1.1 429 Too Many Requests
Retry-After: 42
X-RateLimit-Limit: 5
X-RateLimit-Remaining: 0

{"code":"too_many_requests","message":"Too Many Requests"}
```

`Retry-After` is the number of seconds until the client can try again. Every answer, also a normal one, has the `X-RateLimit-Limit` and `X-RateLimit-Remaining` headers. The error goes through your exception handler, so it has the same JSON shape as your other errors.

## Limiting every route

To limit all routes, put it in `globalMiddleware`:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  globalMiddleware: <dynamic>[
    RateLimit(max: 120),
  ],
  // ...
);
```

## Counting by user

By default each ip has its own count. Sometimes you want to count per user instead. Give a `key` function, which returns any `String`. For example, count by user id after `AuthMiddleware`:

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

Do not count by a raw header, like `req.header('X-Api-Key')`. A client can send a new value with each request and get a new count each time. Count by a value that you checked first, like the id of the logged in user.

## Two limits with the same settings

Two `RateLimit` with the same `max` and `per` share one count for the same client. If you want separate counts, give each one a `name`:

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

## Behind a proxy

Behind Caddy, nginx or a load balancer, every request comes from the proxy ip, so all clients share one count. Add the proxy to `AppConfig.trustedProxies`, so `req.ip()` is the real client ip. See [App config](../reference/app-config.md).

## Where the counts live

When the default [cache](../digging-deeper/cache.md) store is Redis, the counts are in Redis, so all isolates and all servers share them. Use this when you run more than one server.

With any other default store, the counts are kept in the main isolate of each server. All isolates of one server share them, but each server has its own counts. So with 3 servers, a client can send up to 3 times `max`.

To use a store by name, pass `store`:

```dart
RateLimit(max: 10, store: 'redis')
```

## Sliding window

By default the count starts at 0 at the start of each window. So a client can send `max` requests at the end of one minute, and `max` more at the start of the next. That is fine for most apps.

If you want to stop this burst, set `sliding: true`:

```dart
RateLimit(max: 5, per: Duration(minutes: 1), sliding: true)
```

The count is then the count of this window, plus a part of the window before. That part gets smaller as the window goes on. It costs one more read per request.

## Details

- A blocked request still counts, so a client that keeps sending while it is blocked stays blocked.
- In the main isolate mode, each limited request sends one small message to the main isolate.
- A `memory` store named in `store` also counts in the main isolate. A store passed in `cacheStore` is used as it is.
- Sliding window example: 4 requests last minute, 1 this minute, 15 seconds in: the count is `4 x 45/60 + 1 = 4`. `X-RateLimit-Remaining` is `max` minus this count, rounded up. Each count is kept for 2 windows.

## See also

- [Middleware](../the-basic/middleware.md)
- [Security headers](security-headers.md)
- [Production checklist](../reference/production-checklist.md)
