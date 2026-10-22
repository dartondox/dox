# Native MySQL driver

`dox_mysql_native` is the default MySQL and MariaDB driver of the Dox ORM.
Rust talks to the database. Your models, queries and transactions stay the
same. You do not change any config.

- Rust ([mysql_async](https://docs.rs/mysql_async)) owns the connections
  and the pool.
- Dart sends many queries to Rust in one call. Rust sends many results back
  in one message.
- Each connection keeps its prepared statements. The same SQL is not
  prepared again.
- Values have the same Dart types as with the Dart driver (`mysql_dart`).
  Errors are the same `MySQLServerException` class.
- Works with MySQL 8.4 (the default `caching_sha2_password` login) and
  MariaDB 11.

!!! warning "Alpha"
    This driver is new. If you see a problem, [use the Dart driver](#use-the-dart-driver)
    and tell us.

## Speed

One find-by-id query (`SELECT * FROM t WHERE id = @id`), AOT build
(`dart build cli`), database on the same machine (Apple M-series),
10 connections, one isolate:

| | Dart driver | Native driver |
|---|---|---|
| MySQL 8.4, one query at a time | 61 µs | 67 µs |
| MySQL 8.4, 32 queries in flight | 25 µs per query | 11 µs per query |
| MySQL 8.4, CPU time of the app per query | 32 µs | 13.5 µs |
| MariaDB 11, one query at a time | 59 µs | 63 µs |
| MariaDB 11, 32 queries in flight | 25.5 µs per query | 9.7 µs per query |
| MariaDB 11, CPU time of the app per query | 32.5 µs | 12.4 µs |

The CPU time counts the Dart thread and the Rust thread. It is the limit
on one CPU core: about 31,000 queries per second with the Dart driver and
about 75,000 with the native driver.

One query at a time is about the same speed: most of the time is the trip
to the database. The gain is big when many requests run at the same time,
like in a web server.

## Install

`dox_orm` depends on `dox_mysql_native`. You do not add it yourself.
Add it only to use `MysqlNativePool` without the ORM:

```bash
dart pub add dox_mysql_native
```

You do not need Rust when a ready-built library exists for your system
(macOS arm64/x64, Linux x64/arm64, Windows x64). The build hook downloads
it. When there is none yet, the hook builds the library with `cargo`, so
then you need [Rust](https://rustup.rs).

Use `dart run`, `dart test` or `dart build cli`. `dart compile exe` does not
run build hooks.

## Native is the default

You do not change any config. The ORM picks the driver like this:

1. `driverFactory` is set: the ORM uses your driver. It wins over
   everything below.
2. You ask for the Dart driver (see below): the ORM uses the Dart driver.
3. The native library loads: the ORM uses the native driver.
4. The native library does not load (no library for your system, no
   Rust to build it, or a load error): the ORM uses the Dart driver. It
   prints one warning line to stderr, like this:

```text
[dox] warning: dox_mysql_native did not load, using the Dart mysql driver (...)
```

Named connections (`withConnection('x')`, `transaction(..., connection: 'x')`) follow
the same rules.

## Use the Dart driver

For all connections, set the env var:

```bash
DOX_DB_DRIVER=dart dart run bin/server.dart
```

For one connection, set `native: false` in `extra`:

```dart
ConnectionConfig(
  driver: Driver.mysql,
  // ... host, user, password, database as before
  extra: <String, dynamic>{'native': false},
  debug: false,
),
```

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

Isolates that open a pool with the same settings share one pool in Rust.
So `maxConnectionCount` is for the whole process, not per isolate. You can
also give `driver.pool.handle` (an `int`) to another isolate and use
`MysqlNativeDriver(MysqlNativePool.fromHandle(handle))` there.
`MysqlNativeDriver` comes from `package:dox_orm/dox_orm.dart`.

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

The same as the Dox ORM on the Dart driver:

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
JSON object or array comes back decoded. The Dart driver does the same.

## Errors

A server error throws the same exception as the Dart driver:
`MySQLServerException`, with the same `errorCode` (eg. `1062` for a
duplicate key) and `message`. Other errors (eg. the server is down) throw
`MySQLClientException`.

## Not yet

- The `timeZone`, `collation`, `serverPublicKey` and `timeoutMs` keys of the
  Dart driver are not read. The connection uses `utf8mb4`.
- A login with `sha256_password` (not the default) does not work. The
  default `caching_sha2_password` and `mysql_native_password` work.
- A nested `transaction()` joins the outer one, like the Dart driver
  (no savepoints).
