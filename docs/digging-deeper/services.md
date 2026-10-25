---
icon: lucide/blocks
---

# Services

A service is a class with a `setup()` method. Dox runs it at start, in every isolate.

Use it to set up things like the database or auth.

## Why services

Dox runs your app on many [isolates](isolate.md), and they do not share memory.
Code that you run once in `bin/server.dart` only sets up the first isolate. The others have, for example, no database connection.
A service fixes this: each isolate runs `setup()` itself.

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

You do not need to. Dox finds every class that implements `DoxService`.
Run `dart run build_runner build`. The service is then in `lib/generated/container.g.dart`.
Each isolate makes its own instance from the container. Its constructor can ask for other classes of the container.
See [Dependency injection](../the-basic/dependency-injection.md#routers-and-services).

Services run in the order of their file path. To run one first, list it in `AppConfig`:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  container: registerContainer,
  services: <DoxService>[ORMService()], // runs before the others
);
```

A listed service runs first. Then the others run. No service runs twice.

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

In each isolate, Dox runs `setup()` of each service, one after the other: the listed ones first, then the ones of the container.
Then it registers the routes and starts the server, so routes can use what a service set up.
See [What each isolate does at start](isolate.md#what-each-isolate-does-at-start).

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

An error in `shutdown()` goes to the `report` method of the [exception handler](../the-basic/errors.md). The other services still run.

## Rules for a service

- **Open connections in `setup()`, not in the constructor.** A service listed in `AppConfig` is copied to each isolate. An open socket or database pool can not be copied, so the isolate fails to start.
- **Keep `setup()` short.** It runs once per isolate. Data you load in it is kept once per isolate, so 8 isolates keep 8 copies.
