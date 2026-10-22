# Environment variables

Every env var the framework and its packages read. How to read your own keys is on the [Environment Variables](../digging-deeper/env.md) page.

Two ways to read exist in the code:

- `Env.get()` and `EnvReader` (`dox_core`): a real environment variable wins over the `.env` file.
- `Platform.environment` straight: only the real environment, `.env` is not read.
- `dox_migration` has its own `loadEnv()`: it reads `.env` when the file exists, else the real environment. See the note below.

## Read by the framework

| Variable | Who reads it | Default | Meaning | Example |
| --- | --- | --- | --- | --- |
| `APP_ENV` | `dox_core` (`Dox().checkAppKey()`, `OpenApiConfig.isEnabled`) | empty | `production` makes a missing `APP_KEY` a startup error. `development` or `local` turn the `/docs` routes on when `openApi.enabled` is `null`. Read with `Env.get`. | `APP_ENV=production` |
| `DOX_SERVER` | `dox_core` (`DoxServer.usesNative()`) | not set (uses `AppConfig.server`) | `dartio`, `dart_io` or `dart:io` forces the `dart:io` server. `native` forces the native server, also for an app with WebSocket routes. Real environment only. | `DOX_SERVER=dartio` |
| `DOX_HTTP_THREAD` | `dox_http_native` (Rust, `shared_thread()`) | not set (one thread per isolate) | `shared` puts the servers of all isolates on one network thread. Off by default: on 2 cores it cut req/s by a quarter. Real environment only. | `DOX_HTTP_THREAD=shared` |
| `DOX_DB_DRIVER` | `dox_orm` (`NativeDrivers.wanted()`) | not set (native driver) | `dart` uses the Dart `postgres` / `mysql_dart` driver instead of the native (Rust) one. Same as `extra: {'native': false}`. Real environment only. | `DOX_DB_DRIVER=dart` |
| `DB_CONNECTION` | `dox_migration` (`DbConnection.open()`) | postgres | `postgres`, `mysql` or `sqlite`. Any other value means postgres. | `DB_CONNECTION=sqlite` |
| `DB_HOST` | `dox_migration` | `localhost` | Database host. | `DB_HOST=127.0.0.1` |
| `DB_PORT` | `dox_migration` | `5432` (postgres), `3306` (mysql) | Database port. | `DB_PORT=5432` |
| `DB_USERNAME` | `dox_migration` | `postgres` (postgres), `root` (mysql) | Database user. | `DB_USERNAME=app` |
| `DB_PASSWORD` | `dox_migration` | `postgres` (postgres), empty (mysql) | Database password. | `DB_PASSWORD=secret` |
| `DB_DATABASE` | `dox_migration` | falls back to `DB_NAME`, then `dox` | Database name. For sqlite: the file path. | `DB_DATABASE=dox` |
| `DB_NAME` | `dox_migration` | `dox` | Same as `DB_DATABASE`. `DB_DATABASE` wins when both are set. | `DB_NAME=dox` |
| `HOME` / `USERPROFILE` | build hooks of `dox_http_native`, `dox_postgres_native`, `dox_mysql_native` | empty | Used to find `~/.cargo/bin/cargo` when the library must be built from source. | set by the OS |
| `DART_VM_OPTIONS` | the Dart VM | not set | Flags for the VM. The AOT binary from `dox build` reads it. Dox never sets VM flags for you. See [Performance](../digging-deeper/performance.md#dart-vm-flags). | `DART_VM_OPTIONS=--new_gen_semi_max_size=64` |

!!! note "Migrations and `.env`"
    `dox_migration` reads `.env` when the file exists, and only then falls back to the real environment.
    So with a `.env` file in the folder, a real `DB_HOST` is ignored. See [Troubleshooting](troubleshooting.md#migrations-read-env-instead-of-the-real-environment).

`DOX_SERVER`, `DOX_HTTP_THREAD` and `DOX_DB_DRIVER` are read with `Platform.environment` or `std::env::var`. They do not work from `.env`.

## Read by a new project

A new project (`dox create`) reads these keys through its typed env class, `lib/config/env.dart`. The framework itself does not read them. You can rename or remove them in that file.

| Variable | Type | Default | Used for |
| --- | --- | --- | --- |
| `APP_NAME` | `String` | `dox` | Logger name, cache prefix, OpenAPI title. |
| `APP_ENV` | `String` | `development` | `prettyPrint` of the logger. Also read by the framework (see above). |
| `APP_KEY` | `String` | empty | `AppConfig.appKey` and the JWT secret of the auth guard. |
| `APP_PORT` | `int` | `3000` | `AppConfig.serverPort`. |
| `APP_TOTAL_ISOLATE` | `int` | number of CPU cores | `AppConfig.totalIsolate`. |
| `APP_URL` | `String` | `http://localhost:3000` | Base of the local storage URLs. |
| `LOG_LEVEL` | `String` | `info` | `LoggerConfig.level`. |
| `CACHE_STORE` | `String` | `file` | `CacheConfig.defaultStore`: `file`, `memory`, `redis` or `null`. |
| `STORAGE_DISK` | `String` | `local` | `StorageConfig.defaultDisk`: `local`, or `s3` when `AWS_BUCKET` is set. |
| `SOCKETIO_ENABLED` | `bool` | `false` | `SocketIoConfig.enabled`. |
| `DB_CONNECTION` | `String` | `postgres` | `DatabaseConfig.connection`: `postgres`, `mysql` or `sqlite`. |
| `DB_HOST` | `String` | `localhost` | Database host. |
| `DB_PORT` | `int?` | driver default | Database port. |
| `DB_USERNAME` | `String?` | driver default | Database user. |
| `DB_PASSWORD` | `String?` | driver default | Database password. |
| `DB_NAME` | `String?` | `dox` (`dox.sqlite` for sqlite) | Database name, or the sqlite file path. |
| `REDIS_HOST` | `String` | `127.0.0.1` | Redis host for cache, Socket.IO and WebSocket adapters. |
| `REDIS_PORT` | `int` | `6379` | Redis port. |
| `REDIS_DB` | `int` | `0` | Redis database number. |
| `REDIS_USERNAME` | `String?` | none | Redis user. |
| `REDIS_PASSWORD` | `String?` | none | Redis password. |
| `AWS_BUCKET` | `String?` | none | When set, the `s3` disk is added. |
| `AWS_DEFAULT_REGION` | `String` | `us-east-1` | S3 region. |
| `AWS_ACCESS_KEY_ID` | `String` | empty | S3 access key. |
| `AWS_SECRET_ACCESS_KEY` | `String` | empty | S3 secret key. |
| `AWS_ENDPOINT` | `String?` | none | S3 endpoint for R2, MinIO, Spaces. |

The `.env.example` of a new project:

```ini title=".env.example"
APP_NAME=dox
APP_ENV=development
APP_PORT=3003
APP_KEY=ZrNbOZJAjC2MDzqehhsGV2DzFFI4pz5R
APP_URL=http://localhost:3003

# file, memory or redis
CACHE_STORE=file
# local, or s3 when AWS_BUCKET is set
STORAGE_DISK=local
# Socket.IO at /socket.io/ on APP_PORT
SOCKETIO_ENABLED=false

DB_CONNECTION=postgres
DB_HOST=localhost
DB_PORT=5432
DB_USERNAME=postgres
DB_PASSWORD=postgres
DB_NAME=postgres

REDIS_HOST=localhost
REDIS_PORT=6379
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
