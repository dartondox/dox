# Environments

Run the same app in development, staging and production with different config, and keep secrets out of git and out of the image.

## What you need

- A Dox app.
- `build_runner` for the typed env class.

## How Dox reads config

1. A real environment variable (shell, Docker, systemd) wins.
2. Then the `.env` file in the folder where the app starts.

So: use `.env` on your machine. Use real environment variables on a server. The `.env` file is optional there.

## 1. Write the typed env class

One class lists every key, its type and its default. A missing required key stops the app at start, with a list of all problems.

```dart title="lib/config/env.dart"
import 'dart:io';

import 'package:dox_core/dox_core.dart';

part 'env.g.dart';

enum AppEnvironment { development, staging, production }

@DoxEnv()
abstract class AppEnv {
  static AppEnv load([EnvReader? reader]) {
    return _$AppEnv.load(reader);
  }

  String get appName => 'dox';
  AppEnvironment get appEnv => AppEnvironment.development;
  int get appPort => 3000;
  int get appTotalIsolate => Platform.numberOfProcessors;
  Uri get appUrl => Uri.parse('http://localhost:3000');

  /// required: the app does not start without it
  String get appKey;

  String get dbConnection => 'postgres';
  String get dbHost => 'localhost';
  int get dbPort => 5432;
  String get dbName => 'dox';
  String get dbUsername => 'postgres';
  String get dbPassword => '';

  String get corsOrigin => 'http://localhost:5173';
  String get logLevel => 'info';

  bool get isProduction => appEnv == AppEnvironment.production;
  bool get isDevelopment => appEnv == AppEnvironment.development;
}

/// Read once, on first use. A missing or bad key stops the app.
final AppEnv env = AppEnv.load();
```

```bash
dart run build_runner build --delete-conflicting-outputs
```

The key is the getter name in UPPER_SNAKE case: `dbPort` reads `DB_PORT`. `appEnv` reads `APP_ENV` and must be `development`, `staging` or `production`.

## 2. Use it in the config files

Replace `Env.get(...)` with the typed getters. Things that differ per environment become one `if`.

```dart title="lib/config/logger.dart"
import 'package:dox_core/dox_core.dart';
import 'package:my_app/config/env.dart';

LoggerConfig logger = LoggerConfig(
  name: env.appName,
  enabled: true,
  level: env.logLevel,
  // colors on your machine, one JSON line per log in staging and production
  prettyPrint: env.isDevelopment,
);
```

```dart title="lib/config/database.dart"
import 'package:dox_orm/dox_orm.dart';
import 'package:my_app/config/env.dart';

DatabaseConfig databaseConfig = DatabaseConfig(
  connection: env.dbConnection,
  connections: <String, ConnectionConfig>{
    'postgres': ConnectionConfig(
      driver: Driver.postgres,
      host: env.dbHost,
      port: env.dbPort,
      user: env.dbUsername,
      password: env.dbPassword,
      database: env.dbName,
      // print every query on your machine only
      debug: env.isDevelopment,
    ),
    'sqlite': ConnectionConfig(
      driver: Driver.sqlite,
      database: env.dbName,
      debug: env.isDevelopment,
    ),
  },
);
```

## 3. Write the env files

Commit `.env.example`. It lists every key with a safe value. Never commit `.env`.

```ini title=".env.example"
APP_NAME=my_app
APP_ENV=development
APP_PORT=3000
# run `dox key:generate`
APP_KEY=
APP_URL=http://localhost:3000

DB_CONNECTION=postgres
DB_HOST=localhost
DB_PORT=5432
DB_NAME=my_app
DB_USERNAME=postgres
DB_PASSWORD=postgres

CORS_ORIGIN=http://localhost:5173
LOG_LEVEL=debug
```

```bash
cp .env.example .env
dox key:generate   # writes a new APP_KEY into .env
```

```text title=".gitignore"
.env
.env.*
!.env.example
```

| Environment | Where the values live | `APP_ENV` |
| --- | --- | --- |
| your machine | `.env` | `development` |
| staging | real env variables (compose `environment:`, a secrets manager) | `staging` |
| production | real env variables | `production` |

On a server you can also keep a `.env` next to the binary, outside git, with `chmod 600`. systemd reads it with `EnvironmentFile=`. See [Deployment](../digging-deeper/deployment.md#keep-it-running).

## 4. `APP_KEY`

`APP_KEY` encrypts cookies and signs JWT tokens and local signed URLs.

- Make one per environment with `dox key:generate`. Never share the production key with staging.
- When `APP_ENV=production` and `APP_KEY` is empty, the app does not start.
- A new key makes every cookie, token and signed URL invalid. Every user is logged out. Plan it.

## 5. Check the env before a deploy

`dox env:check` loads `AppEnv` with the real environment and `.env`, and prints every missing or bad key. It exits with code 1, so CI stops.

```bash
dox env:check
```

## Check it

Start with a key missing:

```bash
APP_KEY= dart run bin/server.dart
```

```text
Unhandled exception:
EnvException: the env is not valid
  - APP_KEY is missing
```

Start as staging on another port. The real variables win over `.env`:

```bash
APP_ENV=staging APP_PORT=4000 dart run bin/server.dart
```

The app listens on `4000`. `env.appEnv` is `AppEnvironment.staging`, and `env.isProduction` is `false`.

## Things that differ per environment

| Setting | Development | Staging and production |
| --- | --- | --- |
| `prettyPrint` of the logger | `true` | `false` (one JSON line per log) |
| `debug` of the database | `true` | `false` |
| `totalIsolate` | `1` or `2` is enough | one per core (the default) |
| `CORS_ORIGIN` | `http://localhost:5173` | the real front-end URL |
| the server | `dox serve` (JIT) | the `dox build` binary (AOT) |

## See also

- [Environment variables](../digging-deeper/env.md) for all types and rules of the typed env class
- [Docker](docker.md)
- [Deployment](../digging-deeper/deployment.md)
