# Database

Connect Dox to Postgres, MySQL, MariaDB or SQLite with the `dox_orm` package.

Dox gives you two ways to work with the data:

- The [query builder](query-builder.md) builds SQL with methods, like `QueryBuilder.table('blog').where('id', 1).get()`.
- [Models](model/index.md) give you one class per table, with relations and events.

You can also run [transactions](transactions.md), and make tables with [migrations](migration.md) and the [schema builder](schema.md).

## Setup

A new app already has `dox_orm`. To add it to an app, run:

```bash
dox add orm --driver=sqlite
```

The driver is sqlite (the default), postgres or mysql. The command adds `dox_orm` and `dox_migration`, the config, the ORM provider, `bin/migrate.dart`, `db/migration/` and the `DB_*` keys in `.env`. It never overwrites a file. See [Add a package](../getting-started/add-a-package.md).

### Supported databases

| Database | `Driver` | Package | Pool | Good for |
|---|---|---|---|---|
| Postgres | `Driver.postgres` | [`dox_postgres_native`](postgres-native.md) | yes | production |
| MySQL 8+ and MariaDB | `Driver.mysql` | [`dox_mysql_native`](mysql-native.md) | yes | production |
| SQLite | `Driver.sqlite` | `sqlite3` | no, one connection per isolate | development, tests, small apps |

Postgres and MySQL use a native (Rust) driver. If the native library can not load, the app stops with an error. See [Postgres](postgres-native.md#when-the-library-does-not-load) and [MySQL](mysql-native.md#when-the-library-does-not-load).

## Configuration

Put your connections in `lib/config/database.dart`. `connection` is the name of the default connection:

```dart title="lib/config/database.dart"
import 'package:dox_orm/dox_orm.dart';
import 'package:my_app/config/app.dart';
import 'package:my_app/config/env.dart';

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
      extra: <String, dynamic>{'maxConnectionCount': 10},
      debug: appConfig.isDevelopment,
    ),
    'mysql': ConnectionConfig(
      driver: Driver.mysql, // also for MariaDB
      host: env.dbHost,
      port: env.dbPort ?? 3306,
      user: env.dbUsername,
      password: env.dbPassword,
      database: env.dbName,
      extra: <String, dynamic>{'maxConnectionCount': 10},
      debug: appConfig.isDevelopment,
    ),
    'sqlite': ConnectionConfig(
      driver: Driver.sqlite,
      database: env.dbName, // file path, like db/dox.sqlite, or ':memory:'
      debug: appConfig.isDevelopment,
    ),
  },
);
```

Change `my_app` to the name of your app. With `debug` on, each query prints with its values put in:

```
▌ [db:default] SELECT * FROM "users" WHERE "email" = 'a@b.com' LIMIT 1;
```

### Connection options

| Option | What it does |
|---|---|
| `driver` | `Driver.postgres`, `Driver.mysql` or `Driver.sqlite`. |
| `host`, `port`, `user`, `password` | The server. SQLite does not use them. |
| `database` | The database name. For SQLite, the file path or `:memory:`. |
| `useSSL` | Turn on TLS. See [Postgres TLS](postgres-native.md#tls) and [MySQL](mysql-native.md). |
| `debug` | Print each query. |
| `printer` | The query printer: `PrettyQueryPrinter` (default), `ConsoleQueryPrinter`, `FileQueryPrinter` or your own `QueryPrinter`. |
| `logRedact` | Names of values to show as `***` in the log, like `['password', 'token']`. A key that ends with a name matches. |
| `slowQueryMs` | Log queries slower than this. See [Slow query log](#slow-query-log). |
| `extra` | Driver options. See [All extra options](#all-extra-options). |
| `read`, `write`, `sticky` | Read replicas. See [Read replicas](replicas.md). |
| `driverFactory` | A function that makes your own `DBDriver` from the config. |

`DatabaseConfig` also takes `url` ([`DATABASE_URL`](#database_url)), `flags` ([ORM flags](#orm-flags)) and `strict`. For `strict`, see [Strict mode in the ORM](../digging-deeper/performance-mistakes.md#strict-mode-in-the-orm).

### Environment values

The app config and the [migration](migration.md) commands read these keys from `.env`:

```py title=".env"
DB_CONNECTION=postgres # postgres, mysql or sqlite
DB_HOST=localhost
DB_PORT=5432           # 3306 for mysql
DB_NAME=dox            # for sqlite: the file path, like db/dox.sqlite
DB_USERNAME=postgres
DB_PASSWORD=postgres
```

### Starting the ORM

The ORM starts in a provider. The app template already has this file:

```dart title="lib/providers/orm_provider.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_orm/dox_orm.dart';
import 'package:my_app/config/database.dart';

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

After you add a provider, run `dart run build_runner build`. Isolates with the same settings share one pool, so `maxConnectionCount` is for the whole process.

### `DATABASE_URL`

Many hosts give you one database url. Dox reads it from the `DATABASE_URL` key, in `.env` or in the shell. The shell wins:

```bash
DATABASE_URL=postgres://app:s%40cret@db.example.com:5432/blog?sslmode=require
```

| Form | Database |
|---|---|
| `postgres://user:pass@host:5432/db` or `postgresql://...` | Postgres |
| `mysql://user:pass@host:3306/db` or `mariadb://...` | MySQL, MariaDB |
| `sqlite:///abs/path.db`, `sqlite://db/dox.sqlite`, `sqlite::memory:`, `file:db/dox.sqlite` | SQLite |

The url replaces the config of the default connection. That config still gives `debug`, `printer`, `logRedact`, `slowQueryMs`, `extra` and the read hosts. Pass the url through the env class, so the app and `dox migrate` read the same url:

```dart title="lib/config/database.dart"
DatabaseConfig databaseConfig = DatabaseConfig(
  url: env.databaseUrl, // String? get databaseUrl; in env.dart
  connection: env.dbConnection,
  connections: {...},
);
```

Without the `url` line, Dox reads `DATABASE_URL` only from the shell. An empty url turns it off.

- The user, password and database name are url-decoded. Write `@` in a password as `%40`.
- For Postgres, `sslmode` works like libpq. `require` does not check the certificate, so use `verify-full` when you can. See [Postgres TLS](postgres-native.md#tls).
- For MySQL, `ssl=true` turns on TLS and checks the certificate. `verifyCertificate=false` skips the check, for development only.
- Other options go to `extra`, like `?maxConnectionCount=20`.

To make one `ConnectionConfig` from a url, use `ConnectionConfig.fromUrl(url)`.

### Unix socket

A host that starts with `/` is a Unix socket:

```bash
DB_HOST=/cloudsql/my-project:europe-west1:blog
# or
DATABASE_URL=postgres://blog:secret@/blog?host=/cloudsql/my-project:europe-west1:blog
```

For Postgres, the host is the socket folder, like in libpq. For MySQL and MariaDB, the host is the socket file, like `/var/run/mysqld/mysqld.sock`. In the url, `?socket=` and `?host=` do the same.

### Pool settings

Set the pool of Postgres and MySQL in the `extra` map. A time is a `Duration` or a number of seconds:

```dart
extra: <String, dynamic>{
  'maxConnectionCount': 10,
  'requestTimeout': const Duration(seconds: 30),
  'maxConnectionAge': const Duration(minutes: 30),
  'idleTimeout': const Duration(minutes: 5),
  'serverKill': false, // MySQL only
},
```

A request is a wait for a connection, the connect and the query. A transaction with no request for the `requestTimeout` is rolled back. Set `serverKill` to false behind a proxy like ProxySQL, because the kill can reach another server.

### All extra options

| Key | Database | Default | What it does |
|---|---|---|---|
| `maxConnectionCount` | Postgres, MySQL | 10 | Most connections in the pool. |
| `requestTimeout` | Postgres, MySQL | 300 s | The longest time for one request. |
| `maxConnectionAge` | Postgres, MySQL | no limit on Postgres, 12 hours on MySQL | Close a connection older than this, when it has no query. |
| `idleTimeout` | Postgres, MySQL | no limit on Postgres, 12 hours on MySQL | Close a connection not used for this long. |
| `serverKill` | MySQL | true | Stop a cancelled or timed out query on the server with `KILL QUERY`. |
| `preparedStatementCacheSize` | MySQL, SQLite | 100 | Prepared statements kept per connection. |
| `sslMode` | Postgres | disable | TLS mode: disable, prefer, require, verify-ca or verify-full. |
| `sslRootCert` | Postgres | none | PEM file with the CA certificates for verify-ca and verify-full. |
| `verifyCertificate` | MySQL | true | false skips the TLS certificate check. Development only. |
| `timeZone` | Postgres | UTC | Time zone of the session. |
| `applicationName` | Postgres | none | Name of the app in `pg_stat_activity`. |
| `busyTimeout` | SQLite | 5000 | Milliseconds a query waits for a lock. |
| `background` | SQLite | false | Run the queries in a [helper isolate](#run-queries-in-a-helper-isolate). |

To stop one query, see [Cancelling a query](query-builder.md#cancelling-a-query).

## Skip unused drivers

`dox_orm` brings all three drivers, and the build downloads a native library for each. To skip the ones you do not use, add a `hooks: user_defines:` block to the root `pubspec.yaml`. A new app uses SQLite and already has this block:

```yaml title="pubspec.yaml"
hooks:
  user_defines:
    dox_postgres_native:
      skip: true
    dox_mysql_native:
      skip: true
```

For a Postgres app:

```yaml title="pubspec.yaml"
hooks:
  user_defines:
    dox_mysql_native:
      skip: true
    sqlite3:
      source: system
```

For a MySQL app:

```yaml title="pubspec.yaml"
hooks:
  user_defines:
    dox_postgres_native:
      skip: true
    sqlite3:
      source: system
```

Only the bool true skips. With `sqlite3: source: system`, the app loads the `libsqlite3` of the system. If your app opens SQLite, remove these lines, because an image without `libsqlite3` fails.

When you change the database, remove the skip line of the new driver and run `dart pub get`.

## Running raw queries

`QueryBuilder.query()` runs your own SQL. Use `@name` for values, so they are bound:

```dart
List<Map<String, dynamic>> rows = await QueryBuilder.query(
  'select * from blog where id = @id',
  substitutionValues: <String, dynamic>{'id': 1},
);

await QueryBuilder.query('select 1', connection: 'mysql');
```

## Using other connections

`withConnection()` runs a query on another connection from the config:

```dart
List<Map<String, dynamic>> rows = await QueryBuilder.table('blog')
    .withConnection('mysql')
    .get();
```

A model keeps its connection, so `save()` and `delete()` use it:

```dart
Blog blog = Blog()..withConnection('mysql');
blog.title = 'Hello';
await blog.save(); // saved on 'mysql'
```

## Listen to queries

`SqlQueryBuilder().listen()` runs your function after each query, on every connection:

```dart
void onQuery(QueryEvent e) {
  print('${e.connection} ${e.time.inMilliseconds} ms: ${e.sql}');
}

SqlQueryBuilder().listen(onQuery);
```

A `QueryEvent` has `sql`, `bindings` (with `logRedact` values as `***`), `time` and `connection`. A failed query is not sent. `SqlQueryBuilder().removeListener(onQuery)` stops it.

### Slow query log

Set `slowQueryMs` on a connection to log each query slower than that many milliseconds. It works with `debug` off:

```dart
'postgres': ConnectionConfig(
  driver: Driver.postgres,
  // ...
  debug: appConfig.isDevelopment,
  slowQueryMs: 500,
),
```

The line goes to the query printer:

```
▌ [db:postgres SLOW 812ms] SELECT * FROM "orders" WHERE "user_id" = 42;
```

Set it to 0 to log every query.

## ORM flags

`OrmFlags` turns on opt-in ORM behaviors. Each flag is off by default. Pass them as `flags` in `DatabaseConfig`:

```dart title="lib/config/database.dart"
DatabaseConfig databaseConfig = DatabaseConfig(
  connection: env.dbConnection,
  connections: <String, ConnectionConfig>{ /* ... */ },
  flags: OrmFlags.all(), // every flag on
);
```

To turn on only some flags, name them:

```dart
flags: const OrmFlags(pluralTableNames: true, sumReturnsZero: true),
```

| Flag | Off (default) | On |
|---|---|---|
| `skipCleanUpdateEvents` | `save()` with no changes fires `saving`, `updating`, `updated` and `saved`. | It fires only `saving` and `saved`. A model with a `Map` or `List` field always counts as changed. |
| `belongsToKeyFromRelation` | The `belongsTo` foreign key comes from the class name: `@BelongsTo(User) User? author` uses user_id. | It comes from the relation name: author_id. |
| `pluralTableNames` | The table name is singular: `User` uses user. | It is plural: users, blog_posts, categories. A name in `@DoxModel(table: ...)` does not change. |
| `createWritesNull` | `create()` does not send a null key, so the column default is used. | It writes NULL for a null key. |
| `sumReturnsZero` | `sum()` gives null when no row matches. | It gives 0. |
| `selectRawAdds` | `selectRaw()` replaces the select list. | It adds to it. |
| `groupByAdds` | A second `groupBy()` replaces the first. | It adds to the first. `groupByRaw()` too. |
| `lastPageAtLeastOne` | `paginate()` gives `lastPage` 0 when there are no rows. | It gives 1. |
| `updateSetsUpdatedAt` | A model query `update()` does not set updated_at. | It sets updated_at, unless the data has it. |
| `incrementFiresEvents` | `increment()` and `decrement()` on a model fire no events and do not set updated_at. | They fire `saving`, `updating`, `updated` and `saved`, and set updated_at. |
| `preloadUnknownThrows` | `preload('typo')` loads nothing, with no error. | It throws an `ArgumentError`. |
| `toJsonLoadedRelations` | `toJson()` has only the relations named in `preload()`. | It also has the relations loaded with `$getRelation()`. |
| `laravelPostgresTypes` | On Postgres, `timestamps()` and `softDeletes()` make TIMESTAMPTZ, and `json()` makes JSONB. | A new table gets TIMESTAMP and JSON. |

`bin/migrate.dart` does not start the ORM, so give the flags to the migrator too: `Migrator(migrations: migrations, flags: databaseConfig.flags)`. See [Migration](migration.md#database-settings).

## SQLite

SQLite is good for development, tests and small apps. The `sqlite3` package brings SQLite with a build hook, so you do not install it.

For the AOT binary, use `dox build`. It puts the library in `build/bundle/lib/`, so keep it next to `build/bundle/bin/`. See [Deployment](../digging-deeper/deployment.md).

SQLite has no bool, JSON or date type, so Dox converts them:

- `boolean()` is saved as 0 or 1 and read back as a bool.
- `json()` is saved as text and read back as a map or a list.
- Dates are saved as ISO text in UTC and read back as a `DateTime`.

This works for columns with these type names: BOOLEAN, JSON, TIMESTAMP, DATE and DATETIME. Schema limits are in [SQLite notes](schema.md#sqlite-notes).

### Run queries in a helper isolate

A SQLite query blocks its isolate. Set `background` to true to run the queries in a helper isolate, so your isolate keeps serving requests:

```dart
'sqlite': ConnectionConfig(
  driver: Driver.sqlite,
  database: 'db/dox.sqlite',
  debug: false,
  extra: {'background': true},
),
```

With `DATABASE_URL`, add `?background=true`. Each query costs two messages, so turn it on for slow queries and leave it off for many tiny queries.

## MySQL and MariaDB

The driver is [`dox_mysql_native`](mysql-native.md). On MySQL and MariaDB, a transaction can not undo CREATE, ALTER and DROP.

## Without Dox

`dox_orm` also works on its own:

```bash
dart pub add dox_orm
```

Start it with a `DatabaseConfig`, or with your own database object: a `PgNativePool`, a `MysqlNativePool` or a SQLite `Database`:

```dart
import 'package:dox_orm/dox_orm.dart';

SqlQueryBuilder.initializeWithDatabaseConfig(databaseConfig);
// or
SqlQueryBuilder.initialize(database: db, driver: Driver.sqlite);
```

`initialize` also takes `debug`, `printer`, `flags` and `strict`. Call `await SqlQueryBuilder.close()` to close the connections.

## Next steps

- [Query Builder](query-builder.md): write queries.
- [Model](model/index.md): work with rows as objects.
- [Migration](migration.md): create and change tables.
