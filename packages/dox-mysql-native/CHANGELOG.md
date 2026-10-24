## Unreleased

- Each request now has a timeout of 300 s (pool slot, connect and query), like `dox_postgres_native`. Before, a request could wait for a free connection forever.
- A transaction that gets no request for 300 s (eg. its isolate is gone) is rolled back, and its connection goes back to the pool. Before, it held the connection forever.
- Fewer copies of the result bytes. The record head is written in front of the rows, so the record is not copied again. The first result of a batch is moved into the post buffer, not copied. A batch of 64 KiB or more goes to Dart without a copy (external typed data).
- The column names are kept per SQL text. The next result of the same query does not decode them again.
- New `verifyCertificate` on `MysqlNativePool.open()`. It is true by default, so TLS checks the server certificate. Set it to false only for a self-signed certificate in development.

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
