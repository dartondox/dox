# Upgrade from 2.x to 3.0

This guide takes a Dox 2.x app to 3.0. Dox 3.0 is an alpha. The current version is `3.0.0-alpha.4`.

The main changes:

- All Dox packages share one version.
- `dox_query_builder` is now `dox_orm`.
- Form requests and `req.validate(Map)` are gone. Input is a `@Dto` class.
- The cache and the storage have new config classes and new packages.
- A native HTTP server and native database drivers are the default.
- Migrations can be Dart classes. The CLI has more migration commands.
- `dox build` makes a native bundle with `dart build cli`.

Read the [3.x release notes](../others/releases/v3-release.md) for the full list.

!!! warning "Dart 3.13"
    Dox 3.0 needs Dart 3.13 or newer. Dox 2.x ran on Dart 2.19. Update Dart first.

## 1. Packages

### Renames

| 2.x | 3.0 | Note |
| --- | --- | --- |
| `dox_query_builder` | `dox_orm` | The old package still exists. It only re-exports `dox_orm`. Change your imports. |
| `dox_core` | `dox_core` | stays |
| `dox_migration` | `dox_migration` | stays |
| `dox_builder` | `dox_builder` | stays |
| `dox_auth` | `dox_auth` | stays. It uses `dox_orm` now. |
| `dox_websocket` | `dox_websocket` | stays |
| `dox` (the CLI) | `dox` | stays |
| `postgres` in your pubspec | not needed | `dox_orm` depends on it. |

New packages. `dox_core` depends on the first four, so you do not add them:

- `dox_validation`: the DTO annotations and schemas.
- `dox_cache`: the cache behind `Cache()`.
- `dox_storage`: the disks behind `Storage()`.
- `dox_openapi`: the `/docs` page.
- `dox_http_native`: the native server.
- `dox_postgres_native` and `dox_mysql_native`: the native drivers. `dox_orm` depends on them.
- `dox_socketio`: a Socket.IO server. Add it only when you need it.

### `pubspec.yaml`

Before:

```yaml
environment:
  sdk: '>=2.19.0 <4.0.0'

dependencies:
  dox_core: ^2.0.0
  dox_query_builder: ^2.0.0
  dox_migration: ^2.0.0
  postgres: ^3.0.5

dev_dependencies:
  dox_builder: ^2.0.0
  build_runner: ^2.3.3
```

After:

```yaml
environment:
  sdk: ^3.13.0

dependencies:
  dox_core: ^3.0.0-alpha.4
  dox_orm: ^3.0.0-alpha.4
  dox_migration: ^3.0.0-alpha.4

dev_dependencies:
  dox_builder: ^3.0.0-alpha.4
  build_runner: ^2.4.13
```

Add `dox_auth: ^3.0.0-alpha.4` and `dox_websocket: ^3.0.0-alpha.4` when you use them. Then:

```bash
dart pub global activate dox 3.0.0-alpha.4
dart pub get
```

### Imports

```dart
// before
import 'package:dox_query_builder/dox_query_builder.dart';

// after
import 'package:dox_orm/dox_orm.dart';
```

`dox_core` now exports more names: `Request`, `Response`, `Uuid`, `Name`, `Range`, `Image` and the other rule names.
A file that also imports `package:http` or `package:uuid` without a prefix gets an "ambiguous import" error.
Add a prefix, or `hide` the name: `import 'package:dox_core/dox_core.dart' hide Uuid;`.
`dox_orm` and `dox_validation` both have a `Schema` class: `import 'package:dox_orm/dox_orm.dart' hide Schema;`.

## 2. Validation: DTOs replace form requests

These are removed: `FormRequest`, `AppConfig(formRequests:)`, `req.validate(Map)`, `req.validateAsync()`, `DoxValidator`,
`IocContainer.registerRequest()` and `processInputMapper()`. Also `dox create:request`.

Before, 2.x:

```dart
class BlogRequest extends FormRequest {
  String? title;

  @override
  void setUp() {
    title = input('title');
  }

  @override
  Map<String, String> rules() {
    return <String, String>{'title': 'required|string|max:50'};
  }
}

// lib/config/app.dart
formRequests: <Type, FormRequest Function()>{
  BlogRequest: () => BlogRequest(),
},

// controller
Future<Blog> store(BlogRequest req) async {
  Blog blog = Blog();
  blog.title = req.title;
  await blog.save();
  return blog;
}
```

After, 3.0:

```dart title="lib/app/http/dtos/create_blog.dto.dart"
import 'package:dox_core/dox_core.dart';

part 'create_blog.dto.g.dart';

@Dto()
class CreateBlog {
  @MaxLength(50)
  final String title; // not nullable, no default = required

  const CreateBlog({required this.title});

  static const DtoSchema<CreateBlog> schema = $CreateBlogDto;
}
```

```dart title="lib/config/app.dart"
import 'package:my_app/dtos.g.dart';

AppConfig appConfig = AppConfig(
  dtos: dtos, // generated list, replaces formRequests
  // ...
);
```

```dart
Future<Blog> store(CreateBlog body) async {
  Blog blog = Blog();
  blog.title = body.title;
  await blog.save();
  return blog;
}
```

Steps:

1. `dox create:dto CreateBlog` for each form request. Move each rule to an annotation. See the [rules reference](../the-basic/validation-rules.md).
2. Delete the `formRequests:` map from `AppConfig`. Add `dtos: dtos` from `lib/dtos.g.dart`.
3. Run `dox build_runner:build`.
4. Replace `req.validate({...})` in controllers with a DTO parameter, or `await req.validate<CreateBlog>()`.

For input with a shape you only know at run time, `req.validateSchema(v.object({...}))` stays. See [Validation](../the-basic/validation.md).

The error response is now a flat map, one message per field: `{"email": "The email is not a valid email"}`.

## 3. Controllers and routes

- **Typed path params.** `show(DoxRequest req, String id)` still works. You can now write `show(int id)`. A value that is not an `int` answers `404`.
- **Checked at start.** A controller with more path-param parameters than the route has `{...}` params stops the server at start. In 2.x the extra ones got `''`. Fix the route or the method.
- **Unknown parameter types stop the start.** A parameter must be `DoxRequest`, a `@Dto` class, or `String`, `int`, `double`, `num`, `bool`. A type that is not in this list is an error at start.
- `Route.group('blogs', ...)` joins paths as they are. Write `Route.group('/blogs', ...)` and `Route.get('/all', ...)`.
- New: `{id?}` optional params, `{path*}` catch-all params, `Route.files()`, `Route.mount()`.

## 4. Cache

`Cache()` runs on `dox_cache`. The config has a new shape. `CacheDriverInterface` and `FileCacheDriver` are removed.

Before:

```dart title="lib/config/cache.dart"
CacheConfig cache = CacheConfig(
  defaultDriver: Env.get('CACHE_DRIVER', 'file'),
  drivers: <String, CacheDriverInterface>{
    'file': FileCacheDriver(),
  },
);
```

After:

```dart title="lib/config/cache.dart"
CacheConfig cache = CacheConfig(
  defaultStore: Env.get('CACHE_STORE', 'file'),
  stores: <String, Map<String, dynamic>>{
    'file': <String, dynamic>{'driver': 'file', 'path': 'storage/cache'},
    'memory': <String, dynamic>{'driver': 'memory', 'max_size': 10000},
    'redis': <String, dynamic>{'driver': 'redis', 'host': '127.0.0.1', 'port': 6379},
  },
);
```

Other changes:

- A value must be a JSON type (`Map`, `List`, `String`, `num`, `bool`, `null`).
- `put` without a duration now keeps the value forever. In 2.x it was 1 hour. Add `duration:` where you need it.
- `Cache().tag('a')` still works. The new name is `tags(<String>['a'])`.
- A custom driver implements the `dox_cache` driver interface, not `CacheDriverInterface`. See [dox_cache](../packages/cache.md).
- New: `add`, `pull`, `increment`, `decrement`, `remember`, `rememberForever`, `lock`, `getRaw`.

Rename `CACHE_DRIVER` to `CACHE_STORE` in `.env` when you read it like the sample app does.

## 5. Storage

`Storage()` runs on `dox_storage`. `AppConfig.fileStorage` is now `AppConfig.storage`.
`FileStorageConfig`, `StorageDriverInterface` and `LocalStorageDriver` are removed.

Before:

```dart title="lib/config/storage.dart"
FileStorageConfig storage = FileStorageConfig(
  defaultDriver: Env.get('STORAGE_DRIVER', 'local'),
  drivers: <String, StorageDriverInterface>{
    'local': LocalStorageDriver(),
  },
);

// lib/config/app.dart
fileStorage: storage,
```

After:

```dart title="lib/config/storage.dart"
StorageConfig storage = StorageConfig(
  defaultDisk: Env.get('STORAGE_DISK', 'local'),
  disks: <String, Map<String, dynamic>>{
    'local': <String, dynamic>{'driver': 'local', 'root': 'storage'},
    's3': <String, dynamic>{
      'driver': 's3',
      'bucket': Env.get('AWS_BUCKET'),
      'region': Env.get('AWS_DEFAULT_REGION', 'us-east-1'),
      'key': Env.get('AWS_ACCESS_KEY_ID'),
      'secret': Env.get('AWS_SECRET_ACCESS_KEY'),
    },
  },
);

// lib/config/app.dart
storage: storage,
```

Other changes:

- `Storage().get()` returns `Uint8List?`.
- `stream()` and `download()` work on every disk and stream the file.
- An unknown disk name throws.
- A custom driver implements the `dox_storage` driver, not `StorageDriverInterface`. See [dox_storage](../packages/storage.md).
- New: `url()`, `signedUrl()`, `disk()`, `use()`, `Route.files()`.

Rename `STORAGE_DRIVER` to `STORAGE_DISK` in `.env` when you read it like the sample app does.

## 6. Database

### Config: one `DatabaseConfig`

In 2.x the sample app opened a `postgres` connection itself in `ORMService`. In 3.0 the ORM gets a `DatabaseConfig`.

Before:

```dart title="lib/services/orm_service.dart"
class ORMService implements DoxService {
  @override
  Future<void> setup() async {
    SqlQueryBuilder.initialize(
      database: await Connection.open(postgresEndpoint, settings: postgresPoolSetting),
      debug: true,
    );
  }
}
```

After:

```dart title="lib/config/database.dart"
DatabaseConfig databaseConfig = DatabaseConfig(
  connection: Env.get('DB_CONNECTION', 'postgres'),
  connections: <String, ConnectionConfig>{
    'postgres': ConnectionConfig(
      driver: Driver.postgres,
      host: Env.get('DB_HOST', 'localhost'),
      port: Env.get<int>('DB_PORT', 5432),
      user: Env.get('DB_USERNAME', 'postgres'),
      password: Env.get('DB_PASSWORD', 'postgres'),
      database: Env.get('DB_NAME', 'dox'),
      extra: <String, dynamic>{'maxConnectionCount': 10},
      debug: Env.get('APP_ENV') == 'development',
    ),
  },
);
```

```dart title="lib/services/orm_service.dart"
class ORMService implements DoxService {
  @override
  Future<void> setup() async {
    SqlQueryBuilder.initializeWithDatabaseConfig(databaseConfig);
  }
}
```

`SqlQueryBuilder.initialize(database: ...)` still exists. But it uses the Dart driver, not the native one. Use `DatabaseConfig` to get the native driver.
Delete `lib/config/postgres.dart`.

### Native drivers

Postgres and MySQL now use a Rust driver by default (`dox_postgres_native`, `dox_mysql_native`). You do not change any config.
The build hook downloads a ready-built library. When it does not load, the ORM uses the Dart driver and prints one warning line.

- To use the Dart drivers: `DOX_DB_DRIVER=dart`, or `extra: {'native': false}` on one connection.
- Postgres with TLS (`useSSL: true` or `extra['sslMode']`) always uses the Dart driver. The native driver has no TLS yet.
- `extra['maxConnectionAge']`, `queryTimeout` and the other `PoolSettings` keys are not read by the native Postgres driver.

See [Native Postgres driver](../database/postgres-native.md) and [Native MySQL driver](../database/mysql-native.md).

### Query changes

| 2.x | 3.0 |
| --- | --- |
| Postgres ran every query in its own transaction. | A query runs in a transaction only inside `QueryBuilder.transaction()`. |
| Table and column names were not quoted. | They are quoted. On Postgres a quoted name is case sensitive: `userId` is not `userid`. Use `selectRaw`, `whereRaw`, `joinRaw` for raw SQL. |
| `count()` with `groupBy` gave the size of the first group. | It gives the number of groups. `count()` ignores `limit`, `offset` and `orderBy`. |
| `model.delete()` had no where condition. It deleted every row. | It deletes only that record. |
| `forceDelete()` skipped soft deleted rows. | It deletes them too. |
| `save()` could not set a field to `null`. | It can, when the field had a value before. |
| MySQL: `extra['characterSet']` (a `mysql1` type). | `extra['collation']`, default `utf8mb4_general_ci`. |
| MySQL `TIME` was a `Duration`. `BLOB` was text. | `TIME` is a `String`. `BLOB` is a `Uint8List`. |
| MySQL `getDatabaseConnection()` gave a `mysql1` connection. | It gives a `MySQLConnectionPool` (`mysql_dart`). |

New: SQLite (`Driver.sqlite`), `whereNull`, `whereNotNull`, `whereNotIn`, `orWhereIn`, `selectRaw`, `QueryBuilder.transaction()`,
`@Unique` and `@Exists` DTO rules, model events and observers, `@Computed()`.

### Migrations

In 2.x, migrations were `.sql` files and `bin/server.dart` called `Migration().migrate()`.
In 3.0 a migration can be a Dart class. The CLI keeps a registry in `db/migration/migrations.dart`, and `bin/server.dart` uses `Migrator`.

Before:

```dart title="bin/server.dart"
await Migration().migrate();
```

After, with `.sql` files only:

```dart title="bin/server.dart"
await Migrator(
  connection: await databaseConfig.getConnectionConfig().getDatabaseConnection(),
).migrate();
```

After, with Dart migrations (run `dox make:migration` once, it writes the registry and `bin/migrate.dart`):

```dart title="bin/server.dart"
import '../db/migration/migrations.dart';

await Migrator(migrations: migrations).migrate();
```

Command changes:

| 2.x | 3.0 |
| --- | --- |
| `dox create:migration name` (a `.sql` file) | `dox make:migration name` (a `.dart` file). `--sql` gives a `.sql` file. `create:migration` still works. |
| `dox migration:rollback` undid every migration | It undoes the last batch only. `--step=N` undoes the last N. |
| no reset, refresh, status | `dox migration:reset`, `migration:refresh`, `migration:status` |
| `dart run dox_migration` | removed. Use the `dox` CLI, or `dart run bin/migrate.dart`. |
| a failed migration kept going | it stops, exit code 1 |

Your `.sql` files keep working. Keep `db/migration` next to the binary when you have `.sql` files.
A passed MySQL connection must be a `mysql_dart` `MySQLConnection` or `MySQLConnectionPool`.

## 7. The native server

`dox_http_native` is the default HTTP server. Rust parses HTTP, your code stays in Dart. You do not add the package and you do not need Rust.
In a hello world test it served about 5 times more requests than `dart:io`.

What changes for you:

- Nothing in your code. `req.httpRequest`, `HttpResponse` and code written for `dart:io` keep working.
- Each isolate runs its own server on the same port. On Windows only one isolate serves HTTP.
- A request line plus headers over 16 KB gets `431`. A bad request gets `400`. A big body gets `413`.
- A response is sent when it is closed. Big downloads stay in memory until then. Put a proxy in front for very big files, or use a storage signed URL.
- An app with WebSocket or Socket.IO routes uses the `dart:io` server by itself. The native server can not upgrade to WebSocket yet.

To opt out, set one of these:

```dart
AppConfig(
  server: ServerBackend.dartIo,
);
```

```bash
DOX_SERVER=dartio dart run bin/server.dart
```

The env var wins over the config. See [Native server](../digging-deeper/native-server.md).

## 8. Core and config

| 2.x | 3.0 |
| --- | --- |
| `totalIsolate` was a number you picked (the sample used 3). | Default is one isolate per CPU core. The sample reads `APP_TOTAL_ISOLATE`. A crashed isolate restarts. |
| `Env.get('MISSING')` gave the text `"null"`. | `String` gives `''`, `String?` gives `null`, `int`, `num`, `double` and `bool` throw. New `Env.get<bool>()`. |
| An empty `APP_KEY` was the key `"null"`. | With `APP_ENV=production` the start stops. Other environments log a warning. Run `dox key:generate`. |
| `IHttpException` for errors | the same, plus `PayloadTooLargeException` (`413`), `UnsupportedMediaTypeException` (`415`) |
| body size: no limit | `maxBodySize` (10 MB) and `maxMultipartSize` (100 MB) in `AppConfig`. A bigger body gets `413`. |
| `req.ip()` behind a proxy gave the proxy | set `trustedProxies` to read `X-Forwarded-For` |
| `req.ip()` gave `::ffff:127.0.0.1` for IPv4 | it gives `127.0.0.1` |
| cookie `Max-Age` had a bug | fixed. `DoxCookie(maxAge:)` is sent as `Max-Age` in seconds. |
| uploads were read into memory | an upload over 1 MB streams to a temp file. Save it before the controller returns. |
| `File` responses were read into memory | they stream, with `Range` support |
| the `encrypt` package did AES for cookies | `pointycastle` 4 does it. The output is the same, so old cookies still decode. |

New in `AppConfig`: `dtos`, `validationMessages`, `storage`, `openApi`, `socketIo`, `server`, `compress`, `trustedProxies`, `maxBodySize`, `maxMultipartSize`.
Removed: `formRequests`, `fileStorage`.

New features you can add later: the typed env class (`dox env:generate`), the OpenAPI docs page at `/docs`, Socket.IO.

## 9. CLI and build

- `dox build` runs `dart build cli`. The output is `build/bundle/`. Start it with `cd build/bundle && ./bin/server`.
  `dart compile exe` does not work any more, because the native packages use build hooks.
- `dox build` copies `db/` and `.env.example` into the bundle.
- Keep `build/bundle/lib/` next to `build/bundle/bin/server`. The native libraries are there.
- `dox create:request` is removed. Use `dox create:dto`.
- `dox create:controller -r` writes `int id` for the resource methods.
- New: `dox create:dto`, `dox make:migration`, `dox migration:reset`, `migration:refresh`, `migration:status`, `dox env:generate`, `dox env:check`, `dox openapi:generate`.

Update your Dockerfile to use `dox build` or `dart build cli`, and to copy `build/bundle`. The [sample Dockerfile](https://github.com/dartondox/dox-sample/blob/main/Dockerfile) shows it.

## 10. Auth and WebSocket

- `dox_auth` uses `dox_orm` and `dart_jsonwebtoken` 3. The API (`Auth().attempt`, `Auth().login`, `AuthMiddleware`) is the same.
- Fixed: a login with only a password could match the first user.
- `dox_websocket` is the same for an app. A custom adapter's `WebsocketAdapterInterface.emit` now returns `void`. An app with WebSocket routes runs on the `dart:io` server.
- `ioredis` is now version 2. A Redis error reply throws `RedisError`.

## Checklist

Do the steps in this order. Run `dart analyze` after each one.

1. Install Dart 3.13 or newer. Set `sdk: ^3.13.0` in `pubspec.yaml`.
2. Install the CLI: `dart pub global activate dox 3.0.0-alpha.4`.
3. Change the versions to `^3.0.0-alpha.4`. Replace `dox_query_builder` with `dox_orm`. Remove `postgres`. Run `dart pub get`.
4. Replace `package:dox_query_builder/dox_query_builder.dart` with `package:dox_orm/dox_orm.dart` in every file.
5. Fix "ambiguous import" errors with `hide` or a prefix.
6. Make `lib/config/database.dart` with a `DatabaseConfig`. Change `ORMService` to `initializeWithDatabaseConfig`. Delete `lib/config/postgres.dart`.
7. Turn each `FormRequest` into a `@Dto` class. Replace `req.validate({...})`. Remove `formRequests:` and add `dtos: dtos`.
8. Change `lib/config/cache.dart` to `CacheConfig(defaultStore:, stores:)`.
9. Change `lib/config/storage.dart` to `StorageConfig(defaultDisk:, disks:)`. Rename `fileStorage:` to `storage:` in `AppConfig`.
10. Change `bin/server.dart`: `Migration().migrate()` becomes `Migrator(...).migrate()`.
11. Run `dox build_runner:build`. Fix the errors it reports (a DTO field that is not `final`, a rule that does not fit a type).
12. Check the raw SQL in `selectRaw`, `whereRaw` and `joinRaw`. Names are now quoted, so mixed-case names on Postgres must match the table.
13. Check every `count()` with `groupBy`, and every `delete()` on a query, because they changed.
14. Set `APP_KEY` in production. Set `APP_TOTAL_ISOLATE` when you do not want one isolate per core.
15. Run the tests. Start the app with `dox serve` and look for `[dox] warning` lines about native libraries.
16. Change the Dockerfile and CI to `dox build` and `build/bundle`.
17. Optional: `dox env:generate` for a typed env class, `AppConfig(openApi:)` for the docs page.
