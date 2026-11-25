---
icon: lucide/settings
---

# App config

This page lists every field of `AppConfig`, with its type, its default and what it does.

You give `AppConfig` to `Dox().initialize()` in `lib/config/app.dart`. Each field has a default except `appKey`. See the [full example](#full-example).

## Server

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `appKey` | `String` | required | Encrypts cookies and signs local storage URLs. It must be exactly 32 characters. Make one with `dox key:generate`. In production a bad key stops the app at start, see [`APP_ENV`](env.md#read-by-the-framework). |
| `previousKeys` | `List<String>` | `[]` | Old app keys. Dox can still read data that was encrypted with them. New data uses `appKey` only. See [Rotating the key](../security/encryption.md#change-the-key-key-rotation). |
| `serverPort` | `int` | `3000` | The port to listen on. When the env has no `APP_PORT` but has `PORT`, Dox uses `PORT` (Cloud Run, Fly, Render and Heroku set it). |
| `host` | `String?` | `null`: `APP_HOST`, else all interfaces | The network interface to listen on, like `127.0.0.1`. `null` reads `APP_HOST`. With neither, Dox listens on all interfaces (`::`). |
| `totalIsolate` | `int?` | the CPUs the container allows | How many isolates serve HTTP, all on the same port. The default is the number of CPUs this process can use, with the container cpuset and CPU quota. A quota rounds up (1.5 CPUs gives 2 isolates). Windows always uses one. |
| `computeWorkers` | `int` | `AppConfig.defaultComputeWorkers` (4) | How many worker isolates run `Dox().compute`, `Hash.makeAsync` and `Hash.verifyAsync`, in one pool for the process. It must be 1 or more. See [Heavy CPU work](../digging-deeper/isolate.md#heavy-cpu-work). |
| `compress` | `bool` | `false` | gzip the responses, but not streamed responses. It costs CPU on each response, so let a proxy do it if you have one. |
| `maxBodySize` | `int` | `10 * 1024 * 1024` (10 MB) | Biggest JSON or urlencoded body in bytes. Bigger gets `413`. |
| `maxMultipartSize` | `int` | `100 * 1024 * 1024` (100 MB) | Biggest `multipart/form-data` body (file uploads) in bytes. Bigger gets `413`. |
| `bodyTimeout` | `Duration` | `Duration(seconds: 120)` | A client that sends no body bytes for this long gets `408`. A slow but steady upload is fine. |
| `idleTimeout` | `Duration` | `Duration(seconds: 30)` | A keep-alive connection with no new request for this long is closed. Behind a load balancer, set it longer than the balancer's idle timeout. See [Behind a load balancer](../digging-deeper/deployment.md#behind-a-load-balancer). |
| `maxConnections` | `int?` | `null` (no limit) | The most connections one isolate holds open at once (1 or more). When it is full, new clients wait in the OS queue. The app holds up to `maxConnections * totalIsolate`, so keep that below `ulimit -n`. |
| `http2` | `bool` | `false` | The same port also speaks HTTP/2 over plain TCP (h2c). HTTP/1.1 keeps working. See [HTTP/2](../digging-deeper/http2.md). |
| `maxConcurrentStreams` | `int` | `250` | The most open requests one HTTP/2 connection can have (1 or more). Used only when `http2` is `true`. |
| `shutdownTimeout` | `Duration` | `Duration(seconds: 8)` | On `SIGTERM` or `SIGINT`, how long open requests may run before Dox closes them. Keep it below the kill timeout of your platform. See [Graceful shutdown](../digging-deeper/deployment.md#graceful-shutdown). |
| `trustedProxies` | `List<String>` | `[]` | IPs or CIDR ranges of your reverse proxies. Dox reads `X-Forwarded-For` (for `req.ip()`) and `X-Forwarded-Proto` (for `req.scheme()`) only from these. `['*']` trusts any direct client, but only the last hop. Use it only when the app port is not open to the outside. |
| `isDevelopment` | `bool` (getter) | | True when `APP_ENV` is development. It reads the env at each call, so it works before the server starts. Use it in config, like a database `debug` flag. |

## Routing and request handling

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `container` | `void Function(IocContainer)?` | `null` | Pass `registerContainer` from `lib/generated/container.g.dart`. It fills the container, and also gives the routers, providers and model binders. See [Dependency injection](../the-basic/dependency-injection.md). |
| `routers` | `List<Router>` | `[]` | Routers to register first, in this order. Every other `Router` class comes from `container`. |
| `globalMiddleware` | `List<dynamic>` | `[]` | Middleware that runs on every route. A function or an `IDoxMiddleware`. |
| `dtos` | `List<DtoSchema<Object>>` | `[]` | Pass `dtos` from `lib/generated/dtos.g.dart`. Dox finds the DTOs of controllers and `req.validate<T>()` in it. |
| `validationMessages` | `MessageResolver?` | `null` (English messages) | Messages for validation errors, for example in other languages. |
| `responseHandler` | `ResponseHandlerInterface?` | `null` | A class with `DoxResponse handle(DoxResponse res)`. It sees every response before it is sent. |
| `exceptionHandler` | `ExceptionHandler` | `ExceptionHandler()` | Reports every unhandled error and turns it into a response. The default logs the error and the stack. See [Error handling](../the-basic/errors.md). |
| `htmlErrors` | `bool` | `false` | Sends an HTML error page to a request that does not want JSON. In `development` or `local` the page also shows the error and the stack. JSON clients do not change. See [An HTML error page](../the-basic/errors.md#an-html-error-page). |
| `errorPage` | `String Function(int status, Object error, StackTrace stack, bool debug)` | `defaultErrorPage` | Makes the HTML of the page. `debug` is `true` in `development` or `local`. Escape every value you put in the page. Used only with `htmlErrors`. |
| `providers` | `List<DoxProvider>` | `[]` | Providers to run first, in this order. Every other `DoxProvider` class comes from `container`. Dox runs them in every isolate at start. |
| `webSocketAllowedOrigins` | `List<String>?` | `null` (no check) | Checks the `Origin` of each `Route.websocket` route. Only the same host and the listed sites, like `https://app.example.com`, can open a socket. Others get `403`. `[]` means the same host only. With `null`, any website can open a socket with the cookies of the user. The `allowedOrigins` of a route wins. |

## Sub configs

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `cors` | `CORSConfig` | `CORSConfig()` | CORS headers. See [CORSConfig](#corsconfig). |
| `logger` | `LoggerConfig` | `LoggerConfig()` | The `Logger` output. See [LoggerConfig](#loggerconfig). |
| `cache` | `CacheConfig` | `file` store in `storage/cache`, plus a `memory` store | Cache stores for `Cache()`. See [CacheConfig](#cacheconfig). |
| `session` | `SessionConfig` | `cookie` driver, cookie `dox_session`, 2 hours | Settings for `SessionMiddleware`. See [Session](../the-basic/session.md#configuration). |
| `openApi` | `OpenApiConfig` | `OpenApiConfig()` | `/docs`, `/openapi.json` and `/openapi.yaml`. See [OpenApiConfig](#openapiconfig). |
| `strict` | `StrictConfig` | `StrictConfig()` (off) | Warnings for code that blocks the server, for development. `enabled` turns it on. `blockLimit` is how long code can block an isolate before a warning, `StrictConfig.defaultBlockLimit` (50 ms) by default. See [Let Dox warn you](../digging-deeper/performance-mistakes.md#let-dox-warn-you). |
| `flags` | `CoreFlags` | `CoreFlags()` (all off) | Opt-in core behaviors. See [Core flags](#core-flags). |

## Core flags

`CoreFlags` turns on extra behaviors. Each flag is off by default:

```dart
AppConfig(
  appKey: env.appKey,
  flags: const CoreFlags(onlyPresent: true, cookieDefaults: true),
);
```

`CoreFlags.all()` turns on every flag:

```dart
AppConfig(appKey: env.appKey, flags: const CoreFlags.all());
```

| Flag | When it is on |
| --- | --- |
| `laravelErrors` | A `422` body is `{"message": "...", "errors": {"field": ["..."]}}`, with all messages of each field. The OpenAPI docs use this shape too. Off: `{"field": "first message"}`. |
| `onlyPresent` | `req.only([...])` leaves out keys that are not in the input. So `model.update(req.only([...]))` does not write `null` for a field the client did not send. Off: a missing key is in the map with `null`. |
| `cookieDefaults` | A `DoxCookie` with no `path` gets `Path=/`, and one with no `sameSite` gets `SameSite=Lax`. A value you set wins. Off: no `Path` and no `SameSite`. |
| `hasKeyOnly` | `req.has('x')` is `true` when the key is there, with any value (also `''` or null), like `req.exists('x')`. Dot keys work. Off: `''` and null give `false`. |
| `htmlStrings` | A string from a controller is sent as `text/html`. A content type you set wins. Escape user input in the string. Off: `text/plain`. |
| `replaceHeaders` | `res.header(k, v)` replaces a value that a middleware set before. `Vary` and `Set-Cookie` still get one more value. Off: it adds a second value. Pass `replace:` to pick for one call. |
| `decryptServerError` | A `DecryptException` gives a `500` `server_error`, and the `ExceptionHandler` reports it. Off: `400` `decrypt_failed`, not reported. |
| `envExpand` | `.env` values can use `${OTHER}`, and a `"..."` value reads `\n`, `\t`, `\"`, `\\` and `\$`. Also set `Env.flags = flags;` at the top of `main()` in `bin/server.dart` and in your tests, because `.env` is read before `AppConfig` exists. See [Use one value in another](../digging-deeper/env.md#use-one-value-in-another). Off: values are read as written. |
| `rateLimitIpv6Prefix` | The default key of `RateLimit` counts an IPv6 client by its /64 prefix. One home or server gets a whole /64, so with one count per address a client gets a new count with each new address. Clients in one /64 share a count. A `key` you give is used as it is. Off: each full ip has its own count. See [Rate limiting](../security/rate-limiting.md#ipv6-clients). |
| `cacheCopies` | `Cache().store('x')`, `.tag()` and `.tags()` give a new `Cache`, and the first one does not change. Off: they change the same object and give it back. |

The cache has its own flag class, `CacheFlags`, in [`CacheConfig`](#cacheconfig).

## CORSConfig

A value can be a string (`'*'` or a comma list) or a list of strings. A null value sends no header, so set at least `origin`.

| Field | Type | Default | Header |
| --- | --- | --- | --- |
| `enabled` | `bool` | `true` | Send CORS headers. A route can override it with its own `cors` setting. |
| `origin` | `dynamic` | `null` | `Access-Control-Allow-Origin`. One origin, `'*'`, or a list. With a list, Dox sends back only the request origin if it is in the list. |
| `methods` | `dynamic` | `null` | `Access-Control-Allow-Methods` |
| `headers` | `dynamic` | `null` | `Access-Control-Allow-Headers` |
| `exposeHeaders` | `dynamic` | `null` | `Access-Control-Expose-Headers` |
| `credentials` | `bool?` | `null` | `Access-Control-Allow-Credentials`. Browsers refuse it with origin `'*'`, so list your sites in `origin`. |
| `maxAge` | `num?` | `null` | `Access-Control-Max-Age` in seconds |

## LoggerConfig

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `name` | `String` | `''` | Written as `logger.name` in each JSON log line. Left out when empty. |
| `enabled` | `bool` | `false` | Turn the `Logger` on. When it is off, `LogMiddleware` logs nothing too. |
| `prettyPrint` | `bool` | `false` | `true` prints colored text. Each line starts with a tag that says where it comes from, like `[request]`, `[server]` or `[app]`. `false` prints one JSON object per line, for log services. The tag is then in the `source` field, unless your data already has a `source` key. |
| `level` | `String` | `'info'` | The lowest level to print: `debug`, `info`, `warn` or `error`. `success` counts as info, and `danger` as error. |

Your own lines get the tag `[app]`. To use another tag, give it as the third argument of `log`, `info`, `warn`, `success` or `danger`:

```dart
Logger.info('invoice sent', null, 'billing');
```

In JSON mode the tag is the `source` field. Plain warnings on stderr use the same tags.

## CacheConfig

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `defaultStore` | `String` | required | The store `Cache()` uses when no store is named. |
| `stores` | `Map<String, Map<String, dynamic>>` | required | Store name to options. Each store needs a `driver` option. |
| `flags` | `CacheFlags` | `CacheFlags()` (all off) | Opt-in cache behaviors. See below. |
| `encrypter` | `CacheEncrypter?` | `null` | Encrypts stores with `'encrypt': true`. Dox sets it. You need it only [without Dox](../digging-deeper/cache.md#encryption-without-dox). |

`CacheFlags` has one flag. `CacheFlags.all()` turns it on.

| Flag | When it is on |
| --- | --- |
| `lockThrows` | `lock.block(timeout)` with no callback throws `LockTimeoutException` when the lock was not taken in time. Off: it gives `false`. Set `lock.throwOnTimeout` to pick for one lock. |

```dart
CacheConfig(
  defaultStore: 'redis',
  stores: stores,
  flags: const CacheFlags(lockThrows: true),
);
```

Options of each driver:

| Driver | Option | Type | Default | Meaning |
| --- | --- | --- | --- | --- |
| all | `driver` | `String` | required | `file`, `memory`, `redis`, `database` or `null` |
| all | `prefix` | `String` | `dox_cache:` (`<app name>_cache:` on Redis) | Text in front of each key. |
| `file`, `redis`, `database` | `encrypt` | `bool` | `false` | Encrypt the values with the app key. |
| `file` | `path` | `String` | `storage/cache` | Folder of the cache files. |
| `file` | `prune_every` | `int` | `0` | Run `prune()` once every this many writes. `0`: a light prune at most once an hour. |
| `file` | `fsync` | `bool` | `true` | Sync each write to the disk. `false` is faster, but a power cut can lose the last writes. |
| `memory` | `max_size` | `int` | no limit | Most items in the map. |
| `redis` | `host` | `String` | `127.0.0.1` | Redis host. |
| `redis` | `port` | `int` | `6379` | Redis port. |
| `redis` | `username` | `String` | none | Redis user. |
| `redis` | `password` | `String` | none | Redis password. |
| `redis` | `db` | `int` | `0` | Redis database number. |
| `redis` | `tls` | `bool` | `false` | Use TLS. |
| `redis` | `pool_size` | `int` | `10` | Most connections per store. |
| `redis` | `max_value_bytes` | `int` | no limit | Biggest value in bytes. |
| `redis` | `options` | `RedisOptions` | none | All client options. See [Redis options](../digging-deeper/cache.md#redis-options). |
| `database` | `table`, `connection`, `prune_interval` | | | See [Database store](../digging-deeper/cache.md#database-store). |

## StorageConfig

`StorageProvider` of the `dox_storage` package takes it. See [File storage](../digging-deeper/file-storage.md).

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `defaultDisk` | `String` | `'local'` | The disk `Storage()` uses when no disk is named. |
| `disks` | `Map<String, Map<String, dynamic>>` | `{'local': {'driver': 'local', 'root': 'storage'}}` | Disk name to options. Each disk needs a `driver` option. |

Options of each driver:

| Driver | Option | Type | Default | Meaning |
| --- | --- | --- | --- | --- |
| all | `driver` | `String` | required | `local`, `s3`, `azure` or `memory` |
| `local` | `root` | `String` | `storage` | Folder of the files. |
| `local` | `url` | `String` | none | Base of the public URLs, like `http://localhost:3000/files`. |
| `local` | `app_key` | `String` | `AppConfig.appKey` | Key that signs the URLs. |
| `local` | `visibility` | `String` | `public` | `public` or `private`. |
| `local` | `atomic_writes` | `bool` | `false` | Write to a temp file, then rename it. |
| `local` | `permissions` | `bool` or `Map` | off | Visibility is the file mode. See [File storage](../digging-deeper/file-storage.md#visibility-on-a-local-disk). |
| `s3` | `bucket` | `String` | required | Bucket name. |
| `s3` | `region` | `String` | `us-east-1` | Region. |
| `s3` | `key` | `String` | required | Access key id. |
| `s3` | `secret` | `String` | required | Secret access key. |
| `s3` | `token` | `String` | none | Session token. |
| `s3` | `endpoint` | `String` | none | Custom endpoint (R2, MinIO, Spaces). |
| `s3` | `path_style` | `bool` | `false` | Use path style URLs. |
| `s3` | `url` | `String` | none | Base of the public URLs. |
| `s3` | `visibility` | `String` | `private` | `public` or `private`. |
| `s3` | `acl` | `bool` | `true` | The service supports ACLs. |
| `s3` | `batch_delete` | `bool` | `true` | The service supports batch delete. |
| `azure` | `account` | `String` | required | Name of the storage account. |
| `azure` | `key` | `String` | required | Account key (base64). |
| `azure` | `container` | `String` | required | Blob container. The driver does not create it. |
| `azure` | `endpoint` | `String` | none | URL of the blob service, without the container. For Azurite: `http://127.0.0.1:10000/devstoreaccount1`. |
| `azure` | `url` | `String` | none | Base of the public URLs. |

## OpenApiConfig

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `enabled` | `bool?` | `null` | Serve the docs routes. `null` means on only in `development` or `local`. |
| `info` | `Info` | `Info(title: 'Dox API', version: '1.0.0')` | Title and version of the API. |
| `servers` | `List<Server>` | `[]` | Base URLs of the API. |
| `securitySchemes` | `Map<String, SecurityScheme>` | `{}` | Ways to log in, like `{'bearerAuth': SecurityScheme.bearer()}`. |
| `securityByMiddleware` | `Map<String, List<Map<String, List<String>>>>` | `{}` | Security for routes that use a middleware class with this name. It wins over `@Security` on the class. A middleware whose class name ends with `AuthMiddleware` gets `bearerAuth` when it has no `@Security` and no entry here. |
| `registry` | `OpenApiRegistry` | `OpenApiRegistry()` (empty) | What `dox_builder` found in the code. Pass `openApiRegistry` from `lib/generated/openapi.g.dart`. |
| `ui` | `DocsUi` | `DocsUi.scalar` | `scalar` or `swagger`. |
| `scalar` | `ScalarOptions` | `ScalarOptions()` | Options of the Scalar page. See below. |
| `pageTitle` | `String?` | `null` (uses `info.title`) | Title of the `/docs` page. |
| `include` | `List<String>` | `[]` (all routes) | Only routes with these paths are in the docs, like `['/api/*']`. A `*` at the end matches the rest of the path. |
| `exclude` | `List<String>` | `[]` | Routes with these paths are left out. Checked after `include`. |

`ScalarOptions`:

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `theme` | `ScalarTheme` | `ScalarTheme.default_` | One of `default_`, `alternate`, `moon`, `purple`, `solarized`, `bluePlanet`, `deepSpace`, `saturn`, `kepler`, `elysiajs`, `fastify`, `mars`, `laserwave`, `none`. |
| `darkMode` | `bool` | `false` | Start in dark mode. |
| `showDownloadButton` | `bool` | `true` | Show the download button for the OpenAPI document. |
| `proxyUrl` | `String?` | `null` | Send "Try it" requests through this proxy. |

## SocketIoConfig

`SocketIoProvider` of the `dox_socketio` package takes it. See [Socket.IO](../packages/socketio.md).

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `enabled` | `bool` | `true` | Mount Socket.IO on the HTTP port at `/socket.io/`. |
| `options` | `ServerOptions` | `ServerOptions()` | Engine options. See below. |
| `namespaces` | `List<NamespaceHandler>` | `[]` | Namespaces to register, like `ChatNamespace()`. |
| `adapter` | `SocketAdapterFactory?` | `null` (in memory with one isolate, `IsolateAdapter` with many) | Makes the adapter in each isolate. Use a Redis adapter with many servers. |

`ServerOptions`:

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `path` | `String` | `/socket.io/` | URL path. Must end with `/`. |
| `pingInterval` | `Duration` | 25 s | Time between two server pings. |
| `pingTimeout` | `Duration` | 20 s | Time to wait for a pong before the session is closed. |
| `upgradeTimeout` | `Duration` | 10 s | Time a websocket upgrade may take. |
| `connectTimeout` | `Duration` | 45 s | Time a client has to join a namespace after the handshake. |
| `maxHttpBufferSize` | `int` | `1000000` | Biggest message in bytes a client may send. |
| `maxAttachments` | `int` | `10` | Most binary attachments in one packet. A packet with more closes that client. |
| `transports` | `List<String>` | `['polling', 'websocket']` | Allowed transports. |
| `allowUpgrades` | `bool` | `true` | Allow upgrades from polling to websocket. |
| `cors` | `CorsOptions?` | `null` (no CORS headers) | CORS for the long-polling requests. |

`CorsOptions`:

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `origins` | `List<String>` | `['*']` | Allowed origins. |
| `credentials` | `bool` | `false` | Send `Access-Control-Allow-Credentials: true`. |
| `methods` | `List<String>` | `['GET', 'POST']` | Allowed methods for preflight. |
| `allowedHeaders` | `List<String>?` | `null` (the requested headers) | Allowed request headers. |
| `maxAge` | `Duration?` | `null` | How long a browser may cache the preflight answer. |

## DatabaseConfig

The database is not a field of `AppConfig`. A provider calls `SqlQueryBuilder.initializeWithDatabaseConfig(databaseConfig)` in its `setup()`.

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `connection` | `String` | required | Name of the connection to use. |
| `connections` | `Map<String, ConnectionConfig>` | required | Connection name to config. |

`ConnectionConfig`:

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `driver` | `Driver` | required | `Driver.postgres`, `Driver.mysql` (also MariaDB) or `Driver.sqlite`. |
| `host` | `String` | `'localhost'` | Database host. Not used by sqlite. |
| `port` | `int` | `0` | Database port. Not used by sqlite. |
| `user` | `String` | `''` | Database user. Not used by sqlite. |
| `password` | `String` | `''` | Database password. Not used by sqlite. |
| `database` | `String` | required | Database name. For sqlite: the file path, or `:memory:`. |
| `useSSL` | `bool` | `false` | Use TLS. Postgres: mode `require` (no certificate check), set `extra['sslMode']` to change it. MySQL: the certificate is checked. |
| `debug` | `bool` | required | Print every query with `printer`. |
| `printer` | `QueryPrinter?` | `null` | `ConsoleQueryPrinter()`, `PrettyQueryPrinter()`, `FileQueryPrinter(file: File('queries.log'))` or your own. With `buffered: true`, call `await printer.flush()` before `exit()`, or the last lines are lost. |
| `logRedact` | `List<String>` | `[]` | Names of values to hide in the query log. A value shows as `***` when its key ends with one of these names. `['password', 'token']` hides `password`, `users.password` and `remember_token`. Only the log changes. |
| `slowQueryMs` | `int?` | `null` | Log each query that takes longer than this many milliseconds. `0` logs every query. `null` turns it off. It works with `debug` off. |
| `read` | `List<Map<String, dynamic>>?` | `null` | Read replica hosts. Each map can change `host`, `port`, `user`, `password`, `database` and `extra`. See [Read replicas](../database/replicas.md). |
| `write` | `Map<String, dynamic>?` | `null` | Settings of the write host, in the same form as one `read` map. Only used with `read`. |
| `sticky` | `bool` | `false` | With `read`: after a write, the reads of the same request go to the write host. |
| `extra` | `Map<String, dynamic>` | `{}` | Driver options. See below. |
| `driverFactory` | `DBDriver Function(ConnectionConfig)?` | `null` | Your own driver class. It wins over every other setting. |

Keys of `extra`:

| Driver | Key | Type | Default | Meaning |
| --- | --- | --- | --- | --- |
| postgres, mysql | `maxConnectionCount` | `int` | `10` | Most open connections, for the whole process. |
| postgres, mysql | `threads` | `int` | `1` | Rust threads of the native driver. Only the first pool sets it. |
| postgres, mysql | `requestTimeout` | `Duration` | 300 s | The longest wait for one request (a free connection, the connect and the query). Over it, the request fails. |
| postgres, mysql | `maxConnectionAge` | `Duration` | none on Postgres, 12 hours on MySQL | Close a connection older than this, once it has no query. |
| postgres, mysql | `idleTimeout` | `Duration` | no limit on Postgres, 12 hours on MySQL | Close a free connection that is not used for this long. |
| mysql | `serverKill` | `bool` | `true` | Stop a cancelled or timed out query on the server with `KILL`. Set `false` behind a proxy like ProxySQL. |
| mysql, sqlite | `preparedStatementCacheSize` | `int` | `100` | Prepared statements kept per connection. |
| postgres | `sslMode` | `String` | `require` with `useSSL`, else `disable` | TLS mode: `disable`, `prefer`, `require` or `verify-full`. |
| postgres | `sslRootCert` | `String` | none | Path of a PEM file with the CA certificates to trust for `verify-full`. `sslrootcert` in `DATABASE_URL`. |
| postgres | `sslWarning` | `bool` | `true` | `false` hides the warning Dox prints when TLS mode is `require`. `sslWarning=false` in `DATABASE_URL` works too. |
| postgres | `timeZone` | `String` | `UTC` | Session time zone. |
| postgres | `applicationName` | `String` | none | Name of the app in `pg_stat_activity`. |
| mysql | `verifyCertificate` | `bool` | `true` | `false` skips the TLS certificate check. Only for a self-signed certificate in development. |
| sqlite | `busyTimeout` | `int` | `5000` | `PRAGMA busy_timeout` in milliseconds. |
| sqlite | `background` | `bool` | `false` | `true` runs the queries in a helper isolate, so a slow query does not block the request isolate. `?background=true` in `DATABASE_URL` works too. See [SQLite](../database/index.md#run-queries-in-a-helper-isolate). |

A time key takes a `Duration`, or a number of seconds. See [Pool settings](../database/index.md#pool-settings).

## AuthConfig

Auth is not a field of `AppConfig`. A provider calls `Auth.initialize(AuthConfig(...))` in its `setup()`.

| Class | Field | Type | Default | Meaning |
| --- | --- | --- | --- | --- |
| `AuthConfig` | `defaultGuard` | `String` | required | The guard `Auth()` uses when no guard is named. |
| `AuthConfig` | `guards` | `Map<String, AuthGuard>` | `{}` | Guard name to guard. |
| `AuthGuard` | `driver` | `AuthDriver` | required | How a token is made and checked, like `JwtAuthDriver(secret: SecretKey(...))`. |
| `AuthGuard` | `provider` | `AuthProvider` | required | Where users come from. |
| `AuthProvider` | `model` | `dynamic Function()` | required | Makes the user model, like `() => User()`. |
| `AuthProvider` | `identifierFields` | `List<String>` | `['email']` | Columns `attempt()` matches the login with. |
| `AuthProvider` | `passwordField` | `String` | `'password'` | Column with the bcrypt hash. |

## Full example

These are the config files of a new project. They read their values from `env`, the typed env class in `lib/config/env.dart` (see [Env reference](env.md)).

```dart title="lib/config/app.dart"
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:my_app/config/cache.dart';
import 'package:my_app/config/cors.dart';
import 'package:my_app/config/logger.dart';
import 'package:my_app/config/env.dart';
import 'package:my_app/generated/container.g.dart';

AppConfig appConfig = AppConfig(
  /// Changing the key makes old cookies and encrypted data unreadable.
  appKey: env.appKey,
  serverPort: env.appPort,
  totalIsolate: env.appTotalIsolate,
  globalMiddleware: <dynamic>[
    LogMiddleware(enabled: env.appEnv != 'production'),
  ],
  container: registerContainer,

  /// Only in development. Warns when a handler blocks the isolate.
  strict: StrictConfig(enabled: env.appEnv == 'development'),
  cache: cache,
  cors: cors,
  logger: logger,
);
```

```dart title="lib/config/cache.dart"
import 'package:dox_core/dox_core.dart';
import 'package:my_app/config/env.dart';

CacheConfig cache = CacheConfig(
  defaultStore: env.cacheStore,
  stores: <String, Map<String, dynamic>>{
    'file': <String, dynamic>{'driver': 'file', 'path': 'storage/cache'},

    /// one map per isolate, fast, not shared
    'memory': <String, dynamic>{'driver': 'memory', 'max_size': 10000},
  },
);
```

```dart title="lib/config/logger.dart"
import 'package:dox_core/dox_core.dart';
import 'package:my_app/config/env.dart';

LoggerConfig logger = LoggerConfig(
  name: env.appName,
  enabled: true,
  level: env.logLevel,
  /// colored text is slow. JSON lines in production.
  // Env.appEnv, not appConfig.isDevelopment: appConfig is built from
  // this logger, so reading appConfig here would loop.
  prettyPrint: Env.appEnv == 'development',
);
```

```dart title="lib/config/database.dart"
import 'package:dox_orm/dox_orm.dart';
import 'package:my_app/config/app.dart';
import 'package:my_app/config/env.dart';

/// Print every SQL query only in development.
bool _debug = appConfig.isDevelopment;

DatabaseConfig databaseConfig = DatabaseConfig(
  connection: env.dbConnection,

  /// Only in development. Warns about N+1 relation loads and big results.
  strict: OrmStrict(enabled: appConfig.isDevelopment),
  connections: <String, ConnectionConfig>{
    'postgres': ConnectionConfig(
      driver: Driver.postgres,
      host: env.dbHost,
      port: env.dbPort ?? 5432,
      user: env.dbUsername,
      password: env.dbPassword,
      database: env.dbName,
      extra: <String, dynamic>{
        /// One pool for all isolates.
        'maxConnectionCount': 10,
        'maxConnectionAge': Duration(hours: 1),
      },
      debug: _debug,
      printer: PrettyQueryPrinter(),
    ),

    /// MySQL and MariaDB
    'mysql': ConnectionConfig(
      driver: Driver.mysql,
      host: env.dbHost,
      port: env.dbPort ?? 3306,
      user: env.dbUsername,
      password: env.dbPassword,
      database: env.dbName,
      extra: <String, dynamic>{'collation': 'utf8mb4_general_ci'},
      debug: _debug,
      printer: PrettyQueryPrinter(),
    ),

    /// `DB_NAME` is a file path, or `:memory:`.
    'sqlite': ConnectionConfig(
      driver: Driver.sqlite,
      database: env.dbName,
      debug: _debug,
      printer: PrettyQueryPrinter(),
    ),
  },
);
```

```dart title="lib/config/cors.dart"
import 'package:dox_core/dox_core.dart';

CORSConfig cors = CORSConfig(
  enabled: false,
  // a list: Dox sends back the request origin only when it is in the list
  origin: <String>['http://localhost:3000'],
  methods: <String>['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE'],
  headers: <String>[
    'accept',
    'authorization',
    'content-type',
    'x-csrf-token',
    'x-xsrf-token',
    'x-requested-with',
  ],
  exposeHeaders: <String>[
    'cache-control',
    'content-language',
    'content-type',
    'expires',
    'last-modified',
    'pragma',
  ],
  credentials: true,
  maxAge: 90,
);
```

Do not use `origin: '*'` with `credentials: true`, because the browser refuses that pair.

```dart title="lib/providers/orm_provider.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_orm/dox_orm.dart';
import 'package:my_app/config/database.dart';

/// Dox finds it by itself and runs it in every isolate.
/// No database? Delete this file.
class ORMProvider extends DoxProvider {
  @override
  Future<void> setup() async {
    SqlQueryBuilder.initializeWithDatabaseConfig(databaseConfig);
  }

  @override
  Future<void> shutdown() async {
    await SqlQueryBuilder.close();
  }
}
```

A new project also has `lib/config/storage.dart`, `queue.dart` and `schedule.dart`, with a provider for each in `lib/providers/`. See [File storage](../digging-deeper/file-storage.md), [Queue](../digging-deeper/queue.md) and [Scheduler](../digging-deeper/scheduler.md).

A new project has no `openapi.dart`, `socketio.dart` or auth provider. See [OpenAPI](../packages/openapi.md), [Socket.IO](../packages/socketio.md) and [Authentication](../security/authentication.md).

## Next steps

- [Environment variables](env.md): the env keys that fill the config.
- [Dependency injection](../the-basic/dependency-injection.md): the container, routers and providers.
- [Deployment](../digging-deeper/deployment.md): the server settings in production.
