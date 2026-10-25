## Unreleased

- Breaking: `dox_core` no longer depends on `dox_storage` and `dox_socketio`. Add the package you use to your app.
  - Storage: `Storage()`, `StorageConfig` and `StorageDiskFactory` moved to `dox_storage`. `AppConfig.storage` is removed: extend `StorageService` from `dox_storage` (`class AppStorageService extends StorageService { AppStorageService() : super(storageConfig); }`). `Route.files()` is now `Storage.route()`. `Dox().storage` is now `Storage.manager`. `RequestFile.store()` needs `import 'package:dox_storage/dox_storage.dart'`.
  - Socket.IO: `SocketIoConfig` moved to `dox_socketio`. `AppConfig.socketIo` is removed: extend `SocketIoService` from `dox_socketio`. `Dox().socketIo` is now `SocketIoService.server`.
  - `dox_core` no longer exports `Disk`, `DriveManager`, `FileNotFoundException` and `StorageException`. Import them from `dox_storage`.
  - `StreamFile` and `DownloadableFile` stay in `dox_core`.

## 3.0.0-alpha.11

- New: middleware that runs after the controller. Implement `IDoxNextMiddleware` (`handle(DoxRequest req, Next next)`), or use a function `(DoxRequest req, Next next)`. `await next()` runs the rest of the middleware and the controller and gives a `DoxResponse`, so the code after it can change the status, headers and cookies. A thrown error comes back as its error response, so the after part still runs. Before-only middleware work as before. A route with no `next` middleware takes the same fast path as before.
- New: `DoxResponse.status` and `DoxResponse.headers` getters.
- New: `redirect(url, status: 302)` and `back(req, fallback: '/')` helpers.
- New: sessions. `SessionMiddleware` gives each request `req.session` with `get`, `put`, `has`, `forget`, `all`, `flush`, `pull`, `flash`, `reflash`, `keep`, `regenerate`, `invalidate` and `token`. `AppConfig(session: SessionConfig(...))` picks the `cookie` driver (all data in a cookie, encrypted with AES-GCM, 4 KB limit) or the `cache` driver (a random id in the cookie, the data in a `dox_cache` store like `redis`). The cookie is `HttpOnly` and `SameSite=Lax` by default. The cookie driver reads the session on first use. The session is saved, and the cookie sent, only when it changed.
- New: `CsrfMiddleware`. `POST`, `PUT`, `PATCH` and `DELETE` requests must send the session token in `_token`, `X-CSRF-TOKEN` or `X-XSRF-TOKEN`, else `419` (`TokenMismatchException`). It sets an `XSRF-TOKEN` cookie that axios and Inertia send back for you. `except:` skips paths like `/api/*`.
- New: a validation error on a request with a session that does not want JSON (a form post, an Inertia request) flashes `errors` and the old input (never password fields), and redirects back. JSON requests still get `422`. Read them with `req.session.errors` and `req.session.old('email')`. `req.session.flashErrors(...)` does the same by hand. New `req.expectsJson()` and `req.hasSession`.
- New: `DoxCookie(sameSite: SameSite.lax)`.
- New: `TestResponse.cookies` and `DoxTestClient.withCookies(...)`, to go on with a session in tests.

## 3.0.0-alpha.10

- Version bump only, to match the other packages.

## 3.0.0-alpha.9

- New: a real IoC container. `IocContainer` (`Dox().ioc`) has `get<T>()`, `has<T>()`, `singleton<T>()`, `factory<T>()`, `instance<T>()`, `override<T>()` and `clearOverrides()`. Each isolate has its own container: a singleton is one instance per isolate, made on first use.
- New: `AppConfig(container: registerContainer)` with the function from `lib/container.g.dart` (made by `dox_builder`). Every isolate runs it. The routers and services it finds are registered for you, so `AppConfig.routers` and `AppConfig.services` can stay empty. The ones you list there still work and come first.
- New: typed routes. `Route.get<UserController>('users', (UserController c) => c.index)` (also post, put, patch, delete and the others). The controller comes from the container, once per isolate, at start. `(UserController c) => c.index` without `<UserController>` works too. `Route.resource('users', UserController)` takes a controller class.
- New: a controller parameter whose type is in the container gets it from the container.
- New: route model binding for `@DoxModel` classes. A controller parameter of type `User` gets the `User` of the `{user}` param (or the next param), found by its primary key. No row answers 404. `Route.bind` still wins.
- Breaking: the old `IocContainer` methods `register`, `registerByName`, `registerSingleton` and `getByName` are removed. Use `factory`, `singleton` and `get`.
- New: named routes. `Route.get('/users/{id}', c).name('users.show')`, then `route('users.show', params: {'id': 5})` gives `/users/5`. `query:` adds a query string. `Route.group(..., name: 'admin.')` puts a prefix in front of the names inside. Resource routes are named `blogs.index` ... `blogs.destroy`; `Route.resource(..., name:)` picks another base name. A name used twice stops the app at start. An unknown name, a missing param or an extra param throws an `ArgumentError`.
- New: route model binding without `dart:mirrors`. `Route.bind<User>('user', (String id) => User().find(id))` runs before the controller of every route with a `{user}` param. The controller gets it as a `User user` parameter, or with `req.bound<User>('user')`. A binder that gives `null` answers 404.
- New: `ExceptionHandler`, the one place that turns an error into a response. Extend it and set `AppConfig(exceptionHandler: ...)`. `report(error, stackTrace)` logs, `render(error, req)` picks the response. The default answers are the same as before. A URL with no route goes through it too.
- Breaking: `AppConfig.errorHandler` and `defaultErrorHandler` are removed. Override `ExceptionHandler.report` instead. It gets the same errors: every error that is not an `IHttpException`, also errors outside a request. A thrown value that is not an `Exception` or `Error` (like a `String`) is now reported too.
- `responseHandler` still works and still runs after `render`.
- New: `RateLimit` middleware. `RateLimit(max: 60, per: Duration(minutes: 1), key: (DoxRequest req) => req.ip())`. One request too many gets `429` with `Retry-After`. Every answer has `X-RateLimit-Limit` and `X-RateLimit-Remaining`. The counts live in Redis when the default cache store is Redis (shared by all isolates and servers), else in memory. Fixed window. New `TooManyRequestsException`.
- New: `SecurityHeaders` middleware. It adds `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy` and `Cross-Origin-Opener-Policy`, and `Strict-Transport-Security` on https requests only. Each one can be changed or turned off with `null`. `Content-Security-Policy` is off by default.
- New: `Route.health('/health', checks: {...})`. It answers 200 `{"status": "ok"}`, or 503 when a check throws, returns `false` or times out. `HealthCheck.cache()` checks the cache. The error text is in the answer only in `development` and `local`.
- New: `package:dox_core/testing.dart` with `DoxTestClient`. `DoxTestClient.start(appConfig)` runs the app in the test on a free port. `get`, `post`, `put`, `patch`, `delete`, `send`, `withHeaders` and `withToken`. `TestResponse` has `status`, `body`, `json`, `headers` and `expectStatus`, `expectJson`, `expectBody`, `expectHeader`.
- dox_core now depends on `matcher` (for the `expect` methods of `TestResponse`).

## 3.0.0-alpha.8

- Uses dox_http_native 3.0.0-alpha.8: pipelined requests are about 2.8 times faster (1 core: 172k to 480k req/s). Normal requests are as fast as before.
- Security: every file response (`File`, `Storage().stream()`, `Storage().download()`, `Route.files`) sends `X-Content-Type-Options: nosniff`. Before, a `File` response and a raw download did not.
- New: `Route.files(path, download: true)` sends every file as a download (`Content-Disposition: attachment`). Use it for user uploads. html, svg, xml and javascript files are still always sent as a download in a sandbox.
- Fix: a trusted proxy `X-Forwarded-For` hop with a port (`1.2.3.4:5678`, `[::1]:5678`) is now read without the port. Before, it was not a valid ip, so `req.ip()` could be wrong. A bare IPv6 like `::1` still works.

## 3.0.0-alpha.7

- Breaking: `dox_websocket` is gone. Use `dox_socketio` for realtime. `Dox().websocket` and `Dox().setWebsocket()` are removed.
- Breaking: `Route.websocket(path, handler)` is now a raw WebSocket route. `handler` gets the open `WebSocket` and the `DoxRequest`. Middleware runs first. A request that is not a WebSocket upgrade gets 400.
- `dox_http_native` now lives in its own repo (dartondox/dox-http-native). Dox uses it from pub.dev (`^3.0.0-alpha.7`). Its build hook downloads a ready-built library, so you do not need Rust.
- Perf: faster route matching. A plain route is found with one map lookup, also when a param route was added before it (as long as that param route can not match the same path). Param routes are grouped by their first path segment, so a request only tries the routes that can match. The first matching route still wins.
- Perf: the request handler reads `Host` and `Content-Type` once per request. `Host` is read only when the app has a `Route.domain()` route. `HttpBody.read()` takes an optional `contentType`.
- Perf: on the native server, a JSON or form body is used as it is, with no stream in between. The size limit is still checked.
- Perf: JSON responses are encoded in 8 KB chunks, not 256 bytes.
- Perf: fewer objects per request. `RouteData.params`, `DoxRequest.param` and `DoxRequest.method` are made on first use. `RouteData.domainLower` is made once. CORS header lists are joined once.
- Perf: one Future less per async request (`then(onError:)` instead of `then().onError()`).
- Perf: multipart parsing makes its regexes once, and no longer builds a `Future.any` per chunk.
- Perf: `LogMiddleware` lowercases the `redact` words once, not per key.
- Perf: an error response reads `APP_ENV` and lowercases it only when the value changed.
- Perf: `IocContainer` calls `T.toString()` once per call.
- Breaking: the `dart:io` server is gone. Every app runs on the native server (`dox_http_native`), also an app with WebSocket or Socket.IO routes. `AppConfig.server`, the `ServerBackend` enum and the `DOX_SERVER` env var are removed. `DoxServer.usesNative()` and the `isolateId` option of `DoxServer.listen()` are removed.
- Breaking: when the native library does not load, Dox stops at start with an error. It says why (eg. an ABI mismatch) and how to fix it (install Rust so the build hook can build it, or rebuild your `lib_path` library). Before, Dox logged a warning and used `dart:io`.
- On a graceful stop (SIGTERM, `Dox().stop()`), open WebSockets get close code 1001.
- Perf: `AESEncryptor` keeps the key bytes of the last secret and writes the output into one buffer. Decode reads the nonce and text without copies. The output format is the same.
- New: `Hash.makeAsync()` and `Hash.verifyAsync()`. They run bcrypt in another isolate, so a request does not block the server.
- New: `Hash.rounds` (default 10) sets the bcrypt cost. `Hash.make()` also takes `rounds:`.
- Security: the app does not start when `APP_KEY` is empty, not exactly 32 characters, or one of the old public sample keys from `.env.example`. With such a key anyone can sign tokens and cookies. In `APP_ENV` `development`, `local` or `test` Dox only logs a warning. A longer key (eg. 48 or 64 characters) is refused too, because AES needs a key of 16, 24 or 32 bytes and every encrypted cookie failed with it. Before, only an empty key in `production` stopped the app. Run `dox key:generate` for a new key.
- Security: a multipart part header with many backslashes (`name="\\\\...`) no longer blocks a server isolate for hours (ReDoS in the quoted string regex).
- Security: a `StreamFile` response (`Storage().stream()`, `Route.files()`) with an html, xml, svg or javascript type is sent with `Content-Disposition: attachment` and `Content-Security-Policy: sandbox`. Every `StreamFile` gets `X-Content-Type-Options: nosniff`. Before, an uploaded `x.html` or `x.svg` was shown inline, and its script ran on the app origin (stored XSS).
- Security: a `Route.domain()` route only matches when the `Host` header matches. Before, a request with no `Host` matched every domain route. A `Host` with a port (`admin.app.com:8080`) now matches `Route.domain('admin.app.com')`.
- Security: an encrypted cookie is bound to its name (AES-GCM associated data). A value made for `locale` gives `null` when it is sent as `user_id`. `AESEncryptor.encode()`/`decode()` take a new `associatedData` option. Encrypted cookies made by older versions no longer decrypt, so `req.cookie()` gives `null` for them once. Users may need to log in again.
- Security: `DoxCookie` is `HttpOnly` by default. `secure` is `null` by default, which sets `Secure` when the request came over https (`req.scheme()`, see `trustedProxies`). Set `httpOnly: false` or `secure: false` to change it.
- Security: the native server checks `maxBodySize` and `maxMultipartSize` on their own. Before, Rust let any body up to the bigger limit (100 MB) through, so a JSON body could take 100 MB of RAM before Dart said 413.
- New `AppConfig.bodyTimeout` (default 120 seconds). On the native server, a client that does not send the whole body in this time gets 408. It stops slow clients that hold memory and connections.

## 3.0.0-alpha.6

- Security: `Storage().putRequestFile()` and `RequestFile.store()` no longer trust the client file name when the bytes are a known format that does not match it. Before, a valid png sent as `a.html` passed `@Image`/`@Mimes` and was saved as `.html`, so `Route.files()` served it as `text/html` on the app origin (stored XSS). Now it is saved with the extension of the bytes (`.png`).
- Security: new upload file names use a random uuid (v4), not a time-based one (v1). A v1 name shows the upload time and the server, and the next name is easy to guess.
- Security: `trustedProxies: ['*']` trusts the direct peer only. `req.ip()` is the right-most `X-Forwarded-For` hop, the one the proxy added. Before, `*` also trusted every hop in the header, so `req.ip()` was the left-most value, which the client sets (`X-Forwarded-For: 6.6.6.6`). That broke IP rate limits and allow lists, also behind the Fly.io proxy of the deploy guide.
- Security: `LogMiddleware` writes `[REDACTED]` for body fields and headers whose name has `password`, `passwd`, `secret`, `token`, `authorization`, `cookie`, `api_key`, `api-key` or `apikey` in it (upper or lower case). Before, the login body (with the password) and, with `withHeader: true`, the `Authorization` header went to the log as plain text. Change the list with `LogMiddleware(redact: [...])`.
- Security: an error that is not an `IHttpException` answers `500` with `{"code": "server_error", "message": "Server Error"}`. The error text is sent only when `APP_ENV` is `development` or `local`. Before, the client always got `error.toString()`, which can hold SQL, table names, file paths or database hosts. `errorHandler` still gets the full error.
- Graceful shutdown closes the cache stores of `Cache()` (eg. Redis), in every isolate, after the `DoxShutdown` services. Your app needs no extra code.
- The `ORMService` of a new project implements `DoxShutdown` and calls `SqlQueryBuilder.close()`, so the database connections close on shutdown too. In an older project, add this to `lib/services/orm_service.dart`:
  ```dart
  class ORMService implements DoxService, DoxShutdown {
    // setup() as before

    @override
    Future<void> shutdown() async {
      await SqlQueryBuilder.close();
    }
  }
  ```

## 3.0.0-alpha.5

- Fix: CORS `origin` can be a list. Dox compares the request `Origin` with the list and sends back only the origin that matches, or no header. Before, it joined the list with commas, and browsers rejected it. A list also sends `Vary: Origin`.
- Breaking: `AESEncryptor` now uses AES-GCM with a random nonce for each message. Before, it used AES-CTR with an all-zero nonce and no message check. Old encrypted cookies and values can not be read.
- Breaking: `AESEncryptor.decode` throws `DecryptException` (400) when the text was changed or the key is wrong. Before, it printed an error and returned `''`.
- `req.cookie()` returns `null` for an encrypted cookie that can not be decrypted.
- Fix: `Hash.verify` returns `false` for a malformed hash. Before, it threw.
- `AESEncryptor` and `DecryptException` are now exported from `package:dox_core/dox_core.dart`.
- Fix: in `.env`, `KEY=value # note` gave the value `value # note`. A `#` after a space now starts a comment. A `#` inside quotes, or with no space before it, is kept.
- Fix: the `.env` parser removed every quote character inside a value. Now only the quotes around the value are removed.
- Fix: `HEAD` requests got 404, also `HEAD /docs`. A `HEAD` request now runs the `GET` route of the same path. The answer has the status and headers of `GET`, with no body.
- New: Dox listens on `PORT` when `APP_PORT` is not set. Cloud Run, Fly, Render and Heroku set `PORT`. `APP_PORT` still wins.
- New: `AppConfig.host` and the env var `APP_HOST` pick the network interface to listen on, like `127.0.0.1`. The default is the same as before: all interfaces (`::`, IPv6 and IPv4).
- Fix: the start log always said `http://127.0.0.1:<port>`. It now shows the real host and port, like `http://[::]:3000`.
- Removed the unused `sprintf` dependency.
- New: graceful shutdown. On `SIGTERM` or `SIGINT` every isolate stops taking new connections and lets open requests finish, up to `AppConfig.shutdownTimeout` (default 8 seconds). Then Dox runs `DoxShutdown` services and exits with code 0. Before, open requests were cut. A second signal stops at once.
- New: `DoxShutdown`. A service that also implements it gets `shutdown()` in every isolate on stop, to close connections.
- New: `await Dox().stop()` stops the server gracefully in every isolate, without exit.
- Fix: an `s3` storage disk without `bucket`, `key` or `secret` failed with `Null is not a subtype of String`. Now it fails with a clear message that names the missing setting.
- Fix: a URL with no route now answers like a thrown `NotFoundHttpException`. The body is JSON (`{"code": "not_found", "message": "GET /x not found"}`), and the app `responseHandler` runs for it, so apps can format it.
- Fix: the error answer of an `IHttpException` now has its `errorCode`. A text message gives `{"code": "<errorCode>", "message": "<text>"}` as JSON. Before, the body was plain text and `errorCode` was never sent. A `Map` message (like validation errors) is still sent as it is.
- Fix: the `Logger` now reads `LoggerConfig.level`. Lines below that level are not printed. Levels from low to high: `debug`, `info` (and `success`), `warn`, `error` (and `danger`).
- Fix: `Route.group('blogs')` with `Route.get('all')` made `/blogsall`. Path parts now join with one `/`. This also works for nested groups, `Route.prefix` and `Route.resource`.
- Fix: `Route.resource` hid every error from the controller. Now it only skips methods the controller does not have.

## 3.0.0-alpha.4

- Version bump only, to match the other packages.

## 3.0.0-alpha.3

- New: `Cache().getRaw(key)` gives the cached value as JSON text, with no decode. Send it as a JSON response with no extra encode step.
- New Redis cache option `pool_size` (see `dox_cache`).

## 3.0.0-alpha.2

- New default server: `dox_http_native` (Rust hyper parses HTTP, your code stays in Dart). Hello world goes from about 41k to about 144k req/s on one isolate. Set `server: ServerBackend.dartIo` in `AppConfig` (or `DOX_SERVER=dartio`) to use `dart:io`. Dox uses `dart:io` by itself, with one warning line, when the native library does not load, and for apps with WebSocket or Socket.IO routes.
- Faster requests: a simple `GET` hello world went from about 31k to about 40k req/s on one isolate (plain `dart:io` is about 46k). A request with no body and sync middleware and controller now runs with no `Future`. `req.ip()`, the query, `req.all()` and cookies are read on first use only. Reading the client ip was the biggest cost, because it asks the socket. Clean paths skip the two regex calls, and plain routes are found with a map lookup.
- Fix: a `@Dto` body with a `RequestFile` field shows as `multipart/form-data` in the OpenAPI docs.
- Fix: `req.ip()` gave `::ffff:127.0.0.1` for IPv4 clients. Now it gives `127.0.0.1`. The same goes for `X-Forwarded-For` hops.
- Needs Dart 3.13 or newer.
- All dependencies updated to their latest versions.
- Removed the `encrypt` package (not maintained, and it blocked `pointycastle` 4). AES for cookies and the file cache now uses `pointycastle` 4. The output is the same, so old cookies and cache files still decode.
- Fix: `Env.get()` of a missing key with no default gave the text `"null"`. A missing `APP_KEY` became the key `"null"`, which anyone can guess. Now `String` gives `''`, `String?` gives `null`, and `int`/`num`/`double`/`bool` throw a clear error. New: `Env.get<bool>()`.
- Startup stops with an error when `APP_KEY` is empty and `APP_ENV=production`. Other environments log a warning.
- New: typed input with DTOs. A controller asks for a `@Dto` class by type: `store(CreateUser body)`. Dox reads the body (or the query for `GET`), checks it, and answers `422` with `{"items.1.quantity": "..."}` when it is wrong. `await req.validate<T>()` does the same inside a method. See the Validation guide.
- New: `AppConfig(dtos: dtos)` (from `lib/dtos.g.dart`) and `AppConfig(validationMessages:)` for other languages. `req.locale` is the first `Accept-Language`.
- New: typed controller parameters. `DoxRequest` anywhere, one `@Dto`, and `String`, `int`, `double`, `num`, `bool` path params by position. A path param that does not fit its type answers `404`. The types are read once at start; an unknown type stops the server with a clear error.
- New: optional path params `{id?}`.
- New: query strings and form data with repeated keys (`tags=a&tags=b`) and bracket keys (`address[city]`, `items[0][name]`) for DTOs.
- A DTO answers `400` for a body that is not valid JSON, and `415` for a body type it can not read.
- `RequestFile` implements `FileInput` and keeps its first bytes, so `@Mimes` and `@Image` check the real file type.
- Breaking: removed `req.validate(Map)`, `req.validateAsync()`, `FormRequest`, `AppConfig(formRequests:)`, `DoxValidator`, `IocContainer.registerRequest()` and `processInputMapper()`. Use a DTO. `req.validateSchema(schema)` stays for input you only know at runtime.
- Breaking: a controller with more path params than the route has `{...}` params stops the start. Before, the extra ones got `''`.
- Fix: a typed path param like `int id` gave a 500 (it was always a `String`).
- A `ValidationException` from `dox_validation` (for example `schema.parse()` in a controller) answers 422.
- `dox_core` exports `dox_validation` (not its `ValidationException`), with the DTO annotations. `dox_orm` also has `Schema`, and `package:uuid` has `Uuid`: use `hide` or a prefix in a file that needs both.
- Breaking: `Cache()` runs on `dox_cache`. `AppConfig.cache` is a `dox_cache` `CacheConfig(defaultStore:, stores:)` with option maps. `CacheDriverInterface` and `FileCacheDriver` are removed. Values must be JSON types. `put` without a duration keeps the value forever (was 1 hour). New: `add`, `pull`, `increment`, `decrement`, `remember`, `rememberForever`, `lock`, `tags`.
- Breaking: `Storage()` runs on `dox_storage`. `AppConfig.fileStorage` is now `AppConfig.storage` (`StorageConfig(defaultDisk:, disks:)` with option maps for `local`, `s3`, `memory`). `StorageDriverInterface` and `LocalStorageDriver` are removed. An unknown disk name throws.
- `Storage().stream()` and `download()` stream from any disk (S3 too), with `Content-Length`. New: `url`, `signedUrl`, `use()` for the full `Disk`.
- New `Route.files('files')` serves local signed URLs (403 for a bad signature). New catch-all route param `{path*}`.
- OpenAPI: `AppConfig(openApi: OpenApiConfig(...))` adds `/docs`, `/openapi.json` and `/openapi.yaml`. On by default only when `APP_ENV` is development or local. Bodies come from the route `body:` option or a DTO. `Dox().writeOpenApi(dir)` writes the files.
- `RouteData.preMiddleware` now holds the group and router middleware.
- Socket.IO: `AppConfig(socketIo: SocketIoConfig(enabled: true, ...))` serves `/socket.io/` on the app port, before the router. `Route.mount(prefix, handler)` is the raw hook. Off by default.
- No extra work per request when OpenAPI or Socket.IO is off.
- OpenAPI docs are automatic. `dart run build_runner build` writes `lib/openapi.g.dart`. Pass it as `OpenApiConfig(registry: openApiRegistry)`. Each route then gets its summary and description (from the `///` comment), tags, `Class.method` operation id, typed path params, request (a `@Dto` class) and answer schema (from the return type), plus `401`, `404`, `422` and `500`.
- A middleware whose class name ends with `AuthMiddleware` adds `bearerAuth` to the docs, with no config.
- A `GET` or `DELETE` request class becomes query params in the docs.
- `dox_core` exports `OpenApi`, `OpenApiRegistry`, `OpenApiOperation`, `OpenApiRouteBinding` and `ResponseDoc` of `dox_openapi`.
- The OpenAPI JSON and YAML are encoded once and kept, not on each request.
- New `EnvReader` and `EnvException` for the typed env class (`@DoxEnv()`). The real environment wins over `.env`, the same as `Env.get()`. `Env.get()` stays for dynamic keys.
- OpenAPI: `/docs` uses Scalar by default. `OpenApiConfig(ui: DocsUi.swagger)` gives Swagger UI. New `OpenApiConfig` options: `scalar: ScalarOptions(...)` (theme, dark mode, download button, proxy) and `pageTitle`.

## 3.0.0-alpha.1

- Version 3 of Dox. All Dox packages now share one version.
- Needs Dart 3.6 or newer.
- See the [release notes](https://github.com/dartondox/dox/pull/112) for all main changes.
- Faster: streamed bodies, all CPU cores, faster router.
- `uuid` 4 and `mime` 2.

# version 2.0.0

- Change validation {attribute} to {field}
- Restructure response handler and middleware
- Restructure app configuration
- Extract websocket as separate package `dox-websocket`
- Type improvement on usage of auth package
- Bug fix on multithread with services
- Support storage class for file storage
- Add more unit/integration test coverage
- Fix bug for websocket running on multiple isolates
- Update cache config setting on app config
- Added support for multi-thread http server which is 10x faster on concurrency request
- Added support for services (i.e database, redis) to run on each isolate/multi-thread
- Added cache class that run file driver as default 
- Added support for custom cache drivers, i.e redis, memcached
- Added `JSON.stringify()` and `JSON.parse()` that support DateTime to encode
- Added support for DateTime object on http response/return data
- Added support of size and bytes information on uploaded `RequestFile`
- Bug fixed on multipart form data file store
- Removed database config option in app config.
- Moved ioc container from `Global.ioc` to `Dox().ioc`
- Improvement on routes
- Rename Handler interface to ResponseHandlerInterface

# version 1.0.6

- Remove third party dot env package and replace with own `Env` class

# version 1.0.5

- Modify request auth getter to function to support type injection

# version 1.0.4

- Added interfaces/classes for authentication
- Bug fixed on router prefix
- Bug fixed on cookie return type `String?`

# version 1.0.3

- Ignore error on missing method of resource route
- Added single quote rule in linter

# version 1.0.2

- Bug fixed method not found on resource route

# version 1.0.1

- Added missing types on functions and arguments
- Added linter rules

# version 1.0.0

- First stable release

# version 1.0.0-alpha.2

- Support domain routing
- Improvement group routing
- Support middleware routing
- Added app level middleware support 
- Added function's self documentation
- Websocket improvement and support multiple path
- Support serializer

# version 1.0.0-alpha.1

- Added support for validation
- Added support for form data for file uploading
- Improve error handling

# version 1.0.0-alpha.0

- Refactor the code
- Added test cases
- Added support for global middleware
- Added support to throw error exception in response and add support to handle via response handler
- Rename BaseHttpException to HttpException
- Bug fixed on cookie response

# version 0.0.17

- Separate Query builder from core

# version 0.0.16

- Replace with dox query builder
- Added feature to auto encode List<Model> response
- Added resource routes
- Added `req.input()` in DoxRequest
- Added support CORS
- Added More Response options on DoxResponse
- Added `Hash.make('password')` for password encryption
- Added Support websocket
