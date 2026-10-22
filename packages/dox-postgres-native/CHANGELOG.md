## Unreleased

- Fix: a request never got an answer in two cases. A value that Dart can
  not decode (eg. a timestamp out of the `DateTime` range) lost every other
  result of the same batch. A request sent to a transaction after its end
  (eg. a second rollback) was dropped. Both now fail with a clear error.
- A request that gets no answer in 5 minutes fails with a timeout error
  (like `queryTimeout` of the `postgres` package). Connect timeout is 15 s.
  A transaction that Dart does not end in 5 minutes is rolled back, so its
  connection goes back to the pool.
- `tool/stress.dart`: a stress test that finds requests that never finish.

## 3.0.0-alpha.2

- First release.
- Native Postgres driver: Rust (tokio-postgres, deadpool-postgres) owns the
  connections. Your code stays in Dart.
- `PostgresNativeDriver` for the Dox ORM. Same types and exceptions as the
  `postgres` package.
- `PgNativePool`: queries, transactions, one pool for many isolates.
