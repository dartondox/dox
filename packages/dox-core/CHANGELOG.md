## Unreleased

- Needs Dart 3.13 or newer.
- All dependencies updated to their latest versions.
- Removed the `encrypt` package (not maintained, and it blocked `pointycastle` 4). AES for cookies and the file cache now uses `pointycastle` 4. The output is the same, so old cookies and cache files still decode.
- Fix: `Env.get()` of a missing key with no default gave the text `"null"`. A missing `APP_KEY` became the key `"null"`, which anyone can guess. Now `String` gives `''`, `String?` gives `null`, and `int`/`num`/`double`/`bool` throw a clear error. New: `Env.get<bool>()`.
- Startup stops with an error when `APP_KEY` is empty and `APP_ENV=production`. Other environments log a warning.
- Validation runs on `dox_validation`. The old validator code is removed. Messages and the `{field: message}` error map are the same.
- `req.validate()` returns the validated fields. New `await req.validateAsync()` for async rules, and `await req.validateSchema(schema)` for typed output.
- New rules `unique:table,column` and `exists:table,column` (from `dox_orm`).
- `FormRequest.schema()`: a fluent schema used before `rules()`. The result is in `validated`. Form requests run async rules.
- `RequestFile` implements `FileInput`, so `v.file()` and the `file` / `image` rules work.
- A `ValidationException` from `dox_validation` (for example `schema.parse()` in a controller) answers 422.
- `dox_core` exports `dox_validation` (not its `ValidationException`). `dox_orm` also has `Schema`: use a prefix in a file that needs both.
- Breaking: `Cache()` runs on `dox_cache`. `AppConfig.cache` is a `dox_cache` `CacheConfig(defaultStore:, stores:)` with option maps. `CacheDriverInterface` and `FileCacheDriver` are removed. Values must be JSON types. `put` without a duration keeps the value forever (was 1 hour). New: `add`, `pull`, `increment`, `decrement`, `remember`, `rememberForever`, `lock`, `tags`.
- Breaking: `Storage()` runs on `dox_storage`. `AppConfig.fileStorage` is now `AppConfig.storage` (`StorageConfig(defaultDisk:, disks:)` with option maps for `local`, `s3`, `memory`). `StorageDriverInterface` and `LocalStorageDriver` are removed. An unknown disk name throws.
- `Storage().stream()` and `download()` stream from any disk (S3 too), with `Content-Length`. New: `url`, `signedUrl`, `use()` for the full `Disk`.
- New `Route.files('files')` serves local signed URLs (403 for a bad signature). New catch-all route param `{path*}`.
- OpenAPI: `AppConfig(openApi: OpenApiConfig(...))` adds `/docs`, `/openapi.json` and `/openapi.yaml`. On by default only when `APP_ENV` is development or local. Bodies come from the route `body:` option or the form request. `Dox().writeOpenApi(dir)` writes the files.
- `RouteData.preMiddleware` now holds the group and router middleware.
- Socket.IO: `AppConfig(socketIo: SocketIoConfig(enabled: true, ...))` serves `/socket.io/` on the app port, before the router. `Route.mount(prefix, handler)` is the raw hook. Off by default.
- No extra work per request when OpenAPI or Socket.IO is off.


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
