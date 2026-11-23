---
icon: lucide/blocks
---

# Providers

A provider is a class that sets up one part of your app in every isolate when it starts, like the database, auth or a Redis connection.

Dox runs your app on many [isolates](isolate.md), and they do not share memory. So code in `bin/server.dart` sets up only the first isolate. Each isolate runs every provider itself.

## Setup

Make a provider with the CLI. It writes `lib/providers/cache_provider.dart`:

```bash
dox make:provider Cache
```

Dox finds every class that extends `DoxProvider` after `dart run build_runner build`. You do not register it. Its constructor can ask for other classes of the container. See [Dependency injection](../the-basic/dependency-injection.md#routers-and-providers).

## Setting up a part of the app

Put the code in `setup()`. It runs in each isolate before the routes are registered, and Dox waits for it:

```dart title="lib/providers/orm_provider.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_orm/dox_orm.dart';
import 'package:my_app/config/database.dart';

class ORMProvider extends DoxProvider {
  @override
  Future<void> setup() async {
    SqlQueryBuilder.initializeWithDatabaseConfig(databaseConfig);
  }
}
```

Open connections in `setup()`, not in the constructor. Dox copies a provider to each isolate, and an open socket can not be copied.

A package with no `dox_core` dependency imports `DoxProvider` from `package:dox_annotation/provider.dart`.

## Running code after all providers

`boot()` runs after `setup()` of every provider is done. Use it for work that needs the other providers, like a background worker:

```dart
class ReportProvider extends DoxProvider {
  @override
  void setup() {}

  @override
  Future<void> boot() async {
    // every provider has run setup() here
  }
}
```

The web server and the queue worker (`bin/queue.dart`) run `boot()`. The scheduler (`bin/schedule.dart`) and `dox openapi:generate` run only `setup()`.

## Clean up on shutdown

`shutdown()` runs in every isolate when the server stops, after the open requests are done. See [Graceful shutdown](deployment.md#graceful-shutdown):

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

Dox closes the cache stores by itself. An error in `shutdown()` goes to the [exception handler](../the-basic/errors.md), and the other providers still run.

## Choosing the order

Providers run in the order of their file path. List a provider in `AppConfig` to run it first:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  container: registerContainer,
  providers: <DoxProvider>[ORMProvider()], // runs before the others
);
```

No provider runs twice.

## Adding a provider in code

Call `Dox().addProvider()` or `Dox().addProviders()` before `startServer()`:

```dart title="bin/server.dart"
Dox().initialize(appConfig);
Dox().addProvider(MyProvider());
Dox().addProviders(<DoxProvider>[OtherProvider()]);
await Dox().startServer();
```

## Adding global middleware

A provider can add a global middleware in `setup()`. It runs before the middleware of the app. See [Middleware](../the-basic/middleware.md#global-middleware):

```dart
@override
void setup() {
  Dox().addGlobalMiddleware(AuditMiddleware());
}
```

## Work only in the web server

`Dox().isWebServer` is true only in the web server process. It is false in the queue worker, the scheduler and tests:

```dart
@override
void boot() {
  if (Dox().isWebServer) startMetrics();
}
```

## Example: auth

This provider sets up [authentication](../security/authentication.md). Its name is `AppAuthProvider`, because `dox_auth` already has an `AuthProvider` class:

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

## Next steps

- [Isolate](isolate.md#what-each-isolate-does-at-start): what each isolate does at start.
- [Dependency injection](../the-basic/dependency-injection.md): the container.
- [Package commands](package-commands.md): add CLI commands from a package.
