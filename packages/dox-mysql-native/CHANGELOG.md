## 3.0.0-alpha.6

- Unix sockets. In `MysqlNativePool.open()`, a `host` that starts with `/` is the socket file. `fromUrl()` takes `?socket=/path`.
- `close()` is safe with many isolates. Isolates that open the same settings share one pool. Each `open` now counts, and only the last `close()` disconnects the pool. Before, the first `close()` closed it for every isolate.

## 3.0.0-alpha.5

- The hook comment says how to fill the sha256 list from a release: `dart run bin/native_hashes.dart <tag>`. The list stays empty until the first release.

## 3.0.0-alpha.4

- Version bump only, to match the other packages.

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
