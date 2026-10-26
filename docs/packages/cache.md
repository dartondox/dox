---
icon: lucide/zap
---

# Cache

This page shows the full API of `dox_cache`, the cache behind `Cache()` in Dox.

It has `remember`, tags, atomic locks and four drivers.

## In a Dox app

`dox_core` uses `dox_cache` and exports it. There is nothing to install.
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
| `file` | `path` (default `storage/cache`) |
| `redis` | `host` (default `127.0.0.1`), `port` (default `6379`), `username`, `password`, `db`, `tls`, `pool_size` |

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

## All methods

| Method | What it does |
| --- | --- |
| `get(key, [default])` | the value, or the default when missing or expired |
| `getRaw(key)` | the stored JSON text, with no decode. Null when missing |
| `put(key, value, [ttl])` | store it |
| `add(key, value, [ttl])` | store only when missing. Returns true when stored |
| `has(key)` | true when the value is not null |
| `forget(key)` | remove it. Returns true when it was there |
| `flush()` | remove all items of this store |
| `many(keys)` / `putMany(map, [ttl])` | many keys at once |
| `increment(key, [by])` / `decrement(key, [by])` | change a number. A missing key starts at 0. The ttl stays |
| `forever(key, value)` | store without expiry |
| `remember(key, ttl, compute)` | see above |
| `rememberForever(key, compute)` | the same, without expiry |
| `pull(key, [default])` | get it, then remove it |
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
- `memory` and `redis` support locks. The `memory` lock works inside one isolate only. `file` and `null` throw `UnsupportedError`.

## Prefix

Every store has a `prefix` (default `dox_cache:`). It is added to every key.
Use different prefixes when two apps share one Redis database.

!!! info "Redis `flush`"
    `flush` deletes only the keys with the prefix. It never runs `FLUSHDB`.
    An empty prefix makes `flush` throw.

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

## Close

`cache.close()` closes the connections of every store that was built, eg. the Redis connections.
Memory, file and null stores have nothing to close. It is safe to call twice.
A store used after it is built again.

In a Dox app you do not call it. Dox closes `Cache()` stores on shutdown, in every isolate, after the open requests are done.
