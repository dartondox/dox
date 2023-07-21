import 'package:dox_core/cache/cache_driver_interface.dart';
import 'package:dox_core/cache/cache_store.dart';
import 'package:dox_core/cache/file_cache_driver.dart';

class Cache {
  CacheStore _store = CacheStore.file;
  String _tag = 'default';

  /// set a driver to store the data
  Cache store(CacheStore store) {
    _store = store;
    return this;
  }

  /// set tag for the cache
  Cache tag(String name) {
    _tag = name;
    return this;
  }

  /// get the cache driver
  CacheDriverInterface get _driver {
    switch (_store) {
      case CacheStore.file:
        return FileCacheDriver(tag: _tag);
      default:
        return FileCacheDriver(tag: _tag);
    }
  }

  /// set key => value to cache
  /// default duration is 1 hour
  /// ```
  /// Cache().put('foo', 'bar');
  /// Cache().put('foo', 'bar', duration: Duration(hours: 24));
  /// ```
  void put(String key, String value, {Duration? duration}) {
    _driver.put(key, value, duration: duration);
  }

  /// set key => value to cache forever
  /// ```
  /// Cache().forever('foo', 'bar');
  /// ```
  void forever(String key, String value) {
    _driver.forever(key, value);
  }

  /// remove a key from cache
  /// ```
  /// Cache().forget('foo');
  ///
  void forget(String key) {
    _driver.forget(key);
  }

  /// remove all cache
  /// ```
  /// Cache().flush();
  ///
  void flush() {
    _driver.flush();
  }

  /// get a value from cache
  /// ```
  /// String? value = Cache().get('foo');
  ///
  String? get(String key) {
    return _driver.get(key);
  }

  /// get a value exist
  /// ```
  /// bool has = Cache().has('foo');
  ///
  bool has(String key) {
    return _driver.has(key);
  }
}
