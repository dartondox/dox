## Unreleased

- New: `ServerTiming` middleware. It adds a `Server-Timing` header with the `handler` and `total` time of the request. It is off unless you add it, because it shows timing to clients. Use it in development or for trusted clients.
- New: `ServerTiming.add(name, duration)` and `ServerTiming.measure(name, fn)` add your own timing to the current request, with no request passed. The same name is summed and counted. Without the middleware they do nothing.

- New: `AfterResponse.run(work)` runs work after the answer of the current request is sent. Any code can call it, with no request passed. It is off until `AfterResponse.enable()` (for example in the `setup()` of a provider). Errors in the work are reported and never stop the server.
- Fix: `Dox().stop()` closes the `IsolateBus` again after the providers shut down. Before, a provider that used the bus during its shutdown joined it again, and the open port could keep the process alive.
- Docs: `IsolateBus.publish` throws for a value that can not be sent, before any isolate gets it.
- Test: the `IsolateBus` through the real isolates: a crashed isolate is dropped, and the new one joins again.

## 3.1.3

- New: `IsolateBus` sends a message from one isolate to all the other isolates of the app, with no Redis. `publish(channel, message)` sends, `on(channel)` gets the messages of one channel, `size` counts the isolates that listen. The main isolate keeps the hub, like the `RateLimit` counts.
- New: `Dox().isolateCount` is the number of isolates that really run, in every isolate. It also counts `Dox().totalIsolate(n)` and the one isolate on Windows.

## 3.1.2

- Uses dox_validation 3.1.2, so `@Describe('...')` can be used on DTO fields.

## 3.1.1

- `Cache().flexible` takes a null `stale`: keep the last good value until a refresh replaces it.
- New: `Hash.sha256(value)` gives the SHA-256 hex of a value, to store API keys and access tokens as a hash (not for passwords).
- New: `ValidationException.issues` keeps every issue of a failed DTO or schema check (path, rule code, message, params). An `ExceptionHandler` can use it for another 422 shape, like `[{field, message, rule}]`.
- New: `RequestBody` and `BodyKind` are exported, so `req.requestBody.kind` can tell invalid JSON (`BodyKind.invalidJson`) from no body, without importing a file of `lib/http`.

## 3.1.0

- Behavior change: without Redis, `RateLimit` counts are now shared by all isolates. Before, each isolate counted alone, so the real limit was `max` times the number of isolates. Now `max` holds for the whole server. An app with more than one isolate gets a lower real limit than before. Raise `max` if you relied on the old number.
- Security: new check of the `Origin` header on a WebSocket upgrade. Use `Route.websocket(allowedOrigins: [...])` for one route, or `AppConfig.webSocketAllowedOrigins` for all of them. It is off by default, so apps do not change. A WebSocket route with no check prints one warning on stderr at start.
- Security fix: `back()` only follows a `Referer` of the same host. A referer of another site goes to the fallback. Before, it was an open redirect.
- Fix: a multipart body with no boundary or no `Content-Disposition` gets 400, not 500.
- Fix: the headers of `abort()` are kept on routes that have a next middleware.
- Fix: a mounted handler that throws now gives 500. Before, the client could hang.
- Fix: a download name with quotes or non-ASCII letters now gets a safe `Content-Disposition`.
- New: one warning on stderr when CORS has origin `*` together with `credentials: true`.
- New: `Crypt.encryptString` / `Crypt.decryptString` (and `Crypt.encrypt` / `Crypt.decrypt` for JSON values) use the `APP_KEY` of the app. Old keys in `previousKeys` still decrypt.
- New: `Hash.check`, the same as `Hash.verify`, with the Laravel name.
- New: `Cache().many(keys)` and `Cache().putMany(values, duration:)` on the facade. The store already had them.
- New: `MethodOverride(header: true)` also reads the `X-HTTP-Method-Override` header on a POST. It is off by default, so apps do not change.
- Fix: `Route().setStatics(Route().statics)` emptied the static folders. It cleared the list before it copied it.
- Fix: after `%` decoding, the `.where` check now lets `.` match a new line. Before, `.where('page', '.*')` did not match `/docs/a%0Ab` any more.
- `req.pathIs(pattern)` cleans each pattern once, not on every call.
- Docs: `Route.view` is the WebDAV `VIEW` method. It does not render a template like Laravel `Route::view`. `Route.where` says the value is checked again after decoding.
- Security fix: `.where` now checks the param again after `%` decoding. Before, it checked only the text as it is in the URL. So `.where('name', '[^/]+')` let `/nos/..%2F..%2Fetc%2Fpasswd` through, and the controller got `../../etc/passwd`. Now a decoded value that does not match the regex makes the route not match, like any other miss (the next route, the fallback or 404). Params with no `%` and routes without `.where` do not change.
- Security fix: `req.pathIs()` now cleans the path like the router does. Before, it only dropped the `/` at the start. So `/admin/` and `/admin//` reached the `/admin` route, but `pathIs('admin')` was false, and a middleware guard on it was skipped. Now `//` counts as one `/`, and a `/` at the end does not matter, in the path and in the pattern. A path that matched before still matches.
- Fix: with more than one isolate, `Route.staticFiles` added before `startServer()` and outside a `Router` worked only in the main isolate. A file like `/app.css` got a 404 at random. Now the static folders go to every isolate, like routes and fallbacks.
- Fix: a route with an optional param, like `/greet/{name?}`, now shows in the OpenAPI docs as both `/greet` and `/greet/{name}`. Before, only `/greet/{name}` was there, because the `?` was removed before `dox_openapi` could see it.
- Fix: `req.session.reflash()` now keeps the flash data when it is the first use of the session in a request. Before, it kept nothing, because the old flash keys were read before the session was loaded.
- Docs: `has` does not read dot keys (only `input`, `filled`, `exists`, `missing`, `boolean` and `integer` do). `Route.redirect` does not fill `{id}` in the target and drops the query string. A GET to a POST-only path gets the fallback if a fallback covers the path, else 405. A fallback added after `startServer()` does not reach the other isolates.
- With `MethodOverride`, a POST to a path with no route for any method gets 404 at once. Before, Dox read the whole body first.
- Fix: with `MethodOverride`, a POST with `_method=PUT` to a path with no PUT route now says "PUT is not allowed" in the 405 message. Before, it said "POST is not allowed".
- The router calls `Route()` once per route lookup, not twice.
- The warning for a middleware that returns `null` reads `APP_ENV` once, not on every such request.
- Fix: `Crypt.decrypt` of a value made with `Crypt.encryptString` (text that is not JSON) gave a 500 error with a `FormatException`. Now it throws `DecryptException`, a 400 error.
- Fix: in the OpenAPI docs, the short path of an optional route, like `/greet` for `/greet/{name?}`, listed a 404 "Not found" answer. It has no param, so no record can be missing. Now only `/greet/{name}` lists the 404.
- Fix: a `Route.fallback` in a group with a param in its prefix, like `{tenant}`, now matches, and `req.param` gives the param. Before, the prefix was compared as plain text, so the fallback never ran.
- Fix: `.where('id', '^[0-9]+$')` now matches. A leading `^` and a trailing `$` are dropped. Before, they ended up inside the route regex, so the route never matched.
- `req.pathIs()` and `req.routeIs()` build the regex of a pattern once, not on every call.
- Fix: `req.pathIs()` gives false for a path with a bare `%` or a bad code like `%zz`. Before, it threw an error and the client got 500.
- `req.boolean()` no longer makes a new set of true words on every call.
- New: `Route.match(methods, path, handler)` adds one route for each method in the list. `Route.any(path, handler)` adds one for GET, POST, PUT, PATCH and DELETE. OPTIONS is left out, so the CORS preflight answer still works.
- New: `Route.redirect(from, to, status:)` and `Route.permanentRedirect(from, to)`. 302 and 301.
- New: `.where(param, regex)` on a route. The route matches only when the param text matches the regex. Else the next route is tried. Routes without it match the same as before.
- New: `Route.fallback(handler)` answers a GET or HEAD request that matches no route and no static file. It runs its middleware, so in a router the global middleware runs too. It follows the group prefix and domain. The built-in 404 and 405 do not change.
- New: in development (`APP_ENV` is `development` or `local`), Dox prints a warning to stderr when a middleware returns `null`. That ends the request with an empty 200, and the controller does not run. Nothing else changes.
- New request helpers on `DoxRequest`:
  - `input(key, defaultValue)` takes a default. A dot key like `user.name` or `items.0.id` reads inside maps and lists. A key that is in the input as it is still wins, so old code works the same.
  - `filled(key)`: the key is there and not empty. `exists(key)`: the key is there, with any value. `missing(key)`: the key is not there. `has` does not change.
  - `except(keys)`, `boolean(key)`, `integer(key, defaultValue)`.
  - `file(key)` and `hasFile(key)` for uploads.
  - `bearerToken()` reads the token of an `Authorization: Bearer` header.
  - `path()`, `fullUrl()`, `pathIs(pattern)` and `routeIs(pattern)`. A `*` in the pattern matches any text. It is `pathIs`, not `is`, because `is` is a Dart keyword.
- Docs: the `abort` example now uses `req.auth?.id()`. `req.auth?.id` does not exist.
- New: `MethodOverride` middleware. Add it to `AppConfig.globalMiddleware`, and a POST request with a `_method` field of `PUT`, `PATCH` or `DELETE` goes to the route of that method. So a plain HTML form can reach `Route.put`, `Route.patch`, `Route.delete` and `Route.resource` routes. `req.method` gives the new method. `CsrfMiddleware` still checks the request. Other `_method` values and other request methods are ignored. It is off when the middleware is not there.
- Fix: `res.header(name, value)` now replaces a header with the same name in any case, like `withHeaders` does. Before, `header('Cache-Control', ..)` after `cache()` sent two `Cache-Control` values.
- Break: removed the unused `middlewareAndControllerHandler` and `getDoxRequest` helpers.
- Fix: `res.withHeaders(map)` now adds the headers to the ones set before it. Before, it dropped them all, also the `Content-Disposition` of a download. A key in the map replaces the header with the same name, in any case (`cache-control` and `Cache-Control` are one header).
- New: `SessionMiddleware().fromCookie(value)` loads a session from its cookie value, with no request. Use it for a Socket.IO login. Give the value as the browser sent it (still encrypted). It runs the same checks as the middleware: a changed cookie, a cookie of another name, a cookie made with another APP_KEY, an expired session or an unknown session id gives an empty session. Changes to it are not saved.
- New: `DoxCookie.decrypt(name, value)` decrypts a cookie value like `req.cookie(name)` does. `req.cookie` now uses it, with no change in what it accepts.
- New: `package:dox_core/command.dart` with the `Command` base class. A package or an app adds its own `dox` commands with it. Name a library with a top-level `commands` list in the `dox: commands:` key of pubspec.yaml, and the `dox` CLI finds it. It is a separate library, so it does not clash with other `Command` classes (like the one of `package:args`).
- New: `MigrationFile` in `package:dox_core/command.dart`. A command writes a migration into `db/migration` with it, with the same file name as `dox make:migration`. It does not write a second migration with the same name.
- Fix: `Route.mount` matches whole path parts only. A mount at `/admin` now gets `/admin`, `/admin/` and `/admin/...`, but no longer `/administrator` or `/admin-login`. Only requests that went to the wrong handler change. A prefix that ends in `/` (like Socket.IO's `/socket.io/`) works as before.
- Fix: `//` counts as one `/` when a path is matched to a mount prefix. So `/admin//secure/x` goes to a mount at `/admin/secure`. The handler still gets the path as it came.
- Change: when two mount prefixes match, the longest one wins. Before, the first one added won. Apps with one mount, or with mounts that do not overlap, do not change.
- New: `Route.mount(prefix, handler, middleware: true)` runs `AppConfig.globalMiddleware` (security headers, CSRF, rate limit) before the raw handler. A middleware that gives a response stops the request. `RequestTimeout` does not run for a mount. When two mount prefixes match, the longest one wins. `terminate` steps run once the answer is sent. The global CORS config does not apply to a mount. The default is still no middleware, so Socket.IO does not change.
- `RequestFile.head` now keeps the first 128 KB of a big upload (on disk), and all bytes of a small upload (in memory, no copy). Before, it kept 32 bytes. A JPEG keeps its image size after the photo metadata, so `@Dimensions` and `v.file().dimensions()` need these bytes.
- New: `Route.staticFiles(prefix, folder, maxAge:)` serves a folder (CSS, JS, images) for GET and HEAD requests that match no route. Routes always win. `..`, dot files and folders get 404. Files get `Last-Modified`, `304`, Range support, the global CORS headers and an optional `Cache-Control`. The prefix follows `Route.group`, the router prefix and `Route.domain`.
- New: `Route.staticFiles` sends a weak `ETag` (from the file size and change time). A matching `If-None-Match` gets `304` with no body. `If-None-Match` wins over `If-Modified-Since`.
- New: `Route.staticFiles` sends files in a `.well-known` folder at the top of the folder (ACME challenges, `security.txt`). Every other dot name, also inside `.well-known`, still gets `404`.
- Fix: a file response with `If-Range` now uses the `Range` only when `If-Range` is the file's `Last-Modified` date or its strong `ETag`. Else it sends the whole file with `200`, so a resumed download does not mix two versions of a file.
- Fix: a `Range`, `If-Modified-Since` or `If-None-Match` header sent on two lines no longer gives `500`.
- Fix: a static file `304` has the file's content type, not `text/plain`.
- New: `AppConfig.idleTimeout`. A keep-alive connection with no new request for this long is closed. Default 30 seconds, as before. Behind a load balancer, set it longer than the balancer's idle timeout (eg. 65 seconds for AWS ALB). Needs dox_http_native 3.0.3.
- New: `AppConfig.maxConnections`. The most connections one isolate holds open at once. Must be 1 or more (0 or less throws an `ArgumentError` when the server starts). When it is full, new clients wait in the OS listen queue until a connection closes. WebSocket connections and connections that are still closing count too. The queue holds up to 1024 clients, and the OS can make it smaller (`somaxconn`; 128 by default on macOS). When the queue is full, new clients wait and then time out. On Linux each new client goes to one isolate (`SO_REUSEPORT`), so it can wait for a full isolate even when others have room. Default no limit, as before. Needs dox_http_native 3.0.3.
- New: `Route.websocket(maxMessageSize:)`. A bigger message closes the socket with 1009. Default 16 MB, as before.

## 3.0.2

- Change: a Redis cache store with no `prefix` gets `<app name>_cache:` from `APP_NAME` (like `my_shop_cache:`), so two apps on one Redis do not share keys or flush each other's cache. Existing Redis cache keys are not found once after the update. Rate limit counters, cache locks and `cache` driver sessions start fresh, so users with a `cache` driver session log in again. Set `'prefix': 'dox_cache:'` on the store to keep the old keys.
- New: the `Cache()` facade has `flexible` and `touch`, and `remember` / `rememberForever` take `decode` and `lock`.
- Perf: the route binder does not load a value again when a middleware already bound it, like `Can(param: 'post')` of dox_auth.
- New: `RequestId` middleware. Each request gets an id in the `X-Request-Id` header and in `req.requestId`. A safe id from the client is kept. `LogMiddleware` lines have `request_id`, and `ExceptionHandler.report` can read `ExceptionHandler.requestId`.
- New: `ETag` middleware. GET and HEAD answers with a body in memory get a weak `ETag`. A matching `If-None-Match` gets `304 Not Modified` with no body.
- New: signed urls. `Route.signedUrl(name, params:, query:, expires:, absolute:, baseUrl:)` adds a `signature` (HMAC-SHA256 with the `dox:signed-url` key) and an optional `expires`. The `ValidateSignature` middleware answers `403` for a bad or expired url. Old keys from `AppConfig.previousKeys` still work.
- New: `RequestTimeout(Duration)` middleware and `Route.get(...).timeout(Duration)`. A slow route answers `503` with the code `request_timeout`. The late result is dropped.
- New: `IDoxTerminableMiddleware`. Its `terminate(req, res)` runs after the answer is sent. An error in it is reported, and never changes the answer. Routes without one do not pay for it.
- Fix: a middleware item with no `handle` step at the start of a route list ended the request with an empty answer. It is now skipped.

## 3.0.1

- Perf: `AESEncryptor` (encrypted cookies, the cookie session, CSRF) now runs AES-GCM in Rust (`AesGcm` of dox_http_native 3.0.2), with the AES instructions of the CPU. One session cookie took about 116 µs to encrypt and 95 µs to decrypt, now about 1.7 µs and 0.9 µs. The output is the same, so cookies made before still open.
- Removed the `pointycastle` dependency. HKDF now uses HMAC-SHA256 of `package:crypto` (from the Dart team). The keys are the same.
- New: a path that has routes, but not for the request method, answers `405 Method Not Allowed` with an `Allow` header (like `Allow: GET, POST, HEAD`). Before, it was `404`.
- New: `abort(code, [message, headers])` and `HttpStatusException(code)` for any status. Common codes get a default `errorCode` and `message`. The `headers` are sent with the answer.
- New: `ForbiddenHttpException` (403) and `MethodNotAllowedHttpException` (405).
- New: bracket keys in form bodies and query strings nest, like in Laravel. `tags[]=a&tags[]=b` gives `req.input('tags') == ['a', 'b']`, and `address[city]=x` gives a map. A repeated key with no brackets still keeps its last value.
- New: `AppConfig(previousKeys: [...])`. Encrypted cookies and cookie sessions made with an old `APP_KEY` can still be read, so a new key does not log out every user. `AESEncryptor.decode` has a new `previousSecrets` option.
- Fix: path params are now URL-decoded. `/users/a%20b` gives `'a b'`, not `'a%20b'`. A URL from `Route.url()` now gives back the same value. A param that is not valid UTF-8 (like `%ff`) gives 404.
- Fix: 5xx HTTP exceptions (like `InternalErrorException` and `QueryException`) are now sent to `ExceptionHandler.report`. Before, every `IHttpException` was skipped, so real server errors never reached the logs or Sentry. 4xx exceptions are still not reported.
- Fix: `req.headers` joins repeated header values with `, `. Before, two `Accept` values became one string with no separator.
- Fix: a `Range` header with a number too big for an int gave 200 with an empty body. A start that is too big now gives 416, and a suffix that is too big gives the whole file.
- Fix: `req.method` is now the request method. A HEAD request on a GET route said `GET`.
- Fix: on a route with no params, a write to `req.param` stayed for the next requests to that route. Each request now has its own map.

## 3.0.0

- The first stable release.

## 3.0.0-rc.1

- Breaking: Dox no longer uses `APP_KEY` as it is. It makes one key per purpose from it with HKDF-SHA256 (RFC 5869): `dox:cookie` for cookies and the cookie session, `dox:encrypt` for `AESEncryptor`, and more. See the new `KeyDerivation` class. Existing encrypted cookies, sessions and tokens become invalid after this version. Users must log in again.
- `AESEncryptor.encode` and `decode` take a `purpose` label. The default is `dox:encrypt`. The secret can now have any length.
- Fix: `Hash.make` and `Hash.makeAsync` with a password over 72 bytes threw the bcrypt error, and its text held the password. So the password could end up in the logs. Dox now throws its own `ArgumentError` with no password in the text.
- New: `Hash.equals(a, b)` compares two secrets in constant time. `CsrfMiddleware` uses it.
- Fix: the `cookie` session driver did not check the save time in the cookie. A copied cookie stayed valid until `APP_KEY` changed. A session older than `lifetime` is now a new empty session.
- Breaking: `req.auth` is now its own field on the request, not a value in the input. Before, a query or body field `dox_authentication_instance` made `req.auth` throw a 500. `AUTH_REQUEST_KEY` is removed. Use `Auth().setUser(req, user)` or set `req.auth`.
- Fix: `APP_ENV=testing` stopped the app on a bad `APP_KEY`. It is now treated like `test`: only a warning.
- `Logger` is now exported from `package:dox_core/dox_core.dart`.
- The HTTP exceptions (`NotFoundHttpException` and the others) take a `dynamic message`, like `IHttpException`. A map message is sent as JSON as it is, like `NotFoundHttpException(message: {'error': 'not_found'})`.
- Security: the server now sends `X-XSS-Protection: 0`, not `1; mode=block`. OWASP says the old browser filter should be off. `SecurityHeaders` has a new `xssProtection` option. A `null` option (or a `null` value in `extra`) now removes the header, also a server default like `X-Frame-Options`.
- Security: `CsrfMiddleware` no longer reads `_token` from the query string. It reads only the body and the `X-CSRF-TOKEN` / `X-XSRF-TOKEN` headers.
- Doc comments: fixed the examples of `Cache.remember`, `Route.domain`, `Route.middleware` and `Route.disabledCors`.

## 3.0.0-alpha.17

- Version bump only, to match the other packages.

## 3.0.0-alpha.16

- Version bump only, to match the other packages.

## 3.0.0-alpha.15

- Change: the startup hook is `DoxProvider`. Write `class X extends DoxProvider`. `setup()` runs once in every isolate at start. `shutdown()` is optional and runs once in every isolate when the app stops. List providers in `AppConfig.providers`, or add them with `Dox().addProvider()` and `Dox().addProviders()`. The container method is `c.provider<T>()`.

## 3.0.0-alpha.14

- Fix: `AUTH_REQUEST_KEY` is now only in `dox_core`, so importing `dox_core` and `dox_auth` together no longer gives an "ambiguous import" error.
- Fix: `response(x).header('Content-Type', 'image/svg+xml')` failed with "More than one value for header content-type". The default `text/plain` stayed next to the new type. Now `header()` replaces the content type, the same as `contentType()`. The name can be in any case.
- Fix: when sending the error answer failed too, the client got no answer and waited until the timeout. Now Dox reports the error and sends a plain 500. When the head is already sent, it closes the response.
- New: `.env.testing`. When the app runs its tests (`dart test`, or a real `APP_ENV=testing`), Dox reads `.env.testing` on top of `.env`. Its keys win over `.env`. A real environment variable still wins over both. It works for `Env.get()` and the typed `AppEnv.load()`. Use it for a test database: `DB_NAME=my_app_test`. New `Env.isTesting`, and `Env().load(testing: true)`.
- New: `DoxTestClient.withSession()` gives a test client that works like a browser. It keeps the cookies of every response, removes deleted or expired ones, and sends the `XSRF-TOKEN` cookie back in `X-XSRF-TOKEN` on `POST`, `PUT`, `PATCH` and `DELETE`. It does not follow redirects. `client.cookies` gives the kept cookies. The normal client does not change.
- Fix: `OpenApiConfig(enabled: null)` now treats an empty `APP_ENV` as `development`, the same default as `appEnv` of the typed env. Before, `/docs` was off when `APP_ENV` was not set (for example in CI). Set `APP_ENV=production` in production.
- Change: an empty `APP_ENV` means production everywhere in Dox: `/docs` is off, the 500 error text is hidden and a bad `APP_KEY` stops the app. Set `APP_ENV=development` in your `.env` and in CI. The `appEnv` default of the typed env in the docs and examples is now `production` too (was `development`).
- New: `@Security` on a middleware class sets the login scheme of its routes in the OpenAPI docs. `OpenApiConfig.securityByMiddleware` still wins over it.
- Change: a middleware class name that ends with `AuthMiddleware` (and has no `@Security`) now gets a `bearerAuth` scheme with no `bearerFormat`. Before, the docs called every such token a JWT.

## 3.0.0-alpha.13

- New: `OpenApiConfig(include: ['/api/*'], exclude: ['/api/internal/*'])` picks which routes go in the OpenAPI docs by path. A `*` at the end matches the rest of the path.

## 3.0.0-alpha.12

- Breaking: `dox_core` no longer depends on `dox_storage` and `dox_socketio`. Add the package you use to your app.
  - Storage: `Storage()`, `StorageConfig` and `StorageDiskFactory` moved to `dox_storage`. `AppConfig.storage` is removed: extend `StorageService` from `dox_storage` (`class AppStorageService extends StorageService { AppStorageService() : super(storageConfig); }`). `Route.files()` is now `Storage.route()`. `Dox().storage` is now `Storage.manager`. `RequestFile.store()` needs `import 'package:dox_storage/dox_storage.dart'`.
  - Socket.IO: `SocketIoConfig` moved to `dox_socketio`. `AppConfig.socketIo` is removed: extend `SocketIoService` from `dox_socketio`. `Dox().socketIo` is now `SocketIoService.server`.
  - `dox_core` no longer exports `Disk`, `DriveManager`, `FileNotFoundException` and `StorageException`. Import them from `dox_storage`.
  - `StreamFile` and `DownloadableFile` stay in `dox_core`.
- Fix: the OpenAPI docs could give a route the docs of another controller with the same method name. The docs now pass the controller class of `(C c) => c.method` and `Route.get<C>` routes to the registry.
- New: `ControllerAction.controller` gives the controller class.

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
