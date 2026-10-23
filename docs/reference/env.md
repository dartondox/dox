# Environment variables

Every env var the framework and its packages read. How to read your own keys with the typed env class is on the [Environment Variables](../digging-deeper/env.md) page.

The code reads env vars in three ways:

- `Env.get()` and `EnvReader` (`dox_core`): a real environment variable wins over the `.env` file.
- `Platform.environment` straight: only the real environment, `.env` is not read.
- `dox_migration` has its own `loadEnv()`: it reads `.env` and the real environment. A real environment variable wins, the same as `Env.get()`.

## Read by the framework

| Variable | Who reads it | Default | Meaning | Example |
| --- | --- | --- | --- | --- |
| `APP_ENV` | `dox_core` (`Dox().checkAppKey()`, `OpenApiConfig.isEnabled`) | empty | `production` makes a missing `APP_KEY` a startup error. `development` or `local` turn the `/docs` routes on when `openApi.enabled` is `null`. Read with `Env.get`. | `APP_ENV=production` |
| `DOX_SERVER` | `dox_core` (`DoxServer.usesNative()`) | not set (uses `AppConfig.server`) | `dartio`, `dart_io` or `dart:io` forces the `dart:io` server. `native` forces the native server, also for an app with WebSocket routes. Real environment only. | `DOX_SERVER=dartio` |
| `DOX_HTTP_THREAD` | `dox_http_native` (Rust, `shared_thread()`) | not set (one thread per isolate) | `shared` puts the servers of all isolates on one network thread. Off by default: on 2 cores it cut req/s by a quarter. Real environment only. | `DOX_HTTP_THREAD=shared` |
| `DOX_DB_DRIVER` | `dox_orm` (`NativeDrivers.wanted()`) | not set (native driver) | `dart` uses the Dart `postgres` / `mysql_dart` driver instead of the native (Rust) one. Same as `extra: {'native': false}`. Real environment only. | `DOX_DB_DRIVER=dart` |
| `DATABASE_URL` | `dox_orm` (`DatabaseConfig.url`), `dox_migration` | not set | A database url. When it is set, it wins over `DB_CONNECTION` and the other `DB_*` keys. `dox_orm` reads it from the real environment only. See [Database url](../database/index.md#database_url). | `DATABASE_URL=postgres://app:secret@db:5432/blog?sslmode=require` |
| `DB_CONNECTION` | `dox_migration` (`DbConnection.open()`) | postgres | `postgres`, `mysql` or `sqlite`. Any other value means postgres. | `DB_CONNECTION=sqlite` |
| `DB_HOST` | `dox_migration` | `localhost` | Database host. A path that starts with `/` is a Postgres Unix socket folder. | `DB_HOST=127.0.0.1` |
| `DB_PORT` | `dox_migration` | `5432` (postgres), `3306` (mysql) | Database port. | `DB_PORT=5432` |
| `DB_USERNAME` | `dox_migration` | `postgres` (postgres), `root` (mysql) | Database user. | `DB_USERNAME=app` |
| `DB_PASSWORD` | `dox_migration` | `postgres` (postgres), empty (mysql) | Database password. | `DB_PASSWORD=secret` |
| `DB_DATABASE` | `dox_migration` | falls back to `DB_NAME`, then `dox` | Database name. For sqlite: the file path. | `DB_DATABASE=dox` |
| `DB_NAME` | `dox_migration` | `dox` | Same as `DB_DATABASE`. `DB_DATABASE` wins when both are set. | `DB_NAME=dox` |
| `HOME` / `USERPROFILE` | build hooks of `dox_http_native`, `dox_postgres_native`, `dox_mysql_native` | empty | Used to find `~/.cargo/bin/cargo` when the library must be built from source. | set by the OS |
| `DART_VM_OPTIONS` | the Dart VM | not set | Flags for the VM. The AOT binary from `dox build` reads it. Dox never sets VM flags for you. See [Performance](../digging-deeper/performance.md#dart-vm-flags). | `DART_VM_OPTIONS=--new_gen_semi_max_size=64` |

`DOX_SERVER`, `DOX_HTTP_THREAD` and `DOX_DB_DRIVER` are read with `Platform.environment` or `std::env::var`. They do not work from `.env`.

## Read by a new project

A new project (`dox create`) reads these keys through its typed env class, `lib/config/env.dart`. The framework itself does not read them. In code, use the getter: `env.appPort`.

| Variable | Getter | Type | Default | Used for |
| --- | --- | --- | --- | --- |
| `APP_NAME` | `appName` | `String` | `dox` | `LoggerConfig.name`. |
| `APP_ENV` | `appEnv` | `String` | `development` | `development`, `staging` or `production`. `env.isDevelopment` is `true` for `development`. It turns on `prettyPrint` of the logger and the query log of the database. Also read by the framework (see above). |
| `APP_PORT` | `appPort` | `int` | `3000` | `AppConfig.serverPort`. |
| `APP_KEY` | `appKey` | `String` | required | `AppConfig.appKey`. The app stops at start when it is missing. |
| `APP_TOTAL_ISOLATE` | `appTotalIsolate` | `int?` | not set: one per CPU core | `AppConfig.totalIsolate`. |
| `LOG_LEVEL` | `logLevel` | `String` | `info` | `LoggerConfig.level`. |
| `CACHE_STORE` | `cacheStore` | `String` | `file` | `CacheConfig.defaultStore`: `memory`, `file` or `redis`. |
| `STORAGE_DISK` | `storageDisk` | `String` | `local` | `StorageConfig.defaultDisk`: `local`, `s3` or `memory`. |
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
APP_KEY=KKep5qC6uHlAgrwaQTQewgMRSIqQnoj0

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

## Only for work on Dox itself

| Variable | Who reads it | Meaning |
| --- | --- | --- |
| `PG_URL` | Rust tests of `dox_postgres_native` | A Postgres URL. The test is skipped when it is not set. |
| `DB_HOST`, `DB_PORT`, `THREADS` | `packages/dox-postgres-native/tool/stress.dart` | The stress tool. |

## How `.env` is parsed

`Env._loadEnv()` in `packages/dox-core/lib/env/env.dart`:

- One `KEY=value` per line. The key is trimmed.
- The value is everything after the first `=`. A second `=` is kept.
- Every `"`, `'` and `` ` `` character is removed from the value. Then it is trimmed.
- `#` is not special. `KEY=abc # note` gives the value `abc # note`.
- An empty value, or the text `null`, counts as missing.
- The file is read once per isolate, from the current working directory.
