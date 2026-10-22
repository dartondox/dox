## 3.0.0-alpha.2

- First release.
- Native Postgres driver: Rust (tokio-postgres, deadpool-postgres) owns the
  connections. Your code stays in Dart.
- `PostgresNativeDriver` for the Dox ORM. Same types and exceptions as the
  `postgres` package.
- `PgNativePool`: queries, transactions, one pool for many isolates.
