---
icon: lucide/zap
---

# Cache

`Cache()` keeps data that is slow to make, so the next request can read it fast.

A **driver** is the place where the data is kept, like files, memory or Redis. A **store** is a driver with a name and its settings.

The cache is in the `dox_cache` package, which is built into `dox_core`. You can also use it [without Dox](#without-dox).

## Setup

A new project already has `lib/config/cache.dart`, with a file store and a memory store. The `CACHE_STORE` key in `.env` picks the default store.

### Install

In an app that has no cache config, run this command:

```bash
dox add cache
```

To pick another default store, add `--store=redis` (or `memory`, `database`). The database option needs `dox add orm` first.

### Drivers

A store uses one driver:

| Driver | Where the data is | Shared between isolates |
| --- | --- | --- |
| `file` | files in a folder (default `storage/cache`) | yes, on the same machine |
| `memory` | a map inside the isolate | no |
| `redis` | a Redis server | yes, also between machines |
| `database` | a table in your database. See [Database store](#database-store) | yes, also between machines |
| `null` | nowhere. It stores nothing | - |

Each isolate has its own memory store. If all isolates and servers must see the same data, use Redis or the database.

Use the memory store for local development and tests only. In production, use the file store on one server, or use Redis or the database.

### Adding a Redis store

Add a store in the config file. This example adds a Redis store:

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

Add the two env keys to `lib/config/env.dart`, then run `dart run build_runner build`:

```dart title="lib/config/env.dart"
  String get redisHost => '127.0.0.1';

  int get redisPort => 6379;
```

### Store options

| Driver | Options |
| --- | --- |
| `file` | `path` (default `storage/cache`), `prefix`, `encrypt`, `prune_every` and `fsync`. See [Pruning the file store](#pruning-the-file-store) |
| `memory` | `max_size`: the most items. When it is full, the item used least recently is removed. No limit by default. Also `prefix`. |
| `redis` | `host` (default `127.0.0.1`), `port` (default `6379`), `username`, `password`, `db` (default `0`), `tls`, `pool_size` (default 10), `max_value_bytes` (no limit by default), `prefix`, `encrypt` |
| `database` | `table`, `connection`, `prefix`, `encrypt`, `prune_interval`. See [Database store](#database-store) |

A Redis store with no prefix gets `<app name>_cache:` from `APP_NAME`. The other drivers use `dox_cache:`.

### Redis options

To set another Redis option, like a command timeout, give the store a `RedisOptions`:

```dart title="lib/config/cache.dart"
'redis': <String, dynamic>{
  'driver': 'redis',
  'options': RedisOptions(
    host: env.redisHost,
    port: env.redisPort,
    commandTimeout: const Duration(seconds: 2),
  ),
},
```

Do not set `host`, `port`, `username`, `password`, `db`, `tls` or `pool_size` next to it. That throws an `ArgumentError`.

Sessions and the [rate limit](../security/rate-limiting.md) use the same store, so they get these options too.

## Retrieving items

Read a value with `get`. The second argument is the default for a missing key:

```dart
await Cache().get('foo');            // 'bar', or null when missing
await Cache().get('foo', 'default'); // 'default' when missing
```

### Checking if an item exists

Check if a key is in the cache:

```dart
if (await Cache().has('foo')) {
  // ...
}
```

### Retrieving many items

Read many keys at once:

```dart
await Cache().many(<String>['a', 'b', 'c']); // {a: 1, b: 2, c: null}
```

### Retrieve and store

Read a value, or make it and store it when it is missing:

```dart
List<dynamic> posts = await Cache().remember(
  'posts',
  Duration(minutes: 5),
  () async => (await Post().all()).map((Post p) => p.toJson()).toList(),
);
```

The value is stored as JSON, so return maps, lists, strings and numbers, not models. For no expiry, use `rememberForever`.

`remember` has two options:

- `decode` turns the stored JSON back into your type, like `decode: (j) => (j as List).cast<String>()`.
- `lock: true` lets only one caller, on all isolates and servers, run the function. The others wait for its value.

### Serving stale values

Serve an old value while a new one is made in the background. The `flexible` method takes two durations:

- For the first duration, the value is **fresh**. Callers get it as it is.
- For the second duration, the value is **stale**. Callers still get it at once, and the function runs one time in the background.

```dart
Map<String, dynamic> stats = await Cache().flexible(
  'stats', Duration(minutes: 1), Duration(minutes: 5), loadStats,
);
```

Pass null as the second duration to keep the old value until a refresh replaces it:

```dart
Map<String, dynamic> rates = await Cache().flexible(
  'rates', Duration(minutes: 10), null, fetchRates,
);
```

### Retrieve and delete

Read a value and remove it in one step:

```dart
dynamic code = await Cache().pull('login_code');
```

### Retrieving raw JSON

Get the stored JSON text as it is, to send it back with no decode:

```dart
String? json = await Cache().getRaw('posts');
if (json != null) {
  return response(json).contentType(ContentType.json);
}
```

## Storing items

Store a value with `put`. With no duration, the value stays forever:

```dart
await Cache().put('foo', 'bar', duration: Duration(minutes: 10));

await Cache().put('foo', 'bar');
```

A value must be a JSON type. For a model, store `model.toJson()`.

### Storing an item forever

Store a value with no expiry:

```dart
await Cache().forever('settings', <String, dynamic>{'theme': 'dark'});
```

### Storing if not present

Store a value only when the key is missing. It returns true when the value was stored:

```dart
bool stored = await Cache()
    .add('foo', 'bar', duration: Duration(minutes: 10));
```

### Storing many items

Store many values at once:

```dart
await Cache().putMany(<String, Object?>{'a': 1, 'b': 2});
```

### Incrementing and decrementing

Change an integer. A missing key starts at 0:

```dart
await Cache().increment('visits');
await Cache().decrement('stock', 5);
```

### Changing the expiry

Give a key a new expiry:

```dart
await Cache().touch('foo', duration: Duration(hours: 1));
```

## Removing items

Remove one key with `forget`, or all items of the store with `flush`:

```dart
await Cache().forget('foo');

await Cache().flush();
```

On Redis, `flush` deletes only the keys with the store prefix.

## Using another store

`Cache()` uses the default store. Call `store` to use another one:

```dart
await Cache().store('redis').put('foo', 'bar');
```

## Cache tags

A **tag** puts items in a group, so you can remove only that group:

```dart
await Cache().tag('users').put('u1', 'Ann');
await Cache().tag('users').flush(); // removes only the items of this tag
```

For many tags, call `tags(['a', 'b'])`.

## Atomic locks

A **lock** lets only one request, or one server, run some code at a time:

```dart
CacheLock lock = Cache().store('redis')
    .lock('report', Duration(seconds: 30));
if (await lock.get()) {
  try {
    await buildReport();
  } finally {
    await lock.release();
  }
}
```

The lock is freed after its time, 30 seconds here, also when you never call `release()`.

A memory lock works in one isolate only, and a file lock on one machine only. For many servers, use Redis or the database.

### Waiting for a lock

Wait for a lock with `block`. It gives false when the time is over:

```dart
if (await lock.block(Duration(seconds: 5))) {
  // ...
}
```

Pass a callback, and `block` runs it with the lock and then frees the lock. It throws a `LockTimeoutException` when the time is over:

```dart
await lock.block(Duration(seconds: 5), buildReport);
```

To free a lock that another owner holds, use `forceRelease()`.

## Encrypting the cache

By default the cache keeps plain JSON. To hide the values, add `'encrypt': true` to a file or Redis store:

```dart
'file': {'driver': 'file', 'path': 'storage/cache', 'encrypt': true},
```

The values are encrypted with your app key. When the key changes, old entries read as a miss.

Cache keys and tag names are not encrypted. Someone who can write to the store can copy an encrypted value to another key.

## Database store

The `dox_cache_database` package keeps the cache in a table of your database, so all servers share it with no Redis.

Install it and make the table:

```bash
dart pub add dox_cache_database
dox cache:table
dox migrate
```

Give `--table=<name>` to `cache:table` for another table name.

Register the driver when the app starts:

```dart
import 'package:dox_cache_database/dox_cache_database.dart';

Dox().cache.extend(
  'database',
  DatabaseCacheDriverFactory(Dox().cache.config.encrypter),
);
```

Then add a store to the config file:

```dart
'database': <String, dynamic>{
  'driver': 'database',
  'table': 'cache', // optional, default `cache`
  'connection': 'cache', // optional, default the default connection
  'prefix': 'app:', // optional
  'encrypt': true, // optional
},
```

Cache calls inside a transaction on the same connection roll back with it. To avoid this, give the store its own connection.

### Deleting expired rows

Expired rows stay in the table. To delete them in the background, set `prune_interval` on the store, in seconds:

```dart
'database': <String, dynamic>{'driver': 'database', 'prune_interval': 3600},
```

Or call `prune()` yourself, for example in a schedule:

```dart
int deleted = await (store.driver as DatabaseCacheDriver).prune();
```

## Pruning the file store

The file store deletes expired files by itself, one time per hour at most.

To clean up more often, call `prune()` yourself, for example in a schedule:

```dart
int deleted = await (store.driver as FileDriver).prune();
```

Or set `prune_every` on the store to prune one time in that many writes:

```dart
'file': <String, dynamic>{
  'driver': 'file',
  'path': 'storage/cache',
  'prune_every': 1000,
},
```

### Faster writes

Each write syncs the file to the disk, which is slow. Turn the sync off with `fsync`:

```dart
'file': <String, dynamic>{
  'driver': 'file',
  'path': 'storage/cache',
  'fsync': false,
},
```

With the sync off, a power cut can lose the last writes. Keep it on for a store that holds sessions.

## Testing

To use a memory store in tests, see [Testing](testing.md#test-the-cache).

## Without Dox

`dox_cache` also works on its own:

```bash
dart pub add dox_cache
```

Make a `CacheManager` with your stores:

```dart
import 'package:dox_cache/dox_cache.dart';

CacheManager cache = CacheManager(CacheConfig(
  defaultStore: 'redis',
  stores: <String, Map<String, dynamic>>{
    'memory': <String, dynamic>{'driver': 'memory', 'max_size': 1000},
    'file': <String, dynamic>{'driver': 'file', 'path': 'storage/cache'},
    'redis': <String, dynamic>{
      'driver': 'redis',
      'host': '127.0.0.1',
      'prefix': 'app:',
    },
  },
));

CacheStore store = cache.store();     // the default store
await cache.store('file').get('a');   // a named store
```

A `CacheStore` has the same methods as `Cache()`, but the duration is a normal argument:

```dart
await store.put('a', 1, Duration(minutes: 5));
```

### Encryption without Dox

A `CacheManager` you build yourself needs an encrypter for stores with `'encrypt': true`:

```dart
class MyEncrypter implements CacheEncrypter {
  @override
  String encrypt(String text) => myEncrypt(text);

  @override
  String decrypt(String text) => myDecrypt(text); // throw on bad input
}

CacheConfig(defaultStore: 'file', stores: stores, encrypter: MyEncrypter());
```

### Your own driver

Write a factory and register it with `extend`. Or add a ready driver with `addStore`:

```dart
class MyDriverFactory implements CacheDriverFactory {
  @override
  CacheDriver create(Map<String, dynamic> options) {
    return MyDriver(options);
  }
}

cache.extend('mine', MyDriverFactory()); // config: {'driver': 'mine'}
cache.addStore('ready', MemoryDriver());
```

Your driver extends `CacheDriver`. It must implement `prefix`, `get`, `put`, `add`, `increment`, `forget` and `flush`. Override `lock` to support locks.

### Closing the cache

Call `cache.close()` to close the connections of every store, like the Redis connections.

## Next steps

- [Session](../the-basic/session.md): keep sessions in a cache store.
- [Rate limiting](../security/rate-limiting.md): the counts live in the default cache store.
- [Testing](testing.md#test-the-cache): a memory store for each test.
