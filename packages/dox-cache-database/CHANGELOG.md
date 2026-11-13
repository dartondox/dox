## Unreleased

- First version. `DatabaseCacheDriver` is a dox_cache store that keeps cache items, locks and sessions in a database table, on SQLite, Postgres, MySQL and MariaDB. Register it with `Dox().cache.extend('database', DatabaseCacheDriverFactory(encrypter))`. Store options: `table`, `connection`, `prefix`, `encrypt`. `prune()` deletes expired rows.
- A write that fails with a deadlock runs again after a short random wait, up to `DatabaseCacheDriver.deadlockTries` (5) runs in all. A lock wait timeout is not retried, and inside an app transaction on the same connection there is no retry. `DatabaseCacheDriver.isDeadlock(error)` tells if an error is a deadlock.
- The `database:` constructor parameter takes a `DBDriver` to use instead of the one of `connection`.
- `CacheTables.up(schema)` and `CacheTables.down(schema)` make and drop the table. `dox cache:table` writes a migration that uses them.
