## 3.0.0-alpha.3

- Breaking: this package no longer depends on `dox_orm`. `MysqlNativeDriver` moved into `dox_orm`, which now uses it as its default MySQL driver. This package keeps `MysqlNativePool`, with the same API.

## 3.0.0-alpha.2

- First release.
- Native MySQL and MariaDB driver: Rust (mysql_async, tokio) runs the pool
  and a prepared statement cache per connection. Dart gets typed rows.
- `MysqlNativeDriver` plugs into the Dox ORM. The ORM gets the same types
  as with the Dart driver (mysql_dart).
- Works with MySQL 8.4 (caching_sha2_password) and MariaDB 11.
- The build hook downloads a ready-built library. No Rust needed.
