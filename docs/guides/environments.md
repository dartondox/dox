---
icon: lucide/toggle-left
---

# Environments

Run the same app in development, staging and production with different config, and keep secrets out of git and out of the image.

Each place needs other values, like another database or front-end URL. Dox reads them from the environment, not from the code.

## What you need

- A Dox app.
- `build_runner` for the typed env class (a new app has it).

## How Dox reads config

Dox looks for each key in two places:

1. A real environment variable (from the shell, Docker or systemd). This one wins.
2. The `.env` file in the folder where the app starts.

So use a `.env` file on your machine, and real environment variables on a server.

## 1. The typed env class

The `AppEnv` class in `lib/config/env.dart` lists every key, with its type and its default. This guides app adds `corsOrigin` and `appUrl`:

```dart title="lib/config/env.dart"
import 'package:dox_core/dox_core.dart';

part 'env.g.dart';

/// The env of the app, typed. Made by `dox env:generate`.
/// -------------------------------
/// Each getter reads one key: `appName` reads `APP_NAME`.
/// A getter body is the default. A nullable getter is optional.
/// Other getters are required: the app stops at startup when one is
/// missing.
/// Run `dart run build_runner build` after you change this class.
@DoxEnv()
abstract class AppEnv {
  /// reads and checks every key once
  static AppEnv load([EnvReader? reader]) {
    return _$AppEnv.load(reader);
  }

  String get appName => 'dox';

  /// development, staging or production. Not set: production.
  String get appEnv => 'production';

  int get appPort => 3000;

  /// required: used to sign tokens and encrypt cookies
  String get appKey;

  /// isolates (threads) of the HTTP server.
  /// Null: one per CPU the process may use.
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

Each getter reads its name in upper snake case, so `dbPort` reads `DB_PORT`:

- A getter with a body has a default: `int get appPort => 3000;`.
- A nullable getter with no body is optional: `int? get dbPort;` is null when the key is not set.
- Any other getter with no body is required: `String get appKey;`.

If a required key is missing, the app stops at start and lists all the problems.

## 2. Add a key

For a new value, add a getter to `AppEnv`, like this mail host:

```dart
  /// the SMTP server for mails
  String get mailHost => 'localhost';
```

Then run `build_runner` again:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Now `env.mailHost` reads `MAIL_HOST`. Add the key to `.env.example` too.

## 3. Use it in the config files

The config files read the typed getters. For a setting that changes per environment, use `APP_ENV`, like `prettyPrint` and `debug` here. Development is an `APP_ENV` of development, local, test or testing. Any other value is production:

```dart title="lib/config/logger.dart"
import 'package:dox_core/dox_core.dart';
import 'package:my_app/config/env.dart';

LoggerConfig logger = LoggerConfig(
  name: env.appName,
  enabled: true,
  level: env.logLevel,
  // colors on your machine, one JSON line per log in staging and
  // production.
  // Env.appEnv, not appConfig.isDevelopment: appConfig is built from
  // this logger, so reading appConfig here would loop.
  prettyPrint: Env.appEnv == 'development',
);
```

The database prints every query in development only:

```dart title="lib/config/database.dart"
import 'package:dox_orm/dox_orm.dart';
import 'package:my_app/config/app.dart';
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
      debug: appConfig.isDevelopment,
    ),
    'sqlite': ConnectionConfig(
      driver: Driver.sqlite,
      database: env.dbName,
      debug: appConfig.isDevelopment,
    ),
  },
);
```

## 4. Write the env files

Commit `.env.example` with every key and a safe value. Never commit `.env`, because it holds your real secrets:

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

To start on a new machine, copy the example and make a key:

```bash
cp .env.example .env
dox key:generate   # writes a new APP_KEY into .env
```

Keep every `.env` file out of git, except the example:

```text title=".gitignore"
.env
.env.*
!.env.example
```

The values live in a different place in each environment:

| Environment | Where the values live | `APP_ENV` |
| --- | --- | --- |
| your machine | `.env` | development |
| staging | real env variables (compose `environment:`, a secrets manager) | staging |
| production | real env variables | production |

On a server you can also keep a `.env` file next to the binary, with `chmod 600`. See [Deployment](../digging-deeper/deployment.md#keep-it-running).

## 5. `APP_KEY`

`APP_KEY` is your most important secret. It encrypts cookies and signs JWT tokens and local signed URLs.

- Make one key per environment with `dox key:generate`. Never share the production key with staging.
- The key must be exactly 32 characters.
- In production a bad key stops the app at start. A bad key is empty, not 32 characters, or a public sample key.
- A new key stops every cookie, token and signed URL, so every user is logged out.

## 6. Check the env before a deploy

`dox env:check` prints every missing or bad key. On a problem it exits with code 1, so CI stops:

```bash
dox env:check
```

## Check it

Start the app with a key missing:

```bash
APP_KEY= dart run bin/server.dart
```

```text
Unhandled exception:
EnvException: the env is not valid
  - APP_KEY is missing
```

Now start it as staging on another port. The real variables win over `.env`:

```bash
APP_ENV=staging APP_PORT=4000 dart run bin/server.dart
```

The app listens on port 4000. `env.appEnv` is staging, and `appConfig.isDevelopment` is false.

## Things that differ per environment

Most apps change these settings between environments:

| Setting | Development | Staging and production |
| --- | --- | --- |
| `prettyPrint` of the logger | true | false (one JSON line per log) |
| `debug` of the database | true | false |
| `totalIsolate` | 1 or 2 is enough | one per core (the default) |
| `CORS_ORIGIN` | `http://localhost:5173` | the real front-end URL |
| the server | `dox serve` (JIT) | the `dox build` binary (AOT) |

## Next steps

- [Environment variables](../digging-deeper/env.md): all the types and rules of the env class.
- [Docker](docker.md): set the env in a container.
- [Deployment](../digging-deeper/deployment.md): run the app on a server.
