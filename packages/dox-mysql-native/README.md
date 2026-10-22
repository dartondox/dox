# dox_mysql_native

A fast MySQL and MariaDB driver for Dart and the [Dox](https://dartondox.dev)
ORM. Rust ([mysql_async](https://docs.rs/mysql_async)) owns the
connections. Your code stays in Dart.

Values come back with the same Dart types as with the Dox ORM on
`mysql_dart`, and errors are the same `MySQLServerException` class.

```dart
import 'package:dox_mysql_native/dox_mysql_native.dart';

void main() async {
  MysqlNativePool pool = MysqlNativePool.open(
    host: 'localhost',
    user: 'root',
    password: 'password',
    database: 'app',
  );
  MysqlNativeResult result = await pool.query(
    'SELECT id, name FROM users WHERE id = ?',
    parameters: <Object?>[1],
  );
  print(result.rows);
}
```

With the Dox ORM:

```dart
SqlQueryBuilder.initializeWithDatabaseConfig(databaseConfig);
SqlQueryBuilder().dbDriver = MysqlNativeDriver.fromConfig(
  databaseConfig.getConnectionConfig(),
);
```

- Works with MySQL 8.4 (`caching_sha2_password`) and MariaDB 11.
- The build hook downloads a ready-built library when one exists for your
  system. Else it builds it with `cargo` (install Rust with rustup).
- Use `dart run`, `dart test` or `dart build cli`. `dart compile exe` does
  not run build hooks.

More: [Native MySQL driver](https://dartondox.dev/database/mysql-native/).
