# Native Postgres driver

`dox_postgres_native` is the default Postgres driver of the Dox ORM.
Rust talks to the database. Your models, queries and transactions stay the
same. You do not change any config.

- Rust ([tokio-postgres](https://docs.rs/tokio-postgres)) owns the
  connections and the pool.
- Dart sends many queries to Rust in one call. Rust sends many results back
  in one message.
- Each connection keeps its prepared statements. The same SQL is not parsed
  again.
- Values have the same Dart types as with the `postgres` package. Errors
  are the same `ServerException` classes.

!!! warning "Alpha"
    This driver is new. If you see a problem, [use the Dart driver](#use-the-dart-driver)
    and tell us.

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

`dox_orm` depends on `dox_postgres_native`. You do not add it yourself.
Add it only to use `PgNativePool` without the ORM:

```bash
dart pub add dox_postgres_native
```

You do not need Rust. The build hook downloads a ready-built library for
your system. When there is no library for your system and no Rust to build
one, the ORM still works: it uses the Dart driver and prints one warning
line (see below).

The package lives in its own repo:
[dartondox/dox-postgres-native](https://github.com/dartondox/dox-postgres-native).

Use `dart run`, `dart test` or `dart build cli`. `dart compile exe` does not
run build hooks.

## Native is the default

You do not change any config. The ORM picks the driver like this:

1. `driverFactory` is set: the ORM uses your driver. It wins over
   everything below.
2. You ask for the Dart driver (see below), or the connection uses TLS:
   the ORM uses the Dart driver.
3. The native library loads: the ORM uses the native driver.
4. The native library does not load (no library for your system, no
   Rust to build it, or a load error): the ORM uses the Dart driver. It
   prints one warning line to stderr, like this:

```text
[dox] warning: dox_postgres_native did not load, using the Dart postgres driver (...)
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
  driver: Driver.postgres,
  // ... host, user, password, database as before
  extra: <String, dynamic>{'native': false},
  debug: false,
),
```

Postgres with TLS (`useSSL: true` or `extra['sslMode']`) always uses the
Dart driver, because the native driver has no TLS yet.

## Options

The driver reads these keys from `extra` of the `ConnectionConfig`:

| Key | Default | What it does |
|---|---|---|
| `maxConnectionCount` | `10` | Most connections in the pool, for the whole process. |
| `timeZone` | `UTC` | Time zone of the session, like the Dart driver. |
| `applicationName` | none | Name of the app in `pg_stat_activity`. |
| `threads` | `1` | Rust threads for all pools of the process. `0` is one thread with a single-thread runtime. Only the first pool sets it. |

Isolates that open a pool with the same settings share one pool in Rust.
So `maxConnectionCount` is for the whole process, not per isolate. The
pool closes when the last isolate closes it. You can also give
`driver.pool.handle` (an `int`) to another isolate and use
`PostgresNativeDriver(PgNativePool.fromHandle(handle))` there.
`PostgresNativeDriver` comes from `package:dox_orm/dox_orm.dart`.

Each connection keeps up to 512 prepared statements. When it is full, it
drops the one used longest ago. A request (pool slot, connect and query)
fails after 300 s with no answer. A transaction that gets no request for
300 s is rolled back.

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

- SSL. A connection with `useSSL: true` uses the Dart driver.
- `maxConnectionAge`, `queryTimeout` and the other `extra` keys of the Dart
  driver are not read.
- A nested `transaction()` joins the outer one, like the Dart driver
  (no savepoints).
