# dox_postgres_native

Native Postgres client for Dart. It is the default Postgres driver of the Dox ORM.

[![pub package](https://img.shields.io/pub/v/dox_postgres_native.svg)](https://pub.dev/packages/dox_postgres_native)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/dartondox/dox/blob/develop/LICENSE)

Part of [Dox](https://dartondox.dev), a web backend framework for Dart, like Laravel.
Source code: [github.com/dartondox/dox](https://github.com/dartondox/dox).

## Install

You usually do not add this package. `dox_orm` depends on it and uses it by default.
Add it only to use the pool without the ORM:

```bash
dart pub add dox_postgres_native
```

Dox 3.x is in alpha (`3.0.0-alpha.4`). The API can still change before the stable release.

## How it works

- Rust ([tokio-postgres](https://docs.rs/tokio-postgres)) owns the connections and the pool.
- Your models and queries stay in Dart. You do not change any config.
- Values have the same Dart types as with the `postgres` package.
- Server errors are the same `ServerException` classes.

## The native library

A build hook (`hook/build.dart`) gets the Rust library. It tries these in order:

1. A path you set in your app `pubspec.yaml` (`hooks: user_defines: dox_postgres_native: lib_path: ...`).
2. A ready-built library from the GitHub release, checked with sha256.
3. A build from source with `cargo`. This needs [Rust](https://rustup.rs).

In `3.0.0-alpha.4` the hook has no sha256 list for ready-built libraries yet.
So step 2 is skipped, and you need Rust to get the native driver.
Without Rust, the ORM uses the Dart `postgres` driver and prints one warning line.

Use `dart run`, `dart test` or `dart build cli`. `dart compile exe` does not run build hooks.

## Use it

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
  print(result.rows); // [{id: 1, name: Ada}]
}
```

## Turn it off

- For all connections: set the env var `DOX_DB_DRIVER=dart`.
- For one connection: `extra: <String, dynamic>{'native': false}` in its `ConnectionConfig`.

## Features

- Many queries go to Rust in one call. Many results come back in one message.
- Each connection keeps its prepared statements.
- Transactions: `pool.begin()`, `pool.commit(tx)`, `pool.rollback(tx)`.
- Parameters as a map for `@name`, or a list for `$1, $2`.
- Not yet: TLS. A connection with `useSSL: true` uses the Dart driver.

## Documentation

- [Native Postgres driver](https://dartondox.dev/latest/database/postgres-native/)
- [API reference](https://pub.dev/documentation/dox_postgres_native/latest/)

## License

MIT. See [LICENSE](https://github.com/dartondox/dox/blob/develop/LICENSE).
