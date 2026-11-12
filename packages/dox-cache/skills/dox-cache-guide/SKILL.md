---
name: dox-cache-guide
description: How to cache data in a Dox app with Cache() (dox_core) or a CacheManager (dox_cache). Use it when you cache query results, add a cache store (file, memory, Redis), use remember, flexible, tags or cache locks, or replace the cache in tests.
---

# Dox cache guide

`dox_cache` is the cache behind `Cache()` in Dox. `dox_core` exports it,
so a Dox app uses `Cache()` from `package:dox_core/dox_core.dart` and installs nothing more.

Full docs:

- https://dartondox.dev/latest/digging-deeper/cache/
- https://dartondox.dev/latest/packages/cache/

Do not invent methods. The lists below are the real API.

## Drivers

| Driver | Where the data is | Shared between isolates | Locks |
| --- | --- | --- | --- |
| `file` | one JSON file per key in a folder (default `storage/cache`) | yes, on one machine | yes, on one machine |
| `memory` | a map in this isolate | no | yes, in this isolate only |
| `redis` | a Redis server | yes, also between machines | yes |
| `null` | nowhere. Turns caching off | - | no |

Dox runs one isolate per CPU core. Each isolate has its own `memory` store.
A value you put in one isolate is missing in the others. Use `redis` when all isolates and servers must see it.

## Config in a Dox app

The stores are in `lib/config/cache.dart`. `lib/config/app.dart` passes them as `AppConfig(cache: cache)`.
`CACHE_STORE` in `.env` (read as `env.cacheStore`) picks the default store.

```dart
// lib/config/cache.dart
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

`env.redisHost` and `env.redisPort` are not in a new app. Add them to `AppEnv` in `lib/config/env.dart`,
then run `dart run build_runner build`:

```dart
String get redisHost => '127.0.0.1';
int get redisPort => 6379;
```

Store options:

| Driver | Options |
| --- | --- |
| every driver | `driver`, `prefix` |
| `file` | `path` (default `storage/cache`) |
| `memory` | `max_size`: the most items. When full, the least recently used item is removed. |
| `redis` | `host` (default `127.0.0.1`), `port` (default `6379`), `username`, `password`, `db`, `tls`, `pool_size` (default 10), `max_value_bytes` |

## Values are JSON

A value must be a JSON type: `Map`, `List`, `String`, `num`, `bool` or `null`.
A `Map` comes back as `Map<String, dynamic>`. A `List` comes back as `List<dynamic>`.
Never cache a model. Cache `model.toJson()`.

## Use it in a Dox app

`Cache()` takes the ttl as the named argument `duration:`. No duration means forever.

```dart
await Cache().put('foo', 'bar', duration: Duration(minutes: 10));
dynamic foo = await Cache().get('foo');             // null when missing
dynamic other = await Cache().get('x', 'default');  // the default when missing
bool there = await Cache().has('foo');
await Cache().forget('foo');
await Cache().forever('settings', <String, dynamic>{'theme': 'dark'});
bool added = await Cache().add('once', 1, duration: Duration(minutes: 1)); // only when missing
dynamic value = await Cache().pull('foo');          // get and remove
int views = await Cache().increment('views');       // a missing key starts at 0
await Cache().putMany(<String, Object?>{'a': 1, 'b': 2});
Map<String, dynamic> many = await Cache().many(<String>['a', 'b']);
await Cache().touch('a', duration: Duration(minutes: 5)); // new expiry
await Cache().flush();                              // remove every item of the store
```

### remember

Read the value. When it is missing, run the function and store its result.

```dart
List<dynamic> posts = await Cache().remember(
  'posts',
  Duration(minutes: 5),
  () async => (await Post().all()).map((Post p) => p.toJson()).toList(),
);
```

- `rememberForever(key, fn)` does the same with no expiry.
- `decode:` turns the stored JSON into your type on a hit:
  `decode: (Object? json) => List<String>.from(json as List<dynamic>)`.
  Without it, the type must be a JSON type like `List<dynamic>`.
- `lock: true` lets only one caller on all isolates and servers run the function. The store must support locks.

### flexible

Serve a stale value at once and refresh it in the background.

```dart
Map<String, dynamic> stats = await Cache().flexible(
  'stats',
  Duration(minutes: 1), // fresh
  Duration(minutes: 5), // stale: still served, refreshed once in the background
  loadStats,
);
```

Pass `null` as the stale time to keep the last good value until a refresh replaces it.

### getRaw

`getRaw(key)` gives the stored JSON text, with no decode. Send it as is:

```dart
String? json = await Cache().getRaw('posts');
if (json != null) {
  return response(json).contentType(ContentType.json); // ContentType from dart:io
}
```

### Another store and tags

```dart
await Cache().store('redis').put('foo', 'bar');
await Cache().tag('users').put('u1', 'Ann');
await Cache().tag('users').flush();            // removes only the items of this tag
await Cache().tags(<String>['a', 'b']).put('x', 1);
```

`store()` and `tag()` change the `Cache` they are called on. Use a new `Cache()` for each chain.

### Locks

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

- `get()` tries once. `true` means you hold the lock.
- `block(Duration(seconds: 5))` tries until the time is over, then gives `false`.
  With `CacheConfig(flags: const CacheFlags(lockThrows: true))` it throws `LockTimeoutException`.
- `block(timeout, callback)` runs the callback while it holds the lock, then frees it.
- The lock is freed after its ttl, even without `release()`.
- `forceRelease()` frees the lock, whoever holds it.

## Without Dox

```bash
dart pub add dox_cache
```

```dart
import 'package:dox_cache/dox_cache.dart';

CacheManager manager = CacheManager(CacheConfig(
  defaultStore: 'memory',
  stores: <String, Map<String, dynamic>>{
    'memory': <String, dynamic>{'driver': 'memory', 'max_size': 1000},
    'file': <String, dynamic>{'driver': 'file', 'path': 'storage/cache'},
  },
));

CacheStore store = manager.store();          // the default store
await store.put('a', 1, Duration(minutes: 5)); // a CacheStore takes the ttl as a positional argument
dynamic a = await store.get('a');
await manager.store('file').get('a');        // a named store
```

The `CacheStore` methods have the same names as `Cache()`: `get`, `getRaw`, `put`, `add`, `has`,
`forget`, `flush`, `many`, `putMany`, `increment`, `decrement`, `forever`, `remember`,
`rememberForever`, `flexible`, `touch`. In a Dox app, `Cache().repository` is the `CacheStore`
and `Dox().cache` is the `CacheManager`.

## Encrypt values

Add `'encrypt': true` to a `file` or `redis` store. It uses the `encrypter` of `CacheConfig`.
In a Dox app the normal `Dox().cache` has it set (the `APP_KEY` one). A `CacheManager` you build needs `encrypter:`.
On Redis, plain ints stay plain, so `increment` still works.

## Tests

Replace the cache with a memory store, so tests do not write files or need Redis:

```dart
import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

void main() {
  setUp(() {
    Dox().cache = CacheManager(CacheConfig(
      defaultStore: 'memory',
      stores: <String, Map<String, dynamic>>{
        'memory': <String, dynamic>{'driver': 'memory'},
      },
    ));
  });

  test('caches the posts', () async {
    await Cache().put('posts', <String>['a', 'b']);
    expect(await Cache().get('posts'), <dynamic>['a', 'b']);
  });
}
```

A new `CacheManager` in `setUp` gives each test an empty cache.
Or set `CACHE_STORE=memory` in `.env.testing`.
