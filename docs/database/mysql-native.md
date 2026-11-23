---
icon: lucide/database-zap
---

# Native MySQL driver

`dox_mysql_native` is the MySQL and MariaDB driver of the Dox ORM, written in Rust.

You use it through your models and queries. Rust ([mysql_async](https://docs.rs/mysql_async)) owns the connections and the pool, and each connection keeps its prepared statements. It works with MySQL 8.4 and MariaDB 11.

## Setup

`dox_orm` already depends on `dox_mysql_native`. Add it yourself only to use `MysqlNativePool` without the ORM:

```bash
dart pub add dox_mysql_native
```

The build hook downloads a ready library for your system, so you do not need Rust. The package has its own repo: [dartondox/dox-mysql-native](https://github.com/dartondox/dox-mysql-native).

### Options

The driver reads `host`, `port`, `user`, `password`, `database` and `useSSL` of the `ConnectionConfig`, and these keys from `extra`:

| Key | Default | What it does |
|---|---|---|
| `maxConnectionCount` | 10 | Most connections in the pool, for the whole process. |
| `requestTimeout` | 300 s | The longest time for one request. |
| `maxConnectionAge` | 12 hours | Close a connection older than this, when it has no query. |
| `idleTimeout` | 12 hours | Close a connection with no traffic for this long. |
| `serverKill` | true | Stop a cancelled or timed out query on the server with `KILL QUERY`. |
| `preparedStatementCacheSize` | 100 | Prepared statements kept per connection. |
| `verifyCertificate` | true | With `useSSL`, check the server certificate. Set false only for a self-signed certificate in development. |

See [Pool settings](index.md#pool-settings). The connection uses utf8mb4. A login with sha256_password does not work. The default caching_sha2_password and mysql_native_password work.

### Behind a proxy

A cancelled query gets a `KILL QUERY` on a new connection. Behind a proxy with its own connection ids, like ProxySQL, that connection can reach another server. Turn it off there:

```dart
extra: <String, dynamic>{'serverKill': false},
```

Then a cancelled query fails in Dart at once, but it runs to its end on the server. In `DATABASE_URL`, use `?serverKill=false`.

## When the library does not load

If the native library does not load, `SqlQueryBuilder.initializeWithDatabaseConfig` throws an `UnsupportedError`:

```text
dox_mysql_native did not load: <reason>.
Dox needs it to talk to MySQL. Fix: run the app with `dart run` or `dart build cli`. ...
```

To fix it:

- Run the app with `dart run`, `dart test` or `dart build cli`, because they run the build hook. `dart compile exe` does not.
- Or install [Rust](https://rustup.rs). The build hook then builds the library from source.
- If you set `lib_path` in `pubspec.yaml`, check that the file is there and fits your system.

`MysqlNativePool.isAvailable` tells you if the library loaded, and `MysqlNativePool.loadError` gives the reason.

## Types

Rows come back with these Dart types:

| MySQL, MariaDB | Dart |
|---|---|
| TINYINT(1) (`boolean()`) | `bool` |
| TINYINT, SMALLINT, INT, BIGINT, YEAR | `int` |
| FLOAT, DOUBLE, DECIMAL | `double` |
| CHAR, VARCHAR, TEXT, ENUM | `String` |
| DATE, DATETIME, TIMESTAMP | `DateTime` in UTC |
| TIME | `String`, like 12:34:56 |
| JSON | the decoded JSON value |
| BLOB, BINARY, VARBINARY | `Uint8List` |
| NULL | null |

MariaDB keeps JSON columns as LONGTEXT. So on MariaDB, TEXT that holds a JSON object or array comes back decoded.

## Handling errors

Every error throws a `MysqlException`. For a server error, `code` is the MySQL error number, like 1062 for a duplicate key:

```dart
try {
  await QueryBuilder.table('users')
      .insert(<String, dynamic>{'email': email});
} on MysqlException catch (error) {
  if (error.code == 1062) print('taken');
}
```

`sqlState` is the 5 letter SQLSTATE. For other errors, like a down server, both are null. A cancelled query throws a `MysqlQueryCancelledException`. They come from `package:dox_orm/dox_orm.dart`.

## Without Dox

### Opening a pool

`MysqlNativePool.open` opens a pool. `query` returns a `MysqlNativeResult` with `columns` and `rows`:

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

`parameters` is a list for `?`, or a map for `@name`. A write also gives the new id and the changed row count:

```dart
MysqlNativeResult insert = await pool.query(
  'INSERT INTO users (name) VALUES (@name)',
  parameters: <String, dynamic>{'name': 'Bob'},
);
print(insert.insertId);     // the new AUTO_INCREMENT id
print(insert.affectedRows); // 1
```

### Pool settings

`open` also takes `port` (3306), `maxConnections` (10), `secure` (TLS), `verifyCertificate`, `sslRootCert`, `statementCacheSize` (32), `requestTimeout`, `maxConnectionAge`, `idleTimeout` and `serverKill`:

```dart
MysqlNativePool pool = MysqlNativePool.open(
  host: 'localhost',
  user: 'root',
  password: 'password',
  database: 'app',
  secure: true,
  sslRootCert: '/etc/ssl/certs/db-ca.pem',
  requestTimeout: const Duration(seconds: 30),
);
```

A host that starts with `/` is a Unix socket file. Here `maxConnectionAge` has no limit by default.

### Pool from a url

`MysqlNativePool.fromUrl` takes a url with the mysql_async options, like `?pool_max=20`. The kill option there is `server_kill`:

```dart
MysqlNativePool pool =
    MysqlNativePool.fromUrl('mysql://root:password@localhost:3306/app');
```

### Transactions

`begin` gives a transaction id. `execute` is like `query`, but it sends no rows back:

```dart
int tx = await pool.begin();
await pool.execute('UPDATE users SET name = ?',
    parameters: <Object?>['Cy'], transaction: tx);
await pool.commit(tx); // or pool.rollback(tx)
```

### Cancelling a query

Pass a `MysqlCancelToken` to `query`, `execute` or `stream`, and call `cancel()`. `isCancelled` is true after it:

```dart
MysqlCancelToken token = MysqlCancelToken();
Future<MysqlNativeResult> slow =
    pool.query('SELECT SLEEP(10)', cancelToken: token);
token.cancel(); // slow fails with MysqlQueryCancelledException
```

In the ORM, use [`cancelWith()`](query-builder.md#cancelling-a-query).

### Streaming rows

`stream` gives the rows in chunks of up to `chunkSize` rows. Rust reads at most 2 chunks ahead:

```dart
await for (MysqlNativeResult chunk
    in pool.stream('SELECT * FROM logs', chunkSize: 1000)) {
  print(chunk.rows.length);
}
```

Stop the loop with `break` to stop the query. Do not pause a stream for longer than the `net_write_timeout` of the server (60 s by default). In the ORM, use [`cursor()`](query-builder.md#streaming-results).

### Sharing and closing a pool

`pool.handle` works in every isolate of the process. Open the same pool there with `MysqlNativePool.fromHandle(handle)`. `close()` gives back one open, and the last close closes the pool:

```dart
MysqlNativePool other = MysqlNativePool.fromHandle(pool.handle);
pool.close();
```

## Next steps

- [Database](index.md): connections and settings.
- [Native Postgres driver](postgres-native.md): the Postgres driver.
- [Performance: database drivers](../digging-deeper/performance.md#database-drivers): driver speed.
