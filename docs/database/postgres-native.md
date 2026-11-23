---
icon: lucide/database-zap
---

# Native Postgres driver

`dox_postgres_native` is the Postgres driver of the Dox ORM, written in Rust.

You use it through your models and queries. Rust ([tokio-postgres](https://docs.rs/tokio-postgres)) owns the connections and the pool, and each connection keeps its prepared statements.

## Setup

`dox_orm` already depends on `dox_postgres_native`. Add it yourself only to use `PgNativePool` without the ORM:

```bash
dart pub add dox_postgres_native
```

The build hook downloads a ready library for your system, so you do not need Rust. The package has its own repo: [dartondox/dox-postgres-native](https://github.com/dartondox/dox-postgres-native).

### Options

The driver reads these keys from `extra` of the `ConnectionConfig`:

| Key | Default | What it does |
|---|---|---|
| `maxConnectionCount` | 10 | Most connections in the pool, for the whole process. |
| `requestTimeout` | 300 s | The longest time for one request. |
| `maxConnectionAge` | no limit | Close a connection older than this, when it has no query. |
| `idleTimeout` | no limit | Close a free connection not used for this long. |
| `sslMode` | disable | TLS mode, see [TLS](#tls). |
| `sslRootCert` | none | PEM file with the CA certificates for verify-ca and verify-full. |
| `sslWarning` | true | false hides the warning for mode require. |
| `timeZone` | UTC | Time zone of the session. |
| `applicationName` | none | Name of the app in `pg_stat_activity`. |

See [Pool settings](index.md#pool-settings). Isolates with the same settings share one pool.

## When the library does not load

If the native library does not load, `SqlQueryBuilder.initializeWithDatabaseConfig` throws an `UnsupportedError`:

```text
dox_postgres_native did not load: <reason>.
Dox needs it to talk to Postgres. Fix: run the app with `dart run` or `dart build cli`. ...
```

To fix it:

- Run the app with `dart run`, `dart test` or `dart build cli`, because they run the build hook. `dart compile exe` does not.
- Or install [Rust](https://rustup.rs). The build hook then builds the library from source.
- If you set `lib_path` in `pubspec.yaml`, check that the file is there and fits your system.

## TLS

Use TLS when the database is on another machine. Set the mode with `extra['sslMode']`, `useSSL`, or `sslmode` in `DATABASE_URL`:

```dart
ConnectionConfig(
  driver: Driver.postgres,
  // ... host, user, password, database
  extra: <String, dynamic>{'sslMode': 'verify-full'},
  debug: false,
),
```

| Mode | What it does |
|---|---|
| disable | No TLS. The default. |
| prefer | TLS when the server has it. No certificate check. |
| require | TLS. No certificate check, like libpq. `useSSL: true` gives this mode. |
| verify-ca | TLS. The certificate is checked, the host name is not. |
| verify-full | TLS. The certificate and the host name are checked. |

!!! warning
    Mode require does not check the server certificate. Use verify-full when your host supports it. Dox prints one warning per isolate for require.

### Trusting your own CA

verify-ca and verify-full trust the Mozilla roots and the roots of the system. For another CA, give a PEM file in `extra['sslRootCert']`:

```dart
extra: <String, dynamic>{
  'sslMode': 'verify-full',
  'sslRootCert': '/etc/ssl/certs/db-ca.pem',
},
```

In the url, use `sslrootcert`:

```bash
DATABASE_URL=postgres://app:secret@db.example.com/blog?sslmode=verify-full&sslrootcert=/etc/ssl/certs/db-ca.pem
```

Then only the certificates in that file are trusted. A missing or bad file throws a `PgException` when the pool opens.

## Values and types

Send plain Dart values: null, a bool, an `int`, a `double`, a `String`, a `DateTime`, a `Duration` (interval), a `Uint8List` (bytea), a `Map` (json) or a `List` (an array). If the server can not pick the type, add a cast, like `@id::int8`.

The ORM sends a `List` as json text on insert and update. With the pool alone, send `jsonEncode(list)` for a json column.

| Postgres | Dart |
|---|---|
| int2, int4, int8 | `int` |
| float4, float8 | `double` |
| numeric | `String` |
| text, varchar, char | `String` |
| bool | `bool` |
| timestamp, timestamptz, date | `DateTime` in UTC |
| infinity dates | the text 'infinity' or '-infinity' |
| time | `String`, like '13:45:01.5' |
| interval | `Duration` (a month is 30 days) |
| json, jsonb | the decoded JSON value |
| uuid | `String` |
| bytea | `Uint8List` |
| arrays of most types above | `List` |
| NULL | null |

Other types come back as a `Uint8List`.

## Handling errors

A server error throws a `PgServerException`. Its `code` is the SQLSTATE, like 23505 for a unique violation:

```dart
try {
  await QueryBuilder.table('users')
      .insert(<String, dynamic>{'email': email});
} on PgServerException catch (error) {
  if (error.code == '23505') print('taken: ${error.constraint}');
}
```

It also has `severity` and `message`, and `detail`, `hint`, `schema`, `table`, `column` and `constraint` when the server sends them.

Other errors, like a down server, TLS or a timeout, throw a `PgException`. A cancelled query throws a `PgQueryCancelledException`, which is a `PgException`. All of them come from `package:dox_orm/dox_orm.dart`.

## Without Dox

### Opening a pool

`PgNativePool.open` opens a pool. `query` runs SQL and returns a `PgNativeResult` with `columns` and `rows`:

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

`parameters` is a map for `@name`, or a list for `$1, $2`. A host that starts with `/` is a Unix socket folder.

### Pool settings

`open` also takes `port` (5432), `maxConnections` (10), `timeZone`, `applicationName`, `sslMode`, `sslRootCert`, `requestTimeout`, `maxConnectionAge` and `idleTimeout`:

```dart
PgNativePool pool = PgNativePool.open(
  host: 'localhost',
  user: 'postgres',
  password: 'postgres',
  database: 'postgres',
  maxConnections: 20,
  requestTimeout: const Duration(seconds: 30),
  idleTimeout: const Duration(minutes: 5),
);
```

A request over `requestTimeout` fails with a timeout `PgException`.

### Pool from a url

`PgNativePool.fromUrl` reads sslmode, sslrootcert and application_name from the url:

```dart
PgNativePool pool = PgNativePool.fromUrl(
    'postgres://user:pass@host:5432/db?sslmode=require');
```

### Transactions

`begin` gives a transaction id. Pass it as `transaction` to each query:

```dart
int tx = await pool.begin();
await pool.query('UPDATE users SET name = @n',
    parameters: <String, dynamic>{'n': 'Bob'}, transaction: tx);
await pool.commit(tx); // or pool.rollback(tx)
```

### Cancelling a query

Pass a `PgCancelToken` and call `cancel()`. `isCancelled` is true after it:

```dart
PgCancelToken token = PgCancelToken();
Future<PgNativeResult> slow =
    pool.query('SELECT pg_sleep(60)', cancelToken: token);
token.cancel();
try {
  await slow;
} on PgQueryCancelledException {
  print('stopped');
}
```

In a transaction, a cancelled query aborts the transaction, so roll it back. In the ORM, use [`cancelWith()`](query-builder.md#cancelling-a-query).

### Streaming rows

`stream` gives the rows in chunks of up to `chunkSize` rows, 1000 by default. About two chunks are in memory at a time:

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

Stop the loop with `break` to stop the query. In the ORM, use [`cursor()`](query-builder.md#streaming-results).

### Sharing and closing a pool

`pool.handle` is an `int` that works in every isolate of the process. Open the same pool there with `PgNativePool.fromHandle(handle)`. `close()` gives back one open, and the last close closes the pool:

```dart
PgNativePool other = PgNativePool.fromHandle(pool.handle);
pool.close();
```

## Next steps

- [Database](index.md): connections and settings.
- [Native MySQL driver](mysql-native.md): the MySQL driver.
- [Performance: database drivers](../digging-deeper/performance.md#database-drivers): driver speed.
