# Native Postgres driver

`dox_postgres_native` is a faster Postgres driver for the Dox ORM.
Rust talks to the database. Your models, queries and transactions stay the
same. You change one line of config.

- Rust ([tokio-postgres](https://docs.rs/tokio-postgres)) owns the
  connections and the pool.
- Dart sends many queries to Rust in one call. Rust sends many results back
  in one message.
- Each connection keeps its prepared statements. The same SQL is not parsed
  again.
- Values have the same Dart types as with the `postgres` package. Errors
  are the same `ServerException` classes.

!!! warning "Alpha"
    This driver is new. The default Dart driver is still the safe choice.

## Speed

One find-by-id query (`SELECT ... WHERE id = @id`), AOT build
(`dart build cli`), Postgres 14 on the same machine (Apple M-series),
4 connections:

| | Dart driver | Native driver |
|---|---|---|
| One query at a time | 95 µs | 60 µs |
| 64 queries in flight, one isolate | 45 µs per query | 12.5 µs per query |
| 4 isolates, 64 in flight each, 16 connections per pool | 39,500 queries/s | 64,000 queries/s |

The gain is biggest when many requests run at the same time, like in a web
server.

## Install

```bash
dart pub add dox_postgres_native
```

You do not need Rust when a ready-built library exists for your system
(macOS arm64/x64, Linux x64/arm64, Windows x64). The build hook downloads
it. When there is none yet, the hook builds the library with `cargo`, so
then you need [Rust](https://rustup.rs).

Use `dart run`, `dart test` or `dart build cli`. `dart compile exe` does not
run build hooks.

## Use it with the ORM

Keep your Postgres `ConnectionConfig` as it is. Start the ORM like before,
then put the native driver in place of the Dart one:

```dart
import 'package:dox_postgres_native/dox_postgres_native.dart';

class ORMService implements DoxService {
  @override
  Future<void> setup() async {
    SqlQueryBuilder.initializeWithDatabaseConfig(databaseConfig);
    SqlQueryBuilder().dbDriver = PostgresNativeDriver.fromConfig(
      databaseConfig.getConnectionConfig(),
    );
  }
}
```

That is all. `Model`, the query builder, `transaction()` and `Schema` now
run on the native driver.

## Options

The driver reads these keys from `extra` of the `ConnectionConfig`:

| Key | Default | What it does |
|---|---|---|
| `maxConnectionCount` | `10` | Most connections in the pool. |
| `timeZone` | `UTC` | Time zone of the session, like the Dart driver. |
| `applicationName` | none | Name of the app in `pg_stat_activity`. |
| `threads` | `1` | Rust threads for all pools of the process. `0` is one thread with a single-thread runtime. Only the first pool sets it. |

Each isolate that runs `setup()` makes its own pool. To share one pool
between isolates, give `driver.pool.handle` (an `int`) to the other
isolates and use `PostgresNativeDriver(PgNativePool.fromHandle(handle))`
there.

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

## Types

The same as the `postgres` package:

| Postgres | Dart |
|---|---|
| `int2`, `int4`, `int8` | `int` |
| `float4`, `float8` | `double` |
| `numeric` | `String` |
| `text`, `varchar`, `char` | `String` |
| `bool` | `bool` |
| `timestamp`, `timestamptz`, `date` | `DateTime` in UTC |
| `json`, `jsonb` | the decoded JSON value |
| `uuid` | `String` |
| `bytea` | `Uint8List` |
| arrays of most types above | `List` |
| `NULL` | `null` |

Other types decode with the type registry of the `postgres` package.

## Errors

A server error throws the same exception as the Dart driver:
`ServerException`, or `UniqueViolationException` and
`ForeignKeyViolationException`, with the same `code`, `detail`,
`constraintName` and other fields. Other errors (eg. the server is down)
throw `PgException`.

## Not yet

- SSL. `useSSL: true` throws. Use the Dart driver for SSL for now.
- `maxConnectionAge`, `queryTimeout` and the other `extra` keys of the Dart
  driver are not read.
- A nested `transaction()` joins the outer one, like the Dart driver
  (no savepoints).
