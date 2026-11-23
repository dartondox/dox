---
icon: lucide/database-zap
---

# Native MySQL driver

`dox_mysql_native` is the MySQL and MariaDB driver of the Dox ORM, written in Rust.

You use it through your models and queries, and it needs no extra config. Rust ([mysql_async](https://docs.rs/mysql_async)) owns the connections and the pool, and each connection keeps its prepared statements. It works with MySQL 8.4 (with the default `caching_sha2_password` login) and MariaDB 11.

## Setup

`dox_orm` already depends on `dox_mysql_native`, so you do not add it yourself. Add it only if you want to use `MysqlNativePool` without the ORM:

```bash
dart pub add dox_mysql_native
```

You do not need Rust, because the build hook downloads a ready-built library for your system. The package lives in its own repo: [dartondox/dox-mysql-native](https://github.com/dartondox/dox-mysql-native).

## When the library does not load

MySQL has no other driver in Dox. So if the native library does not load, `SqlQueryBuilder.initializeWithDatabaseConfig` (and every other place that opens a MySQL connection) throws an `UnsupportedError` like this:

```text
dox_mysql_native did not load: <reason>.
Dox needs it to talk to MySQL. Fix: run the app with `dart run` or `dart build cli`. ...
```

To fix it:

- Run the app with `dart run`, `dart test` or `dart build cli`, because they run the build hook. `dart compile exe` does not.
- Or install [Rust](https://rustup.rs). The build hook then builds the library from source.
- If you set `lib_path` in `pubspec.yaml`, check that the file is there and is built for your system.

## Options

The driver reads the normal fields of the `ConnectionConfig` (`host`, `port`, `user`, `password`, `database`, `useSSL`) and these keys from `extra`:

| Key | Default | What it does |
|---|---|---|
| `maxConnectionCount` | `10` | Most connections in the pool. |
| `requestTimeout` | 300 s | The longest wait for one request. |
| `maxConnectionAge` | 12 hours | A connection older than this is closed once it has no query. |
| `idleTimeout` | 12 hours | A connection with no traffic for this long is closed. |
| `serverKill` | `true` | Stop a cancelled or timed out query on the server with `KILL`. |
| `preparedStatementCacheSize` | `100` | Prepared statements kept per connection. |
| `verifyCertificate` | `true` | With `useSSL`, TLS checks the server certificate. Set it to `false` only for a self-signed certificate in development. |

The pool settings are explained in [Pool settings](index.md#pool-settings).

Isolates that open a pool with the same settings share one pool in Rust. So `maxConnectionCount` is for the whole process, not per isolate.

### Behind a proxy

When a query is cancelled or times out, the driver sends `KILL QUERY` on a new connection, so the server stops it. Behind a proxy or a load balancer, like ProxySQL or a cloud endpoint over many servers, that new connection may reach another server.

The driver checks that both connections name the same server, and it sends no `KILL` (and prints a warning) if they do not. But behind a proxy with its own connection ids, like ProxySQL, you should set `serverKill` to `false`:

```dart
extra: <String, dynamic>{'serverKill': false},
```

Then a cancelled query fails in Dart at once, but it runs to its end on the server. A timed out query only has its socket closed.

## Using the pool without the ORM

If you do not use the ORM, open a `MysqlNativePool` and run queries on it:

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
```

`parameters` is a list for `?`, or a map for `@name`. A write gives you the new id and the changed row count:

```dart
MysqlNativeResult insert = await pool.query(
  'INSERT INTO users (name) VALUES (@name)',
  parameters: <String, dynamic>{'name': 'Bob'},
);
print(insert.insertId); // the new AUTO_INCREMENT id
print(insert.affectedRows); // 1
```

### Transactions

A transaction runs on one connection, and its queries run in the order you send them. `execute` is like `query`, but the rows are not sent back to Dart:

```dart
int tx = await pool.begin();
await pool.execute('UPDATE users SET name = ?', parameters: <Object?>['Cy'], transaction: tx);
await pool.commit(tx); // or pool.rollback(tx)
```

### Pool settings

All pool settings are optional. Pass them to `MysqlNativePool.open`, with a `Duration` for each time:

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

They work like the [ORM pool settings](index.md#pool-settings). In `MysqlNativePool.open`, `maxConnectionAge` has no limit by default. In the ORM config, the default is 12 hours.

### Cancelling a query

Sometimes a query takes too long and you want to stop it. Pass a `MysqlCancelToken` and call `cancel()`. `query`, `execute` and `stream` all take `cancelToken`:

```dart
MysqlCancelToken token = MysqlCancelToken();
Future<MysqlNativeResult> slow = pool.query('SELECT SLEEP(10)', cancelToken: token);
token.cancel(); // slow fails with MysqlQueryCancelledException
```

If the query has not started, it does not run. If it is running, the driver sends `KILL QUERY` so the server stops it (see `serverKill`). If it already ended, nothing changes. In the ORM, use [`cancelWith()`](query-builder.md#cancelling-a-query).

### Streaming rows

For a big result, you do not want all rows in memory at once. `stream` gives the rows in chunks of up to `chunkSize` rows:

```dart
await for (MysqlNativeResult chunk in pool.stream('SELECT * FROM logs', chunkSize: 1000)) {
  print(chunk.rows.length); // up to 1000
}
```

Rust reads at most 2 chunks ahead of your listener, so a big result does not fill the memory. Stop listening (`break` in `await for`) to stop the query. Do not pause a stream for longer than the server's `net_write_timeout` (60 s by default), because the server then stops the connection. In the ORM, use [`cursor()`](query-builder.md#streaming-results).

## Types

Rows come back with these Dart types:

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

MariaDB keeps `JSON` columns as `LONGTEXT`. So on MariaDB, `TEXT` that holds a JSON object or array comes back decoded.

## Handling errors

Every error throws `MysqlException`. For an error from the server, `code` is the MySQL error number, like `1062` for a duplicate key, so you can check for the error you expect:

```dart
try {
  await QueryBuilder.table('users').insert(<String, dynamic>{'email': email});
} on MysqlException catch (error) {
  if (error.code == 1062) print('taken');
}
```

`sqlState` is the 5 letter SQLSTATE. For other errors, like the server is down, both `code` and `sqlState` are null. `MysqlException` comes from `package:dox_orm/dox_orm.dart`.

## Details

This section is for special cases. Most apps do not need it.

### Limits

- The `timeZone`, `collation`, `serverPublicKey` and `timeoutMs` keys are not read. The connection uses `utf8mb4`.
- A login with `sha256_password` (not the default) does not work. The default `caching_sha2_password` and `mysql_native_password` work.

### Other cases

- A `driverFactory` on the connection wins over the native driver: the ORM uses your driver.
- You can give `driver.pool.handle` (an `int`) to another isolate and use `MysqlNativeDriver(MysqlNativePool.fromHandle(handle))` there. `MysqlNativeDriver` comes from `package:dox_orm/dox_orm.dart`.
- A `CREATE`, `ALTER`, `RENAME` or `DROP` makes every connection prepare its statements again. So run `CREATE TEMP TABLE` or `DROP` once at start up, not on every request.
- `maxConnectionAge` is a real age, also for a busy connection. `idleTimeout` and `maxConnectionAge` never close a connection that runs a query.
- In the url of `MysqlNativePool.fromUrl`, the option is `server_kill`. In `DATABASE_URL` of the ORM, use `?serverKill=false`.
- With `serverKill` on, each connection reads the server name once after login (`@@server_uuid`, on MariaDB the hostname, port and `server_id`). This small query shows in the general log and the audit log of the server. Two servers with the same `server_uuid` (for example a copied data folder) still look like one server.
- The `KILL` connection counts for `max_user_connections`. A `KILL` that fails prints a warning on stderr.
- In a transaction, the next queries wait until the `KILL` has its answer, so it can only stop the cancelled query. When more queries wait on the same connection, the cancelled one runs to its end instead, and its rows are dropped. A connection that got a `KILL QUERY` closes once it has no query. Inside a transaction it stays, and the transaction goes on.
- A stream reads rows as they come, and a paused listener stops the reading. Stopping a stream sends `KILL QUERY` and closes the connection. Outside a transaction, a stream gets a connection of its own. Pass `transaction:` to stream inside a transaction.
- Speed: a find-by-id query takes about 65 µs alone, and about 10 µs each with 32 queries in flight (AOT build, local MySQL 8.4 or MariaDB 11, Apple M-series). See [Performance: database drivers](../digging-deeper/performance.md#database-drivers).
- If you see a problem, please [open an issue](https://github.com/dartondox/dox-mysql-native/issues).
