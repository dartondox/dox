---
icon: lucide/zap
---

# Cache

`Cache()` keeps data that is slow to make, so the next request can read it fast.

It runs on [`dox_cache`](../packages/cache.md), which is built into `dox_core`.

## Drivers

| Driver | Where the data is | Shared between isolates | Locks |
| --- | --- | --- | --- |
| `file` | files in a folder (default `storage/cache`) | yes, on the same machine | yes, on the same machine |
| `memory` | a map inside the isolate | no | yes |
| `redis` | a Redis server | yes, also between machines | yes |
| `null` | nowhere. It stores nothing | - | no |
| `database` | a table in your database, from [`dox_cache_database`](../packages/cache.md#database-store) | yes, also between machines | yes |

!!! warning "Many isolates"
    Dox runs one isolate per CPU core. Each isolate has its own `memory` store.
    So a value you put in one isolate is missing in the others.
    Use `redis` or `database` when all isolates and servers must see the same data.

## Config

A new project already has `lib/config/cache.dart`, with a `file` store and a `memory` store.
`CACHE_STORE` in `.env` picks the default store (`file` when it is not set).
To add a store, edit the file. This example adds a `redis` store:

```dart title="lib/config/cache.dart"
import 'package:dox_core/dox_core.dart';
import 'package:my_app/config/env.dart';

CacheConfig cache = CacheConfig(
  defaultStore: env.cacheStore,
  stores: <String, Map<String, dynamic>>{
    'file': <String, dynamic>{'driver': 'file', 'path': 'storage/cache'},
    'memory': <String, dynamic>{'driver': 'memory', 'max_size': 10000},
    'redis': <String, dynamic>{
      'driver': 'redis',
      'host': env.redisHost,
      'port': env.redisPort,
      'prefix': 'app_cache:',
    },
  },
);
```

Redis needs two keys that a new project does not have yet. Add them to
`lib/config/env.dart` and run `dart run build_runner build`:

```dart title="lib/config/env.dart"
  String get redisHost => '127.0.0.1';

  int get redisPort => 6379;
```

`lib/config/app.dart` already passes it to `AppConfig(cache: cache)`.
Each store is made once per isolate, the first time you use it.

### Store options

| Driver | Options |
| --- | --- |
| `file` | `path` (default `storage/cache`), `prefix` |
| `memory` | `max_size`: the most items. When it is full, the item that was used least recently is removed. No limit by default. Expired items are removed when read, and by a sweep after many writes (at least 1000). Also `prefix`. |
| `redis` | `host` (default `127.0.0.1`), `port` (default `6379`), `username`, `password`, `db` (default `0`), `tls` (`true`/`false`), `pool_size` (default 10), `max_value_bytes` (no limit by default), `prefix` |

A `redis` store with no `prefix` gets `<app name>_cache:` from `APP_NAME`, like `my_shop_cache:`. So two apps on one Redis do not share keys. The other drivers use `dox_cache:`.
You rarely need `pool_size`: the cache sends no blocking commands, so each isolate uses about one Redis connection.

## Encrypt the cache

By default the cache keeps plain JSON. Anyone who can read the cache file or the Redis database can read the values.
To hide them, add `'encrypt': true` to a `file` or `redis` store:

```dart
'file': {'driver': 'file', 'path': 'storage/cache', 'encrypt': true},
```

- It is off by default. A store without the option is not changed.
- The normal `Dox().cache` has the encrypter set for you, and values are encrypted with your `APP_KEY`. A `CacheManager` you build yourself needs `encrypter:` (for example `const CryptCacheEncrypter()`). Old keys in `previousKeys` can still read old entries.
- When the key changes, the old entries cannot be read. They count as a miss. The cache then fills again.
- On a `file` store, the whole file is encrypted, also the expiry time. Lock files are not encrypted. They hold no values.
- On a `redis` store, a plain `int` stays plain text, so `increment` and `decrement` still work. Every other value is encrypted. Tag counters are `int` values, so they stay plain too. To keep a secret number encrypted, store it as a `String`.
- A `memory` or `null` store does not encrypt. Its values never leave the process. The option still needs an encrypter, or building the store throws.
- The option must be `true` or `false`. Any other type, like `'true'`, throws an `ArgumentError`.
- Old plain values read as a miss after you turn the option on. The one exception is an `int` on Redis, which is plain by design and still reads as a value.
- On a `file` store, `prune` deletes files that cannot be decrypted. After a key change with no previous keys, or in a folder that apps with different keys share, `prune` removes those files.
- Cache keys and tag names are not encrypted. A value is not tied to its key, so someone who can write to Redis or the cache folder can copy an encrypted value to another key. Encryption protects against reading only.
- `maxValueBytes` is checked on the plain JSON size. The stored encrypted text is about a third bigger.

## Values are JSON

A value must be a JSON type: `Map`, `List`, `String`, `num`, `bool` or `null`.
A `Map` comes back as `Map<String, dynamic>`. A `List` comes back as `List<dynamic>`.

## Usage

```dart
// no duration: the value stays forever
await Cache().put('foo', 'bar');
await Cache().put('foo', 'bar', duration: Duration(minutes: 10));

await Cache().get('foo');             // 'bar', or null when missing
await Cache().get('foo', 'default');  // 'default' when missing
await Cache().has('foo');             // true
await Cache().forget('foo');          // remove one key
await Cache().forever('settings', <String, dynamic>{'theme': 'dark'});
await Cache().flush();                // remove all items of the store

await Cache().putMany(<String, Object?>{'a': 1, 'b': 2}); // many at once
await Cache().many(<String>['a', 'b', 'c']); // {a: 1, b: 2, c: null}
```

### `remember`

`remember` reads the value from the cache. When it is missing, the function runs and its result is stored.
The value is stored as JSON. Return maps, lists, strings and numbers, not models.

```dart
List<dynamic> posts = await Cache().remember(
  'posts',
  Duration(minutes: 5),
  () async => (await Post().all()).map((Post p) => p.toJson()).toList(),
);
```

`rememberForever(key, fn)` does the same with no expiry.

- `decode:` turns the stored JSON back into your type on a hit, like `decode: (j) => (j as List).cast<String>()`. Without it, use JSON types like `List<dynamic>`.
- `lock: true` lets only one caller on all isolates and servers run the function. The others wait for its value.

`flexible(key, fresh, stale, fn)` serves the value as it is for `fresh`. Then, until `stale` more has passed, it still serves the old value at once and runs `fn` once in the background:

```dart
Map<String, dynamic> stats = await Cache().flexible(
  'stats', Duration(minutes: 1), Duration(minutes: 5), loadStats,
);
```

After `fresh` + `stale`, the value is gone and the next call waits for `fn`.

Pass `null` as `stale` to keep the value until a refresh replaces it. Use it when an old value is better than no value, like rates from a service that can be down. When `fn` fails, callers still get the last good value:

```dart
Map<String, dynamic> rates = await Cache().flexible(
  'rates', Duration(minutes: 10), null, fetchRates,
);
```

### `getRaw`

`getRaw` gives the stored JSON text as it is. Send it as a response with no decode and no encode:

```dart
String? json = await Cache().getRaw('posts');
if (json != null) {
  return response(json).contentType(ContentType.json);
}
```

A missing key gives `null`. A stored `String` comes back as JSON, with its quotes: `"bar"`.
The `memory` driver also keeps JSON text, so `get` decodes on every hit there too.

### Another store

`store(name)` uses a store from the config instead of the default store:

```dart
await Cache().store('redis').put('foo', 'bar');
await Cache().store('memory').get('foo');
```

`store()` changes the `Cache` it is called on. The flag `cacheCopies` makes `store()` and `tags()` give a new `Cache`. See [Core flags](../reference/app-config.md#core-flags).

### Tags

Put items under a tag. Then you can remove only the items of that tag:

```dart
await Cache().tag('users').put('u1', 'Ann');
await Cache().tag('users').flush(); // removes only the items of this tag
```

`tags(['a', 'b'])` uses many tags.

### Locks

A lock makes sure only one request (or one server) runs some code at a time.
The `memory`, `file` and `redis` stores support locks. The `memory` lock works inside one isolate only. The `file` lock works for all isolates on one machine. Use `redis` when many servers must share the lock.

```dart
CacheLock lock = Cache().store('redis').lock('report', Duration(seconds: 30));
if (await lock.get()) {
  try {
    await buildReport();
  } finally {
    await lock.release();
  }
}
```

- `get()` tries once. It is `true` when you got the lock.
- `block(Duration(seconds: 5))` tries again and again until the time is over.
  It gives `false` when the time is over. With the flag `CacheFlags(lockThrows: true)` it throws `LockTimeoutException`. See [CacheConfig](../reference/app-config.md#cacheconfig).
- The lock is freed after its `ttl`, even if you never call `release()`.
- `block(timeout, callback)` runs the callback while it holds the lock, then frees it.
- `forceRelease()` frees the lock, whoever holds it.

### More methods

| Method | What it does |
| --- | --- |
| `add(key, value, duration:)` | store only when the key is missing. `true` when it was stored |
| `pull(key)` | get the value and remove it, in one step |
| `increment(key, [by])` / `decrement(key, [by])` | change an integer. A missing key starts at 0 |
| `touch(key, duration:)` | give a key a new expiry. `false` when it is missing |
| `repository` | the `dox_cache` `CacheStore`, for everything else |

See [dox_cache](../packages/cache.md) for custom drivers.

## Tests

To use a memory store in tests, see [Testing](testing.md#test-the-cache).
