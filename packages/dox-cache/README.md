# dox_cache

Cache for Dart and the [Dox](https://dartondox.dev) framework.
It works like Laravel Cache.

Drivers:

- `memory`: a map in this isolate. Fast. Optional LRU size limit.
- `file`: one JSON text file per key in a folder.
- `redis`: Redis with the [ioredis](https://pub.dev/packages/ioredis) package.
- `null`: stores nothing. Use it to turn caching off.

## Install

```yaml
dependencies:
  dox_cache: ^3.0.0
```

## Quick start

```dart
CacheManager cache = CacheManager(CacheConfig(
  defaultStore: 'redis',
  stores: <String, Map<String, dynamic>>{
    'memory': <String, dynamic>{'driver': 'memory', 'max_size': 1000},
    'file': <String, dynamic>{'driver': 'file', 'path': 'storage/cache'},
    'redis': <String, dynamic>{'driver': 'redis', 'host': '127.0.0.1', 'prefix': 'app:'},
  },
));

CacheStore store = cache.store();          // default store
await store.put('a', 1, Duration(minutes: 5));
await cache.store('file').get('a');        // a named store
```

## Methods

| Method | What it does |
| --- | --- |
| `get(key, [default])` | Value, or default when missing or expired |
| `put(key, value, [ttl])` | Store. No ttl means forever. Zero or negative ttl removes the key |
| `add(key, value, [ttl])` | Store only when missing. Returns true when stored |
| `has(key)` | True when the value is not null |
| `forget(key)` | Remove. Returns true when it existed |
| `flush()` | Remove all items of this store |
| `many(keys)` / `putMany(map, [ttl])` | Many keys at once |
| `increment(key, [by])` / `decrement(key, [by])` | Change an integer. Missing starts at 0. Keeps the ttl |
| `forever(key, value)` | Store without expiry |
| `remember(key, ttl, compute)` | Cached value, or run `compute` and store it |
| `rememberForever(key, compute)` | Same, without expiry |
| `pull(key)` | Get and remove |
| `tags([...])` | Tagged view. `tags(['users']).flush()` removes only those items |
| `lock(name, [ttl])` | Atomic lock: `get()`, `release()`, `block(timeout)` |

## Values are JSON

Values must be JSON-encodable: `Map`, `List`, `String`, `num`, `bool`, `null`.
They are stored as JSON text. Other types throw.

- A Map comes back as `Map<String, dynamic>`. A List comes back as `List<dynamic>`.
- A stored `null` reads as a miss. `has` returns false for it.
- `remember<T>` casts the cached value to `T`, so use JSON types for `T`.

## Prefix

Every store has a `prefix` option (default `dox_cache:`). It is added to every key.
Use different prefixes when stores share one Redis database.

## Drivers

### Memory

```dart
MemoryDriver(prefix: 'app:', maxSize: 1000, clock: CacheClock())
```

- Items live in this isolate only. Dox runs many isolates, and each one has its
  own memory cache. Use Redis when isolates or servers must share data.
- Expired items are removed when read.
- With `maxSize`, the least recently used item is removed when full.
- Supports locks (inside one isolate).

### File

```dart
FileDriver(directory: Directory('storage/cache'), prefix: 'app:')
```

- One file per key. The file name is the sha256 of prefix + key.
- The file holds `{"value": ..., "expires_at": <ms or null>}`.
- Writes go to a temp file and then rename, so readers never see half a file.
- Expired and broken files are deleted when read.
- `flush` deletes everything in the folder. Give the cache its own folder.
- `add` and `increment` are not atomic between processes. No locks.

### Redis

```dart
RedisDriver(Redis(RedisOptions(host: '127.0.0.1', port: 6379)), prefix: 'app:')
```

Config options: `host`, `port`, `username`, `password`, `db`, `tls`, `prefix`.

- `put` uses `SET key value PX ttl`. `add` adds `NX`. `increment` uses `INCRBY`.
- `flush` deletes only keys with the prefix (SCAN, then DEL).
  It never runs `FLUSHDB`. An empty prefix makes `flush` throw.
- Locks use `SET NX PX` with a random owner token. Release is a Lua script that
  deletes the key only when the token matches.
- The ioredis `keyPrefix` option is not used. Use the store `prefix`.
- `many` uses one `MGET`. `putMany` sends all `SET`s in one pipeline.
- There is no size limit by default. Set `maxValueBytes` to refuse big values
  (they throw `ArgumentError`).
- Redis error replies throw `RedisError` (from ioredis).

## Tags

```dart
await store.tags(<String>['users']).put('u1', 'Ann');
await store.tags(<String>['users']).flush();
```

Tags work with every driver. Each tag has a version number in the cache.
Flushing a tag raises the version, so old items are not found anymore.
Old items are not deleted right away. They stay until their ttl ends.

## Locks

```dart
CacheLock lock = store.lock('report', Duration(seconds: 10));
if (await lock.get()) {
  try {
    // only one worker runs this
  } finally {
    await lock.release();
  }
}
bool got = await lock.block(Duration(seconds: 5)); // wait up to 5 s
```

Memory and Redis drivers support locks. To release a lock in another process,
pass the owner token: `store.lock('report', ttl, lock.owner).release()`.

## Custom driver

```dart
class MyDriverFactory implements CacheDriverFactory {
  @override
  CacheDriver create(Map<String, dynamic> options) {
    return MyDriver(options);
  }
}

cache.extend('mine', MyDriverFactory());   // config: {'driver': 'mine'}
cache.addStore('ready', MemoryDriver());   // or add a ready driver
```

`MyDriver extends CacheDriver` and implements `get`, `put`, `add`,
`increment`, `forget` and `flush`.

## Tests

```bash
docker run -d --rm --name dox-cache-redis -p 6399:6379 redis:7-alpine
REDIS_PORT=6399 dart test
docker rm -f dox-cache-redis
```

Redis tests are skipped when Redis is not reachable.
Set `REDIS_HOST` and `REDIS_PORT` to point to your Redis (default `127.0.0.1:6379`).
