---
icon: lucide/timer
---

# Rate limiting

`RateLimit` is a middleware that stops a client that sends too many requests.

Use it on login, sign up and other routes that bots attack.

## Limiting a route

Add `RateLimit` to the route. The defaults are `max: 60` and `per: Duration(minutes: 1)`:

```dart title="lib/routes/api.dart"
Route.post('/auth/login', <dynamic>[
  RateLimit(max: 5, per: Duration(minutes: 1)),
  (AuthController c) => c.login,
]);
```

Each client ip can now send 5 login requests per minute. The 6th request gets 429:

```text
HTTP/1.1 429 Too Many Requests
Retry-After: 42
X-RateLimit-Limit: 5
X-RateLimit-Remaining: 0

{"code":"too_many_requests","message":"Too Many Requests"}
```

`Retry-After` is the number of seconds until the client can try again. Every answer has the `X-RateLimit-Limit` and `X-RateLimit-Remaining` headers. A blocked request also counts, so a client that keeps sending stays blocked.

## Limiting every route

Put it in `globalMiddleware`:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  globalMiddleware: <dynamic>[
    RateLimit(max: 120),
  ],
  // ...
);
```

## Counting by user

Each ip has its own count. To count by another value, give a `key` function that returns a string, like the user id after `AuthMiddleware`:

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

!!! warning
    Do not count by a raw header, like `req.header('X-Api-Key')`. A client can send a new value each time and get a new count. Count by a value that you checked.

## Two limits with the same settings

Two limits with the same `max` and `per` share one count for a client. To keep the counts separate, give each one a `name`:

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

Behind Caddy, nginx or a load balancer, all clients come from the proxy ip and share one count. Add the proxy to `AppConfig.trustedProxies`, so `req.ip()` is the real client ip. See [App config](../reference/app-config.md).

## IPv6 clients

An IPv6 client often has a full /64 block, so it can send from a new address each time. Turn on `rateLimitIpv6Prefix` to count each IPv6 client by its /64 prefix:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  flags: CoreFlags(rateLimitIpv6Prefix: true),
  // ...
);
```

An IPv4 address stays as it is. Your own `key` function does not change. To use the same rule in it, call `RateLimit.ipBucket(req.ip())`.

## Where the counts live

When the default [cache](../digging-deeper/cache.md) store is Redis, the counts are in Redis, and all servers share them. For Redis options, see [Redis options](../digging-deeper/cache.md#redis-options).

With any other default store, each server keeps its counts in its main isolate. So with 3 servers, a client can send up to 3 times `max`. To use a store by name, give `store`:

```dart
RateLimit(max: 10, store: 'redis')
```

In a test, give a ready store with `cacheStore`.

## Sliding window

By default the count starts at 0 in each window. So a client can send `max` requests at the end of one minute and `max` more at the start of the next. To stop this burst, set `sliding: true`:

```dart
RateLimit(max: 5, per: Duration(minutes: 1), sliding: true)
```

The count is then the count of this window plus a part of the window before. It costs one more read per request.

## Next steps

- [Middleware](../the-basic/middleware.md): add middleware to routes.
- [Security headers](security-headers.md): safe headers on every answer.
- [Production checklist](../reference/production-checklist.md): what to set before you go live.
