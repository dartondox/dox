# dox_postgres_native

A fast Postgres driver for Dart and the [Dox](https://dartondox.dev) ORM.
Rust ([tokio-postgres](https://docs.rs/tokio-postgres)) owns the
connections. Your code stays in Dart.

Values come back with the same Dart types as with the `postgres` package,
and errors are the same `ServerException` classes.

```dart
import 'package:dox_postgres_native/dox_postgres_native.dart';

void main() async {
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
  print(result.rows);
}
```

With the Dox ORM:

```dart
SqlQueryBuilder.initializeWithDatabaseConfig(databaseConfig);
SqlQueryBuilder().dbDriver = PostgresNativeDriver.fromConfig(
  databaseConfig.getConnectionConfig(),
);
```

- The build hook downloads a ready-built library when one exists for your
  system. Else it builds it with `cargo` (install Rust with rustup).
- Use `dart run`, `dart test` or `dart build cli`. `dart compile exe` does
  not run build hooks.
- Not yet: SSL.

More: [Native Postgres driver](https://dartondox.dev/database/postgres-native/).
