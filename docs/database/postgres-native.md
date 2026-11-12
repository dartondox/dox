---
icon: lucide/database-zap
---

# Native Postgres driver

`dox_postgres_native` is the Postgres driver of the Dox ORM, written in Rust.

You use it through your models and queries. It needs no extra config.
Rust ([tokio-postgres](https://docs.rs/tokio-postgres)) owns the connections and the pool.
Each connection keeps its prepared statements.

!!! note "New driver"
    This driver is new. If you see a problem, please
    [open an issue](https://github.com/dartondox/dox-postgres-native/issues).

## Speed

A find-by-id query takes about 60 µs alone, and about 12.5 µs each with 64 queries in flight (AOT build, local Postgres 14, Apple M-series). See [Performance: database drivers](../digging-deeper/performance.md#database-drivers).

## Install

`dox_orm` depends on `dox_postgres_native`. You do not add it yourself.
Add it only to use `PgNativePool` without the ORM:

```bash
dart pub add dox_postgres_native
```

You do not need Rust. The build hook downloads a ready-built library for
your system.

The package lives in its own repo:
[dartondox/dox-postgres-native](https://github.com/dartondox/dox-postgres-native).

## When the library does not load

Postgres has no other driver in Dox. When the native library does not load,
`SqlQueryBuilder.initializeWithDatabaseConfig` (and every other place that
opens a Postgres connection) throws an `UnsupportedError` like this:

```text
dox_postgres_native did not load: <reason>.
Dox needs it to talk to Postgres. Fix: run the app with `dart run` or `dart build cli`. ...
```

The reason tells what went wrong, for example no library for your system.
To fix it:

- Run the app with `dart run`, `dart test` or `dart build cli`. They run the
  build hook. `dart compile exe` does not.
- Or install [Rust](https://rustup.rs). The build hook then builds the
  library from source.
- When you set `lib_path` in `pubspec.yaml`, check that the file is there
  and is built for your system.

A `driverFactory` on the connection wins over all of this: the ORM uses your
driver.

## TLS

Set the TLS mode with `useSSL` or `extra['sslMode']`, or with `sslmode` in
the `DATABASE_URL`:

| Mode | What it does |
|---|---|
| `disable` | No TLS. The default. |
| `prefer` | TLS when the server has it. No certificate check. |
| `require` | TLS. No certificate check, like libpq. `useSSL: true` gives this mode. |
| `verify-ca` | TLS. The certificate is checked, the host name is not. |
| `verify-full` | TLS. The certificate and the host name are checked. |

Without `sslRootCert`, `verify-ca` and `verify-full` use the Mozilla roots and the roots of the system.

In mode `require`, Dox prints a warning (once per isolate), because the server certificate is not checked. To hide it, set `extra['sslWarning']` to `false`, or add `sslWarning=false` to `DATABASE_URL`.

```dart
ConnectionConfig(
  driver: Driver.postgres,
  // ... host, user, password, database as before
  extra: <String, dynamic>{'sslMode': 'verify-full'},
  debug: false,
),
```

To trust your own CA (for example the CA bundle of your cloud database, or a
self-signed CA in development), give the path of a PEM file in
`extra['sslRootCert']`, or with `sslrootcert` in the url. Then `verify-ca` and
`verify-full` trust only the certificates in that file. `prefer` and `require` do not use it.

```dart
extra: <String, dynamic>{
  'sslMode': 'verify-full',
  'sslRootCert': '/etc/ssl/certs/db-ca.pem',
},
```

```bash
DATABASE_URL=postgres://app:secret@db.example.com/blog?sslmode=verify-full&sslrootcert=/etc/ssl/certs/db-ca.pem
```

A missing file, or a file with no valid certificate, throws `PgException`
when the pool opens.

## Options

The driver reads these keys from `extra` of the `ConnectionConfig`:

| Key | Default | What it does |
|---|---|---|
| `maxConnectionCount` | `10` | Most connections in the pool, for the whole process. |
| `requestTimeout` | 300 s | The longest wait for one request. |
| `maxConnectionAge` | no limit | A connection older than this is closed once it has no query. |
| `idleTimeout` | kept | A free connection not used for this long is closed. |
| `sslMode` | `disable` | TLS mode, see [TLS](#tls). |
| `sslRootCert` | none | Path of a PEM file with the CA certificates to trust for `verify-ca` and `verify-full`, see [TLS](#tls). |
| `timeZone` | `UTC` | Time zone of the session. |
| `applicationName` | none | Name of the app in `pg_stat_activity`. |
| `threads` | `1` | Rust threads for all pools of the process. `0` is one thread with a single-thread runtime. Only the first pool sets it. |

Isolates that open a pool with the same settings share one pool in Rust.
So `maxConnectionCount` is for the whole process, not per isolate. The
pool closes when the last isolate closes it. You can also give
`driver.pool.handle` (an `int`) to another isolate and use
`PostgresNativeDriver(PgNativePool.fromHandle(handle))` there.
`PostgresNativeDriver` comes from `package:dox_orm/dox_orm.dart`.

Each connection keeps up to 512 prepared statements. When it is full, it
drops the one used longest ago.

A `CREATE`, `ALTER` or `DROP` makes every connection prepare its statements again. If your app runs `CREATE TEMP TABLE` or `DROP` on every request, this happens each time. Do this once at start up, not per request.

## Use it without the ORM

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

int tx = await pool.begin();
await pool.query('UPDATE users SET name = @n', parameters: <String, dynamic>{'n': 'Bob'}, transaction: tx);
await pool.commit(tx); // or pool.rollback(tx)
```

- `parameters` is a map for `@name`, or a list for `$1, $2`.
- A transaction runs on one connection. Its queries run in the order you
  send them.
- `PgNativePool.fromUrl('postgres://user:pass@host:5432/db?sslmode=require')`
  makes a pool from a url.

## Pool settings

All are optional. In the ORM, put them in `extra` (see [Pool settings](index.md#pool-settings)).
Without the ORM, pass them to `PgNativePool.open`:

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

- `requestTimeout` (default 300 s): the longest wait for one request. A request is a free connection, the connect and the query. Over it, the request fails with a `PgException` that says `timeout`. A CancelRequest stops the query on the server, and its connection is closed. A transaction with no request for this long is rolled back.
- `maxConnectionAge` (default: no limit): a connection older than this is closed when it is next free. It is never closed while a query or a transaction uses it. This helps behind a load balancer, or to follow a DNS change after a failover.
- `idleTimeout` (default: kept): a free connection that is not used for this long is closed. A new one opens when it is needed.

`fromUrl` takes the same three. Isolates share one pool only when all settings are the same.

## Cancel a query

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

- Cancel before the query starts: it does not run.
- Cancel while it runs: the driver sends a Postgres CancelRequest, and the future fails with `PgQueryCancelledException`.
- Cancel after it ended: nothing happens. You keep the result.
- A query with a token gets a connection for itself, so the cancel can not stop another query.
- In a transaction, a cancelled query is an error, so Postgres aborts the transaction. Roll it back.
- One token can stop many queries. Use it in the isolate that made it.
- The CancelRequest goes in plain text on a new connection, like libpq before Postgres 17.

In the ORM, use [`cancelWith()`](query-builder.md#cancel-a-query).

## Stream rows

For a big result, `stream` gives the rows in chunks.
Each chunk is a `PgNativeResult` with up to `chunkSize` rows (default 1000).

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

- The query runs on a server-side portal. The driver asks for the next chunk only when your listener is ready. So only about two chunks are in memory, also for millions of rows.
- The query starts when you listen. Stop listening (`break` in `await for`) to stop it. Its connection is free again.
- `cancelToken` stops it too. Then the stream fails with `PgQueryCancelledException`.
- An error comes as a stream error, then the stream ends.
- It holds one connection until it ends. A paused listener that waits longer than `requestTimeout` fails with a timeout.
- It works in a transaction (`transaction: tx`). Other queries of that transaction wait until the stream ends.

In the ORM, use [`cursor()`](query-builder.md#lazy-lazybyid-and-cursor).

## Values

You send plain Dart values: `null`, `bool`, `int`, `double`, `String`,
`DateTime`, `Duration` (an interval), `Uint8List` (bytea), `Map` (json) and
`List` (an array, eg. for `int4[]`).

- The server picks the type. When it can not, add a cast in the SQL, eg.
  `@id::int8`.
- A `List` is an array, not json. On insert and update the ORM sends a
  `List` as json text, so a `List` in a json column works. With the pool
  alone, send `jsonEncode(list)` for a json column.

## Types

| Postgres | Dart |
|---|---|
| `int2`, `int4`, `int8` | `int` |
| `float4`, `float8` | `double` |
| `numeric` | `String` |
| `text`, `varchar`, `char` | `String` |
| `bool` | `bool` |
| `timestamp`, `timestamptz`, `date` | `DateTime` in UTC |
| `infinity` dates | the text `'infinity'` or `'-infinity'` |
| `time` | `String`, eg. `'13:45:01.5'` |
| `interval` | `Duration` (a month is 30 days) |
| `json`, `jsonb` | the decoded JSON value |
| `uuid` | `String` |
| `bytea` | `Uint8List` |
| arrays of most types above | `List` |
| `NULL` | `null` |

Other types come back as `Uint8List`.

## Errors

A server error throws `PgServerException`. It has `code` (the SQLSTATE, eg.
`23505` for a unique violation), `severity`, `message`, and `detail`, `hint`,
`schema`, `table`, `column` and `constraint` when the server sends them.
Other errors (eg. the server is down, a TLS error, a timeout) throw
`PgException`. A query stopped with a cancel token throws
`PgQueryCancelledException`, which is a `PgException`.
They come from `package:dox_orm/dox_orm.dart`.

```dart
try {
  await QueryBuilder.table('users').insert(<String, dynamic>{'email': email});
} on PgServerException catch (error) {
  if (error.code == '23505') print('taken: ${error.constraint}');
}
```
