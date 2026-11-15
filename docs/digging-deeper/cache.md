---
icon: lucide/zap
---

# Cache

`Cache()` keeps data that is slow to make, so the next request can read it fast.

Some work takes a long time, like a big database query or a call to another service. If the result does not change often, you can keep it in the cache and read it from there. The cache runs on [`dox_cache`](../packages/cache.md), which is built into `dox_core`.

## Configuration

A new project already has `lib/config/cache.dart`, with a `file` store and a `memory` store. `CACHE_STORE` in `.env` picks the default store. It is `file` when it is not set.

### Install

A new app already has the cache. In an older app, run `dox add cache`:

```bash
dox add cache
```

It writes `lib/config/cache.dart`, adds it to `lib/config/app.dart` and adds the `CACHE_STORE` key. It never overwrites a file, so it is safe to run twice.

To pick another default store, add `--store=redis` (or `memory`, `database`). `redis` also adds the `REDIS_*` keys. `database` also adds `dox_cache_database`, its provider and the cache table migration, and it needs `dox add orm` first.

### Drivers

A store uses one driver. The driver decides where the data is kept:

| Driver | Where the data is | Shared between isolates |
| --- | --- | --- |
| `file` | files in a folder (default `storage/cache`) | yes, on the same machine |
| `memory` | a map inside the isolate | no |
| `redis` | a Redis server | yes, also between machines |
| `database` | a table in your database, from [`dox_cache_database`](../packages/cache.md#database-store) | yes, also between machines |
| `null` | nowhere. It stores nothing | - |

Dox runs one isolate per CPU core, and each isolate has its own `memory` store. So a value you put in one isolate is missing in the others. If all isolates and servers must see the same data, use `redis` or `database`.

### Adding a Redis store

To add a store, edit `lib/config/cache.dart`. This example adds a `redis` store:

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

Redis needs two env keys that a new project does not have yet. Add them to `lib/config/env.dart`, then run `dart run build_runner build`:

```dart title="lib/config/env.dart"
  String get redisHost => '127.0.0.1';

  int get redisPort => 6379;
```

`lib/config/app.dart` already passes the config to `AppConfig(cache: cache)`. All options of each driver are in [Store options](#store-options).

## Retrieving items

Use `get` to read a value. It gives `null` when the key is missing. The second argument is the default, which you get instead of `null`:

```dart
await Cache().get('foo');            // 'bar', or null when missing
await Cache().get('foo', 'default'); // 'default' when missing
```

### Checking if an item exists

The `has` method returns `true` when the key is in the cache:

```dart
if (await Cache().has('foo')) {
  // ...
}
```

### Retrieving many items

The `many` method reads many keys at once. A missing key gives `null`:

```dart
await Cache().many(<String>['a', 'b', 'c']); // {a: 1, b: 2, c: null}
```

### Retrieve and store

Often you want to read a value, and make it when it is missing. The `remember` method does this. If the key is missing, the function runs and its result is stored for the given time:

```dart
List<dynamic> posts = await Cache().remember(
  'posts',
  Duration(minutes: 5),
  () async => (await Post().all()).map((Post p) => p.toJson()).toList(),
);
```

The value is stored as JSON, so return maps, lists, strings and numbers, not models. To keep the value with no expiry, use `rememberForever(key, fn)`.

`remember` has two options:

- `decode:` turns the stored JSON back into your type on a hit, like `decode: (j) => (j as List).cast<String>()`. Without it, use JSON types like `List<dynamic>`.
- `lock: true` lets only one caller on all isolates and servers run the function. The others wait for its value. Use it when the function is slow and many requests could run it at once.

### Serving stale values

Sometimes an old value is fine for a while, but you do not want a user to wait while it is made again. The `flexible` method serves the value as it is for `fresh`. Then, until `stale` more has passed, it still serves the old value at once and runs the function once in the background:

```dart
Map<String, dynamic> stats = await Cache().flexible(
  'stats', Duration(minutes: 1), Duration(minutes: 5), loadStats,
);
```

After `fresh` + `stale`, the value is gone and the next call waits for the function.

If an old value is always better than no value, pass `null` as `stale`. Then the value stays until a refresh replaces it. This is good for data from a service that can be down: when the function fails, callers still get the last good value:

```dart
Map<String, dynamic> rates = await Cache().flexible(
  'rates', Duration(minutes: 10), null, fetchRates,
);
```

### Retrieve and delete

The `pull` method reads a value and removes it in one step:

```dart
dynamic code = await Cache().pull('login_code');
```

### Retrieving raw JSON

If you only send the cached value back as a response, you do not need to decode it and encode it again. `getRaw` gives the stored JSON text as it is:

```dart
String? json = await Cache().getRaw('posts');
if (json != null) {
  return response(json).contentType(ContentType.json);
}
```

A missing key gives `null`. A stored `String` comes back as JSON, with its quotes: `"bar"`.

## Storing items

Use `put` to store a value. Pass a `duration` to make it expire. With no duration, the value stays forever:

```dart
await Cache().put('foo', 'bar', duration: Duration(minutes: 10));

await Cache().put('foo', 'bar');
```

A value must be a JSON type: `Map`, `List`, `String`, `num`, `bool` or `null`. A `Map` comes back as `Map<String, dynamic>`, and a `List` comes back as `List<dynamic>`.

### Storing an item forever

The `forever` method stores a value with no expiry:

```dart
await Cache().forever('settings', <String, dynamic>{'theme': 'dark'});
```

### Storing if not present

The `add` method stores a value only when the key is missing. It returns `true` when the value was stored:

```dart
bool stored = await Cache().add('foo', 'bar', duration: Duration(minutes: 10));
```

### Storing many items

The `putMany` method stores many values at once:

```dart
await Cache().putMany(<String, Object?>{'a': 1, 'b': 2});
```

### Incrementing and decrementing

The `increment` and `decrement` methods change an integer. A missing key starts at 0:

```dart
await Cache().increment('visits');
await Cache().decrement('stock', 5);
```

### Changing the expiry

The `touch` method gives a key a new expiry. It returns `false` when the key is missing:

```dart
await Cache().touch('foo', duration: Duration(hours: 1));
```

## Removing items

The `forget` method removes one key. The `flush` method removes all items of the store:

```dart
await Cache().forget('foo');

await Cache().flush();
```

## Using another store

By default, `Cache()` uses the default store. If you want another store from the config, use `store`:

```dart
await Cache().store('redis').put('foo', 'bar');
```

`store()` changes the `Cache` it is called on. The flag `cacheCopies` makes `store()` and `tags()` give a new `Cache` instead. See [Core flags](../reference/app-config.md#core-flags).

## Cache tags

Tags let you group items, so you can remove only the items of one group. Put items under a tag with `tag`, then call `flush` on the tag:

```dart
await Cache().tag('users').put('u1', 'Ann');
await Cache().tag('users').flush(); // removes only the items of this tag
```

To use many tags, call `tags(['a', 'b'])`.

## Atomic locks

Sometimes only one request (or one server) may run some code at a time, like building a report. A lock does this. The `memory`, `file`, `redis` and `database` stores support locks:

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

`get()` tries once. It is `true` when you got the lock. The lock is freed after its time (`30` seconds here), even if you never call `release()`.

The `memory` lock works inside one isolate only, and the `file` lock works for all isolates on one machine. If many servers must share the lock, use `redis` or `database`.

### Waiting for a lock

`block` tries again and again until the time is over. It gives `false` when the time is over:

```dart
if (await lock.block(Duration(seconds: 5))) {
  // ...
}
```

If you pass a callback, `block` runs it while it holds the lock, then frees the lock. It returns the result of the callback, and throws a `LockTimeoutException` when it could not get the lock in time:

```dart
await lock.block(Duration(seconds: 5), buildReport);
```

With the flag `CacheFlags(lockThrows: true)`, `block` with no callback throws a `LockTimeoutException` instead of giving `false`. See [CacheConfig](../reference/app-config.md#cacheconfig).

To free a lock, whoever holds it, use `forceRelease()`.

## Encrypting the cache

By default the cache keeps plain JSON. So anyone who can read the cache files or the Redis database can read the values. To hide them, add `'encrypt': true` to a `file` or `redis` store:

```dart
'file': {'driver': 'file', 'path': 'storage/cache', 'encrypt': true},
```

The values are encrypted with your `APP_KEY`. When the key changes, old entries count as a miss and the cache fills again. Old keys in `previousKeys` can still read old entries.

Encryption only stops people from reading values. Cache keys and tag names are not encrypted. On Redis, a plain `int` stays plain text, so `increment` still works. To keep a secret number encrypted, store it as a `String`.

## Testing

To use a memory store in tests, see [Testing](testing.md#test-the-cache).

## Details

### Store options

| Driver | Options |
| --- | --- |
| `file` | `path` (default `storage/cache`), `prefix`, `encrypt` |
| `memory` | `max_size`: the most items. When it is full, the item used least recently is removed. No limit by default. Also `prefix`. |
| `redis` | `host` (default `127.0.0.1`), `port` (default `6379`), `username`, `password`, `db` (default `0`), `tls` (`true`/`false`), `pool_size` (default 10), `max_value_bytes` (no limit by default), `prefix`, `encrypt` |

- A `redis` store with no `prefix` gets `<app name>_cache:` from `APP_NAME`, like `my_shop_cache:`. So two apps on one Redis do not share keys. The other drivers use `dox_cache:`.
- You rarely need `pool_size`. The cache sends no blocking commands, so each isolate uses about one Redis connection.
- Each store is made once per isolate, the first time you use it.
- The `memory` driver removes expired items when they are read, and in a sweep after many writes (at least 1000). It also keeps JSON text, so `get` decodes on every hit.
- `repository` gives the `dox_cache` `CacheStore`. See [dox_cache](../packages/cache.md) for custom drivers.

### Encryption

- `encrypt` must be `true` or `false`. Any other type, like `'true'`, throws an `ArgumentError`.
- A `CacheManager` you build yourself needs `encrypter:`, for example `const CryptCacheEncrypter()`. The normal `Dox().cache` has it set for you.
- A `memory` or `null` store does not encrypt, because its values never leave the process. The option still needs an encrypter, or building the store throws.
- On a `file` store, the whole file is encrypted, also the expiry time. Lock files are not encrypted, because they hold no values. `prune` deletes files that can not be decrypted.
- Tag counters are `int` values, so on Redis they stay plain too.
- Old plain values read as a miss after you turn the option on. Only an `int` on Redis still reads as a value.
- A value is not tied to its key. So someone who can write to Redis or the cache folder can copy an encrypted value to another key.
- `max_value_bytes` is checked on the plain JSON size. The encrypted text is about a third bigger.
