---
icon: lucide/history
---

# Changelog

What changed in `dox_core`, newest first. Each version lists the changes you may notice in your app. The full list, with every detail, is in [`CHANGELOG.md`](https://github.com/dartondox/dox/blob/main/packages/dox-core/CHANGELOG.md).

## 3.2.2

### New

- `Dox().compute(task)` runs heavy CPU work (a PDF, an image, a big JSON file) on a worker isolate. The server keeps answering other requests in the meantime. `AppConfig.computeWorkers` sets the number of workers (default 4).
- Strict mode for development: `AppConfig(strict: StrictConfig(enabled: true))`. It warns when a route blocks the isolate too long, or when `Hash.make` runs in the web server. Off by default.
- Log lines have a tag that says where they come from: `[request]`, `[server]`, `[error]` or `[app]`. Pass your own tag as the third argument: `Logger.info('done', null, 'billing')`.
- `CoreFlags.rateLimitIpv6Prefix` counts an IPv6 client by its /64 prefix. Off by default.

### Changed

- `Hash.makeAsync` and `Hash.verifyAsync` use the `Dox().compute` workers. Before, each call started a new isolate.
- The stderr warnings use the same tags. `dox: warning:` and `[dox]` are now `[server]` or `[request]`.

### Fixed

- Sessions with the `cache` driver on a `memory` store were kept per isolate, so users were logged out at random. They are now shared by all isolates.
- A slow handler could lose its upload temp file when the client left early.
- An error after a stream started (like server-sent events) wrote `Internal Server Error` into the stream. Now the stream just ends.
- A cut multipart upload kept the request open for ever. Now it gets 400.
- `AfterResponse` work could start before the handler ended, or never run after a sync throw.

### Security

- The `RateLimit` counter without Redis now keeps at most 100,000 clients, so many fake IPs can not fill the memory.

### Performance

- Faster and lighter requests: lazy request body, lazy cookie session, fewer header reads, a smaller JSON buffer, faster route matching and `RateLimit` on Redis in one round trip.

## 3.2.1

### New

- `AppConfig.isDevelopment` is true when `APP_ENV` is `development`.
- `Env.appEnv` gives `APP_ENV` in lower case.

### Fixed

- `Env.get` as the first env read of the app did not see `.env`. Now every env read loads `.env` first.
- In `.env`, `KEY=#value` was read as empty. Now it keeps `#value`.
- A value with only spaces now gives the default.

### Security

- An env error no longer prints the bad value, because it may be a secret.
- The `APP_KEY` check refuses more public sample keys. If your key is one of them, run `dox key:generate`.

## 3.2.0

### Breaking

- The JSON lines of `Logger` and `LogMiddleware` use standard log field names (Datadog). `level` is now `status`. `LogMiddleware` also renames `source_ip` to `network.client.ip` and `request_id` to `http.request_id`.
- `Command`, `MigrationFile` and `DoxProvider` moved to `dox_annotation`. `dox_core` still exports them. Upgrade `dox_builder` together with `dox_core`.

### New

- `CoreFlags`: opt-in behaviors, all off by default. Pass them as `AppConfig(flags: ...)`. `CoreFlags.all()` turns on every flag. See [App config](app-config.md).
- `CoreFlags.envExpand` lets `.env` values use `${OTHER}`. `export KEY=value` lines now work too.
- `RateLimit(sliding: true)` uses a sliding window.
- `AppConfig(htmlErrors: true)` sends an HTML error page to browsers. Errors stay JSON by default.
- Providers get a `boot()` step that runs after every `setup()`.
- `Dox().addGlobalMiddleware()` lets a provider add global middleware.
- `Dox().isWebServer` is true only in the web server process.
- `Dox().loadRoutes()` gives the app routes without a server. `dox route:list` uses it.
- `Route.resource(..., parameter: 'photo')` names the item param.
- `route()` and `Route.url()` take `absolute: true`, and put unknown params in the query string.
- A cache store with `'encrypt': true` encrypts its values with `APP_KEY`.
- `ServerTiming` middleware adds a `Server-Timing` header.
- `AfterResponse.run(work)` runs work after the response is sent.
- `session.regenerate(keepToken: true)` keeps the CSRF token.
- `dox_core` exports the `JSON` helper.
- An AI agent skill (`dox-core-guide`). Install it with `dart run skills@ get`.

### Changed

- `Logger` writes lines in batches, not one `print()` per line. Warnings and errors are written at once.
- `LogMiddleware` writes through `Logger` and follows `LoggerConfig`.

### Fixed

- `Route.group` and the other route scopes now restore their state when the callback throws.
- `Dox().stop()` could keep the process alive.

## 3.1.3

### New

- `IsolateBus` sends a message to all isolates of the app, with no Redis.
- `Dox().isolateCount` gives the number of running isolates.

## 3.1.2

### Changed

- Uses `dox_validation` 3.1.2, so `@Describe('...')` works on DTO fields.

## 3.1.1

### New

- `Hash.sha256(value)`, to store API keys and tokens as a hash. Not for passwords.
- `ValidationException.issues` keeps every issue, so you can build your own 422 body.
- `Cache().flexible` takes a null `stale`.
- `RequestBody` and `BodyKind` are exported, to tell invalid JSON from no body.

## 3.1.0

### Breaking

- Without Redis, `RateLimit` counts are shared by all isolates. Before, the real limit was `max` times the number of isolates. Raise `max` if you relied on that.
- When two `Route.mount` prefixes match, the longest one wins. Before, the first one won.
- Removed the unused `middlewareAndControllerHandler` and `getDoxRequest` helpers.

### New

- Routes: `Route.match`, `Route.any`, `Route.redirect`, `Route.permanentRedirect`, `Route.fallback` and `.where(param, regex)`.
- `Route.staticFiles(prefix, folder)` serves CSS, JS and images, with `ETag`, `304` and Range support.
- `MethodOverride` middleware, so an HTML form can send PUT, PATCH and DELETE.
- Request helpers: `input` with dot keys and a default, `filled`, `exists`, `missing`, `except`, `boolean`, `integer`, `file`, `hasFile`, `bearerToken`, `path`, `fullUrl`, `pathIs` and `routeIs`.
- `Crypt.encryptString` and `Crypt.decryptString`, with the `APP_KEY`.
- `Hash.check`, the same as `Hash.verify`.
- `Cache().many` and `Cache().putMany`.
- `Route.mount(..., middleware: true)` runs the global middleware before the raw handler.
- `SessionMiddleware().fromCookie(value)` loads a session with no request, for a Socket.IO login.
- `package:dox_core/command.dart` lets a package add its own `dox` commands.
- `AppConfig.idleTimeout` and `AppConfig.maxConnections`.
- `Route.websocket(maxMessageSize:)`.
- A warning in development when a middleware returns `null`.

### Fixed

- `res.withHeaders` dropped the headers set before it.
- `res.header` added a second value instead of replacing one.
- A mounted handler that threw left the client hanging.
- `Route.mount('/admin')` also matched `/administrator`.
- Static files added before `startServer()` worked only in one isolate.
- Many smaller router, OpenAPI and session fixes.

### Security

- `.where` now checks a param again after `%` decoding. Before, `%2F` could slip `../` past it.
- `req.pathIs()` now cleans the path like the router does, so `/admin//` can not skip a guard.
- `back()` only follows a `Referer` of the same host. It was an open redirect.
- WebSocket routes can check the `Origin` header: `Route.websocket(allowedOrigins: [...])`.

## 3.0.2

### Changed

- A Redis cache store with no `prefix` uses `<app name>_cache:`. Your old cache keys are not found once after the update. Set `'prefix': 'dox_cache:'` to keep them.

### New

- Middleware: `RequestId`, `ETag`, `ValidateSignature` and `RequestTimeout`.
- Signed urls: `Route.signedUrl(...)`.
- `IDoxTerminableMiddleware` runs a step after the response is sent.
- `Cache()` has `flexible` and `touch`.

## 3.0.1

### New

- A path with routes, but not for the request method, gives `405` with an `Allow` header. Before, it gave `404`.
- `abort(code, [message, headers])` for any status.
- Bracket keys nest: `tags[]=a&tags[]=b` gives a list.
- `AppConfig(previousKeys: [...])` reads cookies made with an old `APP_KEY`, so a new key does not log users out.

### Fixed

- Path params are now URL-decoded.
- 5xx HTTP exceptions now reach `ExceptionHandler.report`.
- `req.method` said `GET` for a HEAD request.

### Performance

- Encrypted cookies and sessions are about 100 times faster (AES-GCM in Rust).

## 3.0.0

The first stable release.
