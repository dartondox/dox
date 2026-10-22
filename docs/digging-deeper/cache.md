# Cache

`Cache()` stores data that is slow to make, so the next request can read it fast.
It runs on [`dox_cache`](../packages/cache.md), which is built into `dox_core`.

Drivers: `file`, `memory`, `redis` and `null` (stores nothing).

## Config

`config/cache.dart`:

```dart
CacheConfig cache = CacheConfig(
  defaultStore: Env.get('CACHE_STORE', 'file'),
  stores: <String, Map<String, dynamic>>{
    'file': <String, dynamic>{'driver': 'file', 'path': 'storage/cache'},
    'memory': <String, dynamic>{'driver': 'memory', 'max_size': 10000},
    'redis': <String, dynamic>{
      'driver': 'redis',
      'host': Env.get('REDIS_HOST', '127.0.0.1'),
      'port': Env.get<int>('REDIS_PORT', 6379),
      'prefix': 'app_cache:',
    },
  },
);
```

Pass it to `AppConfig(cache: cache)`. Each store is made once per isolate, the first time you use it.

!!! warning "Many isolates"
    Dox runs one isolate per CPU core. Each isolate has its own `memory` store.
    Use `redis` when all isolates and servers must see the same data.

Redis options: `host`, `port`, `username`, `password`, `db`, `tls`, `prefix`, `pool_size`.

`pool_size` is the most Redis connections one store opens in one isolate. The default is 10.
Each isolate has its own pool. So 4 isolates with `pool_size: 10` can open up to 40 connections.

```dart
'redis': <String, dynamic>{'driver': 'redis', 'host': '127.0.0.1', 'pool_size': 20},
```

## Values are JSON

Values must be JSON types: `Map`, `List`, `String`, `num`, `bool`.
A `Map` comes back as `Map<String, dynamic>`.

## Usage

```dart
// no duration: the value stays forever
await Cache().put('foo', 'bar');
await Cache().put('foo', 'bar', duration: Duration(minutes: 10));

await Cache().get('foo');             // 'bar', or null
await Cache().get('foo', 'default');  // a default when it is missing
await Cache().has('foo');             // true
await Cache().forget('foo');
await Cache().forever('settings', <String, dynamic>{'theme': 'dark'});
await Cache().flush();                // remove all items of the store
```

### `getRaw`

`get` decodes the JSON text into Dart values. If you send the value back as JSON,
Dox must encode it again. That is double work.
`getRaw` gives the stored JSON text as is, so you can send it with no decode and no encode.

```dart
String? json = await Cache().getRaw('posts');
if (json != null) {
  return response(json).contentType(ContentType.json);
}
```

A stored `String` comes back as JSON, with its quotes: `"bar"`. A missing key gives `null`.

### `remember`

```dart
List<dynamic> posts = await Cache().remember(
  'posts',
  Duration(minutes: 5),
  () => Post().all(),
);
```

The value is read from the cache. When it is missing, the function runs and its result is stored.
`rememberForever(key, fn)` does the same without expiry.

### `store`

```dart
await Cache().store('redis').put('foo', 'bar');
await Cache().store('memory').get('foo');
```

### `tag`

```dart
await Cache().tag('users').put('u1', 'Ann');
await Cache().tag('users').flush(); // removes only the items of this tag
```

### More

| Method | What it does |
| --- | --- |
| `add(key, value, duration:)` | store only when the key is missing |
| `pull(key)` | get the value and remove it |
| `increment(key, [by])` / `decrement(key, [by])` | change an integer |
| `lock(name, ttl)` | atomic lock (memory and redis) |
| `repository` | the `dox_cache` `CacheStore`, for everything else |

See [dox_cache](../packages/cache.md) for locks and custom drivers.

## Tests

`Dox().cache` is the `CacheManager`. Replace it in a test:

```dart
Dox().cache = CacheManager(CacheConfig(
  defaultStore: 'memory',
  stores: <String, Map<String, dynamic>>{'memory': <String, dynamic>{'driver': 'memory'}},
));
```
