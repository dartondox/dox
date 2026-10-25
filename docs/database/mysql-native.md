# Native MySQL driver

`dox_mysql_native` is the MySQL and MariaDB driver of the Dox ORM.
Rust talks to the database. Your models, queries and transactions stay the
same. You do not change any config.

- Rust ([mysql_async](https://docs.rs/mysql_async)) owns the connections
  and the pool.
- Dart sends many queries to Rust in one call. Rust sends many results back
  in one message.
- Each connection keeps its prepared statements. The same SQL is not
  prepared again.
- Errors are `MysqlException`, with the MySQL error `code` and the
  `sqlState`.
- Works with MySQL 8.4 (the default `caching_sha2_password` login) and
  MariaDB 11.

!!! warning "Alpha"
    This driver is new. If you see a problem, please
    [open an issue](https://github.com/dartondox/dox-mysql-native/issues).

## Speed

One find-by-id query (`SELECT * FROM t WHERE id = @id`), AOT build
(`dart build cli`), database on the same machine (Apple M-series),
10 connections, one isolate:

| | Time |
|---|---|
| MySQL 8.4, one query at a time | 67 µs |
| MySQL 8.4, 32 queries in flight | 11 µs per query |
| MySQL 8.4, CPU time of the app per query | 13.5 µs |
| MariaDB 11, one query at a time | 63 µs |
| MariaDB 11, 32 queries in flight | 9.7 µs per query |
| MariaDB 11, CPU time of the app per query | 12.4 µs |

The CPU time counts the Dart thread and the Rust thread. It is the limit
on one CPU core: about 75,000 queries per second.

One query at a time spends most of its time on the trip to the database.
Many requests at the same time, like in a web server, get the most out of it.

## Install

`dox_orm` depends on `dox_mysql_native`. You do not add it yourself.
Add it only to use `MysqlNativePool` without the ORM:

```bash
dart pub add dox_mysql_native
```

You do not need Rust. The build hook downloads a ready-built library for
your system. When there is no library for your system and no Rust to build
one, the app stops with a clear error (see below).

The package lives in its own repo:
[dartondox/dox-mysql-native](https://github.com/dartondox/dox-mysql-native).

Use `dart run`, `dart test` or `dart build cli`. `dart compile exe` does not
run build hooks.

## When the library does not load

MySQL has no other driver in Dox. When the native library does not load,
`SqlQueryBuilder.initializeWithDatabaseConfig` (and every other place that
opens a MySQL connection) throws an `UnsupportedError` like this:

```text
dox_mysql_native did not load: <reason>.
Dox needs it to talk to MySQL. Fix: run the app with `dart run` or `dart build cli`. ...
```

To fix it:

- Run the app with `dart run`, `dart test` or `dart build cli`. They run the
  build hook. `dart compile exe` does not.
- Or install [Rust](https://rustup.rs). The build hook then builds the
  library from source.
- When you set `lib_path` in `pubspec.yaml`, check that the file is there
  and is built for your system.

A `driverFactory` on the connection wins over all of this: the ORM uses your
driver.

## Options

The driver reads the normal fields of the `ConnectionConfig` (`host`,
`port`, `user`, `password`, `database`, `useSSL`) and these keys from
`extra`:

| Key | Default | What it does |
|---|---|---|
| `maxConnectionCount` | `10` | Most connections in the pool. |
| `maxConnectionAge` | 12 hours | A connection older than this is closed and opened again. |
| `preparedStatementCacheSize` | `100` | Prepared statements kept per connection. |
| `threads` | `1` | Rust threads for all pools of the process. Only the first pool sets it. One thread is the fastest for most apps. |
| `verifyCertificate` | `true` | With `useSSL`, TLS checks the server certificate. Set it to `false` only for a self-signed certificate in development. |

Isolates that open a pool with the same settings share one pool in Rust.
So `maxConnectionCount` is for the whole process, not per isolate. The
native Postgres driver does the same. You can
also give `driver.pool.handle` (an `int`) to another isolate and use
`MysqlNativeDriver(MysqlNativePool.fromHandle(handle))` there.
`MysqlNativeDriver` comes from `package:dox_orm/dox_orm.dart`.

A request (pool slot, connect and query) fails after 300 s with no
answer. A transaction that gets no request for 300 s is rolled back, so
its connection goes back to the pool.

## Use it without the ORM

```dart
MysqlNativePool pool = MysqlNativePool.open(
  host: 'localhost',
  user: 'root',
  password: 'password',
  database: 'app',
);

MysqlNativeResult result = await pool.query(
  'SELECT id, name FROM users WHERE id = ?',
  parameters: <Object?>[1],
);
print(result.rows); // [{id: 1, name: Ada}]

MysqlNativeResult insert = await pool.query(
  'INSERT INTO users (name) VALUES (@name)',
  parameters: <String, dynamic>{'name': 'Bob'},
);
print(insert.insertId); // the new AUTO_INCREMENT id
print(insert.affectedRows); // 1

int tx = await pool.begin();
await pool.execute('UPDATE users SET name = ?', parameters: <Object?>['Cy'], transaction: tx);
await pool.commit(tx); // or pool.rollback(tx)
```

- `parameters` is a list for `?`, or a map for `@name`.
- `execute` is like `query`, but the rows are not sent back to Dart.
- A transaction runs on one connection. Its queries run in the order you
  send them.

## Types

| MySQL / MariaDB | Dart |
|---|---|
| `TINYINT(1)` (`boolean()`) | `bool` |
| `TINYINT`, `SMALLINT`, `INT`, `BIGINT`, `YEAR` | `int` |
| `FLOAT`, `DOUBLE`, `DECIMAL` | `double` |
| `CHAR`, `VARCHAR`, `TEXT`, `ENUM` | `String` |
| `DATE`, `DATETIME`, `TIMESTAMP` | `DateTime` in UTC |
| `TIME` | `String`, like `12:34:56` |
| `JSON` | the decoded JSON value |
| `BLOB`, `BINARY`, `VARBINARY` | `Uint8List` |
| `NULL` | `null` |

MariaDB keeps `JSON` columns as `LONGTEXT`. So on MariaDB, `TEXT` that is a
JSON object or array comes back decoded.

## Errors

Every error throws `MysqlException`. For an error from the server, `code`
is the MySQL error number (eg. `1062` for a duplicate key) and `sqlState`
is the 5 letter SQLSTATE. For other errors (eg. the server is down) both
are null. `MysqlException` comes from `package:dox_orm/dox_orm.dart`.

```dart
try {
  await QueryBuilder.table('users').insert(<String, dynamic>{'email': email});
} on MysqlException catch (error) {
  if (error.code == 1062) print('taken');
}
```

## Not yet

- The `timeZone`, `collation`, `serverPublicKey` and `timeoutMs` keys are
  not read. The connection uses `utf8mb4`.
- A login with `sha256_password` (not the default) does not work. The
  default `caching_sha2_password` and `mysql_native_password` work.
- A nested `transaction()` joins the outer one (no savepoints).
