---
icon: lucide/blocks
---

# Providers

A provider is a class that sets up one part of your app when it starts, for example the database, auth or a Redis connection.

A provider has two methods:

- `setup()` runs when the app starts. You must write it.
- `shutdown()` runs when the app stops. It is optional.

## Why providers

Dox runs your app on many [isolates](isolate.md), and they do not share memory.
Code that you run once in `bin/server.dart` only sets up the first isolate. The others have, for example, no database connection.
A provider fixes this: each isolate runs `setup()` itself.

## Create a provider

Extend `DoxProvider` and put your code in `setup()`. `setup()` can be `async`. Dox waits for it.

```dart title="lib/providers/orm_provider.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_orm/dox_orm.dart';
import 'package:my_app/config/database.dart';

class ORMProvider extends DoxProvider {
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

You do not need to. Dox finds every class that extends `DoxProvider`.
Run `dart run build_runner build`. The provider is then in `lib/generated/container.g.dart`.
Each isolate makes its own instance from the container. Its constructor can ask for other classes of the container.
See [Dependency injection](../the-basic/dependency-injection.md#routers-and-providers).

Providers run in the order of their file path. To run one first, list it in `AppConfig`:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  container: registerContainer,
  providers: <DoxProvider>[ORMProvider()], // runs before the others
);
```

A listed provider runs first. Then the others run. No provider runs twice.

You can also add a provider in code, before `startServer()`:

```dart title="bin/server.dart"
Dox().initialize(appConfig);
Dox().addProvider(MyProvider());
await Dox().startServer();
```

## Example: auth

```dart title="lib/providers/auth_provider.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/models/user/user.model.dart';
import 'package:my_app/config/env.dart';

class AppAuthProvider extends DoxProvider {
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

The name is `AppAuthProvider`, because `dox_auth` already has a class named `AuthProvider` (it finds the user model).
See [Authentication](../security/authentication.md).

## When `setup()` runs

In each isolate, Dox runs `setup()` of each provider, one after the other: the listed ones first, then the ones of the container.
Then it registers the routes and starts the server, so routes can use what a provider set up.
See [What each isolate does at start](isolate.md#what-each-isolate-does-at-start).

`dox openapi:generate` also runs `setup()` of every provider, because it needs the routes.

## Clean up on shutdown

On `SIGTERM` or `SIGINT` Dox stops the server gracefully (see [Deployment](deployment.md#graceful-shutdown)).
After the open requests are done, it runs `shutdown()` of every provider.
It runs in every isolate. Use it to close connections or flush data.
A provider that has nothing to close does not need to write `shutdown()`.

The `ORMProvider` of a new project already does this: its `shutdown()` calls `SqlQueryBuilder.close()`.
Dox closes the cache stores (eg. Redis) by itself, after the providers.

```dart title="lib/providers/redis_provider.dart"
class RedisProvider extends DoxProvider {
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

An error in `shutdown()` goes to the `report` method of the [exception handler](../the-basic/errors.md). The other providers still run.

## Rules for a provider

- **Open connections in `setup()`, not in the constructor.** A provider listed in `AppConfig` is copied to each isolate. An open socket or database pool can not be copied, so the isolate fails to start.
- **Keep `setup()` short.** It runs once per isolate. Data you load in it is kept once per isolate, so 8 isolates keep 8 copies.
