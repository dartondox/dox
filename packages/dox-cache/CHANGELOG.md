## Unreleased

- Ships an AI agent skill (dox-cache-guide). Install it in your app with `dart run skills@ get`.
- Requires Dart 3.14 or newer.
- New: `CacheFlags`, opt-in behaviors that work like Laravel, as `CacheConfig(flags: ...)`. All are off by default. `CacheFlags.all()` turns on every flag.
- New: `CacheFlags.lockThrows` makes `lock.block(timeout)` with no callback throw `LockTimeoutException` when the time is over, not give `false`.
- New: `CacheLock.throwOnTimeout` picks this for one lock. A store sets it from the flag. `CacheStore` takes `flags:`.

## 3.1.3

- Version bump only, to match the other packages.

## 3.1.2

- Version bump only, to match the other packages.

## 3.1.1

- New: `flexible` takes a null `stale`. Then the value is kept until a refresh replaces it, so callers still get the last good value when `compute` fails.

## 3.1.0

- New: the file driver can delete expired and broken files by itself. Set the `prune_every` option (or `FileDriver(pruneEvery: ...)`) to run `prune()` in the background once every that many writes. It is off by default (`0`). Only one prune runs at a time, and a failed prune is ignored.
- Fix: `FileDriver.prune()` could delete a new value that `add`, `increment` or `touch` wrote at the same time. Now it takes the same key lock as they do and reads the file again under it. A key that is locked right now is skipped.

## 3.0.2

- Fix: `remember` and `rememberForever` threw on a cache hit when `T` was not a raw JSON type, like `List<String>`. Pass the new `decode` option to turn the cached JSON into `T`. Without it, `T` must be a raw JSON type.
- Fix: `remember` runs `compute` once when many calls for the same key run at the same time in one isolate. The others wait for the first. With the new `lock: true`, callers in other isolates and servers wait too.
- Fix: `pull` is atomic now. Redis uses `GETDEL` (needs Redis 6.2 or newer). Drivers get a new `pull` method.
- Fix: the file driver keeps each prefix in its own sub folder. `flush` deletes only the files of its own prefix, and keeps temp files of writes that are running.
- Change: because of this, files written by older versions are in the base folder and are not found any more. It is a cache, so they are only misses. You can delete the old files in the base folder by hand.
- Fix: a file driver read no longer deletes an expired or broken file. Another isolate may have just written a new value. Use the new `FileDriver.prune()` to delete expired and broken files.
- Fix: the file driver has locks now (`File.create(exclusive: true)`). `add`, `increment` and `touch` take a lock on the key, so they are safe across isolates.
- Fix: a Redis prefix with no `:` at the end gets one. So the prefix `app` does not match the keys of `app2`.
- New: `flexible(key, fresh, stale, compute)`: stale while revalidate.
- New: `touch(key, ttl)` sets a new ttl and keeps the value.
- New: `get` and `pull` take a function as the default. It runs only on a miss.
- New: `lock.block(timeout, callback)` runs the callback while it holds the lock. It throws `LockTimeoutException` when the time is over. `lock.forceRelease()` frees a lock of any owner.
- New: the Redis option `max_value_bytes`.
- Faster: tagged `many`, `putMany`, `has`, `pull` and `remember` read the tag versions once per call.
- Faster: the memory driver keeps the expiry as int milliseconds. It does not read the clock for items with no expiry. `has` does not decode the value.
- Change: `MemoryEntry.expiresAt` is an `int` in milliseconds now. `CacheClock` has a new `nowMs()`.

## 3.0.1

- Version bump only, to match the other packages.

## 3.0.0

- The first stable release.

## 3.0.0-rc.1

- Needs `ioredis` 3.0.1. It fixes a crash on disconnect when the Redis host is a name like `localhost` or `redis`.

## 3.0.0-alpha.17

- Version bump only, to match the other packages.

## 3.0.0-alpha.16

- Change: uses ioredis `^3.0.0`, the first stable ioredis release.

## 3.0.0-alpha.15

- Version bump only, to match the other packages.

## 3.0.0-alpha.14

- Version bump only, to match the other packages.

## 3.0.0-alpha.13

- Version bump only, to match the other packages.

## 3.0.0-alpha.12

- Version bump only, to match the other packages.

## 3.0.0-alpha.11

- Version bump only, to match the other packages.

## 3.0.0-alpha.10

- Version bump only, to match the other packages.

## 3.0.0-alpha.9

- Version bump only, to match the other packages.

## 3.0.0-alpha.8

- Version bump only, to match the other packages.

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
