# Health check

A health route tells a load balancer, Docker or Kubernetes if the app can serve requests.

## Add the route

```dart title="lib/routes/web.dart"
Route.health('/health');
```

`GET /health` answers `200` with:

```json
{"status": "ok"}
```

## Check the database and the cache

Give named checks. Each check is a function:

```dart title="lib/routes/web.dart"
import 'package:dox_orm/dox_orm.dart';

Route.health(
  '/health',
  checks: <String, HealthCheckFunction>{
    'database': () => QueryBuilder.query('select 1'),
    'cache': HealthCheck.cache(),
  },
);
```

When all checks pass, the answer is `200`:

```json
{"status": "ok", "checks": {"database": "ok", "cache": "ok"}}
```

When one check fails, the answer is `503 Service Unavailable`:

```json
{"status": "fail", "checks": {"database": "fail", "cache": "ok"}}
```

A check fails when it:

- throws an error,
- returns `false`,
- or takes longer than `timeout` (default 5 seconds).

The checks run at the same time.

- `HealthCheck.cache()` writes a key to the default cache store and reads it back. `HealthCheck.cache('redis')` checks the store with that name.
- Any other check is your own function, like a call to another API.

## Error details

The error of a failed check is passed to `exceptionHandler.report()`, so you see it in your logs.

The answer has the error text (in `errors`) only when `APP_ENV` is `development` or `local`.
In other envs the text is left out, because it can show hosts or user names.

## Change the timeout

```dart
Route.health(
  '/health',
  timeout: Duration(seconds: 2),
  checks: <String, HealthCheckFunction>{
    'database': () => QueryBuilder.query('select 1'),
  },
);
```

!!! tip
    A route in a router gets the middleware of that router and the global middleware.
    Put `Route.health` in a router with no auth middleware, or the health check gets `401`.

## See also

- [Docker](../guides/docker.md) for a health check in the image
- [Deployment](deployment.md)
