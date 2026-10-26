---
icon: lucide/settings
---

# App config

Every field of `AppConfig`, with its type, its default and what it does.

`AppConfig` is the one object you give to `Dox().initialize()`. It lives in `lib/config/app.dart`.

Source: `packages/dox-core/lib/interfaces/app_config.dart`.

## Server

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `appKey` | `String` | required | Encrypts cookies (`req.cookie()`, `DoxCookie`) and signs local storage URLs. It must be exactly 32 characters. The app stops at start when it is empty, has another length, or is a public sample key. When `APP_ENV` is `development`, `local`, `test` or `testing`, this is only a warning. Make one with `dox key:generate`. |
| `serverPort` | `int` | `3000` | The port the HTTP server listens on. When the env has no `APP_PORT` but has `PORT`, Dox listens on `PORT` instead (Cloud Run, Fly, Render and Heroku set it). |
| `host` | `String?` | `null`: `APP_HOST`, else all interfaces | The network interface to listen on, like `127.0.0.1`. `null` reads the env var `APP_HOST`. With neither, Dox listens on all interfaces, IPv6 and IPv4 (`::`). |
| `totalIsolate` | `int?` | `Platform.numberOfProcessors` | Isolates (threads) that serve HTTP, all on the same port. On Windows the native server runs on one isolate. |
| `compress` | `bool` | `false` | gzip responses (`HttpServer.autoCompress`). Rust gzips on its own thread, not on the isolate. It still costs CPU on every response. Let a proxy do it when you have one. |
| `maxBodySize` | `int` | `10 * 1024 * 1024` (10 MB) | Biggest JSON or urlencoded body in bytes. Bigger gets `413`. |
| `maxMultipartSize` | `int` | `100 * 1024 * 1024` (100 MB) | Biggest `multipart/form-data` body (file uploads) in bytes. Bigger gets `413`. |
| `bodyTimeout` | `Duration` | `Duration(seconds: 120)` | A client that sends no body bytes for this long gets `408`. A slow but steady upload is fine. Native server only. |
| `shutdownTimeout` | `Duration` | `Duration(seconds: 8)` | On `SIGTERM` or `SIGINT`, how long open requests may run before Dox closes them. Keep it below the kill timeout of your platform. See [Graceful shutdown](../digging-deeper/deployment.md#graceful-shutdown). |
| `trustedProxies` | `List<String>` | `[]` | IPs or CIDR ranges of reverse proxies. Only when the direct client is in this list does Dox read `X-Forwarded-For` for `req.ip()` and `X-Forwarded-Proto` for `req.scheme()`. `['*']` trusts any direct client, and takes the right-most `X-Forwarded-For` hop (the one the proxy added) as the client. |

## Routing and request handling

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `container` | `void Function(IocContainer)?` | `null` | Fills the container: `registerContainer` from `lib/generated/container.g.dart`. Every isolate runs it. It also gives the routers, providers and model binders. See [Dependency injection](../the-basic/dependency-injection.md). |
| `routers` | `List<Router>` | `[]` | Routers to register first, in this order. Every other `Router` class comes from `container`. |
| `globalMiddleware` | `List<dynamic>` | `[]` | Middleware that runs on every route. A function or an `IDoxMiddleware`. |
| `dtos` | `List<DtoSchema<Object>>` | `[]` | Every DTO of the app: `dtos` from `lib/generated/dtos.g.dart`. Dox finds the DTO of a controller parameter and of `req.validate<T>()` with it. |
| `validationMessages` | `MessageResolver?` | `null` (English messages) | Messages for validation errors, for example in other languages. |
| `responseHandler` | `ResponseHandlerInterface?` | `null` | A class with `DoxResponse handle(DoxResponse res)`. It sees every response before it is sent. |
| `exceptionHandler` | `ExceptionHandler` | `ExceptionHandler()` | Reports every unhandled error and turns it into a response. The default logs the error with `Logger.warn` and the stack with `Logger.danger`. See [Error handling](../the-basic/errors.md). |
| `providers` | `List<DoxProvider>` | `[]` | Providers to run first, in this order. Every other `DoxProvider` class comes from `container`. Dox runs them in every isolate at start. |

## Sub configs

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `cors` | `CORSConfig` | `CORSConfig()` | CORS headers. See [CORSConfig](#corsconfig). |
| `logger` | `LoggerConfig` | `LoggerConfig()` | The `Logger` output. See [LoggerConfig](#loggerconfig). |
| `cache` | `CacheConfig` | `file` store in `storage/cache`, plus a `memory` store | Cache stores for `Cache()`. See [CacheConfig](#cacheconfig). |
| `session` | `SessionConfig` | `cookie` driver, cookie `dox_session`, 2 hours | Settings for `SessionMiddleware`. See [Session](../the-basic/session.md#config). |
| `openApi` | `OpenApiConfig` | `OpenApiConfig()` | `/docs`, `/openapi.json` and `/openapi.yaml`. See [OpenApiConfig](#openapiconfig). |

## CORSConfig

Source: `packages/dox-core/lib/interfaces/app_config.dart`. Headers are set in `packages/dox-core/lib/http/http_cors_handler.dart`.

A value can be a `String` (`'*'` or a comma list) or a `List<String>`. A `null` value sends no header.

| Field | Type | Default | Header |
| --- | --- | --- | --- |
| `enabled` | `bool` | `true` | Send CORS headers. A route can override it with its own `cors` setting. |
| `origin` | `dynamic` | `null` | `Access-Control-Allow-Origin`. One origin, `'*'`, or a list. With a list, Dox sends back only the request origin if it is in the list. |
| `methods` | `dynamic` | `null` | `Access-Control-Allow-Methods` |
| `headers` | `dynamic` | `null` | `Access-Control-Allow-Headers` |
| `exposeHeaders` | `dynamic` | `null` | `Access-Control-Expose-Headers` |
| `credentials` | `bool?` | `null` | `Access-Control-Allow-Credentials` |
| `maxAge` | `num?` | `null` | `Access-Control-Max-Age` in seconds |

!!! note
    With the default `CORSConfig()` every value is `null`. So `enabled: true` alone sends no header. Set `origin` at least.

## LoggerConfig

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `name` | `String` | `''` | The `name` field in each JSON log line. |
| `enabled` | `bool` | `false` | Turn the `Logger` on. |
| `prettyPrint` | `bool` | `false` | `true` prints colored text. `false` prints one JSON object per line (for log services). |
| `level` | `String` | `'info'` | The lowest level to print: `debug`, `info`, `warn` or `error`. `Logger.success` counts as `info`. `Logger.danger` counts as `error`. An unknown value prints every line. |

## CacheConfig

Source: `packages/dox-cache/lib/src/cache_config.dart`. Option keys: `packages/dox-cache/lib/src/constants/cache_constants.dart`.

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `defaultStore` | `String` | required | The store `Cache()` uses when no store is named. |
| `stores` | `Map<String, Map<String, dynamic>>` | required | Store name to options. Each store needs a `driver` option. |

Options of each driver:

| Driver | Option | Type | Default | Meaning |
| --- | --- | --- | --- | --- |
| all | `driver` | `String` | required | `file`, `memory`, `redis` or `null` |
| all | `prefix` | `String` | `dox_cache:` | Text in front of every key. |
| `file` | `path` | `String` | `storage/cache` | Folder of the cache files. |
| `memory` | `max_size` | `int` | no limit | Most items in the map. |
| `redis` | `host` | `String` | `127.0.0.1` | Redis host. |
| `redis` | `port` | `int` | `6379` | Redis port. |
| `redis` | `username` | `String` | none | Redis user. |
| `redis` | `password` | `String` | none | Redis password. |
| `redis` | `db` | `int` | `0` | Redis database number. |
| `redis` | `tls` | `bool` | `false` | Use TLS. |
| `redis` | `pool_size` | `int` | `10` | Most connections per store. |

## StorageConfig

`StorageProvider` of the `dox_storage` package takes it. See [File storage](../digging-deeper/file-storage.md).
Source: `lib/src/dox/storage_config.dart` in [dartondox/dox-storage](https://github.com/dartondox/dox-storage).

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `defaultDisk` | `String` | `'local'` | The disk `Storage()` uses when no disk is named. |
| `disks` | `Map<String, Map<String, dynamic>>` | `{'local': {'driver': 'local', 'root': 'storage'}}` | Disk name to options. Each disk needs a `driver` option. |

Options of each driver:

| Driver | Option | Type | Default | Meaning |
| --- | --- | --- | --- | --- |
| all | `driver` | `String` | required | `local`, `s3` or `memory` |
| `local` | `root` | `String` | `storage` | Folder of the files. |
| `local` | `url` | `String` | none | Base of the public URLs, like `http://localhost:3000/files`. |
| `local` | `app_key` | `String` | `AppConfig.appKey` | Key that signs the URLs. |
| `local` | `visibility` | `String` | `public` | `public` or `private`. |
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

An unknown driver throws `ArgumentError('Storage disk "<name>" has unknown driver "<type>"')`.

## OpenApiConfig

Source: `packages/dox-core/lib/openapi/openapi_config.dart`.

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `enabled` | `bool?` | `null` | Serve the docs routes. `null` means: on only when `APP_ENV` is `development` or `local`. An empty `APP_ENV` counts as production. |
| `info` | `Info` | `Info(title: 'Dox API', version: '1.0.0')` | Title and version of the API. |
| `servers` | `List<Server>` | `[]` | Base URLs of the API. |
| `securitySchemes` | `Map<String, SecurityScheme>` | `{}` | Ways to log in, like `{'bearerAuth': SecurityScheme.bearer()}`. |
| `securityByMiddleware` | `Map<String, List<Map<String, List<String>>>>` | `{}` | Security for routes that use a middleware class with this name. It wins over `@Security` on the class. A class name that ends with `AuthMiddleware` gets `bearerAuth` when it has neither. |
| `registry` | `OpenApiRegistry` | `OpenApiRegistry()` (empty) | What `dox_builder` found in the code. Pass `openApiRegistry` from `lib/generated/openapi.g.dart`. |
| `ui` | `DocsUi` | `DocsUi.scalar` | `scalar` or `swagger`. |
| `scalar` | `ScalarOptions` | `ScalarOptions()` | Options of the Scalar page. See below. |
| `pageTitle` | `String?` | `null` (uses `info.title`) | Title of the `/docs` page. |
| `include` | `List<String>` | `[]` (all routes) | Only routes with these paths are in the docs, like `['/api/*']`. A `*` at the end matches the rest of the path. |
| `exclude` | `List<String>` | `[]` | Routes with these paths are left out. Checked after `include`. |

`ScalarOptions` (`lib/src/docs_ui.dart` in [dartondox/dox-openapi](https://github.com/dartondox/dox-openapi)):

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `theme` | `ScalarTheme` | `ScalarTheme.default_` | One of `default_`, `alternate`, `moon`, `purple`, `solarized`, `bluePlanet`, `deepSpace`, `saturn`, `kepler`, `elysiajs`, `fastify`, `mars`, `laserwave`, `none`. |
| `darkMode` | `bool` | `false` | Start in dark mode. |
| `showDownloadButton` | `bool` | `true` | Show the download button for the OpenAPI document. |
| `proxyUrl` | `String?` | `null` | Send "Try it" requests through this proxy. |

## SocketIoConfig

`SocketIoProvider` of the `dox_socketio` package takes it. See [Socket.IO](../packages/socketio.md).
Source: `lib/src/dox/socket_io_config.dart` in [dartondox/dox-socketio](https://github.com/dartondox/dox-socketio).

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `enabled` | `bool` | `true` | Mount Socket.IO on the HTTP port at `/socket.io/`. |
| `options` | `ServerOptions` | `ServerOptions()` | Engine options. See below. |
| `namespaces` | `List<NamespaceHandler>` | `[]` | Namespaces to register, like `ChatNamespace()`. |
| `adapter` | `SocketAdapterFactory?` | `null` (in memory) | Makes the adapter in each isolate. Use a Redis adapter with many isolates. |

`ServerOptions` (`lib/src/engine/server_options.dart` in dox-socketio). The defaults match the Node.js server.

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
Source: `packages/dox-orm/lib/src/types/database_config.dart` and `connection_config.dart` in [dartondox/dox-orm](https://github.com/dartondox/dox-orm).

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `connection` | `String` | required | Name of the connection to use. A missing name throws `Exception('<name> not found')`. |
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
| `printer` | `QueryPrinter?` | `null` | `ConsoleQueryPrinter()`, `PrettyQueryPrinter()`, `FileQueryPrinter()` or your own. |
| `extra` | `Map<String, dynamic>` | `{}` | Driver options. See below. |
| `driverFactory` | `DBDriver Function(ConnectionConfig)?` | `null` | Your own driver class. It wins over every other setting. |

Keys of `extra`:

| Driver | Key | Type | Default | Meaning |
| --- | --- | --- | --- | --- |
| postgres, mysql | `maxConnectionCount` | `int` | `10` | Most open connections, for the whole process. |
| postgres, mysql | `threads` | `int` | `1` | Rust threads of the native driver. Only the first pool sets it. |
| mysql, sqlite | `preparedStatementCacheSize` | `int` | `100` | Prepared statements kept per connection. |
| postgres | `sslMode` | `String` | `require` with `useSSL`, else `disable` | TLS mode: `disable`, `prefer`, `require` or `verify-full`. |
| postgres | `sslRootCert` | `String` | none | Path of a PEM file with the CA certificates to trust for `verify-full`. `sslrootcert` in `DATABASE_URL`. |
| postgres | `timeZone` | `String` | `UTC` | Session time zone. |
| postgres | `applicationName` | `String` | none | Name of the app in `pg_stat_activity`. |
| mysql | `verifyCertificate` | `bool` | `true` | `false` skips the TLS certificate check. Only for a self-signed certificate in development. |
| mysql | `maxConnectionAge` | `Duration` | 12 hours | Close and reopen a connection after this time. |
| sqlite | `busyTimeout` | `int` | `5000` | `PRAGMA busy_timeout` in milliseconds. |

The `database.dart` of a new project also sets `maxConnectionAge` for Postgres and `collation` for MySQL. The Postgres driver does not read `maxConnectionAge`, and no driver reads `collation`. So these two keys change nothing.

## AuthConfig

Auth is not a field of `AppConfig`. A provider calls `Auth.initialize(AuthConfig(...))` in its `setup()`.
Source: `lib/src/interfaces.dart` in [dartondox/dox-auth](https://github.com/dartondox/dox-auth).

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

The config files of a new project. They read their values from `env`, the typed env class in `lib/config/env.dart` (see [Env reference](env.md)).

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
  totalIsolate: env.appTotalIsolate ?? Platform.numberOfProcessors,
  globalMiddleware: <dynamic>[
    LogMiddleware(enabled: env.appEnv != 'production'),
  ],
  container: registerContainer,
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
  prettyPrint: env.isDevelopment,
);
```

```dart title="lib/config/database.dart"
import 'package:dox_orm/dox_orm.dart';
import 'package:my_app/config/env.dart';

/// Print every SQL query only in development.
bool _debug = env.isDevelopment;

DatabaseConfig databaseConfig = DatabaseConfig(
  connection: env.dbConnection,
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

Do not use `origin: '*'` together with `credentials: true`.
With credentials the browser sends cookies, so it does not accept `*`, and the call fails.
Dox does not send back any origin in place of `*`, because that would let every site call the app with the user's cookies.
`'*'` is fine for a public API with `credentials: false` (or not set).

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

A new project has no `openapi.dart`, `socketio.dart` or auth provider. You add them when you need them. See [OpenAPI](../packages/openapi.md), [Socket.IO](../packages/socketio.md) and [Authentication](../security/authentication.md).
