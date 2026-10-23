import 'package:dox_core/dox_core.dart';
import 'package:my_app/config/env.dart';

/// Cache stores
/// -------------------------------
/// `Cache()` uses the default store. `Cache().store('memory')` picks one.
/// Drivers: file, memory, redis, null. Values must be JSON types.
CacheConfig cache = CacheConfig(
  defaultStore: env.cacheStore,
  stores: <String, Map<String, dynamic>>{
    'file': <String, dynamic>{'driver': 'file', 'path': 'storage/cache'},

    /// one map per isolate, fast, not shared
    'memory': <String, dynamic>{'driver': 'memory', 'max_size': 10000},
  },
);
