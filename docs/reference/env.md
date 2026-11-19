---
icon: lucide/file-key
---

# Environment variables

This page lists every env var that Dox and its packages read.

To read your own keys with the typed env class, see [Environment Variables](../digging-deeper/env.md).

## Read by the framework

`APP_ENV` changes how strict Dox is, so set it first:

- `development` or `local`: Dox shows error details in `500` answers and health checks, turns `/docs` on (when `openApi.enabled` is `null`), and turns the `dox_view` template cache off.
- `development`, `local`, `test` or `testing`: a bad `APP_KEY` or a JWT secret under 32 bytes is only a warning.
- Any other value, or no value: Dox treats the app as production. A bad key stops the app at start, `/docs` is off and error details are hidden.

So set `APP_ENV=development` in your local `.env` and in CI.

| Variable | Who reads it | Default | Meaning | Example |
| --- | --- | --- | --- | --- |
| `APP_ENV` | `dox_core`, `dox_auth`, `dox_view` | empty | See the list above. A bad `APP_KEY` is one that is missing, not exactly 32 characters, or a public sample key. `testing` as a real env var also loads `.env.testing`. | `APP_ENV=production` |
| `APP_NAME` | `dox_core` (`Cache`) | not set | The default `prefix` of a `redis` cache store: `My Shop` gives `my_shop_cache:`. So two apps on one Redis do not share keys. | `APP_NAME="My Shop"` |
| `APP_URL` | `dox_core` (`Route.signedUrl`) | not set | The scheme and host in front of an absolute [signed URL](../security/signed-urls.md). | `APP_URL=https://example.com` |
| `PORT` | `dox_core` (`DoxServer.portFor()`) | not set | The port to listen on, when `APP_PORT` is not set. Cloud Run, Fly, Render and Heroku set it. | `PORT=8080` |
| `APP_HOST` | `dox_core` (`DoxServer.hostFor()`) | not set (all interfaces, `::`) | The host to listen on. `127.0.0.1` keeps the app off the network, for an app behind a proxy on the same machine. `AppConfig.host` wins over it. | `APP_HOST=127.0.0.1` |
| `DATABASE_URL` | `dox_orm` (`DatabaseConfig.url`), `dox_migration` | not set | A database url. It wins over `DB_CONNECTION` and the other `DB_*` keys. The app reads it with the line `url: env.databaseUrl` in `lib/config/database.dart`. Without that line, only the shell value is read. See [Database url](../database/index.md#database_url). | `DATABASE_URL=postgres://app:secret@db:5432/blog?sslmode=require` |
| `DB_CONNECTION` | `dox_migration` (`DbConnection.config()`) | sqlite | `sqlite`, `postgres` or `mysql`. Any other value is an error. | `DB_CONNECTION=postgres` |
| `DB_HOST` | `dox_migration` | `localhost` | Database host. A path that starts with `/` is a Unix socket: the folder for Postgres, the socket file for MySQL. | `DB_HOST=127.0.0.1` |
| `DB_PORT` | `dox_migration` | `5432` (postgres), `3306` (mysql) | Database port. | `DB_PORT=5432` |
| `DB_USERNAME` | `dox_migration` | `postgres` (postgres), `root` (mysql) | Database user. | `DB_USERNAME=app` |
| `DB_PASSWORD` | `dox_migration` | `postgres` (postgres), empty (mysql) | Database password. | `DB_PASSWORD=secret` |
| `DB_DATABASE` | `dox_migration` | falls back to `DB_NAME`, then `dox` | Database name. For sqlite: the file path. | `DB_DATABASE=dox` |
| `DB_NAME` | `dox_migration` | `dox` | Same as `DB_DATABASE`. `DB_DATABASE` wins when both are set. | `DB_NAME=dox` |
| `HOME` / `USERPROFILE` | build hooks of `dox_http_native`, `dox_postgres_native`, `dox_mysql_native` | empty | Used to find `cargo` when a native library must be built from source. | set by the OS |
| `DART_VM_OPTIONS` | the Dart VM | not set | Flags for the Dart VM. The binary from `dox build` reads it. Dox never sets VM flags for you. See [Performance](../digging-deeper/performance.md#dart-vm-flags). | `DART_VM_OPTIONS=--new_gen_semi_max_size=64` |

## Read by a new project

A new project (`dox create`) reads these keys with its typed env class in `lib/config/env.dart`. The framework itself does not read them. In code, use the getter, like `env.appPort`.

| Variable | Getter | Type | Default | Used for |
| --- | --- | --- | --- | --- |
| `APP_NAME` | `appName` | `String` | `dox` | `LoggerConfig.name`. |
| `APP_ENV` | `appEnv` | `String` | `production` | `development`, `staging` or `production`. `development` turns on colored logs and the query log. Any value except `production` turns on `LogMiddleware` (one log line per request). The framework reads it too, see above. |
| `APP_PORT` | `appPort` | `int` | `3000` | `AppConfig.serverPort`. When it is not set, Dox uses `PORT` if the env has it. |
| `APP_KEY` | `appKey` | `String` | required | `AppConfig.appKey`. Exactly 32 characters. Run `dox key:generate` to make one. |
| `APP_TOTAL_ISOLATE` | `appTotalIsolate` | `int?` | not set: one per CPU the process may use (cpuset and CPU quota) | `AppConfig.totalIsolate`. |
| `LOG_LEVEL` | `logLevel` | `String` | `info` | `LoggerConfig.level`. |
| `CACHE_STORE` | `cacheStore` | `String` | `file` | `CacheConfig.defaultStore`. A new project has the stores `file` and `memory`. Add a `redis` store in `lib/config/cache.dart` before you use it. |
| `STORAGE_DISK` | `storageDisk` | `String` | `local` | `StorageConfig.defaultDisk`. A new project has the disk `local`. Add an `s3` or `memory` disk in `lib/config/storage.dart` before you use it. |
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

A real environment variable always wins over the `.env` file. The file is read like this:

- One `KEY=value` per line. A line that starts with `#` is a comment.
- `export KEY=value` is read like `KEY=value`.
- The value is everything after the first `=`, so `DATABASE_URL=postgres://u:p@h/db?a=b` works.
- A `#` after a space starts a comment: `KEY=abc # note` gives `abc`. `KEY=abc#def` stays `abc#def`.
- Quotes (`"`, `'` or `` ` ``) keep the value as it is, also a `#`. The quotes are removed.
- An empty value (`KEY=`), only spaces, or the text `null` counts as missing. So `Env.get` gives the default.
- In tests (`dart test`, or `APP_ENV=testing` as a real env var), Dox also reads `.env.testing`. Its keys win over `.env`.
- With `CoreFlags.envExpand`, `${OTHER}` and `"..."` escapes work. See [Use one value in another](../digging-deeper/env.md#use-one-value-in-another).

Migrations (`dox_migration`) use their own simpler parser. It does not strip `# note` comments, so keep comments on their own line.

## Details

- `Env.get()` and `EnvReader` read the real environment and `.env`. Code that reads `Platform.environment` sees only the real environment.
- The `.env` file is read once per isolate, from the current folder.
- The parser of `dox_migration` removes every quote character, has no `${VAR}` expansion, and does not read `.env.testing`.
