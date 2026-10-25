## 3.0.0-alpha.7

- Perf: the memory driver removes expired items and expired locks in a sweep after many writes. Before, a key that was written once with a ttl and never read again stayed in memory forever.
- Perf: the memory driver with no `max_size` does not reorder the map on every hit. The order is only needed for LRU.
- Perf: a tagged cache reads all tag versions with one `many` call (one `MGET` on Redis). `tags(...).flush()` raises all tag versions at the same time. Before, each tag was one round trip after the other.
- Perf: the Redis driver frees a lock with `EVALSHA`. It sends the full script only when Redis does not know it yet.
- Perf: the file driver makes the cache folder only when it is missing. Before, it ran `create(recursive: true)` on every write. Lock tokens use one shared `Random.secure()`.

## 3.0.0-alpha.6

- New `CacheManager.close()`. It closes the connections of every store that was built. The Redis driver closes its connection and its pool connections, with no reconnect. Memory, file and null stores do nothing. It is safe to call twice. A store used after it is built again.
- New `CacheDriver.close()`, for one driver. Custom drivers can override it. The default does nothing.

## 3.0.0-alpha.5

- Version bump only, to match the other packages.

## 3.0.0-alpha.4

- Version bump only, to match the other packages.

## 3.0.0-alpha.3

- New: `getRaw(key)` gives the stored value as JSON text, with no decode. Use it to send a cached value as a JSON response. Memory and Redis return the stored text as is. A stored String comes back with its quotes (`"bar"`). The stored format did not change, so old values still read the same.
- Faster `get`: a plain store builds the key with no async step. `itemKey` now returns `FutureOr<String>`. Memory `get` costs about 0.6 µs instead of 0.86 µs. Memory `getRaw` costs about 0.3 µs.
- New Redis option `pool_size`: the most connections one store opens (ioredis `maxConnection`). Default is 10, the same as before.
- Uses `ioredis` 2.0.0-alpha.2. It sends all commands on one shared connection and writes them together (auto-pipelining). A Redis read costs much less CPU. The cache now uses one connection per store, so `pool_size` rarely matters.

## 3.0.0-alpha.2

- Needs Dart 3.13 or newer.
- All dependencies updated to their latest versions.

## 3.0.0-alpha.1

- Uses `ioredis` 2. Redis error replies throw `RedisError`.
- Redis: no value size limit by default (was 60 KB). `maxValueBytes` is still there if you want one.
- Redis: `many` uses one `MGET`, `putMany` uses one pipeline, `flush` uses `SCAN` + `DEL` (no Lua).
- First release.
- `CacheManager` with named stores and custom drivers.
- Drivers: memory (with LRU), file, Redis, null.
- `remember`, `pull`, `add`, `increment`, `many`, tags and atomic locks.
