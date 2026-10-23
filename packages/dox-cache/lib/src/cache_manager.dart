import 'cache_clock.dart';
import 'cache_config.dart';
import 'cache_driver.dart';
import 'cache_store.dart';
import 'constants/cache_constants.dart';
import 'drivers/file_driver.dart';
import 'drivers/memory_driver.dart';
import 'drivers/null_driver.dart';
import 'drivers/redis_driver.dart';

/// Gives named cache stores from the config. Each store is built once.
///
/// ```
/// CacheManager cache = CacheManager(config);
/// await cache.store().put('a', 1);
/// await cache.store('redis').get('a');
/// ```
class CacheManager {
  CacheManager(this.config, {CacheClock clock = const CacheClock()}) {
    _factories[CacheConstants.memoryDriver] = MemoryDriverFactory(clock);
    _factories[CacheConstants.fileDriver] = FileDriverFactory(clock);
    _factories[CacheConstants.redisDriver] = const RedisDriverFactory();
    _factories[CacheConstants.nullDriver] = const NullDriverFactory();
  }

  final CacheConfig config;

  final Map<String, CacheDriverFactory> _factories =
      <String, CacheDriverFactory>{};

  final Map<String, CacheStore> _stores = <String, CacheStore>{};

  /// The store with [name], or the default store.
  CacheStore store([String? name]) {
    String storeName = name ?? config.defaultStore;
    CacheStore? existing = _stores[storeName];
    if (existing != null) {
      return existing;
    }
    CacheStore created = CacheStore(_createDriver(storeName));
    _stores[storeName] = created;
    return created;
  }

  /// Add a driver type. Stores with `'driver': name` use [factory].
  void extend(String name, CacheDriverFactory factory) {
    _factories[name] = factory;
  }

  /// Add a ready driver as a store.
  void addStore(String name, CacheDriver driver) {
    _stores[name] = CacheStore(driver);
  }

  /// Close the connections of every store that was built (eg. Redis).
  /// A store used after this is built again. Safe to call twice.
  /// ```
  /// await cache.close();
  /// ```
  Future<void> close() async {
    List<CacheStore> stores = _stores.values.toList();
    _stores.clear();
    for (CacheStore store in stores) {
      await store.driver.close();
    }
  }

  CacheDriver _createDriver(String storeName) {
    Map<String, dynamic>? options = config.stores[storeName];
    if (options == null) {
      throw ArgumentError('Cache store "$storeName" is not configured');
    }
    String? driverName = options[CacheConstants.driverOption] as String?;
    CacheDriverFactory? factory = _factories[driverName];
    if (factory == null) {
      throw ArgumentError(
        'Cache driver "$driverName" of store "$storeName" is not supported',
      );
    }
    return factory.create(options);
  }
}
