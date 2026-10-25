# Native Postgres driver

`dox_postgres_native` is the Postgres driver of the Dox ORM.
Rust talks to the database. Your models, queries and transactions stay the
same. You do not change any config.

- Rust ([tokio-postgres](https://docs.rs/tokio-postgres)) owns the
  connections and the pool.
- Dart sends many queries to Rust in one call. Rust sends many results back
  in one message.
- Each connection keeps its prepared statements. The same SQL is not parsed
  again.
- Server errors are `PgServerException`. Other errors are `PgException`.

!!! warning "Alpha"
    This driver is new. If you see a problem, please
    [open an issue](https://github.com/dartondox/dox-postgres-native/issues).

## Speed

One find-by-id query (`SELECT ... WHERE id = @id`), AOT build
(`dart build cli`), Postgres 14 on the same machine (Apple M-series),
4 connections:

| | Time |
|---|---|
| One query at a time | 60 µs |
| 64 queries in flight, one isolate | 12.5 µs per query |
| 4 isolates, 64 in flight each, 16 connections per pool | 64,000 queries/s |

Many requests at the same time, like in a web server, get the most out of it.

## Install

`dox_orm` depends on `dox_postgres_native`. You do not add it yourself.
Add it only to use `PgNativePool` without the ORM:

```bash
dart pub add dox_postgres_native
```

You do not need Rust. The build hook downloads a ready-built library for
your system. When there is no library for your system and no Rust to build
one, the app stops with a clear error (see below).

The package lives in its own repo:
[dartondox/dox-postgres-native](https://github.com/dartondox/dox-postgres-native).

Use `dart run`, `dart test` or `dart build cli`. `dart compile exe` does not
run build hooks.

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
| `verify-full` | TLS. The certificate and the host name are checked. It uses the Mozilla roots and the roots of the system. |

```dart
ConnectionConfig(
  driver: Driver.postgres,
  // ... host, user, password, database as before
  extra: <String, dynamic>{'sslMode': 'verify-full'},
  debug: false,
),
```

In a url, `sslmode=verify-ca` is read as `verify-full`.

## Options

The driver reads these keys from `extra` of the `ConnectionConfig`:

| Key | Default | What it does |
|---|---|---|
| `maxConnectionCount` | `10` | Most connections in the pool, for the whole process. |
| `sslMode` | `disable` | TLS mode, see [TLS](#tls). |
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
- `PgNativePool.fromUrl('postgres://user:pass@host:5432/db?sslmode=require')`
  makes a pool from a url.

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
`PgException`. Both come from `package:dox_orm/dox_orm.dart`.

```dart
try {
  await QueryBuilder.table('users').insert(<String, dynamic>{'email': email});
} on PgServerException catch (error) {
  if (error.code == '23505') print('taken: ${error.constraint}');
}
```

## Not yet

- `maxConnectionAge` and `queryTimeout` are not read.
- A nested `transaction()` joins the outer one (no savepoints).
