---
icon: lucide/blocks
---

# Providers

A provider is a class that sets up one part of your app when it starts, for example the database, auth or a Redis connection.

Dox runs your app on many [isolates](isolate.md), and they do not share memory. So code that you run once in `bin/server.dart` only sets up the first isolate, and the others have, for example, no database connection. A provider fixes this, because each isolate runs it itself.

## Writing providers

To make a provider, run `dox make:provider`. It writes `lib/providers/cache_provider.dart` with an empty `setup()`:

```bash
dox make:provider Cache
```

See [`dox make:provider`](../reference/cli.md#dox-makeprovider).

### The setup method

A provider extends `DoxProvider`. Put your code in `setup()`. It runs when the app starts, and it can be `async`, because Dox waits for it:

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

Open connections in `setup()`, not in the constructor. A provider listed in `AppConfig` is copied to each isolate. An open socket or database pool can not be copied, so the isolate fails to start.

Keep `setup()` short, because it runs once per isolate. Data you load in it is also kept once per isolate, so 8 isolates keep 8 copies.

A package that does not use `dox_core` imports `DoxProvider` from `package:dox_annotation/provider.dart`.

### The boot method

Sometimes a provider needs other providers to be ready, for example to start a background worker. Use `boot()` for this. It runs after `setup()` of every provider is done:

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

The boots run one by one, in the provider order. `boot()` is optional.

The web server and the queue worker (`bin/queue.dart`) run `boot()`. The scheduler (`bin/schedule.dart`) and `dox openapi:generate` do not. They run only `setup()`.

### Clean up on shutdown

When the app stops, you often want to close connections or flush data. Use `shutdown()` for this. On `SIGTERM` or `SIGINT`, Dox stops the server gracefully (see [Deployment](deployment.md#graceful-shutdown)). After the open requests are done, it runs `shutdown()` of every provider, in every isolate:

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

`shutdown()` is optional. The `ORMProvider` of a new project already closes the database here. Dox closes the cache stores (like Redis) by itself, after the providers.

An error in `shutdown()` goes to the `report` method of the [exception handler](../the-basic/errors.md). The other providers still run.

## Registering providers

You do not need to register a provider. Dox finds every class that extends `DoxProvider`. Run `dart run build_runner build`, and the provider is then in `lib/generated/container.g.dart`.

Each isolate makes its own instance from the container, so its constructor can ask for other classes of the container. See [Dependency injection](../the-basic/dependency-injection.md#routers-and-providers).

### Choosing the order

Providers run in the order of their file path. If one provider must run first, list it in `AppConfig`:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  container: registerContainer,
  providers: <DoxProvider>[ORMProvider()], // runs before the others
);
```

A listed provider runs first, then the others run. No provider runs twice.

### Adding a provider in code

You can also add a provider in `bin/server.dart`, before `startServer()`:

```dart title="bin/server.dart"
Dox().initialize(appConfig);
Dox().addProvider(MyProvider());
await Dox().startServer();
```

## Example: auth

This provider sets up [authentication](../security/authentication.md):

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

The class is named `AppAuthProvider`, because `dox_auth` already has a class named `AuthProvider` (it finds the user model).

## Details

- In each isolate, Dox runs `setup()` of each provider one after the other: the listed ones first, then the ones of the container. Then it registers the routes and starts the server, so routes can use what a provider set up. See [What each isolate does at start](isolate.md#what-each-isolate-does-at-start).
- `dox openapi:generate` also runs `setup()` of every provider, because it needs the routes.
- The queue `inProcess` worker starts in `boot()`, so it does not run in the scheduler process.
