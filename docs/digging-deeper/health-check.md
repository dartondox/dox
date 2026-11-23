---
icon: lucide/heart-pulse
---

# Health check

A health route tells a load balancer, Docker or Kubernetes if the app can serve requests.

## Setup

Add `Route.health` in a router. Use a router with no auth middleware, or the check gets 401:

```dart title="lib/routes/web.dart"
@override
void register() {
  Route.health('/health');
}
```

A GET request to `/health` gets 200 with `{"status": "ok"}`.

## Checking the database and the cache

Give named checks. A check fails when it throws, returns false or takes longer than the timeout:

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

When all checks pass, the answer is 200:

```json
{"status": "ok", "checks": {"database": "ok", "cache": "ok"}}
```

When one check fails, the answer is 503:

```json
{"status": "fail", "checks": {"database": "fail", "cache": "ok"}}
```

`HealthCheck.cache()` writes a key to the default cache store and reads it back. `HealthCheck.cache('redis')` checks the store with that name.

## Changing the timeout

A check fails after 5 seconds by default. Set `timeout` to change it:

```dart
Route.health(
  '/health',
  timeout: Duration(seconds: 2),
  checks: <String, HealthCheckFunction>{
    'database': () => QueryBuilder.query('select 1'),
  },
);
```

## Seeing why a check failed

The error of a failed check goes to `exceptionHandler.report()`, so it is in your logs. The answer shows the error text in `errors` only when `APP_ENV` is `development` or `local`.

## Next steps

- [Docker](../guides/docker.md): a health check in the image.
- [Deployment](deployment.md): run the app on a server.
