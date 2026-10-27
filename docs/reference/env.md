---
icon: lucide/file-key
---

# Environment variables

Every env var the framework and its packages read.

How to read your own keys with the typed env class is on the [Environment Variables](../digging-deeper/env.md) page.

The code reads env vars in three ways:

- `Env.get()` and `EnvReader` (`dox_core`): a real environment variable wins over the `.env` file.
- `Platform.environment` straight: only the real environment, `.env` is not read.
- `dox_migration` has its own `loadEnv()`: it reads `.env` and the real environment. A real environment variable wins, the same as `Env.get()`.

## Read by the framework

If `APP_ENV` is not set or empty, Dox treats the app as production: `/docs` is off and error details are hidden. Set `APP_ENV=development` in your `.env` and in CI.

| Variable | Who reads it | Default | Meaning | Example |
| --- | --- | --- | --- | --- |
| `APP_ENV` | `dox_core`, `dox_auth`, `dox_view` | empty | Any value except `development`, `local`, `test` or `testing` (also empty) makes a bad `APP_KEY` a startup error: missing, not exactly 32 characters, or a public sample key. The same rule applies to a JWT secret shorter than 32 bytes (`dox_auth`). In `development`, `local`, `test` and `testing` both are only a warning. `development` or `local` also: show error details in `500` responses and in health check answers, turn the `/docs` routes on when `openApi.enabled` is `null`, and turn the template cache of `dox_view` off. `testing` as a real environment variable also loads `.env.testing` (see below). Read with `Env.get`. | `APP_ENV=production` |
| `PORT` | `dox_core` (`DoxServer.portFor()`) | not set | The port to listen on, when `APP_PORT` is not set. Cloud Run, Fly, Render and Heroku set it. `APP_PORT` wins when both are set. Read with `Env.get`. | `PORT=8080` |
| `APP_HOST` | `dox_core` (`DoxServer.hostFor()`) | not set (all interfaces, `::`) | The host to listen on. `127.0.0.1` keeps the app off the network, for an app behind a proxy on the same machine. `AppConfig.host` wins over it. Read with `Env.get`. | `APP_HOST=127.0.0.1` |
| `DATABASE_URL` | `dox_orm` (`DatabaseConfig.url`), `dox_migration` | not set | A database url. When it is set, it wins over `DB_CONNECTION` and the other `DB_*` keys. `dox_orm` reads it from the real environment only. See [Database url](../database/index.md#database_url). | `DATABASE_URL=postgres://app:secret@db:5432/blog?sslmode=require` |
| `DB_CONNECTION` | `dox_migration` (`DbConnection.config()`) | postgres | `postgres`, `mysql` or `sqlite`. Any other value means postgres. | `DB_CONNECTION=sqlite` |
| `DB_HOST` | `dox_migration` | `localhost` | Database host. A path that starts with `/` is a Unix socket: the folder for Postgres, the socket file for MySQL. | `DB_HOST=127.0.0.1` |
| `DB_PORT` | `dox_migration` | `5432` (postgres), `3306` (mysql) | Database port. | `DB_PORT=5432` |
| `DB_USERNAME` | `dox_migration` | `postgres` (postgres), `root` (mysql) | Database user. | `DB_USERNAME=app` |
| `DB_PASSWORD` | `dox_migration` | `postgres` (postgres), empty (mysql) | Database password. | `DB_PASSWORD=secret` |
| `DB_DATABASE` | `dox_migration` | falls back to `DB_NAME`, then `dox` | Database name. For sqlite: the file path. | `DB_DATABASE=dox` |
| `DB_NAME` | `dox_migration` | `dox` | Same as `DB_DATABASE`. `DB_DATABASE` wins when both are set. | `DB_NAME=dox` |
| `HOME` / `USERPROFILE` | build hooks of `dox_http_native`, `dox_postgres_native`, `dox_mysql_native` | empty | Used to find `~/.cargo/bin/cargo` when the library must be built from source. | set by the OS |
| `DART_VM_OPTIONS` | the Dart VM | not set | Flags for the VM. The AOT binary from `dox build` reads it. Dox never sets VM flags for you. See [Performance](../digging-deeper/performance.md#dart-vm-flags). | `DART_VM_OPTIONS=--new_gen_semi_max_size=64` |

## Read by a new project

A new project (`dox create`) reads these keys through its typed env class, `lib/config/env.dart`. The framework itself does not read them. In code, use the getter: `env.appPort`.

| Variable | Getter | Type | Default | Used for |
| --- | --- | --- | --- | --- |
| `APP_NAME` | `appName` | `String` | `dox` | `LoggerConfig.name`. |
| `APP_ENV` | `appEnv` | `String` | `production` | `development`, `staging` or `production`. `env.isDevelopment` is `true` for `development`. It turns on `prettyPrint` of the logger and the query log of the database. Any value except `production` turns on `LogMiddleware` (one log line per request). Also read by the framework (see above). |
| `APP_PORT` | `appPort` | `int` | `3000` | `AppConfig.serverPort`. When `APP_PORT` is not set, Dox listens on `PORT` if the env has it. |
| `APP_KEY` | `appKey` | `String` | required | `AppConfig.appKey`. It must be exactly 32 characters. Run `dox key:generate` for one. The app stops at start when it is missing, has another length, or is a public sample key (only a warning in `development`, `local`, `test` and `testing`). |
| `APP_TOTAL_ISOLATE` | `appTotalIsolate` | `int?` | not set: one per CPU core | `AppConfig.totalIsolate`. |
| `LOG_LEVEL` | `logLevel` | `String` | `info` | `LoggerConfig.level`. |
| `CACHE_STORE` | `cacheStore` | `String` | `file` | `CacheConfig.defaultStore`. A new project has the stores `file` and `memory` in `lib/config/cache.dart`. Add a `redis` store there before you use it. |
| `STORAGE_DISK` | `storageDisk` | `String` | `local` | `StorageConfig.defaultDisk`. A new project has the disk `local` in `lib/config/storage.dart`. Add an `s3` or `memory` disk there before you use it. |
| `DB_CONNECTION` | `dbConnection` | `String` | `sqlite` | `DatabaseConfig.connection`: `sqlite`, `postgres` or `mysql`. |
| `DB_NAME` | `dbName` | `String` | `db/dox.sqlite` | The database name. For SQLite: the file path. |
| `DB_HOST` | `dbHost` | `String` | `localhost` | Database host. |
| `DB_PORT` | `dbPort` | `int?` | not set: `5432` for Postgres, `3306` for MySQL | Database port. |
| `DB_USERNAME` | `dbUsername` | `String` | `postgres` | Database user. |
| `DB_PASSWORD` | `dbPassword` | `String` | empty | Database password. |

To add a key, add a getter to `AppEnv` and run `dart run build_runner build`. See [Environments](../guides/environments.md#2-add-a-key).

The `.env.example` of a new project:

```ini title=".env.example"
APP_NAME=dox
APP_ENV=development
APP_PORT=3000
APP_KEY=

CACHE_STORE=file
STORAGE_DISK=local

# SQLite needs no setup. The file is created at the first start.
DB_CONNECTION=sqlite
DB_NAME=db/dox.sqlite

# Postgres or MySQL: set DB_CONNECTION=postgres or mysql and fill these in.
DB_HOST=localhost
DB_PORT=5432
DB_USERNAME=postgres
DB_PASSWORD=postgres
```

## How `.env` is parsed

`Env.parse()` in `packages/dox-core/lib/env/env.dart`:

- One `KEY=value` per line. The key is trimmed. A line that starts with `#` is a comment.
- The value is everything after the first `=`. A second `=` is kept.
- `#` after a space starts a comment: `KEY=abc # note` gives `abc`. `KEY=abc#def` stays `abc#def`.
- A value in quotes (`"`, `'` or `` ` ``) is kept as it is, also a `#`. The quotes are removed.
- An empty value, or the text `null`, counts as missing.
- The file is read once per isolate, from the current working directory.
- In tests (`dart test`, or `APP_ENV=testing` as a real environment variable), Dox also reads `.env.testing` next to `.env`. Its keys win over the keys of `.env`. A real environment variable still wins over both.

`dox_migration` has its own simpler parser. It removes every quote character and does not strip `# note` comments. It does not read `.env.testing`. Keep comments on their own line.
