# Database

This page shows how to connect Dox to a database.
Dox works with Postgres, MySQL, MariaDB and SQLite through the `dox_orm` package.

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
    D --> T["Dart driver<br>postgres, mysql_dart, sqlite3"]
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

| Database | `Driver` | Default driver | Fallback Dart driver | Pool | Good for |
|---|---|---|---|---|---|
| Postgres | `Driver.postgres` | [`dox_postgres_native`](postgres-native.md) | `postgres` | Yes | Production |
| MySQL 8+ and MariaDB | `Driver.mysql` | [`dox_mysql_native`](mysql-native.md) | `mysql_dart` | Yes | Production |
| SQLite | `Driver.sqlite` | `sqlite3` | none | No, one connection per isolate | Development, tests, small apps |

!!! info "Native drivers"
    Postgres and MySQL use a native (Rust) driver by default.
    It is faster when many requests run at the same time.
    You do not change any config for it.

    The ORM uses the Dart driver in these cases:

    - The native library can not load on your system. The ORM prints one warning line.
    - Postgres uses TLS (`useSSL: true` or `extra['sslMode']`). The native Postgres driver has no TLS yet.
    - You ask for it: set `DOX_DB_DRIVER=dart` for all connections,
      or `extra: {'native': false}` for one connection.

    See the [Postgres](postgres-native.md#use-the-dart-driver) and
    [MySQL](mysql-native.md#use-the-dart-driver) pages.

Dox picks the driver of a connection like this:

```mermaid
flowchart TD
    A["Driver.postgres or Driver.mysql"] --> B{"DOX_DB_DRIVER=dart<br>or extra native: false?"}
    B -->|yes| X["Dart driver"]
    B -->|no| C{"Postgres with TLS?<br>useSSL or sslMode"}
    C -->|yes| X
    C -->|no| L{"Native library loads?"}
    L -->|no| W["Dart driver<br>prints one warning"]
    L -->|yes| N["Native Rust driver"]
    Q["Driver.sqlite"] --> S["sqlite3<br>one connection per isolate"]
```

## Config

Put the connections in `lib/config/database.dart`.
`connection` is the name of the default connection.

```dart title="lib/config/database.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_orm/dox_orm.dart';

DatabaseConfig databaseConfig = DatabaseConfig(
  connection: env.dbConnection,
  connections: <String, ConnectionConfig>{
    'postgres': ConnectionConfig(
      driver: Driver.postgres,
      host: 'localhost',
      port: 5432,
      user: 'postgres',
      password: 'postgres',
      database: 'postgres',
      extra: <String, dynamic>{'maxConnectionCount': 10},
      debug: false,
    ),
    'mysql': ConnectionConfig(
      driver: Driver.mysql, // also for MariaDB
      host: 'localhost',
      port: 3306,
      user: 'root',
      password: 'password',
      database: 'dox',
      extra: <String, dynamic>{'maxConnectionCount': 10},
      debug: false,
    ),
    'sqlite': ConnectionConfig(
      driver: Driver.sqlite,
      database: 'storage/app.db', // file path, or ':memory:'
      debug: false,
    ),
  },
);
```

- `debug: true` prints each SQL query and its values.
- `user`, `password`, `host` and `port` are not used by SQLite.

Start the ORM in a service.
Each isolate runs the service. The native Postgres and MySQL drivers then share one pool per process (isolates with the same settings get the same pool), so `maxConnectionCount` is for the whole process. The Dart drivers make one pool per isolate.
On shutdown, `SqlQueryBuilder.close()` closes every connection of the isolate.

```dart title="lib/services/orm_service.dart"
class ORMService implements DoxService, DoxShutdown {
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

### `.env`

The app config and the [migration](migration.md) commands read these values.

```py title=".env"
DB_CONNECTION=postgres # postgres, mysql or sqlite
DB_HOST=localhost
DB_PORT=5432           # 3306 for mysql
DB_NAME=dox            # for sqlite: the file path, like storage/app.db
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
- `sslmode`: `disable`, `allow` and `prefer` mean no TLS. Other values turn TLS on. For Postgres it works like libpq: `require` encrypts but does not check the server certificate (Heroku urls use it). `verify-ca` and `verify-full` check the certificate. Use `verify-full` when your host supports it. `useSSL: true` in code also checks the certificate. Add `verifyCertificate=false` to skip the check, only for a self-signed certificate in development. For MySQL, `ssl=true` works too, and it checks the certificate.
- The native Postgres driver has no TLS yet. With TLS on, Postgres uses the Dart driver.
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
Both the native and the Dart Postgres driver use the socket file `<folder>/.s.PGSQL.<port>`.
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

`?socket=` and `?host=` do the same thing. Both the native and the Dart MySQL driver use the socket.

### `extra` options

`extra` is a map in `ConnectionConfig` for driver options.

| Key | Database | Default | What it does |
|---|---|---|---|
| `maxConnectionCount` | Postgres, MySQL | `10` | Most connections in the pool. |
| `native` | Postgres, MySQL | `true` | `false` uses the Dart driver for this connection. |
| `threads` | Postgres, MySQL | `1` | Rust threads of the native driver. |
| `maxConnectionAge` | MySQL | 12 hours | A connection older than this is opened again. |
| `preparedStatementCacheSize` | MySQL, and the Dart Postgres and SQLite drivers | `100` | Prepared statements kept per connection. |
| `timeZone` | Postgres | `UTC` | Time zone of the session. |
| `applicationName` | Postgres | none | Name of the app in `pg_stat_activity`. |
| `busyTimeout` | SQLite | `5000` | Milliseconds a query waits for a lock. |

The Dart drivers read some more keys.
The Dart Postgres driver reads the `PoolSettings` keys of the `postgres` package,
like `sslMode`, `queryTimeout` and `connectTimeout`.
The Dart MySQL driver reads `collation` (default `utf8mb4_general_ci`), `timeoutMs`,
`timeZone`, `serverPublicKey` and `allowPublicKeyRetrieval`.

!!! info "MySQL 8 login without TLS"
    The MySQL 8 default login (`caching_sha2_password`) needs the server RSA key without TLS.
    A fake server can send its own key and read the password.
    So the Dart driver only asks the server for it with TLS on, or on `localhost`,
    `127.0.0.1`, `::1` or a Unix socket.
    Else give the key in `serverPublicKey` (safer), set `useSSL: true`,
    or set `allowPublicKeyRetrieval: true`.

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

- The default driver is [`dox_mysql_native`](mysql-native.md).
  The fallback Dart driver is `mysql_dart`.
- Both have a connection pool and send values as bound parameters.
- MySQL 8 and 9 login (`caching_sha2_password`) works.
- `CREATE`, `ALTER` and `DROP` are saved right away. A transaction can not undo them.

MySQL values are converted by column type:

| MySQL / MariaDB | Dart |
|---|---|
| Integer types | `int` |
| `FLOAT`, `DOUBLE`, `DECIMAL` | `double` |
| `DATE`, `DATETIME`, `TIMESTAMP` | `DateTime`, read as UTC |
| `boolean()` columns (`TINYINT(1)`) | `bool` |
| `TIME` | `String` |
| `JSON` | `Map` or `List` |

!!! info "JSON on MariaDB"
    MariaDB stores JSON as `LONGTEXT`, so the driver can not see the column type.
    On MariaDB, text that starts with `{` or `[` and is valid JSON is decoded.
    Other text columns are not decoded.

## SQLite

SQLite is good for development, tests and small apps.
For a busy production app, use Postgres or MySQL.

!!! info "How it runs"
    The `sqlite3` package calls SQLite directly (FFI).
    A query blocks the isolate while it runs.
    Each isolate has one connection.
    While a transaction is open, the other queries of that isolate wait.
    The database file uses WAL mode, so readers do not wait for the writer.
    `busy_timeout` makes a query wait for a lock from another isolate, instead of failing.
    Foreign keys are turned on.

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
    - `schema.table` with `.change()` makes the table again and copies the rows.
      See [SQLite notes](schema.md#sqlite-notes).
    - `dropColumn` does not work on a primary key, unique or indexed column.
    - A new column with `NOT NULL` needs a default value.
    - `truncate()` runs `DELETE FROM` and resets the id counter.
    - `insertMultiple` with rows that have different keys inserts the rows one by one,
      because SQLite has no `DEFAULT` in `VALUES`.
    - SQLite before 3.39 has no `RIGHT JOIN`.

!!! info "Native library"
    The `sqlite3` package (v3) bundles SQLite with a build hook.
    You do not install a system library.
    `dart run` and `dart test` run the hook by themselves.
    For the AOT binary, use `dox build` (it runs `dart build cli`).
    It puts the library in `build/bundle/lib/`, next to `build/bundle/bin/server`.
    Keep the two folders together.
    `dart compile exe` does not work with build hooks.
    See [Deployment](../digging-deeper/deployment.md).
