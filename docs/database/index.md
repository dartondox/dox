# Database

Connect Dox to Postgres, MySQL, MariaDB or SQLite with the `dox_orm` package.

- [Query builder](query-builder.md): build SQL with methods.
- [Models](model/index.md): one class per table.
- [Transactions](transactions.md): many queries that succeed or fail together.
- [Migration](migration.md) and [Schema](schema.md): create and change tables.

This is how a query travels from your code to the database:

```mermaid
flowchart LR
    M["Model or QueryBuilder"] --> S["SQL text<br>quoted names, @values"]
    S --> D{"Driver"}
    D --> N["Native Rust pool<br>dox_postgres_native, dox_mysql_native"]
    D --> T["sqlite3"]
    N --> DB[("Database")]
    T --> DB
```

## Install

The query builder and the models are in the `dox_orm` package.

```bash
dart pub add dox_orm
```

```dart
import 'package:dox_orm/dox_orm.dart';
```

## Supported databases

| Database | `Driver` | Driver | Pool | Good for |
|---|---|---|---|---|
| Postgres | `Driver.postgres` | [`dox_postgres_native`](postgres-native.md) | Yes | Production |
| MySQL 8+ and MariaDB | `Driver.mysql` | [`dox_mysql_native`](mysql-native.md) | Yes | Production |
| SQLite | `Driver.sqlite` | `sqlite3` | No, one connection per isolate | Development, tests, small apps |

!!! info "Native drivers"
    Postgres and MySQL use a native (Rust) driver. There is no other driver.
    When the native library can not load, the app stops with an error.
    See the [Postgres](postgres-native.md#when-the-library-does-not-load) and
    [MySQL](mysql-native.md#when-the-library-does-not-load) pages.

## Skip unused drivers

`dox_orm` brings all three drivers. The build downloads a native library for each one.
An app needs only the driver of its database.
To skip the others, add a `hooks: user_defines:` block to `pubspec.yaml`.

- Put it in the `pubspec.yaml` of your app.
- In a pub workspace, put it in the root `pubspec.yaml` of the workspace.
  Dart reads `user_defines` only from the root package.

`skip: true` turns off the download of a driver.
Only the bool `true` skips. Any other value does nothing.

### SQLite app

A new app uses SQLite. Its `pubspec.yaml` already has this block.

```yaml title="pubspec.yaml"
hooks:
  user_defines:
    dox_postgres_native:
      skip: true
    dox_mysql_native:
      skip: true
```

### Postgres app

```yaml title="pubspec.yaml"
hooks:
  user_defines:
    dox_mysql_native:
      skip: true
    sqlite3:
      source: system
```

### MySQL app

```yaml title="pubspec.yaml"
hooks:
  user_defines:
    dox_postgres_native:
      skip: true
    sqlite3:
      source: system
```

`sqlite3: source: system` comes from the `sqlite3` package.
The build does not download SQLite.
The app loads the `libsqlite3` library of the system when it opens SQLite.

!!! warning "SQLite on a system without `libsqlite3`"
    With `source: system`, the app fails when it opens SQLite on a system
    without `libsqlite3`. The `FROM scratch` Docker image has no `libsqlite3`.
    When your app opens SQLite, remove the `sqlite3` lines.

### Switch the database

When you switch the database, remove the `skip` line of the driver you now use.
Then run `dart pub get`.

A driver that is still skipped stops the app when it opens a pool.
The error says that the native library is not in the build, and to remove `skip`.

## Config

Put the connections in `lib/config/database.dart`.
`connection` is the name of the default connection.

```dart title="lib/config/database.dart"
import 'package:dox_orm/dox_orm.dart';
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
      debug: env.isDevelopment,
    ),
    'mysql': ConnectionConfig(
      driver: Driver.mysql, // also for MariaDB
      host: env.dbHost,
      port: env.dbPort ?? 3306,
      user: env.dbUsername,
      password: env.dbPassword,
      database: env.dbName,
      extra: <String, dynamic>{'maxConnectionCount': 10},
      debug: env.isDevelopment,
    ),
    'sqlite': ConnectionConfig(
      driver: Driver.sqlite,
      database: env.dbName, // file path, like db/dox.sqlite, or ':memory:'
      debug: env.isDevelopment,
    ),
  },
);
```

`env` is the typed env of the app, in `lib/config/env.dart`.
Change `my_app` to the name of your app in `pubspec.yaml`.

- `debug: true` prints each SQL query and its values. The app template turns it on only in development.
- `user`, `password`, `host` and `port` are not used by SQLite.

Start the ORM in a provider. The app template already has this file.
Each isolate runs the provider.
Isolates with the same settings share one pool, so `maxConnectionCount` is for the whole process.

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

Dox finds every `DoxProvider` class on its own.
After you add a provider, run `dart run build_runner build`.

### ORM flags

`OrmFlags` turns on opt-in ORM behaviors.
Each flag is off by default. With all flags off, the ORM works as this page and the other database pages say.
Pass the flags as `flags:` in `DatabaseConfig`:

```dart title="lib/config/database.dart"
DatabaseConfig databaseConfig = DatabaseConfig(
  connection: env.dbConnection,
  connections: <String, ConnectionConfig>{ /* ... */ },
  flags: OrmFlags.all(), // every flag on
);
```

Turn on only some flags by name:

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
| `laravelPostgresTypes` | On Postgres, `timestamps()` and `softDeletes()` make `TIMESTAMPTZ`, and `json()` makes `JSONB`. | A new table gets `TIMESTAMP` and `JSON`. |

- `OrmFlags.all()` turns on every flag. New apps can start with it.
- The ORM keeps the flags in `SqlQueryBuilder().flags`. Each isolate runs the ORM provider, so each isolate gets the same flags. All connections use them.
- `SqlQueryBuilder.initialize(..., flags: ...)` takes the flags too.
- `pluralTableNames` does not change a name set with `@DoxModel(table: ...)`. The default foreign key stays singular (`user_id`).
- `belongsToKeyFromRelation` needs the relation name. The model generator does not pass it yet, so a generated model still uses the class name. Set `foreignKey` on the relation to be sure.
- `laravelPostgresTypes` changes only tables made with `Schema.create`. It never changes a table that is already there, and `Schema.table` keeps the old types. MySQL and SQLite do not change.
- Migrations get the flags from `SqlQueryBuilder().flags`. `bin/migrate.dart` does not start the ORM, so give the flags to the migrator: `Migrator(migrations: migrations, flags: databaseConfig.flags)`. See [Migration](migration.md#database-settings).

### `.env`

The app config and the [migration](migration.md) commands read these values.

```py title=".env"
DB_CONNECTION=postgres # postgres, mysql or sqlite
DB_HOST=localhost
DB_PORT=5432           # 3306 for mysql
DB_NAME=dox            # for sqlite: the file path, like db/dox.sqlite
DB_USERNAME=postgres
DB_PASSWORD=postgres
```

### `DATABASE_URL`

Many hosts (Fly, Render, Heroku and others) give you one database url.
Dox reads it from the `DATABASE_URL` environment variable.

The rule: **when `DATABASE_URL` is set, it wins.**
It replaces the config of the default connection (`DatabaseConfig.connection`).
That config still gives `debug`, `printer`, `slowQueryMs` and `extra`.
Other named connections do not change.

```bash
DATABASE_URL=postgres://app:s%40cret@db.example.com:5432/blog?sslmode=require
```

| Form | Database |
|---|---|
| `postgres://user:pass@host:5432/db` or `postgresql://...` | Postgres |
| `mysql://user:pass@host:3306/db` or `mariadb://...` | MySQL, MariaDB |
| `sqlite:///abs/path.db`, `sqlite://db/dox.sqlite`, `sqlite::memory:`, `file:db/dox.sqlite` | SQLite |

- The user, password and database name are url-decoded. Write `@` in a password as `%40`.
- No port: `5432` for Postgres, `3306` for MySQL.
- For Postgres, `sslmode` works like libpq (`disable`, `prefer`, `require`, `verify-ca`, `verify-full`). `require` does not check the certificate. Use `verify-full` when your host supports it. See [Postgres TLS](postgres-native.md#tls).
- For MySQL, `ssl=true` (or `sslmode=require`) turns TLS on, and it checks the certificate. Add `verifyCertificate=false` to skip the check, only for a self-signed certificate in development.
- `host=/path` (or `socket=/path`) connects to a Unix socket, like `host=/cloudsql/project:region:instance`. See [Unix socket](#unix-socket).
- Any other option goes to `extra`, like `?maxConnectionCount=20`. A number becomes an `int`, `true` and `false` a `bool`. This works for SQLite too, like `sqlite://db/dox.sqlite?background=true`.

The ORM reads `DATABASE_URL` from the real environment, not from `.env`.
To use a url from `.env`, or any other url, give it yourself:

```dart
DatabaseConfig(
  connection: 'postgres',
  connections: {...},
  url: Env.get<String?>('DATABASE_URL'),
);
```

An empty `url` (`url: ''`) turns `DATABASE_URL` off.
To make one `ConnectionConfig` from a url, use `ConnectionConfig.fromUrl(url)`.
[Migrations](migration.md#database-settings) read `DATABASE_URL` too, also from `.env`.

### Unix socket

A host that starts with `/` is a Unix socket.
Google Cloud SQL on Cloud Run uses `/cloudsql/PROJECT:REGION:INSTANCE`.

```bash
DB_HOST=/cloudsql/my-project:europe-west1:blog
# or
DATABASE_URL=postgres://blog:secret@/blog?host=/cloudsql/my-project:europe-west1:blog
```

**Postgres**: the host is the socket folder, like in libpq.
The driver uses the socket file `<folder>/.s.PGSQL.<port>`.
A host that already ends with `/.s.PGSQL.5432` works too.

**MySQL and MariaDB**: the host is the socket file itself. The port is not used.
On Cloud SQL, the socket file is `/cloudsql/PROJECT:REGION:INSTANCE`.
A local server often uses `/var/run/mysqld/mysqld.sock` or `/tmp/mysql.sock`.

```bash
DB_CONNECTION=mysql
DB_HOST=/var/run/mysqld/mysqld.sock
# or
DATABASE_URL=mysql://app:secret@/app?socket=/var/run/mysqld/mysqld.sock
```

`?socket=` and `?host=` do the same thing.

### `extra` options

`extra` is a map in `ConnectionConfig` for driver options.

| Key | Database | Default | What it does |
|---|---|---|---|
| `maxConnectionCount` | Postgres, MySQL | `10` | Most connections in the pool. |
| `threads` | Postgres, MySQL | `1` | Rust threads of the native driver. |
| `maxConnectionAge` | MySQL | 12 hours | A connection older than this is opened again. |
| `preparedStatementCacheSize` | MySQL, SQLite | `100` | Prepared statements kept per connection. |
| `sslMode` | Postgres | `disable` | TLS mode: `disable`, `prefer`, `require`, `verify-ca` or `verify-full`. |
| `sslRootCert` | Postgres | none | Path of a PEM file with the CA certificates to trust for `verify-ca` and `verify-full`. |
| `verifyCertificate` | MySQL | `true` | `false` skips the TLS certificate check. Only for development. |
| `timeZone` | Postgres | `UTC` | Time zone of the session. |
| `applicationName` | Postgres | none | Name of the app in `pg_stat_activity`. |
| `busyTimeout` | SQLite | `5000` | Milliseconds a query waits for a lock. |
| `background` | SQLite | `false` | `true` (or `1`, `'true'`, `'1'`) runs the queries in a helper isolate. See [Run queries in a helper isolate](#run-queries-in-a-helper-isolate). |

### Table and column names are quoted

Table and column names you pass to `select`, `where`, `join`, `groupBy`, `orderBy`,
`insert` and `update` are quoted.
Postgres and SQLite use `"name"`. MySQL uses `` `name` ``.
So names like `order` or `key` work.

- `table.column`, `table.*`, `*` and `column as alias` are quoted in the right way.
- Anything else (for example `count(*) as total`) throws an `ArgumentError`.
  So user input can not add SQL.
- For expressions, use the raw methods (`selectRaw`, `whereRaw`, `orderByRaw`, `groupByRaw`, `joinRaw`).
- On Postgres, a quoted name is case sensitive. `userId` is not the same column as `userid`.

### Raw queries

`QueryBuilder.query()` runs SQL on the default connection.
Use `@name` for values. The values are sent as bound parameters.

```dart
List<Map<String, dynamic>> rows = await QueryBuilder.query(
  'select * from blog where id = @id',
  substitutionValues: <String, dynamic>{'id': 1},
);
```

Pass `connection` to run it on another connection.

```dart
await QueryBuilder.query('select 1', connection: 'mysql');
```

### Other connections

Use `withConnection()` with a connection name from the config.

```dart
List<Map<String, dynamic>> rows = await QueryBuilder.table('blog')
    .withConnection('mysql')
    .get();
```

A model keeps its connection. `save()` and `delete()` use it.
Models that a query returns use the connection of the query.

```dart
Blog blog = Blog()..withConnection('mysql');
blog.title = 'Hello';
await blog.save(); // saved on 'mysql'
```

### Listen to queries

`SqlQueryBuilder().listen()` runs your function after each query.
It works on every connection and inside a transaction.
Use it for metrics or your own query log.

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

The function runs only after a query that worked. A failed query is not sent: its error goes to your code.
It also gets the queries of `Schema`, `truncate()` and the migrator, when they run on a connection of the ORM. A migrator that opens its own database from `.env` does not use a connection of the ORM, so its queries are not sent.
If the function throws, Dox logs the error and the query still returns its rows.
`SqlQueryBuilder().removeListener(onQuery)` stops it.

### Slow query log

Set `slowQueryMs` on a connection to log each query that takes longer than that many milliseconds.
It is off by default. It works with `debug` off, so you can use it in production.

```dart
'postgres': ConnectionConfig(
  driver: Driver.postgres,
  // ...
  debug: env.isDevelopment,
  slowQueryMs: 500,
),
```

The log line goes to the query `printer`.
It has the time, the connection name and the SQL, like `Slow query (812 ms, postgres): select ...`.
A value named in `logRedact` shows as `***`.
Set `slowQueryMs` to `0` to log every query.
A failed query is not logged here.
With `debug` on, a slow query of the query builder shows twice: the debug line before it runs, and the slow line with its time after it.

## MySQL and MariaDB

- The driver is [`dox_mysql_native`](mysql-native.md). Its page lists how values are converted.
- `CREATE`, `ALTER` and `DROP` are saved right away. A transaction can not undo them.

## SQLite

SQLite is good for development, tests and small apps.
For a busy production app, use Postgres or MySQL.

!!! info "How it runs"
    The `sqlite3` package calls SQLite directly (FFI). A query blocks the isolate while it runs.
    Each isolate has one connection.
    The file uses WAL mode, so readers do not wait for the writer.
    `busyTimeout` makes a query wait for a lock from another isolate, instead of failing.
    Foreign keys are on.
    Before each `SELECT`, the driver checks `PRAGMA schema_version` to see if a table changed.

!!! info "Types"
    SQLite has no bool, JSON or date type. Dox converts them for you:

    - `boolean()` is saved as `0`/`1` and read back as `bool`.
    - `json()` is saved as text and read back as `Map` or `List`.
    - Dates are saved as ISO text in UTC and read back as `DateTime`.

    The driver uses the column type in `CREATE TABLE`.
    It finds the table by the table names in the query.
    So it works on tables made by `Schema`, or by SQL with the same type names
    (`BOOLEAN`, `JSON`, `TIMESTAMP`, `DATE`, `DATETIME`).
    A column with an alias (`active as is_active`) is not converted.

!!! warning "Limits"
    - Schema limits (`change()`, `dropColumn`, `NOT NULL` columns) are in [SQLite notes](schema.md#sqlite-notes).
    - `dropColumn` does not work on a primary key column.
    - `insertMultiple` with rows that have different keys inserts the rows one by one,
      because SQLite has no `DEFAULT` in `VALUES`.
    - SQLite before 3.39 has no `RIGHT JOIN`.

!!! info "Native library"
    The `sqlite3` package (v3) bundles SQLite with a build hook.
    You do not install a system library.
    For the AOT binary, use `dox build`. It puts the library in `build/bundle/lib/`,
    next to `build/bundle/bin/server`. Keep the two folders together.
    `dart compile exe` does not work with build hooks.
    See [Deployment](../digging-deeper/deployment.md).

### Run queries in a helper isolate

A SQLite query blocks the isolate while it runs.
So one slow query stops every other request on that isolate.

Set `background` to `true` to run the queries in a helper isolate.
The helper isolate opens the database and runs every query.
Your isolate only waits for the answer, so it keeps serving other requests.

```dart
'sqlite': ConnectionConfig(
  driver: Driver.sqlite,
  database: 'db/dox.sqlite',
  debug: false,
  extra: {'background': true},
),
```

It is off by default.
Queries, transactions, `:memory:` databases, the query listener and the slow query log work the same.
A SQL error is the same `SqliteException`.
A database that does not open (for example a wrong folder) does not throw at startup. The error comes on the first query, and on every query after it.
To turn it on with `DATABASE_URL`, add `?background=true`, like `sqlite://db/dox.sqlite?background=true`.

Each query costs one message to the helper isolate and one back.

- Turn it on when some queries are slow, like a big report or a search with no index.
- Leave it off when the app runs many tiny queries. They get a little slower.
