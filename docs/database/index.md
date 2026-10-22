# Database

Dox talks to Postgres, MySQL/MariaDB and SQLite with the `dox_orm` package.

- [Query builder](query-builder.md): build SQL with methods.
- [Models](model/index.md): one class per table.
- [Transactions](transactions.md): many queries that succeed or fail together.
- [Migration](migration.md) and [Schema](schema.md): create and change tables.

## Install

The query builder and models live in the `dox_orm` package.

```bash
dart pub add dox_orm
```

```dart
import 'package:dox_orm/dox_orm.dart';
```

!!! note
    `dox_orm` was called `dox_query_builder` before 3.0. The old package only re-exports `dox_orm` now. Change your `pubspec.yaml` and imports to `dox_orm`.

## Supported databases

| Database | `Driver` | Dart package | Pool | Good for |
|---|---|---|---|---|
| Postgres | `Driver.postgres` | `postgres` | Yes | Production |
| MySQL 8+ and MariaDB | `Driver.mysql` | `mysql_dart` | Yes | Production |
| SQLite | `Driver.sqlite` | `sqlite3` | No, one connection per isolate | Dev, tests, small apps |

!!! tip
    For more speed, see the [native Postgres driver](postgres-native.md) and the [native MySQL driver](mysql-native.md).

## Config

Put the connections in `lib/config/database.dart`.
`connection` is the name of the default connection.

```dart
DatabaseConfig databaseConfig = DatabaseConfig(
  connection: Env.get('DB_CONNECTION', 'postgres'),
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

Start it in a service, so every isolate has its own pool.

```dart
class ORMService implements DoxService {
  @override
  Future<void> setup() async {
    SqlQueryBuilder.initializeWithDatabaseConfig(databaseConfig);
  }
}
```

### `.env`

The app config and the [migration](migration.md) commands read these values.

```py
DB_CONNECTION=postgres # postgres, mysql or sqlite
DB_HOST=localhost
DB_PORT=5432           # 3306 for mysql
DB_NAME=dox            # for sqlite: the file path, like storage/app.db
DB_USERNAME=postgres
DB_PASSWORD=postgres
```

!!! info "MySQL `extra` options"
    `maxConnectionCount` (default 10) is the pool size.
    `collation` (default `utf8mb4_general_ci`), `timeoutMs`, `timeZone` and `maxConnectionAge`
    are also read.
    The MySQL 8 default login (`caching_sha2_password`) works, also without TLS.
    Without TLS the driver asks the server for its RSA key to encrypt the password.
    To not ask, give the key in `serverPublicKey`, or set `useSSL: true`.
    Set `allowPublicKeyRetrieval: false` to turn the asking off.

!!! info "SQLite `extra` options"
    `busyTimeout` (default 5000 ms) is how long a query waits for a lock.

!!! info "Table and column names are quoted"
    Table and column names you pass to `select`, `where`, `join`, `groupBy`, `orderBy`,
    `insert` and `update` are quoted: `"name"` on Postgres and SQLite, and `` `name` `` on MySQL.
    So names like `order` or `key` work.
    `table.column`, `*` and `column as alias` are handled.
    A value with `(` (for example `count(*) as total`) is kept as it is.
    For anything else, use the raw functions (`selectRaw`, `whereRaw`, `joinRaw`).
    On Postgres a quoted name is case sensitive, so `userId` is not the same as `userid`.

### Raw queries

```dart
List<Map<String, dynamic>> rows = await QueryBuilder.query(
  'select * from blog where id = @id',
  substitutionValues: <String, dynamic>{'id': 1},
);
```

## MySQL and MariaDB

- The driver is `mysql_dart`. MySQL 8 and 9 login (`caching_sha2_password`) works.
- It has a real connection pool and sends values as bound parameters.
- `getDatabaseConnection()` returns a `MySQLConnectionPool`.
- `CREATE`, `ALTER` and `DROP` save right away. A transaction can not undo them.

### MySQL JSON

!!! info
    On MySQL, JSON columns are decoded to `Map` or `List` when you read them.
    Other text columns are not decoded.
    MariaDB stores JSON as `LONGTEXT`, so the driver can not see the column type.
    On MariaDB, text that starts with `{` or `[` and is valid JSON is decoded.
    `boolean()` columns (`TINYINT(1)`) are read as `bool`.

### MySQL types

!!! info
    MySQL values are converted by column type:
    integers to `int`, `FLOAT`, `DOUBLE` and `DECIMAL` to `double`,
    `DATE`, `DATETIME` and `TIMESTAMP` to `DateTime` (read as UTC),
    `boolean()` (`TINYINT(1)`) to `bool`. `TIME` stays a `String`.

## SQLite

SQLite is good for development, tests and small apps.
For a busy production app, use Postgres or MySQL.

!!! info "How it runs"
    The `sqlite3` package calls SQLite directly (FFI). A query blocks the isolate while it runs.
    Each isolate has one connection. While a transaction is open, other queries of that isolate wait.
    The database file uses WAL mode, so readers do not wait for the writer.
    `busy_timeout` makes a query wait for a lock from another isolate instead of failing.
    Foreign keys are turned on.

!!! info "Types"
    SQLite has no bool, JSON or date type.
    `boolean()` is saved as `0`/`1` and read back as `bool`.
    `json()` is saved as text and read back as `Map` or `List`.
    Dates are saved as ISO text in UTC and read back as `DateTime`.
    This uses the type in `CREATE TABLE`, so it works on tables made by `Schema` or by SQL
    with the same type names (`BOOLEAN`, `JSON`, `TIMESTAMP`, `DATE`, `DATETIME`).
    The driver finds the type by the table names in the query.
    A column with an alias (`active as is_active`) is not converted.

!!! warning "Limits"
    - `schema.table` with `.change()` changes a column (type, null, default) by making the table again
      and copying the rows. It keeps the primary key, foreign keys, unique columns and indexes.
      It throws for tables with `CHECK` constraints or generated columns.
    - `dropColumn` does not work on a primary key, unique or indexed column (SQLite limit).
    - A new column with `NOT NULL` needs a default value.
    - `truncate()` runs `DELETE FROM` and resets the id counter.
    - `insertMultiple` with rows that have different keys inserts the rows one by one,
      because SQLite has no `DEFAULT` in `VALUES`.
    - There is no `RIGHT JOIN` before SQLite 3.39.

!!! info "Native library"
    The `sqlite3` package (v3) bundles SQLite with a build hook. You do not install
    a system library. `dart run` and `dart test` run the hook by themselves.
    For the AOT binary use `dox build` (it runs `dart build cli`). It puts the library
    in `build/bundle/lib/`, next to `build/bundle/bin/server`. Keep the two folders together.
    `dart compile exe` does not work with build hooks. See [Deployment](../digging-deeper/deployment.md).
