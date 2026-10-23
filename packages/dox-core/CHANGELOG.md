## Unreleased

- Security: `Storage().putRequestFile()` and `RequestFile.store()` no longer trust the client file name when the bytes are a known format that does not match it. Before, a valid png sent as `a.html` passed `@Image`/`@Mimes` and was saved as `.html`, so `Route.files()` served it as `text/html` on the app origin (stored XSS). Now it is saved with the extension of the bytes (`.png`).
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
