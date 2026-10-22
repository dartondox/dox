# Cache (dox_cache)

`dox_cache` is a cache like Laravel Cache. It has `remember`, tags, atomic locks and four drivers.

!!! tip "Built into Dox"
    `dox_core` uses `dox_cache` for [`Cache()`](../digging-deeper/cache.md).
    In a Dox app, set the stores in `config/cache.dart` (the `CacheConfig` of this page), and use `Cache()`.
    `Dox().cache` is the `CacheManager`. `Cache().repository` is the `CacheStore`.
    This page is for the full API and for using `dox_cache` outside Dox.

## Install

```bash
dart pub add dox_cache
```

```dart
import 'package:dox_cache/dox_cache.dart';
```

!!! note
    `dox_core` exports `CacheConfig`, `CacheManager`, `CacheStore` and `CacheLock` from this package.
    They are the same classes, so importing both packages is fine.

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

## Set up

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

Redis options: `host`, `port`, `username`, `password`, `db`, `tls`, `prefix`, `pool_size`.

`pool_size` is the most Redis connections one store opens in one isolate (ioredis `maxConnection`). The default is 10.
Most of the time a store uses only one connection. ioredis sends all commands on one shared connection and writes the commands of one event-loop turn together (auto-pipelining).
It opens more connections only while a blocking command (like `BLPOP`) waits. The cache does not send blocking commands, so you rarely need to change `pool_size`.
Each Dox isolate has its own connection, so the total is about one per isolate.

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
    (The old `Cache()` in `dox_core` keeps it for 1 hour.)
    A zero or negative ttl removes the key.

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
| `pull(key)` | get it, then remove it |
| `tags([...])` | a tagged view |
| `lock(name, [ttl])` | an atomic lock |

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

`memory` and `redis` support locks. The `memory` lock works inside one isolate only.

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

`MyDriver extends CacheDriver` and implements `get`, `put`, `add`, `increment`, `forget` and `flush`.
