import 'package:dox_app/config/env.dart';
import 'package:dox_core/dox_core.dart';

/// Cache stores
/// -------------------------------
/// `Cache()` uses the default store. `Cache().store('redis')` picks one.
/// Drivers: file, memory, redis, null. Values must be JSON types.
/// Set `CACHE_STORE=redis` to share the cache between isolates and servers.
CacheConfig cache = CacheConfig(
  defaultStore: env.cacheStore,
  stores: <String, Map<String, dynamic>>{
    'file': <String, dynamic>{'driver': 'file', 'path': 'storage/cache'},

    /// one map per isolate, fast, not shared
    'memory': <String, dynamic>{'driver': 'memory', 'max_size': 10000},

    /// shared by all isolates and servers
    'redis': <String, dynamic>{
      'driver': 'redis',
      'host': env.redisHost,
      'port': env.redisPort,
      'db': env.redisDb,
      'password': env.redisPassword,
      'prefix': '${env.appName}_cache:',
    },
  },
);
