# Database

Connect Dox to Postgres, MySQL, MariaDB or SQLite with the `dox_orm` package.

Almost every web app keeps its data in a database. Dox gives you two ways to work with it:

- The [query builder](query-builder.md) builds SQL with methods, like `QueryBuilder.table('blog').where('id', 1).get()`.
- [Models](model/index.md) give you one class per table, with relations and events.

You can also run [transactions](transactions.md), and create and change tables with [migrations](migration.md) and the [schema builder](schema.md).

## Setup

A new app already has `dox_orm`. To add it to an app, run:

```bash
dox add orm --driver=sqlite
```

`--driver` is `sqlite` (the default), `postgres` or `mysql`. The command adds `dox_orm` and `dox_migration`, writes `lib/config/database.dart`, the ORM provider, `bin/migrate.dart` and `db/migration/`, and adds the `DB_*` keys to `.env`. It also turns off the build of the drivers you do not use (see [Skip unused drivers](#skip-unused-drivers)). It never overwrites a file, so it is safe to run twice. See [Add a package](../getting-started/add-a-package.md).

If you only want the package, run `dart pub add dox_orm` and import it:

```dart
import 'package:dox_orm/dox_orm.dart';
```

## Supported databases

| Database | `Driver` | Driver | Pool | Good for |
|---|---|---|---|---|
| Postgres | `Driver.postgres` | [`dox_postgres_native`](postgres-native.md) | Yes | Production |
| MySQL 8+ and MariaDB | `Driver.mysql` | [`dox_mysql_native`](mysql-native.md) | Yes | Production |
| SQLite | `Driver.sqlite` | `sqlite3` | No, one connection per isolate | Development, tests, small apps |

Postgres and MySQL use a native (Rust) driver, and there is no other driver. If the native library can not load, the app stops with an error. See the [Postgres](postgres-native.md#when-the-library-does-not-load) and [MySQL](mysql-native.md#when-the-library-does-not-load) pages.

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

`env` is the typed env of the app, in `lib/config/env.dart`. Change `my_app` to the name of your app in `pubspec.yaml`. SQLite does not use `user`, `password`, `host` or `port`.

`debug: true` prints each SQL query with its values put in, so you can copy it and run it in psql, mysql or the sqlite CLI. The app template turns it on only in development:

```
▌ [db:default] SELECT * FROM "users" WHERE "email" = 'a@b.com' LIMIT 1;
```

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

  /// Close the database connections when the server stops.
  @override
  Future<void> shutdown() async {
    await SqlQueryBuilder.close();
  }
}
```

Dox finds every `DoxProvider` class on its own. After you add a provider, run `dart run build_runner build`.

Each isolate runs the provider. Isolates with the same settings share one pool, so `maxConnectionCount` is for the whole process, not for one isolate.

### `DATABASE_URL`

Many hosts (Fly, Render, Heroku and others) give you one database url. Dox reads it from the `DATABASE_URL` key, in `.env` or in the shell. If both have it, the shell wins.

When `DATABASE_URL` is set, it wins over the config of the default connection. That config still gives `debug`, `printer`, `slowQueryMs` and `extra`. Other named connections do not change.

```bash
DATABASE_URL=postgres://app:s%40cret@db.example.com:5432/blog?sslmode=require
```

| Form | Database |
|---|---|
| `postgres://user:pass@host:5432/db` or `postgresql://...` | Postgres |
| `mysql://user:pass@host:3306/db` or `mariadb://...` | MySQL, MariaDB |
| `sqlite:///abs/path.db`, `sqlite://db/dox.sqlite`, `sqlite::memory:`, `file:db/dox.sqlite` | SQLite |

The app passes the url in through the env class, so the app and `dox migrate` use the same url:

```dart title="lib/config/env.dart"
String? get databaseUrl;
```

```dart title="lib/config/database.dart"
DatabaseConfig databaseConfig = DatabaseConfig(
  url: env.databaseUrl,
  connection: env.dbConnection,
  connections: {...},
);
```

If your `lib/config/database.dart` has no `url: env.databaseUrl` line, Dox reads `DATABASE_URL` only from the shell, not from `.env`. An empty `url` (`url: ''`) turns `DATABASE_URL` off.

Some rules for the url:

- The user, password and database name are url-decoded. Write `@` in a password as `%40`.
- With no port, Postgres uses `5432` and MySQL uses `3306`.
- For Postgres, `sslmode` works like libpq (`disable`, `prefer`, `require`, `verify-ca`, `verify-full`). `require` does not check the certificate, so use `verify-full` when your host supports it. See [Postgres TLS](postgres-native.md#tls).
- For MySQL, `ssl=true` (or `sslmode=require`) turns TLS on and checks the certificate. Add `verifyCertificate=false` to skip the check, only for a self-signed certificate in development.
- `host=/path` (or `socket=/path`) connects to a Unix socket. See [Unix socket](#unix-socket).
- Any other option goes to `extra`, like `?maxConnectionCount=20`. A number becomes an `int`, and `true` and `false` become a `bool`. This works for SQLite too, like `sqlite://db/dox.sqlite?background=true`.

To make one `ConnectionConfig` from a url, use `ConnectionConfig.fromUrl(url)`.

### Unix socket

Some hosts, like Google Cloud SQL on Cloud Run, give you a Unix socket instead of a network host. A host that starts with `/` is a Unix socket:

```bash
DB_HOST=/cloudsql/my-project:europe-west1:blog
# or
DATABASE_URL=postgres://blog:secret@/blog?host=/cloudsql/my-project:europe-west1:blog
```

For Postgres, the host is the socket folder, like in libpq. The driver uses the socket file `<folder>/.s.PGSQL.<port>`. A host that already ends with `/.s.PGSQL.5432` works too.

For MySQL and MariaDB, the host is the socket file itself, and the port is not used. On Cloud SQL the socket file is `/cloudsql/PROJECT:REGION:INSTANCE`. A local server often uses `/var/run/mysqld/mysqld.sock` or `/tmp/mysql.sock`:

```bash
DB_CONNECTION=mysql
DB_HOST=/var/run/mysqld/mysqld.sock
# or
DATABASE_URL=mysql://app:secret@/app?socket=/var/run/mysqld/mysqld.sock
```

In the url, `?socket=` and `?host=` do the same thing.

### Pool settings

Postgres and MySQL keep a pool of connections. You can set how long the pool waits and how long it keeps a connection, in the `extra` map. A time is a `Duration` or a number of seconds, so `?requestTimeout=30` in `DATABASE_URL` works too:

```dart
extra: <String, dynamic>{
  'maxConnectionCount': 10,
  'requestTimeout': const Duration(seconds: 30),
  'maxConnectionAge': const Duration(minutes: 30),
  'idleTimeout': const Duration(minutes: 5),
  'serverKill': false, // MySQL only
},
```

- `maxConnectionCount` (default `10`): the most connections in the pool.
- `requestTimeout` (default 300 s): the longest wait for one request. A request is getting a free connection, connecting and running the query. If it takes longer, it fails and its connection is closed. A transaction with no request for this long is rolled back.
- `maxConnectionAge` (default: no limit on Postgres, 12 hours on MySQL): a connection older than this is closed and opened again. It is never closed while it runs a query or a transaction. This helps behind a load balancer, or after a database failover.
- `idleTimeout` (default: no limit on Postgres, 12 hours on MySQL): a free connection that is not used for this long is closed.
- `serverKill` (MySQL, default `true`): the server stops a cancelled or timed out query with `KILL QUERY`. Set it to `false` behind a proxy like ProxySQL, because the `KILL` may reach another server. Then a cancelled query stops in Dart at once, but it runs to its end on the server.

To stop one query by hand, see [Cancel a query](query-builder.md#cancelling-a-query). All other `extra` keys are in [All `extra` options](#all-extra-options).

## Skip unused drivers

`dox_orm` brings all three drivers, and the build downloads a native library for each one. Your app needs only the driver of its database. To skip the others, add a `hooks: user_defines:` block to the `pubspec.yaml` of your app. In a pub workspace, put it in the root `pubspec.yaml`, because Dart reads `user_defines` only from the root package.

`skip: true` turns off the download of a driver. Only the bool `true` skips, any other value does nothing.

A new app uses SQLite, and its `pubspec.yaml` already has this block:

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

`sqlite3: source: system` comes from the `sqlite3` package. The build does not download SQLite, and the app loads the `libsqlite3` library of the system when it opens SQLite. So if your app does open SQLite, remove these lines: a system without `libsqlite3`, like the `FROM scratch` Docker image, fails then.

When you switch to another database, remove the `skip` line of the driver you now use, and run `dart pub get`. A driver that is still skipped stops the app when it opens a pool. The error tells you to remove `skip`.

## Running raw queries

Sometimes the query builder can not build the SQL you need. `QueryBuilder.query()` runs your own SQL on the default connection. Use `@name` for values, so they are sent as bound parameters and are safe from SQL injection:

```dart
List<Map<String, dynamic>> rows = await QueryBuilder.query(
  'select * from blog where id = @id',
  substitutionValues: <String, dynamic>{'id': 1},
);
```

Pass `connection` to run it on another connection:

```dart
await QueryBuilder.query('select 1', connection: 'mysql');
```

## Using other connections

If your app has more than one connection, use `withConnection()` with a connection name from the config:

```dart
List<Map<String, dynamic>> rows = await QueryBuilder.table('blog')
    .withConnection('mysql')
    .get();
```

A model keeps its connection, so `save()` and `delete()` use it. Models that a query returns use the connection of the query:

```dart
Blog blog = Blog()..withConnection('mysql');
blog.title = 'Hello';
await blog.save(); // saved on 'mysql'
```

## Listen to queries

If you want metrics or your own query log, `SqlQueryBuilder().listen()` runs your function after each query. It works on every connection and inside transactions:

```dart
void onQuery(QueryEvent e) {
  print('${e.connection} ${e.time.inMilliseconds} ms: ${e.sql}');
}

SqlQueryBuilder().listen(onQuery);
```

A `QueryEvent` has:

- `sql`: the SQL text, with `@name` for each value.
- `bindings`: the values. A value named in `logRedact` shows as `***`.
- `time`: how long the query took, a `Duration`.
- `connection`: the name of the connection.

The function runs only after a query that worked, because the error of a failed query goes to your code. If the function throws, Dox logs the error and the query still returns its rows. `SqlQueryBuilder().removeListener(onQuery)` stops it.

### Slow query log

To find slow queries in production, set `slowQueryMs` on a connection. Dox then logs each query that takes longer than that many milliseconds. It is off by default, and it works with `debug` off:

```dart
'postgres': ConnectionConfig(
  driver: Driver.postgres,
  // ...
  debug: appConfig.isDevelopment,
  slowQueryMs: 500,
),
```

The line goes to the query `printer`, with the connection name, the time and the SQL:

```
▌ [db:postgres SLOW 812ms] SELECT * FROM "orders" WHERE "user_id" = 42;
```

Set `slowQueryMs` to `0` to log every query. A failed query is not logged here.

## ORM flags

`OrmFlags` turns on opt-in ORM behaviors. Each flag is off by default, and with all flags off the ORM works as the database pages say. Pass the flags as `flags:` in `DatabaseConfig`. A new app can start with `OrmFlags.all()`, which turns on every flag:

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
| `skipCleanUpdateEvents` | `save()` with no changes fires `saving`, `updating`, `updated` and `saved`. | It fires only `saving` and `saved`. A model with a `Map` or `List` field always counts as changed. A save with changes runs `beforeSave` two times, and a save with no changes runs it one time. |
| `belongsToKeyFromRelation` | The default `belongsTo` foreign key comes from the class name: `@BelongsTo(User) User? author` uses `user_id`. | It comes from the relation name: `author_id`. |
| `pluralTableNames` | The default table name is singular: `User` uses `user`. | It is plural, with English plural rules: `users`, `blog_posts`, `categories`. |
| `createWritesNull` | `create()` does not send a `null` key, so the column default is used. | It writes `NULL` for a key that is `null` in the map. |
| `sumReturnsZero` | `sum()` gives `null` when no row matches. | It gives `0`. |
| `selectRawAdds` | `selectRaw()` replaces the select list. | It adds to it, so `select('a').selectRaw('count(*) as c')` selects both. |
| `groupByAdds` | A second `groupBy()` replaces the first. | It adds to the first. `groupByRaw()` too. |
| `lastPageAtLeastOne` | `paginate()` gives `lastPage` `0` when there are no rows. | It gives `1`. |
| `updateSetsUpdatedAt` | A model query `update()`, like `Blog().where('id', 1).update({...})`, does not touch `updated_at`. | It sets `updated_at`, unless the data already has it. |
| `incrementFiresEvents` | `increment()` and `decrement()` on a model do not fire events or set `updated_at`. | They fire `saving`, `updating`, `updated` and `saved`, and set `updated_at`. A hook that cancels stops the write. |
| `preloadUnknownThrows` | `preload('typo')` loads nothing, with no error. | It throws an `ArgumentError`. With a dot path, each level is checked. |
| `toJsonLoadedRelations` | `toJson()` has only the relations named in `preload()`. | It also has the relations loaded with `$getRelation()`. |
| `laravelPostgresTypes` | On Postgres, `timestamps()` and `softDeletes()` make `TIMESTAMPTZ`, and `json()` makes `JSONB`. | A new table gets `TIMESTAMP` and `JSON`. |

`bin/migrate.dart` does not start the ORM, so give the flags to the migrator too: `Migrator(migrations: migrations, flags: databaseConfig.flags)`. See [Migration](migration.md#database-settings).

## SQLite

SQLite is good for development, tests and small apps. For a busy production app, use Postgres or MySQL.

You do not install SQLite on your system, because the `sqlite3` package bundles it with a build hook. For the AOT binary, use `dox build`. It puts the library in `build/bundle/lib/`, next to `build/bundle/bin/server`, so keep the two folders together. `dart compile exe` does not work with build hooks. See [Deployment](../digging-deeper/deployment.md).

SQLite has no bool, JSON or date type, so Dox converts them for you:

- `boolean()` is saved as `0`/`1` and read back as `bool`.
- `json()` is saved as text and read back as `Map` or `List`.
- Dates are saved as ISO text in UTC and read back as `DateTime`.

This works for tables made by `Schema`, or by SQL with the same type names (`BOOLEAN`, `JSON`, `TIMESTAMP`, `DATE`, `DATETIME`). A column with an alias (`active as is_active`) is not converted.

Schema limits, like `change()`, `dropColumn` and `NOT NULL` columns, are in [SQLite notes](schema.md#sqlite-notes).

### Run queries in a helper isolate

A SQLite query blocks the isolate while it runs, so one slow query stops every other request on that isolate. Set `background` to `true` to run the queries in a helper isolate instead. Your isolate only waits for the answer, so it keeps serving other requests:

```dart
'sqlite': ConnectionConfig(
  driver: Driver.sqlite,
  database: 'db/dox.sqlite',
  debug: false,
  extra: {'background': true},
),
```

With `DATABASE_URL`, add `?background=true`, like `sqlite://db/dox.sqlite?background=true`.

Each query costs one message to the helper isolate and one back. So turn it on when some queries are slow, like a big report or a search with no index. Leave it off when the app runs many tiny queries, because they get a little slower.

## MySQL and MariaDB

The driver is [`dox_mysql_native`](mysql-native.md). Its page lists how values are converted.

On MySQL and MariaDB, `CREATE`, `ALTER` and `DROP` are saved right away, so a transaction can not undo them.

## Details

This section is for special cases. Most apps do not need it.

### All `extra` options

| Key | Database | Default | What it does |
|---|---|---|---|
| `maxConnectionCount` | Postgres, MySQL | `10` | Most connections in the pool. |
| `requestTimeout` | Postgres, MySQL | 300 s | The longest wait for one request. |
| `maxConnectionAge` | Postgres, MySQL | none on Postgres, 12 hours on MySQL | A connection older than this is closed once it has no query. |
| `idleTimeout` | Postgres, MySQL | no limit on Postgres, 12 hours on MySQL | A connection not used for this long is closed. |
| `serverKill` | MySQL | `true` | Stop a cancelled or timed out query on the server with `KILL`. |
| `preparedStatementCacheSize` | MySQL, SQLite | `100` | Prepared statements kept per connection. |
| `sslMode` | Postgres | `disable` | TLS mode: `disable`, `prefer`, `require`, `verify-ca` or `verify-full`. |
| `sslRootCert` | Postgres | none | Path of a PEM file with the CA certificates to trust for `verify-ca` and `verify-full`. |
| `verifyCertificate` | MySQL | `true` | `false` skips the TLS certificate check. Only for development. |
| `timeZone` | Postgres | `UTC` | Time zone of the session. |
| `applicationName` | Postgres | none | Name of the app in `pg_stat_activity`. |
| `busyTimeout` | SQLite | `5000` | Milliseconds a query waits for a lock. |
| `background` | SQLite | `false` | `true` (or `1`, `'true'`, `'1'`) runs the queries in a [helper isolate](#run-queries-in-a-helper-isolate). |

### Table and column names

- Table and column names you pass to `select`, `where`, `join`, `groupBy`, `orderBy`, `insert` and `update` are quoted. Postgres and SQLite use `"name"`, MySQL uses `` `name` ``. So names like `order` or `key` work.
- `table.column`, `table.*`, `*` and `column as alias` are quoted the right way. Anything else, like `count(*) as total`, throws an `ArgumentError`, so user input can not add SQL. For expressions, use the raw methods (`selectRaw`, `whereRaw`, `orderByRaw`, `groupByRaw`, `joinRaw`).
- On Postgres, a quoted name is case sensitive. `userId` is not the same column as `userid`.

### Query logs

- The default printer is `PrettyQueryPrinter`. Other printers, like `ConsoleQueryPrinter` and `FileQueryPrinter`, get the slow line as `Slow query (812 ms, postgres): select ...`.
- A value named in `logRedact` shows as `***` in the slow query log (`'***'` in the `PrettyQueryPrinter` line).
- With `debug` on, a slow query of the query builder shows twice: the debug line before it runs, and the slow line after it.
- The query listener also gets the queries of `Schema`, `truncate()` and the migrator, when they run on a connection of the ORM. A migrator that opens its own database from `.env` does not, so its queries are not sent.

### More about ORM flags

- The ORM keeps the flags in `SqlQueryBuilder().flags`. Each isolate runs the ORM provider, so each isolate gets the same flags, and all connections use them.
- `SqlQueryBuilder.initialize(..., flags: ...)` takes the flags too.
- `pluralTableNames` does not change a name set with `@DoxModel(table: ...)`. The default foreign key stays singular (`user_id`).
- `belongsToKeyFromRelation` needs the relation name. The model generator does not pass it yet, so a generated model still uses the class name. Set `foreignKey` on the relation to be sure.
- `laravelPostgresTypes` changes only tables made with `Schema.create`. It never changes a table that is already there, and `Schema.table` keeps the old types. MySQL and SQLite do not change.

### More about SQLite

- The `sqlite3` package calls SQLite directly (FFI). Each isolate has one connection.
- The file uses WAL mode, so readers do not wait for the writer. `busyTimeout` makes a query wait for a lock from another isolate instead of failing. Foreign keys are on.
- Before each `SELECT`, the driver checks `PRAGMA schema_version` to see if a table changed. It finds the column types from `CREATE TABLE`, by the table names in the query.
- `dropColumn` does not work on a primary key column.
- `insertMultiple` with rows that have different keys inserts the rows one by one, because SQLite has no `DEFAULT` in `VALUES`.
- SQLite before 3.39 has no `RIGHT JOIN`.
- With `background` on, queries, transactions, `:memory:` databases, the query listener and the slow query log work the same, and a SQL error is the same `SqliteException`. A database that does not open (for example a wrong folder) does not throw at startup. The error comes on the first query, and on every query after it.

## See also

- [Query Builder](query-builder.md): write queries.
- [Model](model/index.md): work with rows as objects.
- [Migration](migration.md): create and change tables.
