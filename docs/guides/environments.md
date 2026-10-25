---
icon: lucide/toggle-left
---

# Environments

Run the same app in development, staging and production with different config, and keep secrets out of git and out of the image.

## What you need

- A Dox app.
- `build_runner` for the typed env class (a new app has it).

## How Dox reads config

1. A real environment variable (shell, Docker, systemd) wins.
2. Then the `.env` file in the folder where the app starts.

So: use `.env` on your machine. Use real environment variables on a server. The `.env` file is optional there.

## 1. The typed env class

A new project already has `lib/config/env.dart`. Its `AppEnv` class lists every key, its type and its default. In this file of the guides app, `corsOrigin` and `appUrl` are added keys. The rest comes with a new project.

```dart title="lib/config/env.dart"
import 'package:dox_core/dox_core.dart';

part 'env.g.dart';

/// The env of the app, typed. Made by `dox env:generate`.
/// -------------------------------
/// Each getter reads one key: `appName` reads `APP_NAME`.
/// A getter body is the default. A nullable getter is optional.
/// Other getters are required: the app stops at startup when one is missing.
/// Run `dart run build_runner build` after you change this class.
@DoxEnv()
abstract class AppEnv {
  /// reads and checks every key once
  static AppEnv load([EnvReader? reader]) {
    return _$AppEnv.load(reader);
  }

  String get appName => 'dox';

  /// development, staging or production
  String get appEnv => 'development';

  bool get isDevelopment => appEnv == 'development';

  int get appPort => 3000;

  /// required: used to sign tokens and encrypt cookies
  String get appKey;

  /// isolates (threads) of the HTTP server. Null: one per CPU core.
  int? get appTotalIsolate;

  String get logLevel => 'info';

  /// memory, file or redis
  String get cacheStore => 'file';

  /// local, s3 or memory
  String get storageDisk => 'local';

  /// sqlite, postgres or mysql
  String get dbConnection => 'sqlite';

  /// the database name. For SQLite: the file path.
  String get dbName => 'db/dox.sqlite';

  String get dbHost => 'localhost';

  /// null: 5432 for Postgres, 3306 for MySQL
  int? get dbPort;

  String get dbUsername => 'postgres';

  String get dbPassword => '';

  /// the front-end URL that may call the API
  String get corsOrigin => 'http://localhost:5173';

  /// the public URL of this app, used in file links
  String get appUrl => 'http://localhost:3000';
}

/// The env of the app. Read and checked once, on first use.
final AppEnv env = AppEnv.load();
```

The key is the getter name in UPPER_SNAKE case: `dbPort` reads `DB_PORT`.

- A getter with a body has a default: `int get appPort => 3000;`.
- A nullable getter with no body is optional: `int? get dbPort;` is `null` when the key is not set.
- Any other getter with no body is required: `String get appKey;`.

A missing required key stops the app at start, with a list of all problems. The part file `env.g.dart` is made by `build_runner` and is in `.gitignore`.

## 2. Add a key

Say the app needs a mail host. Add one getter to `AppEnv`:

```dart
  /// the SMTP server for mails
  String get mailHost => 'localhost';
```

Then run `build_runner` again:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Now `env.mailHost` reads `MAIL_HOST`. Add `MAIL_HOST` to `.env.example` too.

## 3. Use it in the config files

The config files read the typed getters. A setting that differs per environment becomes one `bool`.

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
      port: env.dbPort ?? 5432,
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

## 4. Write the env files

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

## 5. `APP_KEY`

`APP_KEY` encrypts cookies and signs JWT tokens and local signed URLs.

- Make one per environment with `dox key:generate`. Never share the production key with staging.
- When `APP_ENV=production` and `APP_KEY` is empty, the app does not start.
- A new key makes every cookie, token and signed URL invalid. Every user is logged out. Plan it.

## 6. Check the env before a deploy

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

The app listens on `4000`. `env.appEnv` is `'staging'`, and `env.isDevelopment` is `false`.

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
