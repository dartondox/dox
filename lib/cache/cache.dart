import 'package:dox_core/cache/cache_driver_interface.dart';
import 'package:dox_core/cache/drivers/file/file_cache_driver.dart';
import 'package:dox_core/cache/drivers/redis/redis_cache_driver.dart';
import 'package:dox_core/dox_core.dart';

class Cache {
  CacheStore _store = Dox().config.cacheStore;
  String _tag = 'default';
  CacheDriverInterface? _customDriver = Dox().config.customCacheDriver;

  /// set a driver to store the data
  Cache store(CacheStore store) {
    _store = store;
    return this;
  }

  Cache driver(CacheDriverInterface driver) {
    _customDriver = driver;
    return this;
  }

  /// set tag for the cache
  Cache tag(String name) {
    _tag = name;
    return this;
  }

  /// get the cache driver
  CacheDriverInterface get _driver {
    if (_customDriver != null) {
      return _customDriver!;
    }
    switch (_store) {
      case CacheStore.file:
        return FileCacheDriver(tag: _tag);
      case CacheStore.redis:
        return RedisCacheDriver(tag: _tag);
      default:
        return FileCacheDriver(tag: _tag);
    }
  }

  /// set key => value to cache
  /// default duration is 1 hour
  /// ```
  /// await Cache().put('foo', 'bar');
  /// await Cache().put('foo', 'bar', duration: Duration(hours: 24));
  /// ```
  Future<void> put(String key, String value, {Duration? duration}) async {
    await _driver.put(key, value, duration: duration);
  }

  /// set key => value to cache forever
  /// ```
  /// await Cache().forever('foo', 'bar');
  /// ```
  Future<void> forever(String key, String value) async {
    await _driver.forever(key, value);
  }

  /// remove a key from cache
  /// ```
  /// await Cache().forget('foo');
  ///
  Future<void> forget(String key) async {
    await _driver.forget(key);
  }

  /// remove all cache
  /// ```
  /// await Cache().flush();
  ///
  Future<void> flush() async {
    await _driver.flush();
  }

  /// get a value from cache
  /// ```
  /// String? value = await Cache().get('foo');
  ///
  Future<dynamic> get(String key) async {
    return await _driver.get(key);
  }

  /// get a value exist
  /// ```
  /// bool has = await Cache().has('foo');
  ///
  Future<bool> has(String key) async {
    return await _driver.has(key);
  }
}
