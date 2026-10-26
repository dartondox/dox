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
That config still gives `debug`, `printer` and `extra`.
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
- Any other option goes to `extra`, like `?maxConnectionCount=20`. A number becomes an `int`, `true` and `false` a `bool`.

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
