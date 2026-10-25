# Cache

`Cache()` keeps data that is slow to make, so the next request can read it fast.

It runs on [`dox_cache`](../packages/cache.md), which is built into `dox_core`.

## Drivers

| Driver | Where the data is | Shared between isolates | Locks |
| --- | --- | --- | --- |
| `file` | files in a folder (default `storage/cache`) | yes, on the same machine | no |
| `memory` | a map inside the isolate | no | yes |
| `redis` | a Redis server | yes, also between machines | yes |
| `null` | nowhere. It stores nothing | - | no |

!!! warning "Many isolates"
    Dox runs one isolate per CPU core. Each isolate has its own `memory` store.
    So a value you put in one isolate is missing in the others.
    Use `redis` when all isolates and servers must see the same data.

## Config

Without a config, Dox has a `file` store (the default) and a `memory` store.
To change the stores, make `lib/config/cache.dart`:

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

Then pass it to `AppConfig(cache: cache)` in `lib/config/app.dart`.
Each store is made once per isolate, the first time you use it.

### Store options

| Driver | Options |
| --- | --- |
| `file` | `path` (default `storage/cache`), `prefix` |
| `memory` | `max_size`: the most items. When it is full, the item that was used least recently is removed. No limit by default. Expired items are removed when read, and by a sweep every few thousand writes. Also `prefix`. |
| `redis` | `host` (default `127.0.0.1`), `port` (default `6379`), `username`, `password`, `db` (default `0`), `tls` (`true`/`false`), `pool_size` (default 10), `prefix` |

The default `prefix` is `dox_cache:`.
You rarely need `pool_size`: the cache sends no blocking commands, so each isolate uses about one Redis connection.

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
```

### `remember`

`remember` reads the value from the cache. When it is missing, the function runs and its result is stored.

```dart
List<dynamic> posts = await Cache().remember(
  'posts',
  Duration(minutes: 5),
  () => Post().all(),
);
```

`rememberForever(key, fn)` does the same with no expiry.

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

### Tags

Put items under a tag. Then you can remove only the items of that tag:

```dart
await Cache().tag('users').put('u1', 'Ann');
await Cache().tag('users').flush(); // removes only the items of this tag
```

`tags(['a', 'b'])` uses many tags.

### Locks

A lock makes sure only one request (or one server) runs some code at a time.
The `memory` and `redis` stores support locks. Use `redis` when many isolates must share the lock.

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
- The lock is freed after its `ttl`, even if you never call `release()`.

### More methods

| Method | What it does |
| --- | --- |
| `add(key, value, duration:)` | store only when the key is missing. `true` when it was stored |
| `pull(key)` | get the value and remove it |
| `increment(key, [by])` / `decrement(key, [by])` | change an integer. A missing key starts at 0 |
| `repository` | the `dox_cache` `CacheStore`, for everything else |

See [dox_cache](../packages/cache.md) for custom drivers.

## Tests

To use a memory store in tests, see [Testing](testing.md#test-the-cache).
