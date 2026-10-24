# Production checklist

Check each item before you deploy. Each item says what to check, how to do it, and where to read more.

Items marked **Dox limit** are things Dox does not do for you. You must handle them outside Dox.

## Secrets and config

| Check | How | Read more |
| --- | --- | --- |
| `APP_KEY` is set, 32 characters and secret | `dox key:generate`, or a random value of exactly 32 characters in the real env. It signs JWT tokens and encrypts cookies. Never use the value from `.env.example`. | [Encryption](../security/encryption.md) |
| `APP_ENV=production` | An empty `APP_KEY`, a key that is not exactly 32 characters, or an old sample key stops the app at start (`StateError`). Only `APP_ENV` `development`, `local` or `test` logs a warning instead. | [Env reference](env.md) |
| The env is complete | Run `dox env:check` in CI or before the deploy. It exits with code 1 when a key is missing or bad. | [CLI](cli.md) |
| No secrets in the image or in git | `.env` in `.dockerignore` and `.gitignore`. Pass values as env vars (`docker run -e`, `env_file:`, systemd `EnvironmentFile=`). `dox build` copies `.env.example` only. | [Docker](../guides/docker.md) |
| No comments after values in `.env` | `KEY=abc # note` gives the value `abc # note`. Put comments on their own line. | [Troubleshooting](troubleshooting.md) |

## Auth and passwords

| Check | How | Read more |
| --- | --- | --- |
| JWT tokens expire | `JwtAuthDriver.expiresIn` is 1 hour by default. Pick a time that fits your app, like `JwtAuthDriver(secret: SecretKey(env.appKey), expiresIn: Duration(hours: 12))`. | [Authentication](../security/authentication.md) |
| You can not revoke one token | **Dox limit.** There is no token list on the server. To log out everyone, change `APP_KEY`. | [Authentication](../security/authentication.md) |
| Passwords are hashed | `user.password = Hash.make(input)` (bcrypt). Never store or encrypt a plain password. | [Hashing](../security/hashing.md) |
| The hash is never sent | `List<String> get hidden => <String>['password'];` in the user model. The JWT payload is `user.toJson()`, and anyone can read it. | [Authentication](../security/authentication.md) |
| Passwords have a max length | bcrypt throws on input over 72 bytes. Add `@MaxLength(72)` to the password field of the DTO. It counts characters, so non-ASCII text can still pass 72 bytes. | [Troubleshooting](troubleshooting.md) |

## HTTP and network

| Check | How | Read more |
| --- | --- | --- |
| HTTPS at the proxy | Dox has no TLS server. Run Caddy or nginx in front. Keep the app port private. | [Deployment](../digging-deeper/deployment.md) |
| `trustedProxies` is set behind a proxy | `AppConfig(trustedProxies: <String>['127.0.0.1', '::1'])`, or the proxy network, like `'172.16.0.0/12'`. Without it, `req.ip()` is the proxy and `req.scheme()` is `http`. Do not use `['*']` when the app port is public. | [App config](app-config.md) |
| Body limits are on | Keep `maxBodySize` (10 MB) and `maxMultipartSize` (100 MB), or lower them. Set the same limit in the proxy: `client_max_body_size 100m;` | [Request](../the-basic/request.md) |
| CORS has real origins | `CORSConfig(origin: 'https://my.app')`, or a list like `<String>['https://my.app', 'https://admin.my.app']`. With a list, Dox sends back only the request origin when it is in the list. | [CORS](../security/cors.md) |
| No `credentials: true` with `origin: '*'` | The new project's `cors.dart` has `origin: '*'` and `credentials: true` with `enabled: false`. When you turn CORS on, set a real origin first. | [CORS](../security/cors.md) |
| Rate limiting | **Dox limit.** Dox has no rate limiter. Do it at the proxy. See [below](#rate-limit-at-the-proxy). | [Deployment](../digging-deeper/deployment.md) |
| gzip at the proxy | Keep `compress: false`. Turn on gzip in Caddy (`encode gzip`) or nginx (`gzip on;`). | [Performance](../digging-deeper/performance.md) |
| OpenAPI docs | Off in production by default (on only for `APP_ENV` `development` or `local`). Do not set `enabled: true` for a private API. | [OpenAPI](../packages/openapi.md) |

## Build and run

| Check | How | Read more |
| --- | --- | --- |
| AOT binary, not `dart run` | `dox build`, then run `build/bundle/bin/server`. Keep `bin/` and `lib/` together. Not `dart compile exe`. | [Deployment](../digging-deeper/deployment.md) |
| Native server loads | The app starts and the start line says `(native)`. When the library does not load, the app stops with `dox_http_native did not load` and the fix. | [Native server](../digging-deeper/native-server.md) |
| Native database driver is on | No `[dox] warning: dox_postgres_native did not load` (or `mysql`) line at start. Do not set `DOX_DB_DRIVER=dart`. Postgres with TLS uses the Dart driver. | [Postgres native](../database/postgres-native.md) |
| Isolates = cores | Keep the default `totalIsolate` (`Platform.numberOfProcessors`), or set `APP_TOTAL_ISOLATE` to the cores the container really gets. Use fewer when the database runs on the same machine. | [Isolate](../digging-deeper/isolate.md) |
| Shared state across isolates | Cache: `redis`, not `memory`. WebSocket: `WebsocketRedisAdapter`. Socket.IO: a Redis adapter and `transports: ['websocket']`. | [Isolate](../digging-deeper/isolate.md) |
| A supervisor restarts the process | Docker `restart: unless-stopped`, or systemd `Restart=always`. Dox restarts a dead worker isolate, but not the main isolate. | [Deployment](../digging-deeper/deployment.md) |
| Writable temp folder | Uploads over 1 MB go to a temp file. A `FROM scratch` image needs `/tmp` with mode `1777`. | [Docker](../guides/docker.md) |
| Uploads live on a volume or S3 | The `local` disk writes to `storage/`. Mount it as a volume, or use the `s3` disk. | [File storage](../digging-deeper/file-storage.md) |

## Database

| Check | How | Read more |
| --- | --- | --- |
| Postgres or MySQL for a busy app | SQLite has one connection per isolate, and a query blocks the isolate. Use it for small apps only. With SQLite use an absolute file path, never `:memory:` with many isolates. | [Database](../database/index.md) |
| Migrations run once per deploy | The new project runs `Migrator(migrations: migrations).migrate()` in `bin/server.dart` before `startServer()`. Or run `dart run bin/migrate.dart run` (or `dox migrate`) in CI. Do one, not both at the same time on many machines. | [Migration](../database/migration.md) |
| Migrations use the right database | `dox_migration` reads `.env` when the file exists, and ignores the real env then. Do not ship a `.env` next to the binary, or give `Migrator(connection: ...)` your own pool. | [Troubleshooting](troubleshooting.md) |
| Small MySQL migrations | MySQL saves `CREATE`, `ALTER` and `DROP` at once. A failed migration can leave half the changes. One table change per migration. | [Migration](../database/migration.md) |
| Pool size fits the database | `extra: {'maxConnectionCount': 10}` is per isolate. Total = isolates x pool size. Keep it under the database `max_connections`. | [Database](../database/index.md) |
| Query logging is off | The new project's `database.dart` has `debug: true` on every connection, which prints every query. Set `debug: false` in production. | [Database](../database/index.md) |
| Backups | **Dox limit.** Dox has no backup tool. Use `pg_dump`, `mysqldump`, managed database snapshots, or a copy of the SQLite file (with the `-wal` file, or `sqlite3 app.db ".backup x.db"`). Test a restore. | |

## Logs and errors

| Check | How | Read more |
| --- | --- | --- |
| JSON logs | `LoggerConfig(enabled: true, prettyPrint: false)`. The new project sets `prettyPrint` only when `APP_ENV=development`. | [App config](app-config.md) |
| Log level | Set `LOG_LEVEL=warn` to print only warnings and errors. | [App config](app-config.md) |
| Access logs in one place | `LogMiddleware` writes one line per request, every 20 ms. A hard kill can lose the last lines. Turn it off when the proxy already logs requests. | [Performance](../digging-deeper/performance.md) |
| Errors go to your tracker | Set `AppConfig.errorHandler`. Any non-HTTP error is passed to it. The client gets `500` with `server_error`. The error text is sent only when `APP_ENV` is `development` or `local`. | [HTTP exceptions](http-exceptions.md) |

## Health and shutdown

| Check | How | Read more |
| --- | --- | --- |
| Health route | **Dox limit.** Dox has no built-in health route. Add one that asks the database: `Route.get('/health', healthController.check)` with `await QueryBuilder.query('select 1');`. | [Docker](../guides/docker.md) |
| Graceful shutdown | On `SIGTERM` or `SIGINT`, Dox stops taking connections and lets open requests finish, in every isolate. Set `shutdownTimeout` below the kill timeout of your platform. The `ORMService` closes the database in its `DoxShutdown` hook, and Dox closes the cache stores. Close your own connections in a `DoxShutdown` service. | [Deployment](../digging-deeper/deployment.md#graceful-shutdown) |
| Zero downtime deploys | Run two processes (or machines) behind the proxy. Restart one at a time. | [Deployment](../digging-deeper/deployment.md) |

## Rate limit at the proxy

Dox has no rate limiter. Add one in the proxy.

nginx:

```nginx
# in http { }
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;

# in server { location / { } }
limit_req zone=api burst=20 nodelay;
limit_req_status 429;
```

Caddy needs the [`caddy-ratelimit`](https://github.com/mholt/caddy-ratelimit) plugin (build Caddy with `xcaddy build --with github.com/mholt/caddy-ratelimit`):

```
example.com {
  rate_limit {
    zone api {
      key    {remote_host}
      events 100
      window 1m
    }
  }
  reverse_proxy 127.0.0.1:3000
}
```

!!! note
    The proxy must see the real client IP. When there is a load balancer in front of the proxy, set the real IP module of the proxy first.
