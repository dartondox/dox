---
icon: lucide/heart-pulse
---

# Health check

A health route tells a load balancer, Docker or Kubernetes if the app can serve requests.

The load balancer calls the route every few seconds. If the answer is not `200`, it stops sending traffic to this server, or it restarts it.

## Adding the route

Add `Route.health` in `register()` of a router:

```dart title="lib/routes/web.dart"
@override
void register() {
  Route.get('/ping', (WebController c) => c.pong);
  Route.health('/health');
}
```

`GET /health` answers `200` with:

```json
{"status": "ok"}
```

The route gets the middleware of its router and the global middleware. So put `Route.health` in a router with no auth middleware, or the health check gets `401`.

## Checking the database and the cache

The app may run, but its database may be down. To check this, give named checks. Each check is a function:

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

A check fails when it throws an error, returns `false`, or takes longer than the timeout. The checks run at the same time.

`HealthCheck.cache()` writes a key to the default cache store and reads it back. `HealthCheck.cache('redis')` checks the store with that name. Any other check is your own function, like a call to another API.

## Changing the timeout

A check fails after 5 seconds by default. Use `timeout` to change it:

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

The error of a failed check goes to `exceptionHandler.report()`, so you see it in your logs.

The answer has the error text (in `errors`) only when `APP_ENV` is `development` or `local`. In other envs the text is left out, because it can show hosts or user names.

## See also

- [Docker](../guides/docker.md) for a health check in the image
- [Deployment](deployment.md)
