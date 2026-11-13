---
icon: lucide/zap
---

# Cache

This page shows the full API of `dox_cache`, the cache behind `Cache()` in Dox.

It has `remember`, tags, atomic locks and four drivers.

## In a Dox app

`dox_core` uses `dox_cache` and exports it. There is nothing to install.
To set up the cache config in an app, run `dox add cache`. A new app already has it. See [Cache](../digging-deeper/cache.md#install).
With no config, Dox has a `file` store (the default) and a `memory` store. Use it with `Cache()`:

```dart
await Cache().put('foo', 'bar', duration: Duration(minutes: 10));
String? foo = await Cache().get('foo');

// store JSON values, so a model becomes a map with toJson()
List<dynamic> posts = await Cache().remember(
  'posts',
  Duration(minutes: 5),
  () async => (await Post().all()).map((Post p) => p.toJson()).toList(),
);
```

The app template has the stores in `lib/config/cache.dart`.
`lib/config/app.dart` passes them to `AppConfig(cache: cache)`.
Change this file to add a store, like Redis:

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

Then set `CACHE_STORE=redis` in `.env`.

- `Cache().store('memory')` uses another store.
- `Dox().cache` is the `CacheManager` of this page. `Cache().repository` is the `CacheStore`.
- The full guide is at [Cache](../digging-deeper/cache.md).

## Drivers

| Driver | What it is | Shared between isolates |
| --- | --- | --- |
| `memory` | a map in this isolate. Fast. Optional LRU size limit | No |
| `file` | one JSON file per key in a folder | Yes (same machine) |
| `redis` | Redis, with the [ioredis](https://pub.dev/packages/ioredis) package | Yes |
| `null` | stores nothing. Use it to turn caching off | - |
| `database` | a table in your database, from the `dox_cache_database` package. See [Database store](#database-store) | Yes |

!!! warning
    Dox runs many isolates. Each isolate has its own `memory` cache.
    Use `redis` when isolates or servers must see the same data.

## Without Dox

```bash
dart pub add dox_cache
```

```dart
import 'package:dox_cache/dox_cache.dart';
```

!!! note
    `dox_core` exports `CacheConfig`, `CacheManager`, `CacheStore` and `CacheLock` from this package.
    They are the same classes, so importing both packages is fine.

Make a `CacheManager` with your stores:

```dart
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

| Driver | Options |
| --- | --- |
| every driver | `driver`, `prefix` (default `dox_cache:`) |
| `memory` | `max_size`: the most items. When full, the least recently used item is removed. No limit when not set |
| `file` | `path` (default `storage/cache`). Each prefix gets its own sub folder |
| `redis` | `host` (default `127.0.0.1`), `port` (default `6379`), `username`, `password`, `db`, `tls`, `pool_size`, `max_value_bytes` (values bigger than this throw. No limit by default) |

`pool_size` is the most Redis connections one store opens in one isolate (default 10). A store uses about one, so you rarely change it.

## Basic use

```dart
await store.put('a', 1, Duration(minutes: 5));
await store.get('a');               // 1
await store.get('missing', 'none'); // 'none'
await store.has('a');               // true
await store.forget('a');
```

!!! info "No ttl means forever"
    `put` without a ttl keeps the value forever.
    A zero or negative ttl removes the key.
    `Cache()` in `dox_core` takes the ttl as a named argument: `Cache().put('a', 1, duration: Duration(minutes: 5))`.

## Remember

Get the cached value, or run the function and cache the result.

```dart
List<dynamic> posts = await store.remember('posts', Duration(minutes: 10), () async {
  return await loadPostsAsJson();
});
```

A cached value comes back as JSON. A `List` is `List<dynamic>` and a `Map` is `Map<String, dynamic>`.
So without `decode`, the type must be a raw JSON type.
For other types, pass `decode`. It turns the cached JSON into your type:

```dart
List<String> names = await store.remember<List<String>>(
  'names',
  Duration(minutes: 10),
  loadNames,
  decode: (Object? json) => List<String>.from(json as List<dynamic>),
);
```

- Many calls for the same key at the same time run the function once in one isolate. The others wait for the first.
- With `lock: true`, callers in other isolates and servers wait too. It uses a cache lock, so the driver must support locks.

## Flexible

Stale while revalidate. The value is fresh for the first time. After that it is stale for the second time.
A stale value is still returned right away, and one caller refreshes it in the background.
After both times, the value is gone and the next call waits for the function.

```dart
int count = await store.flexible<int>(
  'users',
  Duration(minutes: 5),  // fresh
  Duration(minutes: 10), // stale
  countUsers,
);
```

It takes `decode` like `remember`. The driver must support locks.

## All methods

| Method | What it does |
| --- | --- |
| `get(key, [default])` | the value, or the default when missing or expired. The default can be a function. It runs only on a miss |
| `getRaw(key)` | the stored JSON text, with no decode. Null when missing |
| `put(key, value, [ttl])` | store it |
| `add(key, value, [ttl])` | store only when missing. Returns true when stored |
| `has(key)` | true when the value is not null |
| `forget(key)` | remove it. Returns true when it was there |
| `flush()` | remove all items of this store |
| `many(keys)` / `putMany(map, [ttl])` | many keys at once |
| `increment(key, [by])` / `decrement(key, [by])` | change a number. A missing key starts at 0. The ttl stays |
| `forever(key, value)` | store without expiry |
| `remember(key, ttl, compute, {decode, lock})` | see above |
| `flexible(key, fresh, stale, compute, {decode})` | see above |
| `touch(key, ttl)` | set a new ttl and keep the value. Returns true when the key was there |
| `rememberForever(key, compute, {decode, lock})` | the same, without expiry |
| `pull(key, [default])` | get it and remove it, in one atomic step |
| `tags([...])` | a tagged view |
| `lock(name, [ttl, owner])` | an atomic lock |

## Values are JSON

Values must be JSON types: `Map`, `List`, `String`, `num`, `bool`, `null`. Other types throw.

- A `Map` comes back as `Map<String, dynamic>`. A `List` comes back as `List<dynamic>`.
- A stored `null` reads as a miss. `has` returns false for it.
- For a model, store `model.toJson()`, not the model.

## Tags

```dart
await store.tags(<String>['users']).put('u1', 'Ann');
await store.tags(<String>['users']).flush(); // removes only the 'users' items
```

Tags work with every driver. Old items are not deleted right away. They are just not found any more, and they go away when their ttl ends.

## Locks

Only one worker runs the code at a time.

```dart
CacheLock lock = store.lock('report', Duration(seconds: 10));
if (await lock.get()) {
  try {
    // only one worker runs this
  } finally {
    await lock.release();
  }
}

bool got = await lock.block(Duration(seconds: 5)); // wait up to 5 seconds
```

- `get()` takes the lock and returns `true`, or returns `false` when someone else has it.
- `block(timeout)` tries again every 50 ms until it gets the lock or the time is over.
- The `ttl` frees the lock by itself if the worker crashes. Without a ttl, the lock stays until `release()`.
- `release()` frees the lock only for the owner that took it.
- `block(timeout, callback)` runs the callback while it holds the lock, frees the lock and returns the result. It throws `LockTimeoutException` when the time is over.
- `block(timeout)` with no callback gives `false` when the time is over. With `lock.throwOnTimeout = true` or the flag `CacheFlags(lockThrows: true)` it throws `LockTimeoutException`. See [CacheConfig](../reference/app-config.md#cacheconfig).
- `forceRelease()` frees the lock, whoever holds it.
- `memory`, `file` and `redis` support locks. The `memory` lock works inside one isolate only. The `file` lock is a file made with `create(exclusive: true)`. It works for all isolates on one machine. `null` throws `UnsupportedError`.

## Prefix

Every store has a `prefix` (default `dox_cache:`). It is added to every key.
Use different prefixes when two apps share one Redis database.
On Redis, a prefix with no `:` at the end gets one, so `app` does not match the keys of `app2`.

!!! info "Redis `flush`"
    `flush` deletes only the keys with the prefix. It never runs `FLUSHDB`.
    An empty prefix makes `flush` throw.

## Encrypt the cache

By default the cache keeps plain JSON. Anyone who can read the cache file or the Redis database can read the values.
To hide them, add `'encrypt': true` to a `file` or `redis` store, and give the config an encrypter. In a Dox app, the normal `Dox().cache` has the encrypter set for you. A `CacheManager` you build yourself needs `encrypter:` (for example `const CryptCacheEncrypter()`). Without Dox, write your own class:

```dart
class MyEncrypter implements CacheEncrypter {
  @override
  String encrypt(String text) => myEncrypt(text);

  @override
  String decrypt(String text) => myDecrypt(text); // throw on bad input
}

CacheConfig(defaultStore: 'file', stores: stores, encrypter: MyEncrypter());
```

Then turn it on per store:

```dart
'file': {'driver': 'file', 'path': 'storage/cache', 'encrypt': true},
```

- It is off by default. A store without the option is not changed.
- In a Dox app the values are encrypted with your `APP_KEY`. Old keys in `previousKeys` can still read old entries.
- When the key changes, the old entries cannot be read. They count as a miss. The cache then fills again.
- A store with `'encrypt': true` and no encrypter throws a `StateError` when it is built, for every store type.
- On a `file` store, the whole file is encrypted, also the expiry time. Lock files are not encrypted. They hold no values.
- On a `redis` store, a plain `int` stays plain text, so `increment` and `decrement` still work. Every other value is encrypted. Tag counters are `int` values, so they stay plain too. To keep a secret number encrypted, store it as a `String`.
- A `memory` or `null` store does not encrypt. Its values never leave the process. The option still needs an encrypter, or building the store throws.
- The option must be `true` or `false`. Any other type, like `'true'`, throws an `ArgumentError`.
- Old plain values read as a miss after you turn the option on. The one exception is an `int` on Redis, which is plain by design and still reads as a value.
- On a `file` store, `prune` deletes files that cannot be decrypted. After a key change with no previous keys, or in a folder that apps with different keys share, `prune` removes those files.
- Cache keys and tag names are not encrypted. A value is not tied to its key, so someone who can write to Redis or the cache folder can copy an encrypted value to another key. Encryption protects against reading only.
- `maxValueBytes` is checked on the plain JSON size. The stored encrypted text is about a third bigger.

## File driver

- Each prefix has its own sub folder inside `path`. `flush` deletes only the files of that prefix.
- `add`, `increment` and `touch` take a file lock on the key, so they are safe across isolates.
- A read never deletes a file. An expired file stays until it is written again.
- `prune()` deletes the expired files. Call it from time to time, eg. in a schedule:

```dart
int deleted = await (store.driver as FileDriver).prune();
```

- Or set `prune_every` on the store to run `prune()` in the background once every that many writes. It is off by default. Each run reads every file of the store, so pick a big number, eg. `1000`:

```dart
'file': {'driver': 'file', 'path': 'storage/cache', 'prune_every': 1000},
```

- `prune()` takes the key lock that `add`, `increment` and `touch` use, so it never deletes their new value. A plain `put` takes no lock. If a `put` writes a key at the same moment `prune()` deletes it, the new value is lost. It is only a cache miss.

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

- A full key (the prefix and the key) may have at most 255 characters. A longer key throws an `ArgumentError`.
- Cache calls inside an app transaction on the same connection join that transaction. Their writes roll back with it, and other servers do not see a lock until the commit. Give the store its own `connection` (a second connection with the same database settings) to keep the cache out of app transactions.
- An expired row reads as a miss, but it stays in the table. Call `prune()` from time to time, eg. in a schedule:

```dart
int deleted = await (store.driver as DatabaseCacheDriver).prune();
```

- Expiry times come from the clock of each server. Keep the clocks of your servers in sync.

## Your own driver

```dart
class MyDriverFactory implements CacheDriverFactory {
  @override
  CacheDriver create(Map<String, dynamic> options) {
    return MyDriver(options);
  }
}

cache.extend('mine', MyDriverFactory()); // config: {'driver': 'mine'}
cache.addStore('ready', MemoryDriver()); // or add a ready driver
```

`MyDriver extends CacheDriver`. It must implement `prefix`, `get`, `put`, `add`, `increment`, `forget` and `flush`.
Override `lock` to support locks, and `close` to close its connections.
Override `pull` to make it atomic, and `has` and `touch` to make them faster. The defaults work, but `pull` is a get and then a forget.

## Close

`cache.close()` closes the connections of every store that was built, eg. the Redis connections.
Memory, file and null stores have nothing to close. It is safe to call twice.
A store used after it is built again.

In a Dox app you do not call it. Dox closes `Cache()` stores on shutdown, in every isolate, after the open requests are done.
