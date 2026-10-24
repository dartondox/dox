## Unreleased

- Breaking: isolates that open the same settings (and the same `maxConnections`) now share one pool in Rust, like `dox_mysql_native`. So `maxConnections` is for the whole process, not per isolate. Before, 8 isolates with the default of 10 could open 80 connections. Each `open` counts, and only the last `close()` closes the pool. The native ABI version is now 2.
- The prepared statement cache of a connection drops the statement used longest ago when it is full (LRU, 512 statements). Before, it dropped all statements at once.
- Fewer copies of the result bytes. Rust writes each result straight into the buffer of the next post. A batch of 64 KiB or more goes to Dart without a copy (external typed data).
- Faster decode of `uuid`, `numeric`, `date`, `json` and `jsonb`, without the type registry of the `postgres` package. A negative `numeric` below 1 now has its leading zero: `-0.5`, not `-.5` like the `postgres` package.
- An `int` parameter is written as text straight into the request buffer, without a `String`. It still goes without a type, so the server picks it.
- The column names are kept per SQL text, not only for the last result. Queries that take turns no longer decode their column names again.

## 3.0.0-alpha.6

- Version bump only, to match the other packages.

## 3.0.0-alpha.5

- The hook comment says how to fill the sha256 list from a release: `dart run bin/native_hashes.dart <tag>`. The list stays empty until the first release.
- A `host` that starts with `/` is a Unix socket folder (eg. Cloud SQL `/cloudsql/project:region:instance`). A test checks it.

## 3.0.0-alpha.4

- Less work per request. Rust copies a batch of requests once and keeps slices of it, instead of one copy of the SQL and of each parameter. A batch of plain queries uses one timeout timer, not one per query. Dart keeps waiting requests in a list, not a map.

## 3.0.0-alpha.3

- Column names and types are decoded once per result shape. The next result with the same columns reuses them.
- Breaking: this package no longer depends on `dox_orm`. `PostgresNativeDriver` moved into `dox_orm`, which now uses it as its default Postgres driver. This package keeps `PgNativePool`.
- Fix: a request never got an answer in two cases. A value that Dart can
  not decode (eg. a timestamp out of the `DateTime` range) lost every other
  result of the same batch. A request sent to a transaction after its end
  (eg. a second rollback) was dropped. Both now fail with a clear error.
- A request that gets no answer in 5 minutes fails with a timeout error
  (like `queryTimeout` of the `postgres` package). Connect timeout is 15 s.
  A transaction that Dart does not end in 5 minutes is rolled back, so its
  connection goes back to the pool.
- `tool/stress.dart`: a stress test that finds requests that never finish.
- Faster queries. Plain queries now share connections: tokio-postgres
  sends the queries of one connection together (pipelining). One tokio task
  runs each batch from Dart, not one task per query. The SQL bytes are
  cached, and binding named parameters builds no extra `Set`.

## 3.0.0-alpha.2

- First release.
- Native Postgres driver: Rust (tokio-postgres, deadpool-postgres) owns the
  connections. Your code stays in Dart.
- `PostgresNativeDriver` for the Dox ORM. Same types and exceptions as the
  `postgres` package.
- `PgNativePool`: queries, transactions, one pool for many isolates.
