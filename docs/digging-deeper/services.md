# Services

A service is a class with a `setup()` method. Dox runs it at start, in every isolate. Use it to set up things like the database or auth.

## Why services

Dox runs your app on many isolates (see [Isolate](isolate.md)). Each isolate has its own memory.

So code that you run once in `bin/server.dart` only sets up the first isolate. The other isolates do not see it. For example, they have no database connection.

A service fixes this. Dox sends the list of services to each isolate, and each isolate runs `setup()` itself.

## Create a service

Implement `DoxService` and put your code in `setup()`. `setup()` can be `async`. Dox waits for it.

```dart title="lib/services/orm_service.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_orm/dox_orm.dart';
import 'package:my_app/config/database.dart';

class ORMService implements DoxService, DoxShutdown {
  @override
  Future<void> setup() async {
    SqlQueryBuilder.initializeWithDatabaseConfig(databaseConfig);
  }

  /// Close the database connections when the server stops.
  @override
  Future<void> shutdown() async {
    await SqlQueryBuilder.close();
  }
}
```

## Register it

Add an instance of the service to the list in `lib/config/services.dart`:

```dart title="lib/config/services.dart"
import 'package:dox_core/dox_core.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/orm_service.dart';

List<DoxService> services = <DoxService>[
  ORMService(),
  AuthService(),
];
```

This list goes to `AppConfig(services: services)` in `lib/config/app.dart`.

You can also add a service in code, before `startServer()`:

```dart title="bin/server.dart"
Dox().initialize(appConfig);
Dox().addService(MyService());
await Dox().startServer();
```

## Example: auth

```dart title="lib/services/auth_service.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/models/user/user.model.dart';

class AuthService implements DoxService {
  @override
  void setup() {
    Auth.initialize(AuthConfig(
      defaultGuard: 'web',
      guards: <String, AuthGuard>{
        'web': AuthGuard(
          driver: JwtAuthDriver(secret: SecretKey(env.appKey)),
          provider: AuthProvider(model: () => User()),
        ),
      },
    ));
  }
}
```

See [Authentication](../security/authentication.md).

## When `setup()` runs

In each isolate, Dox does these steps in this order:

1. It runs `setup()` of each service, one after the other, in list order.
2. It registers the routes of your routers.
3. It starts the HTTP server.

So routes can use what a service set up.

`dox openapi:generate` also runs `setup()` of every service, because it needs the routes.

## Clean up on shutdown

On `SIGTERM` or `SIGINT` Dox stops the server gracefully (see [Deployment](deployment.md#graceful-shutdown)).
After the open requests are done, it runs `shutdown()` of each service that also implements `DoxShutdown`.
It runs in every isolate. Use it to close connections or flush data.

The `ORMService` of a new project already does this: its `shutdown()` calls `SqlQueryBuilder.close()`.
Dox closes the cache stores (eg. Redis) by itself, after the services.

```dart title="lib/services/redis_service.dart"
class RedisService implements DoxService, DoxShutdown {
  late RedisConnection redis;

  @override
  Future<void> setup() async {
    redis = await RedisConnection.open();
  }

  @override
  Future<void> shutdown() async {
    await redis.close();
  }
}
```

An error in `shutdown()` goes to `errorHandler`. The other services still run.

## Rules for a service

- **Open connections in `setup()`, not in the constructor.** Dox copies the service object to each isolate. An open socket or database pool can not be copied, so the isolate fails to start.
- **Keep `setup()` short.** It runs once per isolate. Data you load in it is kept once per isolate, so 8 isolates keep 8 copies.
- **Do not depend on another isolate.** Each isolate has its own static values and singletons. To share data between isolates, use a database, Redis or the [cache](cache.md) with the `redis` driver.
