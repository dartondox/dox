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
