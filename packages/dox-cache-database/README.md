# dox_cache_database

A database cache store for [dox_cache](https://pub.dev/packages/dox_cache).
It keeps cache items, locks and sessions in a table of your database. All
servers that use the same database share them, with no Redis.

It works on SQLite, Postgres, MySQL and MariaDB, through the dox_orm
connection of your app.

## Install

```bash
dart pub add dox_cache_database
```

## Make the table

```bash
dox cache:table
dox migrate
```

`dox cache:table` writes a `create_cache_table` migration that calls
`CacheTables.up(schema)`. Give `--table=<name>` for another table name, and
set the same name in the store options (see below).

The table has three columns:

- `key`: string(255), the primary key. On MySQL and MariaDB it uses the
  `utf8mb4_bin` collation, so `A` and `a` are two keys.
- `value`: long text. The value as JSON text. On MySQL and MariaDB it uses
  `utf8mb4_bin` too, so lock owners compare by case.
- `expires_at`: bigint, nullable. Unix time in milliseconds (UTC). Null
  means it never expires.

## Register the store

Register the driver when the app starts, before the first use of the store
(for example in a service provider):

```dart
import 'package:dox_cache_database/dox_cache_database.dart';

Dox().cache.extend(
  'database',
  DatabaseCacheDriverFactory(Dox().cache.config.encrypter),
);
```

Then add a store with `'driver': 'database'` to your cache config:

```dart
'database': <String, dynamic>{
  'driver': 'database',
  'table': 'cache', // optional, default `cache`
  'connection': 'main', // optional, default the default connection
  'prefix': 'app:', // optional
  'encrypt': true, // optional, needs the encrypter above
},
```

A full key (the prefix + the key, also for locks) may have at most 255
characters. A longer key throws an `ArgumentError`.

## Use its own connection

Cache calls inside an app transaction on the same connection join that
transaction:

- Their writes roll back with it.
- A lock is not seen by other servers until the commit.
- The row locks of `increment`, `pull` and `touch` stay until the end.
- On Postgres, a failed cache query also breaks the app transaction.

To keep the cache out of app transactions, add a second connection with
the same database settings, and give its name to the store:

```dart
// in DatabaseConfig.connections
'cache': ConnectionConfig(/* the same settings as your main connection */),

// in the cache store options
'connection': 'cache',
```

The second connection has its own pool, so it is outside the app
transaction. On SQLite a second connection waits until the write
transaction of the first one ends.

## Database sessions

Sessions can use this store too:

```dart
session: SessionConfig(driver: 'cache', store: 'database'),
```

## Delete expired rows

An expired row reads as a miss, but it stays in the table until the key is
written again. Run `prune()` from time to time, for example in a schedule:

```dart
DatabaseCacheDriver driver =
    Dox().cache.store('database').driver as DatabaseCacheDriver;
int deleted = await driver.prune();
```

On Postgres with a collation other than `C`, `flush()` and `prune()` can
not use the index of the `key` column, so they read the whole table. This
is slow only on very big tables.

`prune()` deletes only the rows of the store prefix. With an empty prefix
it deletes every expired row of the table, also the rows of other stores.

## How it stays safe across servers

- `add` and taking a lock run two statements. The first deletes the row
  of the key only when it is expired. The second inserts the row only when
  the key is missing. This insert is the atomic step, so only one server
  wins.
- `increment`, `pull` and `touch` lock the row in a transaction.
- A lock release deletes the row only when the owner matches.
- A write that fails with a deadlock runs again after a short random
  wait, up to 5 runs in all. A lock wait timeout is not retried. Inside an app
  transaction on the same connection there is no retry: the deadlock
  rolled back the app transaction, so the error goes to you.

## Server clocks

Expiry times come from the clock of each server, not from the database.
Keep the clocks of your servers in sync (for example with NTP). When two
clocks differ, a key or a lock can end early by that difference. So in the
worst case a lock ends early by the clock difference, and a second server
can take it while the first one still works.
