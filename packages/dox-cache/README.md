# dox_cache

Cache for Dart with memory, file and Redis drivers. It works like Laravel Cache.

[![pub package](https://img.shields.io/pub/v/dox_cache.svg)](https://pub.dev/packages/dox_cache)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/dartondox/dox/blob/main/LICENSE)

Part of [Dox](https://dartondox.dev), a web backend framework for Dart, like Laravel.
Source code: [github.com/dartondox/dox](https://github.com/dartondox/dox).

## Install

```bash
dart pub add dox_cache
```

To see what is ready and what may still change, read [Status and roadmap](https://dartondox.dev/latest/concepts/status-and-roadmap/).

## Use it

```dart
import 'package:dox_cache/dox_cache.dart';

void main() async {
  CacheManager cache = CacheManager(CacheConfig(
    defaultStore: 'memory',
    stores: <String, Map<String, dynamic>>{
      'memory': <String, dynamic>{'driver': 'memory', 'max_size': 1000},
      'file': <String, dynamic>{'driver': 'file', 'path': 'storage/cache'},
      'redis': <String, dynamic>{'driver': 'redis', 'host': '127.0.0.1', 'prefix': 'app:'},
    },
  ));

  CacheStore store = cache.store(); // the default store
  await store.put('a', 1, Duration(minutes: 5));
  print(await store.get('a')); // 1

  List<dynamic> posts = await store.remember('posts', Duration(minutes: 10), () async {
    return <dynamic>['first post'];
  });
  print(posts);
}
```

In a Dox app you do not set this up yourself. Set the stores in `config/cache.dart` and use `Cache()`.

## Features

- Drivers: `memory` (with an optional LRU size limit), `file`, `redis` and `null`.
- `get`, `put`, `add`, `forget`, `many`, `putMany`, `increment`, `pull`, `remember`.
- Tags: `store.tags(['users']).flush()` removes only those items.
- Atomic locks with `lock(name, ttl)`: `get()`, `release()`, `block(timeout)`. Memory and Redis only.
- A key prefix per store. Redis `flush` deletes only keys with the prefix.
- Your own driver with `cache.extend(name, factory)`.

Values must be JSON types: `Map`, `List`, `String`, `num`, `bool`, `null`.
The `memory` store lives in one isolate. Use `redis` when isolates or servers must share data.

## Documentation

- [Cache package](https://dartondox.dev/latest/packages/cache/)
- [Cache in a Dox app](https://dartondox.dev/latest/digging-deeper/cache/)
- [API reference](https://pub.dev/documentation/dox_cache/latest/)

## License

MIT. See [LICENSE](https://github.com/dartondox/dox/blob/main/LICENSE).
