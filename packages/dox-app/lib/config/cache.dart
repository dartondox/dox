import 'package:dox_core/dox_core.dart';

/// Cache stores
/// -------------------------------
/// `Cache()` uses the default store. `Cache().store('redis')` picks one.
/// Drivers: file, memory, redis, null. Values must be JSON types.
/// Set `CACHE_STORE=redis` to share the cache between isolates and servers.
CacheConfig cache = CacheConfig(
  defaultStore: Env.get('CACHE_STORE', 'file'),
  stores: <String, Map<String, dynamic>>{
    'file': <String, dynamic>{'driver': 'file', 'path': 'storage/cache'},

    /// one map per isolate, fast, not shared
    'memory': <String, dynamic>{'driver': 'memory', 'max_size': 10000},

    /// shared by all isolates and servers
    'redis': <String, dynamic>{
      'driver': 'redis',
      'host': Env.get('REDIS_HOST', '127.0.0.1'),
      'port': Env.get<int>('REDIS_PORT', 6379),
      'db': Env.get<int>('REDIS_DB', 0),
      'password': Env.get<String?>('REDIS_PASSWORD'),
      'prefix': '${Env.get('APP_NAME', 'dox')}_cache:',
    },
  },
);
