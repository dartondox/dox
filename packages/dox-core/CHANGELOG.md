## Unreleased

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
