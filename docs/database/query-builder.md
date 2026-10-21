# Query Builder

Query Builder provides a user-friendly interface where users can define the criteria and parameters for database queries without needing to write the SQL code manually. Query builders are commonly used in database management systems and data analysis tools to streamline the query creation process, making it more accessible to users who may not be proficient in writing SQL queries.

## Installation

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

## Config

Put the connections in `lib/config/database.dart`.

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

### `create`

=== "Create"

    ```dart
    await Actor().create(
        {'name': 'John Wick', 'age': 60}
    );
    ```

### `insert`

=== "Insert"

    ```dart
    await Actor().insert(
        {'name': 'John Wick', 'age': 60}
    );
    ```

=== "Multiple insert"

    ```dart
    await Actor().insertMultiple([
        {'name': 'John Wick', 'age': 60},
        {'name': 'John Doe', 'age': 25},
    ]);
    ```

!!! info
    `insert` works with any primary key type, for example a uuid string.
    `insertMultiple` uses the keys from all rows. When a row does not have a key,
    that column gets its default value.

### `update`

=== "Update rows"

    ```dart
    await Actor()
        .where('id', 3)
        .where('status', 'active')
        .update({
            "name": "Updated AJ",
            "age": 120,
        });
    ```

### `count`

=== "Count all"

    ```dart
    await Actor().count();
    ```

=== "Count with condition"

    ```dart
    await Actor().where('age', '>=' , 23).count();
    ```

!!! info
    `count()` does not use `limit`, `offset` and `orderBy`.
    With `groupBy`, `count()` returns the number of groups.

### `find`

=== "Find by id"

    ```dart
    await Actor().find(id);
    ```

=== "Find by custom column"

    ```dart
    await Actor().find('name', 'John Wick');
    ```

### `getFirst`

=== "Get first row"

    ```dart
    Actor actor = await Actor().getFirst(); // limit = 1
    ```

### `all`

=== "Ge all rows"

    ```dart
    List<Actor> actors = await Actor().all();
    for(Actor actor in actors) {
        print(actor.id)
    }
    ```

### `get`

=== "Get"

    ```dart
    List<Actor> actors = await Actor().where('name', 'John Wick').get();
        for(Actor actor in actors) {
        print(actor.id)
    }
    ```

### `toSql`

=== "To SQL query"

    ```dart
    String query = Actor().where('name', 'John Wick').toSql();
    print(query)
    ```

### `delete`

=== "Delete a row"

    ```dart
    await Actor().where('name', 'John Wick').delete();
    ```

### `forceDelete`

=== "Force delete"

    ```dart
    await Actor().where('name', 'John Wick').forceDelete();
    ```

!!! info
    This is for models with softDeletes. It also deletes rows that are already
    soft deleted, so you do not need `withTrash()`.

### `withTrash`

=== "Get from trash"

    ```dart
    List actors = await Actor().where('name', 'John Wick').withTrash().get();
    for(Actor actor in actors) {
        print(actor.id)
    }
    ```

!!! info
    This work only with softDeletes. On a model without softDeletes it does nothing.


### `select`

=== "Multiple select"

    ```dart
    await Actor()
        .select('id')
        .select('name')
        .where('name', 'John Wick').get();
    ```

=== "Select with array of columns"

    ```dart
    await Actor()
        .select(['id', 'name', 'age']).where('name', 'John Wick').get();
    ```

=== "Select with comma separated columns"

    ```dart
    await Actor()
        .select('id, name, age').where('name', 'John Wick').get();
    ```

=== "Select raw"

    ```dart
    // nothing is quoted
    await Actor().selectRaw('DISTINCT name').get();
    ```

### `whereIn`

=== "Where in condition"

    ```dart
    await Actor().whereIn('id', ['1', '2']).get();
    ```

=== "Where not in"

    ```dart
    await Actor().whereNotIn('id', [1, 2]).get();
    ```

=== "Or where in / not in"

    ```dart
    await Actor().where('age', 60).orWhereIn('id', [1, 2]).get();
    await Actor().where('age', 60).orWhereNotIn('id', [1, 2]).get();
    ```

!!! info
    Each value is sent as a bound parameter.
    An empty list matches no rows for `whereIn`, and all rows for `whereNotIn`.

### `whereNull`

=== "Where null / not null"

    ```dart
    await Actor().whereNull('deleted_at').get();
    await Actor().whereNotNull('deleted_at').get();
    ```

=== "Or where null / not null"

    ```dart
    await Actor().where('age', 60).orWhereNull('deleted_at').get();
    await Actor().where('age', 60).orWhereNotNull('deleted_at').get();
    ```

### `where`

=== "where"

    ```dart
    await Actor().where('name', 'John Wick').get();
    ```

=== "Where with custom condition"

    ```dart
    await Actor().where('name', '=', 'John Wick').get();
    await Actor().where('age', '>=', 23).get();
    ```

=== "Where null"

    ```dart
    // builds `deleted_at IS NULL`
    await Actor().where('deleted_at', null).get();
    ```

### `orWhere`

=== "orWhere"

    ```dart
    await Actor().orWhere('name', 'John Wick').get();
    ```

=== "orWhere with custom condition"

    ```dart
    await Actor().orWhere('name', '=', 'John Wick').get();
    await Actor().orWhere('age', '>=', 23).get();
    ```

=== "where and orWhere"

    ```dart
    await Actor()
    .where('name', 'John Doe').orWhere('name', 'John Wick').get();
    ```

### `whereRaw`

=== "whereRaw"

    ```dart
    await Actor().whereRaw('name = @name', {'name', 'John Wick'}).get();
    ```

### `orWhereRaw`

=== "Or where raw"

    ```dart
    await Actor().orWhereRaw('name = @name', {'name', 'John Wick'}).get();
    ```

### `limit`, `take`, `offset`

=== "Limit"

    ```dart
    await Actor().limit(10).get();
    ```

=== "Take"

    ```dart
    await Actor().take(10).get();
    ```

=== "offset"

    ```dart
    await Actor().limit(10).offset(10).get();
    ```

!!! info
    Limit and take are the same function.

### `groupBy`

=== "Group by"

    ```dart
    await Actor()
        .select('count(*) as total, name').groupBy('name').get();
    ```

### `orderBy`

=== "default"

    ```dart
    await Actor().orderBy('name').get();
    ```

=== "desc"

    ```dart
    await Actor().orderBy('name', 'desc').get();
    ```

=== "asc"

    ```dart
    await Actor().orderBy('name', 'asc').get();
    ```

=== "multiple columns"

    ```dart
    await Actor()
        .orderBy('name', 'asc')
        .orderBy('id', 'desc')
        .get();
    ```

!!! info
    The direction must be `asc` or `desc`. Any other value throws an `ArgumentError`.
    The column name is quoted, but a name with `(` is kept as it is.
    Do not pass user input as the column name.


### `join`

=== "Join"

    ```dart
    await Actor()
        .join('actor_info', 'actor_info.admin_id', 'admin.id')
        .get();
    ```

### `leftJoin`

=== "Left join"

    ```dart
    await Actor()
        .leftJoin('actor_info', 'actor_info.admin_id', 'admin.id')
        .get();
    ```

### `rightJoin`

=== "Right join"

    ```dart
    await Actor()
        .rightJoin('actor_info', 'actor_info.admin_id', 'admin.id')
        .get();
    ```

### `joinRaw`

=== "Join raw"

    ```dart
    await Actor()
        .joinRaw('actor_info on actor_info.admin_id = admin.id')
        .get();
    ```

### `leftJoinRaw`

=== "Left join raw"

    ```dart
    await Actor()
        .leftJoinRaw('actor_info on actor_info.admin_id = admin.id')
        .get();
    ```

### `rightJoinRaw`

=== "Right Join Raw"

    ```dart
    await Actor()
        .rightJoinRaw('actor_info on actor_info.admin_id = admin.id')
        .get();
    ```

### `debug`

=== "Debug"

    ```dart
    await Actor().debug(true).all();
    ```

### `transaction`

=== "Transaction"

    ```dart
    await QueryBuilder.transaction(() async {
        Actor actor = Actor();
        actor.name = 'John Wick';
        await actor.save();
        await QueryBuilder.table('actor_info').insert({'actor_id': actor.id});
    });
    ```

=== "Other connection"

    ```dart
    await QueryBuilder.transaction(() async {
        // ...
    }, connection: 'mysql');
    ```

!!! info
    The transaction commits when the function ends.
    It rolls back when the function throws, and the error is thrown again.
    All queries and models inside the function use the transaction.
    A transaction inside another transaction joins the outer one.
    On MySQL, create/alter/drop table commits right away and can not be rolled back.

### Connections

!!! info
    Postgres and MySQL use a connection pool. Set the pool size with `maxConnectionCount`
    in the connection `extra` config.
    A transaction uses one connection of the pool. Other queries use the other connections.
    Values are always sent as bound parameters, never written into the SQL text.
    SQLite uses one connection per isolate. While a transaction is open,
    other queries of that isolate wait until it ends.

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
    - `Schema.table` changes a column (type, null, default) by making the table again
      and copying the rows. It keeps the primary key, foreign keys, unique columns and indexes.
      It throws for tables with `CHECK` constraints or generated columns.
    - `dropColumn` does not work on a primary key, unique or indexed column (SQLite limit).
    - A new column with `NOT NULL` needs a default value.
    - `truncate()` runs `DELETE FROM` and resets the id counter.
    - `insertMultiple` with rows that have different keys inserts the rows one by one,
      because SQLite has no `DEFAULT` in `VALUES`.
    - There is no `RIGHT JOIN` before SQLite 3.39.

!!! info "Native library"
    The `sqlite3` package (v2) loads the SQLite library of the system.
    macOS has it. On Debian or Ubuntu, install `libsqlite3-dev` (it gives `libsqlite3.so`).
    `dart compile exe` works. Apps that do not use SQLite do not need the library.
    In the Dox Docker image (`FROM scratch`), copy the library into the final image:

    ```dockerfile
    FROM dart:stable AS build
    RUN apt-get update && apt-get install -y --no-install-recommends libsqlite3-0
    # ... build as before ...

    FROM scratch
    COPY --from=build /runtime/ /
    COPY --from=build /usr/lib/*-linux-gnu/libsqlite3.so.0 /usr/lib/libsqlite3.so
    # ... copy the server as before ...
    ```
