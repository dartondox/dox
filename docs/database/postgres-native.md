---
icon: lucide/database-zap
---

# Native Postgres driver

`dox_postgres_native` is the Postgres driver of the Dox ORM, written in Rust.

You use it through your models and queries, and it needs no extra config. Rust ([tokio-postgres](https://docs.rs/tokio-postgres)) owns the connections and the pool, and each connection keeps its prepared statements.

## Installation

`dox_orm` already depends on `dox_postgres_native`, so you do not add it yourself. Add it only if you want to use `PgNativePool` without the ORM:

```bash
dart pub add dox_postgres_native
```

You do not need Rust, because the build hook downloads a ready-built library for your system. The package lives in its own repo: [dartondox/dox-postgres-native](https://github.com/dartondox/dox-postgres-native).

## When the library does not load

Postgres has no other driver in Dox. So if the native library does not load, `SqlQueryBuilder.initializeWithDatabaseConfig` (and every other place that opens a Postgres connection) throws an `UnsupportedError` like this:

```text
dox_postgres_native did not load: <reason>.
Dox needs it to talk to Postgres. Fix: run the app with `dart run` or `dart build cli`. ...
```

The reason tells you what went wrong, for example that there is no library for your system. To fix it:

- Run the app with `dart run`, `dart test` or `dart build cli`, because they run the build hook. `dart compile exe` does not.
- Or install [Rust](https://rustup.rs). The build hook then builds the library from source.
- If you set `lib_path` in `pubspec.yaml`, check that the file is there and is built for your system.

## TLS

You should use TLS when the database is on another machine, so nobody on the network can read the data. Set the mode with `extra['sslMode']`, with `useSSL`, or with `sslmode` in `DATABASE_URL`:

```dart
ConnectionConfig(
  driver: Driver.postgres,
  // ... host, user, password, database as before
  extra: <String, dynamic>{'sslMode': 'verify-full'},
  debug: false,
),
```

| Mode | What it does |
|---|---|
| `disable` | No TLS. The default. |
| `prefer` | TLS when the server has it. No certificate check. |
| `require` | TLS. No certificate check, like libpq. `useSSL: true` gives this mode. |
| `verify-ca` | TLS. The certificate is checked, the host name is not. |
| `verify-full` | TLS. The certificate and the host name are checked. |

Use `verify-full` if your host supports it. In mode `require`, Dox prints a warning (once per isolate), because the server certificate is not checked. To hide it, set `extra['sslWarning']` to `false`, or add `sslWarning=false` to `DATABASE_URL`.

### Trusting your own CA

By default, `verify-ca` and `verify-full` trust the Mozilla roots and the roots of the system. If your database uses another CA (for example the CA bundle of your cloud database, or a self-signed CA in development), give the path of a PEM file in `extra['sslRootCert']`:

```dart
extra: <String, dynamic>{
  'sslMode': 'verify-full',
  'sslRootCert': '/etc/ssl/certs/db-ca.pem',
},
```

Or use `sslrootcert` in the url:

```bash
DATABASE_URL=postgres://app:secret@db.example.com/blog?sslmode=verify-full&sslrootcert=/etc/ssl/certs/db-ca.pem
```

Then `verify-ca` and `verify-full` trust only the certificates in that file. `prefer` and `require` do not use it. A missing file, or a file with no valid certificate, throws `PgException` when the pool opens.

## Options

The driver reads these keys from `extra` of the `ConnectionConfig`:

| Key | Default | What it does |
|---|---|---|
| `maxConnectionCount` | `10` | Most connections in the pool, for the whole process. |
| `requestTimeout` | 300 s | The longest wait for one request. |
| `maxConnectionAge` | no limit | A connection older than this is closed once it has no query. |
| `idleTimeout` | no limit | A free connection not used for this long is closed. |
| `sslMode` | `disable` | TLS mode, see [TLS](#tls). |
| `sslRootCert` | none | Path of a PEM file with the CA certificates to trust for `verify-ca` and `verify-full`, see [TLS](#tls). |
| `timeZone` | `UTC` | Time zone of the session. |
| `applicationName` | none | Name of the app in `pg_stat_activity`. |

The pool settings are explained in [Pool settings](index.md#pool-settings).

Isolates that open a pool with the same settings share one pool in Rust. So `maxConnectionCount` is for the whole process, not per isolate.

## Using the pool without the ORM

If you do not use the ORM, open a `PgNativePool` and run queries on it:

```dart
PgNativePool pool = PgNativePool.open(
  host: 'localhost',
  user: 'postgres',
  password: 'postgres',
  database: 'postgres',
);

PgNativeResult result = await pool.query(
  'SELECT id, name FROM users WHERE id = @id',
  parameters: <String, dynamic>{'id': 1},
);
print(result.rows); // [{id: 1, name: Ada}]
```

`parameters` is a map for `@name`, or a list for `$1, $2`. To make a pool from a url, use `PgNativePool.fromUrl('postgres://user:pass@host:5432/db?sslmode=require')`.

### Transactions

A transaction runs on one connection, and its queries run in the order you send them:

```dart
int tx = await pool.begin();
await pool.query('UPDATE users SET name = @n', parameters: <String, dynamic>{'n': 'Bob'}, transaction: tx);
await pool.commit(tx); // or pool.rollback(tx)
```

### Pool settings

All pool settings are optional. Pass them to `PgNativePool.open`. `fromUrl` takes the same three:

```dart
PgNativePool pool = PgNativePool.open(
  host: 'localhost',
  user: 'postgres',
  password: 'postgres',
  database: 'postgres',
  requestTimeout: const Duration(seconds: 30),
  maxConnectionAge: const Duration(minutes: 30),
  idleTimeout: const Duration(minutes: 5),
);
```

They work like the [ORM pool settings](index.md#pool-settings). When a request goes over `requestTimeout`, it fails with a `PgException` that says `timeout`, and a CancelRequest stops the query on the server.

### Cancelling a query

Sometimes a query takes too long and you want to stop it. Pass a `PgCancelToken` and call `cancel()`:

```dart
PgCancelToken token = PgCancelToken();
Future<PgNativeResult> slow = pool.query('SELECT pg_sleep(60)', cancelToken: token);
token.cancel();
try {
  await slow;
} on PgQueryCancelledException {
  print('stopped');
}
```

If the query has not started, it does not run. If it is running, the driver sends a Postgres CancelRequest and the future fails with `PgQueryCancelledException`. If it already ended, you keep the result.

In a transaction, a cancelled query is an error, so Postgres aborts the transaction. Roll it back then. In the ORM, use [`cancelWith()`](query-builder.md#cancelling-a-query).

### Streaming rows

For a big result, you do not want all rows in memory at once. `stream` gives the rows in chunks. Each chunk is a `PgNativeResult` with up to `chunkSize` rows (default 1000):

```dart
await for (PgNativeResult chunk in pool.stream(
  'SELECT * FROM events WHERE day = @day',
  parameters: <String, dynamic>{'day': '2026-01-01'},
  chunkSize: 500,
)) {
  for (Map<String, dynamic> row in chunk.rows) {
    // ...
  }
}
```

The driver asks for the next chunk only when your listener is ready, so only about two chunks are in memory, even for millions of rows. Stop listening (`break` in `await for`) to stop the query. In the ORM, use [`cursor()`](query-builder.md#streaming-results).

## Values and types

You send plain Dart values: `null`, `bool`, `int`, `double`, `String`, `DateTime`, `Duration` (an interval), `Uint8List` (bytea), `Map` (json) and `List` (an array, for example for `int4[]`). The server picks the type. If it can not, add a cast in the SQL, like `@id::int8`.

A `List` is an array, not json. On insert and update the ORM sends a `List` as json text, so a `List` in a json column works. With the pool alone, send `jsonEncode(list)` for a json column.

Rows come back with these Dart types:

| Postgres | Dart |
|---|---|
| `int2`, `int4`, `int8` | `int` |
| `float4`, `float8` | `double` |
| `numeric` | `String` |
| `text`, `varchar`, `char` | `String` |
| `bool` | `bool` |
| `timestamp`, `timestamptz`, `date` | `DateTime` in UTC |
| `infinity` dates | the text `'infinity'` or `'-infinity'` |
| `time` | `String`, like `'13:45:01.5'` |
| `interval` | `Duration` (a month is 30 days) |
| `json`, `jsonb` | the decoded JSON value |
| `uuid` | `String` |
| `bytea` | `Uint8List` |
| arrays of most types above | `List` |
| `NULL` | `null` |

Other types come back as `Uint8List`.

## Handling errors

A server error throws `PgServerException`. Its `code` is the SQLSTATE, like `23505` for a unique violation, so you can check for the error you expect:

```dart
try {
  await QueryBuilder.table('users').insert(<String, dynamic>{'email': email});
} on PgServerException catch (error) {
  if (error.code == '23505') print('taken: ${error.constraint}');
}
```

`PgServerException` also has `severity` and `message`, and `detail`, `hint`, `schema`, `table`, `column` and `constraint` when the server sends them.

Other errors, like the server is down, a TLS error or a timeout, throw `PgException`. A query stopped with a cancel token throws `PgQueryCancelledException`, which is a `PgException`. All of them come from `package:dox_orm/dox_orm.dart`.

## Details

This section is for special cases. Most apps do not need it.

- A `driverFactory` on the connection wins over the native driver: the ORM uses your driver.
- The pool closes when the last isolate closes it. You can give `driver.pool.handle` (an `int`) to another isolate and use `PostgresNativeDriver(PgNativePool.fromHandle(handle))` there. `PostgresNativeDriver` comes from `package:dox_orm/dox_orm.dart`.
- Isolates share one pool only when all settings are the same.
- Each connection keeps up to 512 prepared statements. When it is full, it drops the one used longest ago.
- A `CREATE`, `ALTER` or `DROP` makes every connection prepare its statements again. So run `CREATE TEMP TABLE` or `DROP` once at start up, not on every request.
- `maxConnectionAge` also helps to follow a DNS change after a failover. A connection is never closed while a query or a transaction uses it.
- A query with a cancel token gets a connection for itself, so the cancel can not stop another query. One token can stop many queries. Use it in the isolate that made it. The CancelRequest goes in plain text on a new connection, like libpq before Postgres 17.
- A stream runs on a server-side portal and starts when you listen. It holds one connection until it ends, and a paused listener that waits longer than `requestTimeout` fails with a timeout. `cancelToken` stops it too, and then the stream fails with `PgQueryCancelledException`. An error comes as a stream error, then the stream ends. It works in a transaction (`transaction: tx`), and other queries of that transaction wait until the stream ends.
- Speed: a find-by-id query takes about 60 µs alone, and about 12.5 µs each with 64 queries in flight (AOT build, local Postgres 14, Apple M-series). See [Performance: database drivers](../digging-deeper/performance.md#database-drivers).
- If you see a problem, please [open an issue](https://github.com/dartondox/dox-postgres-native/issues).
