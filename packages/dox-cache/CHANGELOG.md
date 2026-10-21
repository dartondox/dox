## Unreleased

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
