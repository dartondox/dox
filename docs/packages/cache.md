---
icon: lucide/zap
---

# Cache

`dox_cache` keeps data that is slow to make, so the next request can read it fast.

It is the cache behind `Cache()` in Dox. It has `remember`, tags, atomic locks and many drivers. This page shows the full API. For a shorter guide, see [Cache](../digging-deeper/cache.md).

## Setup

`dox_core` uses `dox_cache` and exports it, so there is nothing to install. A new app already has the cache config. If your app does not have it, run `dox add cache`. See [Cache](../digging-deeper/cache.md#install).

The stores are in `lib/config/cache.dart`, and `lib/config/app.dart` passes them to `AppConfig(cache: cache)`. To add a store, like Redis, edit this file:

```dart title="lib/config/cache.dart"
import 'package:dox_core/dox_core.dart';
import 'package:my_app/config/env.dart';

CacheConfig cache = CacheConfig(
  defaultStore: env.cacheStore, // CACHE_STORE in .env, default 'file'
  stores: <String, Map<String, dynamic>>{
    'file': <String, dynamic>{'driver': 'file', 'path': 'storage/cache'},
    'memory': <String, dynamic>{'driver': 'memory', 'max_size': 10000},
    'redis': <String, dynamic>{'driver': 'redis', 'host': '127.0.0.1', 'prefix': 'app_cache:'},
  },
);
```

Then set `CACHE_STORE=redis` in `.env`. With no config at all, Dox has a `file` store (the default) and a `memory` store.

### Drivers

| Driver | What it is | Shared between isolates |
| --- | --- | --- |
| `memory` | a map in this isolate. Fast. Optional LRU size limit | No |
| `file` | one JSON file per key in a folder | Yes (same machine) |
| `redis` | Redis, with the [ioredis](https://pub.dev/packages/ioredis) package | Yes |
| `null` | stores nothing. Use it to turn caching off | - |
| `database` | a table in your database, from the `dox_cache_database` package. See [Database store](#database-store) | Yes |

Dox runs many isolates, and each isolate has its own `memory` cache. So use `redis` or `database` when all isolates and servers must see the same data.

### Store options

| Driver | Options |
| --- | --- |
| every driver | `driver`, `prefix` (default `dox_cache:`) |
| `memory` | `max_size`: the most items. When full, the least recently used item is removed. No limit when not set |
| `file` | `path` (default `storage/cache`). Each prefix gets its own sub folder |
| `redis` | `host` (default `127.0.0.1`), `port` (default `6379`), `username`, `password`, `db`, `tls`, `pool_size` (default 10), `max_value_bytes` (values bigger than this throw. No limit by default) |

The `prefix` is added to every key. Use different prefixes when two apps share one Redis database.

## Using another store

`Cache()` uses the default store. Use `store` to pick another one by name:

```dart
await Cache().store('memory').get('foo');
```

## Retrieving items

Use `get` to read a value. The second argument is the default, which you get when the key is missing or expired. The default can also be a function, which runs only on a miss:

```dart
String? foo = await Cache().get('foo');

String name = await Cache().get('name', 'none');
```

### Checking if an item exists

The `has` method returns `true` when the value is there and is not `null`:

```dart
if (await Cache().has('foo')) {
  // ...
}
```

### Retrieving many items

The `many` method reads many keys at once. A missing key gives `null`:

```dart
Map<String, dynamic> values = await Cache().many(<String>['a', 'b']);
```

### Retrieve or store

Often you want to read a value, or make it and cache it when it is missing. Use `remember` for this:

```dart
List<dynamic> posts = await Cache().remember(
  'posts',
  Duration(minutes: 5),
  () async => (await Post().all()).map((Post p) => p.toJson()).toList(),
);
```

If many calls ask for the same key at the same time, the function runs only once in one isolate. The others wait for it. Pass `lock: true` if callers in other isolates and servers should wait too. This needs a driver with locks.

`rememberForever` does the same, but the value never expires.

A cached value comes back as JSON, so a `List` is `List<dynamic>` and a `Map` is `Map<String, dynamic>`. If you want another type, pass `decode`. It turns the cached JSON into your type:

```dart
List<String> names = await Cache().remember<List<String>>(
  'names',
  Duration(minutes: 10),
  loadNames,
  decode: (Object? json) => List<String>.from(json as List<dynamic>),
);
```

### Stale while revalidate

Sometimes an old value is fine for a while, but you do not want callers to wait for a refresh. Use `flexible`. The value is fresh for the first time. After that it is stale for the second time: callers still get it right away, and one caller refreshes it in the background. After both times, the next call waits for the function:

```dart
int count = await Cache().flexible<int>(
  'users',
  Duration(minutes: 5),  // fresh
  Duration(minutes: 10), // stale
  countUsers,
);
```

It takes `decode` like `remember`. The driver must support locks.

### Retrieve and delete

The `pull` method reads a value and removes it, in one atomic step:

```dart
dynamic value = await Cache().pull('foo');
```

## Storing items

Use `put` to store a value. Without a `duration`, the value is kept forever. A zero or negative duration removes the key:

```dart
await Cache().put('foo', 'bar', duration: Duration(minutes: 10));
```

Values must be JSON types: `Map`, `List`, `String`, `num`, `bool` or `null`. Other types throw. So for a model, store `model.toJson()`, not the model. A stored `null` reads as a miss.

### Storing if not present

The `add` method stores the value only when the key is missing. It returns `true` when it stored it:

```dart
bool added = await Cache().add('foo', 'bar', duration: Duration(minutes: 10));
```

### Storing many items

```dart
await Cache().putMany(<String, Object?>{'a': 1, 'b': 2});
```

### Storing items forever

```dart
await Cache().forever('foo', 'bar');
```

### Incrementing and decrementing

Use `increment` and `decrement` for counters. A missing key starts at 0, and the ttl stays the same:

```dart
await Cache().increment('visits');
await Cache().decrement('stock', 5);
```

### Changing the expiry time

The `touch` method gives a key a new ttl and keeps the value. It returns `true` when the key was there:

```dart
await Cache().touch('foo', duration: Duration(hours: 1));
```

## Deleting items

The `forget` method removes one item. The `flush` method removes all items of the store:

```dart
await Cache().forget('foo');

await Cache().flush();
```

On Redis, `flush` deletes only the keys with the store prefix. It never runs `FLUSHDB`. So an empty prefix makes `flush` throw.

## Cache tags

Tags let you group items, so you can flush the group without touching other items:

```dart
await Cache().tag('users').put('u1', 'Ann');

await Cache().tag('users').flush(); // removes only the 'users' items
```

Use `tags(<String>['users', 'admins'])` for many tags. Tags work with every driver. A flushed item is not deleted at once. It is just not found any more, and it goes away when its ttl ends.

## Atomic locks

Sometimes only one worker may run a piece of code at a time, for example a report job. Use a lock:

```dart
CacheLock lock = Cache().lock('report', Duration(seconds: 10));
if (await lock.get()) {
  try {
    // only one worker runs this
  } finally {
    await lock.release();
  }
}
```

`get()` takes the lock and returns `true`, or returns `false` when someone else has it. The ttl frees the lock by itself if the worker crashes. Without a ttl, the lock stays until `release()`.

### Waiting for a lock

`block` tries again every 50 ms until it gets the lock or the time is over. It returns `false` when the time is over:

```dart
bool got = await lock.block(Duration(seconds: 5));
```

If you give a callback, `block` runs it while it holds the lock, frees the lock and returns the result. It throws `LockTimeoutException` when the time is over:

```dart
String result = await lock.block(Duration(seconds: 5), () async => makeReport());
```

The `memory`, `file`, `redis` and `database` drivers support locks. A `memory` lock works inside one isolate only. A `file` lock works for all isolates on one machine.

## Encrypting the cache

By default the cache keeps plain JSON, so anyone who can read the cache files or the Redis database can read the values. To hide them, add `'encrypt': true` to the store:

```dart
'file': <String, dynamic>{'driver': 'file', 'path': 'storage/cache', 'encrypt': true},
```

The values are then encrypted with your `APP_KEY`. Old keys in `previousKeys` can still read old entries. When the key changes and the old key is gone, the old entries count as a miss, and the cache fills again.

Cache keys and tag names are not encrypted. Encryption protects against reading only: someone who can write to the store can still copy an encrypted value to another key.

## Database store

The `dox_cache_database` package keeps the cache in a table of your database. All servers that use the same database share the cache, the locks and the sessions, with no Redis. It works on SQLite, Postgres, MySQL and MariaDB.

Install it and make the table:

```bash
dart pub add dox_cache_database
dox cache:table
dox migrate
```

`dox cache:table` writes a migration that calls `CacheTables.up(schema)`. Give `--table=<name>` for another table name.

Register the driver when the app starts, before the first use of the store:

```dart
import 'package:dox_cache_database/dox_cache_database.dart';

Dox().cache.extend(
  'database',
  DatabaseCacheDriverFactory(Dox().cache.config.encrypter),
);
```

Then add a store to `lib/config/cache.dart`:

```dart
'database': <String, dynamic>{
  'driver': 'database',
  'table': 'cache', // optional, default `cache`
  'connection': 'cache', // optional, default the default connection
  'prefix': 'app:', // optional
  'encrypt': true, // optional
},
```

Cache calls inside an app transaction on the same connection join that transaction, so their writes roll back with it. If you do not want this, give the store its own `connection`: a second connection with the same database settings.

An expired row reads as a miss, but it stays in the table. So call `prune()` from time to time, for example in a schedule:

```dart
int deleted = await (store.driver as DatabaseCacheDriver).prune();
```

## Pruning the file store

A read never deletes a file, so an expired file stays until it is written again. Call `prune()` from time to time to delete expired files, for example in a schedule:

```dart
int deleted = await (store.driver as FileDriver).prune();
```

You can also set `prune_every` on the store. It runs `prune()` in the background once every that many writes. Each run reads every file of the store, so pick a big number:

```dart
'file': <String, dynamic>{'driver': 'file', 'path': 'storage/cache', 'prune_every': 1000},
```

## Without Dox

`dox_cache` also works on its own:

```bash
dart pub add dox_cache
```

Make a `CacheManager` with your stores:

```dart
import 'package:dox_cache/dox_cache.dart';

CacheManager cache = CacheManager(CacheConfig(
  defaultStore: 'redis',
  stores: <String, Map<String, dynamic>>{
    'memory': <String, dynamic>{'driver': 'memory', 'max_size': 1000},
    'file': <String, dynamic>{'driver': 'file', 'path': 'storage/cache'},
    'redis': <String, dynamic>{'driver': 'redis', 'host': '127.0.0.1', 'prefix': 'app:'},
  },
));

CacheStore store = cache.store();     // the default store
await cache.store('file').get('a');   // a named store
```

A `CacheStore` has the same methods as `Cache()`. The only difference is that the ttl is a normal argument, not a named one:

```dart
await store.put('a', 1, Duration(minutes: 5));
```

In a Dox app, `Dox().cache` is this `CacheManager`, and `Cache().repository` is the `CacheStore`. `dox_core` exports the same classes, so importing both packages is fine.

### Encryption without Dox

A `CacheManager` you build yourself needs an `encrypter` for stores with `'encrypt': true`. Use `const CryptCacheEncrypter()` with Dox, or write your own class:

```dart
class MyEncrypter implements CacheEncrypter {
  @override
  String encrypt(String text) => myEncrypt(text);

  @override
  String decrypt(String text) => myDecrypt(text); // throw on bad input
}

CacheConfig(defaultStore: 'file', stores: stores, encrypter: MyEncrypter());
```

### Your own driver

Write a factory and register it with `extend`. Or add a ready driver with `addStore`:

```dart
class MyDriverFactory implements CacheDriverFactory {
  @override
  CacheDriver create(Map<String, dynamic> options) {
    return MyDriver(options);
  }
}

cache.extend('mine', MyDriverFactory()); // config: {'driver': 'mine'}
cache.addStore('ready', MemoryDriver());
```

`MyDriver extends CacheDriver`. It must implement `prefix`, `get`, `put`, `add`, `increment`, `forget` and `flush`. Override `lock` to support locks and `close` to close its connections. You can also override `pull` to make it atomic, and `has` and `touch` to make them faster.

### Closing the cache

`cache.close()` closes the connections of every store that was built, like the Redis connections. It is safe to call twice. In a Dox app you do not call it, because Dox closes the stores on shutdown.

## Details

This section is for special cases. Most apps do not need it.

- `getRaw(key)` gives the stored JSON text with no decode, or `null` when it is missing.
- `pool_size` is the most Redis connections one store opens in one isolate. A store uses about one, so you rarely change it.
- On Redis, a prefix with no `:` at the end gets one, so `app` does not match the keys of `app2`.
- `release()` frees a lock only for the owner that took it. `forceRelease()` frees it, whoever holds it.
- `block(timeout)` with no callback throws `LockTimeoutException` instead of returning `false` when you set `lock.throwOnTimeout = true` or the flag `CacheFlags(lockThrows: true)`. See [CacheConfig](../reference/app-config.md#cacheconfig).
- The `null` driver throws `UnsupportedError` for locks.
- On the `file` driver, `add`, `increment`, `touch` and `prune()` take a file lock on the key, so they are safe across isolates. A plain `put` takes no lock, so a `put` at the same moment as `prune()` can be lost. It is only a cache miss.
- With `encrypt`, a whole cache file is encrypted, also the expiry time. Lock files hold no values and are not encrypted.
- With `encrypt` on Redis, a plain `int` stays plain text, so `increment` and `decrement` still work. Tag counters are `int` values too. To keep a secret number encrypted, store it as a `String`.
- `memory` and `null` stores do not encrypt, because the values never leave the process. The option still needs an encrypter.
- `'encrypt'` must be `true` or `false`. Another type, like `'true'`, throws an `ArgumentError`. A store with `'encrypt': true` and no encrypter throws a `StateError` when it is built.
- After you turn `encrypt` on, old plain values read as a miss (except an `int` on Redis).
- On an encrypted `file` store, `prune` also deletes files that it can not decrypt.
- `max_value_bytes` is checked on the plain JSON size. The encrypted text is about a third bigger.
- On the database store, a full key (the prefix and the key) may have at most 255 characters. A longer key throws an `ArgumentError`.
- The database store takes expiry times from the clock of each server, so keep the clocks in sync.
