---
icon: lucide/clipboard-check
---

# Production checklist

This page lists what to check before you deploy a Dox app.

Go through each table one time before your first deploy. An item marked "Dox limit" is a task that you do outside Dox.

## Secrets and config

| Check | How | Read more |
| --- | --- | --- |
| `APP_KEY` is set, 32 characters and secret | Run `dox key:generate`, or set a random value of exactly 32 characters in the real env. It signs JWT tokens and encrypts cookies. Never use the value from `.env.example`. | [Encryption](../security/encryption.md) |
| `APP_ENV=production` | Set it, or leave it empty: both mean production. A bad `APP_KEY` then stops the app at start, `/docs` is off and error details are hidden. | [Env reference](env.md) |
| The env is complete | Run `dox env:check` in CI or before the deploy. It exits with code 1 when a key is missing or bad. | [CLI](cli.md) |
| No secrets in the image or in git | Put `.env` in `.dockerignore` and `.gitignore`. Pass values as env vars (`docker run -e`, `env_file:`, systemd `EnvironmentFile=`). `dox build` copies only `.env.example`. | [Docker](../guides/docker.md) |
| No comments after values in `.env` | The app strips `# note`, but migrations keep it in the value. Put comments on their own line. | [Env reference](env.md) |

## Auth and passwords

| Check | How | Read more |
| --- | --- | --- |
| JWT tokens expire | `JwtAuthDriver.expiresIn` is 1 hour by default. Pick a time that fits your app, like `expiresIn: Duration(hours: 12)`. | [Authentication](../security/authentication.md) |
| A JWT works until it expires | The server keeps no token list by default. To revoke tokens, set `revocation: true` on `JwtAuthDriver`, or use `AccessTokenAuthDriver` (tokens live in a table). To log out everyone, change `APP_KEY` with no `previousKeys`. | [Authentication](../security/authentication.md) |
| Passwords are hashed | Use `user.password = await Hash.makeAsync(input)` (bcrypt, on another isolate). Never store or encrypt a plain password. | [Hashing](../security/hashing.md) |
| The hash is never sent | Add `List<String> get hidden => <String>['password'];` to the user model. The JWT payload is `user.toJson()`, and anyone can read it. | [Authentication](../security/authentication.md) |
| Passwords have a max length | bcrypt takes at most 72 bytes, and `Hash.make` throws on longer input. Add `@MaxLength(72)` to the password field of the DTO. | [Troubleshooting](troubleshooting.md) |

## HTTP and network

| Check | How | Read more |
| --- | --- | --- |
| HTTPS at the proxy | Dox has no TLS server. Run Caddy or nginx in front. Keep the app port private. | [Deployment](../digging-deeper/deployment.md) |
| `trustedProxies` is set behind a proxy | Set `AppConfig(trustedProxies: <String>['127.0.0.1', '::1'])`, or the proxy network, like `'172.16.0.0/12'`. Without it, `req.ip()` is the proxy and `req.scheme()` is `http`. Do not use `['*']` when the app port is public. | [App config](app-config.md) |
| Body limits are on | Keep `maxBodySize` (10 MB) and `maxMultipartSize` (100 MB), or lower them. Set the same limit in the proxy: `client_max_body_size 100m;` | [Request](../the-basic/request.md) |
| CORS has real origins | Use `CORSConfig(origin: 'https://my.app')`, or a list like `<String>['https://my.app', 'https://admin.my.app']`. | [CORS](../security/cors.md) |
| No `credentials: true` with `origin: '*'` | The browser refuses this pair. The new project's `cors.dart` has `credentials: true` and a `localhost` origin. When you turn CORS on, put your real origins in the list. | [CORS](../security/cors.md) |
| Rate limiting | Add `RateLimit(...)` to login and other busy routes. Use a Redis cache store, so all servers share the counts. You can also [limit at the proxy](#rate-limit-at-the-proxy). | [Rate limiting](../security/rate-limiting.md) |
| Security headers | Add `const SecurityHeaders()` to `globalMiddleware`. | [Security headers](../security/security-headers.md) |
| gzip at the proxy | Keep `compress: false`. Turn on gzip in Caddy (`encode gzip`) or nginx (`gzip on;`). | [Performance](../digging-deeper/performance.md) |
| OpenAPI docs | They are off in production. Do not set `enabled: true` for a private API. | [OpenAPI](../packages/openapi.md) |

## Build and run

| Check | How | Read more |
| --- | --- | --- |
| AOT binary, not `dart run` | Run `dox build`, then `build/bundle/bin/server`. Keep `bin/` and `lib/` together. Do not use `dart compile exe`. | [Deployment](../digging-deeper/deployment.md) |
| Native server loads | The start line says `(native)`. If the library does not load, the app stops and prints the fix. | [Native server](../digging-deeper/native-server.md) |
| Native database driver loads | The database works. If the library does not load, the app stops and prints the fix. | [Postgres native](../database/postgres-native.md) |
| Isolates = cores | Keep the default `totalIsolate`. It uses the CPUs the container allows (cpuset and CPU quota). Use fewer when the database runs on the same machine. With SQLite, 1-2 isolates are enough. | [Isolate](../digging-deeper/isolate.md) |
| Shared state across isolates | Use a `redis` cache, not `memory`. For Socket.IO, use `transports: ['websocket']` on the client, and a Redis adapter with many servers. | [Isolate](../digging-deeper/isolate.md) |
| A supervisor restarts the process | Use Docker `restart: unless-stopped`, or systemd `Restart=always`. Dox restarts a dead worker isolate, but not the main isolate. | [Deployment](../digging-deeper/deployment.md) |
| Writable temp folder | Uploads over 1 MB go to a temp file. A `FROM scratch` image needs `/tmp` with mode `1777`. | [Docker](../guides/docker.md) |
| Uploads live on a volume or S3 | The `local` disk writes to `storage/`. Mount it as a volume, or use the `s3` disk. | [File storage](../digging-deeper/file-storage.md) |

## Database

| Check | How | Read more |
| --- | --- | --- |
| Postgres or MySQL for a busy app | SQLite has one connection per isolate, and a query blocks the isolate, so use it for small apps only. Give it an absolute file path. | [Database](../database/index.md) |
| Migrations run once per deploy | The new project runs migrations in `bin/server.dart` before `startServer()`. Or run `dox migrate` once in CI. With many machines, run migrations in one place only, so two machines do not migrate at the same time. | [Migration](../database/migration.md) |
| Migrations use the right database | Migrations also read a `.env` file, so a key that is only in an old `.env` is still used. Do not ship a `.env` next to the binary, or give `Migrator(config: ...)` your own config. | [Migration](../database/migration.md) |
| Small MySQL migrations | MySQL saves `CREATE`, `ALTER` and `DROP` at once, so a failed migration can leave half the changes. Make one table change per migration. | [Migration](../database/migration.md) |
| Pool size fits the database | Set `extra: {'maxConnectionCount': 10}`. All isolates share one pool, so this is the total for the process. Keep it under the database `max_connections`. | [Database](../database/index.md) |
| Query logging is off | `debug: true` prints every query. The new project turns it on only in `development`. | [Database](../database/index.md) |
| Backups | Dox limit: Dox has no backup tool. Use `pg_dump`, `mysqldump`, managed snapshots, or `sqlite3 app.db ".backup x.db"`. Test a restore. | |

## Logs and errors

| Check | How | Read more |
| --- | --- | --- |
| JSON logs | Use `LoggerConfig(enabled: true, prettyPrint: false)`. The new project does this outside `development`. | [App config](app-config.md) |
| Log level | Set `LOG_LEVEL=warn` to print only warnings and errors. | [App config](app-config.md) |
| Access logs in one place | `LogMiddleware` logs one line per request. The new project turns it off in `production`, because the proxy already logs requests. Log lines are written every 20 ms, so a hard kill can lose the last lines. | [Performance](../digging-deeper/performance.md) |
| Errors go to your tracker | Extend `ExceptionHandler` and set `AppConfig.exceptionHandler`. Every error that is not an HTTP exception goes to its `report` method. | [Error handling](../the-basic/errors.md) |

## Health and shutdown

| Check | How | Read more |
| --- | --- | --- |
| Health route | Add `Route.health('/health', checks: ...)` with a database check, so the load balancer knows when the app can not serve. | [Health check](../digging-deeper/health-check.md) |
| Graceful shutdown | On `SIGTERM` or `SIGINT`, Dox stops taking connections and lets open requests finish. Set `shutdownTimeout` below the kill timeout of your platform. Close your own connections in the `shutdown()` of a provider. | [Deployment](../digging-deeper/deployment.md#graceful-shutdown) |
| Zero downtime deploys | Run two processes (or machines) behind the proxy. Restart one at a time. | [Deployment](../digging-deeper/deployment.md) |

## Rate limit at the proxy

You can also limit requests at the proxy, so bad clients never reach the app.

nginx:

```nginx
# in http { }
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;

# in server { location / { } }
limit_req zone=api burst=20 nodelay;
limit_req_status 429;
```

Caddy needs the [caddy-ratelimit](https://github.com/mholt/caddy-ratelimit) plugin. Build Caddy with it:

```bash
xcaddy build --with github.com/mholt/caddy-ratelimit
```

Then add the limit:

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

The proxy must see the real client IP. If a load balancer is in front of the proxy, set the real IP module of the proxy first.

## Next steps

- [Deployment](../digging-deeper/deployment.md): build and run the app in production.
- [Environments](../guides/environments.md): config and secrets for each environment.
