---
icon: lucide/database-zap
---

# Native MySQL driver

`dox_mysql_native` is the MySQL and MariaDB driver of the Dox ORM, written in Rust.

You use it through your models and queries. It needs no extra config.
Rust ([mysql_async](https://docs.rs/mysql_async)) owns the connections and the pool.
Each connection keeps its prepared statements.
It works with MySQL 8.4 (the default `caching_sha2_password` login) and MariaDB 11.

!!! note "New driver"
    This driver is new. If you see a problem, please
    [open an issue](https://github.com/dartondox/dox-mysql-native/issues).

## Speed

A find-by-id query takes about 65 µs alone, and about 10 µs each with 32 queries in flight (AOT build, local MySQL 8.4 or MariaDB 11, Apple M-series). See [Performance: database drivers](../digging-deeper/performance.md#database-drivers).

## Install

`dox_orm` depends on `dox_mysql_native`. You do not add it yourself.
Add it only to use `MysqlNativePool` without the ORM:

```bash
dart pub add dox_mysql_native
```

You do not need Rust. The build hook downloads a ready-built library for
your system.

The package lives in its own repo:
[dartondox/dox-mysql-native](https://github.com/dartondox/dox-mysql-native).

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
| `requestTimeout` | 300 s | The longest wait for one request. |
| `maxConnectionAge` | 12 hours | A connection older than this is closed once it has no query. |
| `idleTimeout` | 12 hours | A connection with no traffic for this long is closed. |
| `serverKill` | `true` | Stop a cancelled or timed out query on the server with `KILL`. |
| `preparedStatementCacheSize` | `100` | Prepared statements kept per connection. |
| `threads` | `1` | Rust threads for all pools of the process. Only the first pool sets it. One thread is the fastest for most apps. |
| `verifyCertificate` | `true` | With `useSSL`, TLS checks the server certificate. Set it to `false` only for a self-signed certificate in development. |

Isolates that open a pool with the same settings share one pool in Rust.
So `maxConnectionCount` is for the whole process, not per isolate. You can
also give `driver.pool.handle` (an `int`) to another isolate and use
`MysqlNativeDriver(MysqlNativePool.fromHandle(handle))` there.
`MysqlNativeDriver` comes from `package:dox_orm/dox_orm.dart`.

A `CREATE`, `ALTER`, `RENAME` or `DROP` makes every connection prepare its statements again. If your app runs `CREATE TEMP TABLE` or `DROP` on every request, this happens each time. Do it once at start up, not per request.

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

## Pool settings

All are optional. In the ORM, put them in `extra` (see [Pool settings](index.md#pool-settings)).
Without the ORM, pass them to `MysqlNativePool.open`.
A time is a `Duration`.

```dart
MysqlNativePool pool = MysqlNativePool.open(
  host: 'localhost',
  user: 'root',
  password: 'password',
  database: 'app',
  requestTimeout: const Duration(seconds: 30),
  maxConnectionAge: const Duration(minutes: 30),
  idleTimeout: const Duration(minutes: 5),
  serverKill: true,
);
```

- `requestTimeout` (default 300 s): the longest wait for one request. A request is a free connection, the connect and the query. Over it, the request fails, and its connection is closed. A transaction with no request for this long is rolled back.
- `maxConnectionAge` (default: 12 hours in the ORM config, no limit in `MysqlNativePool.open`): a connection older than this is closed once it has no query. It is a real age, also for a busy connection.
- `idleTimeout` (default 12 hours): a connection with no traffic for this long is closed once it has no query.
- `serverKill` (default `true`): the driver stops a cancelled or timed out query on the server with `KILL QUERY`, sent on a new connection. In the url of `MysqlNativePool.fromUrl`, the option is `server_kill`. In `DATABASE_URL` of the ORM, use `?serverKill=false`.

A connection that runs a query is never closed by these.

The `KILL` connection goes to the same address as the connection of the query.
Each connection reads the server name once after login (`@@server_uuid`, on MariaDB the hostname, port and `server_id`).
The `KILL` is sent only when both connections name the same server. Else no `KILL` is sent, and a warning is printed.
This small query shows in the general log and the audit log of the server.

!!! warning "Behind a proxy"
    The `KILL` goes on a new connection.
    Behind a proxy or a load balancer (like ProxySQL, or a cloud endpoint over many servers), that connection may reach another server.
    The server name check then sends no `KILL`, so it can not hit another session.
    You can also set `serverKill: false` there.
    A cancelled query then fails in Dart at once, but it runs to its end on the server.
    A timed out query only has its socket closed.

The `KILL` connection also counts for `max_user_connections`.
A `KILL` that fails prints a warning on stderr.

## Cancel a query

```dart
MysqlCancelToken token = MysqlCancelToken();
Future<MysqlNativeResult> slow = pool.query('SELECT SLEEP(10)', cancelToken: token);
token.cancel(); // slow fails with MysqlQueryCancelledException
```

- `query`, `execute` and `stream` take `cancelToken`.
- Not started yet: it does not run. Running: the driver sends `KILL QUERY`, so the server stops it (see `serverKill`). Ended already: nothing changes.
- In a transaction, the next queries wait until the `KILL` has its answer, so it can only stop the cancelled query.
- When more queries wait on the same connection, the cancelled one runs to its end instead, and its rows are dropped.
- A connection that got a `KILL QUERY` closes once it has no query. Inside a transaction it stays, and the transaction goes on.

In the ORM, use [`cancelWith()`](query-builder.md#cancel-a-query).

## Stream rows

```dart
await for (MysqlNativeResult chunk in pool.stream('SELECT * FROM logs', chunkSize: 1000)) {
  print(chunk.rows.length); // up to 1000
}
```

- Each event is a chunk of up to `chunkSize` rows, with the same columns and rows as `query`.
- Rows are read from the server as they come. Rust reads at most 2 chunks ahead of your listener. A paused listener stops the reading, so a big result does not fill the memory.
- Stop listening (`break` in `await for`) to stop the query. It is stopped with `KILL QUERY`, and the connection is closed.
- Outside a transaction, a stream gets a connection of its own. Pass `transaction:` to stream inside a transaction.
- The server stops a connection whose client does not read for `net_write_timeout` (60 s by default). Do not pause a stream for longer.

In the ORM, use [`cursor()`](query-builder.md#lazy-lazybyid-and-cursor).

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
