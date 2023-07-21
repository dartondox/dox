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

  void put(String key, String value, {Duration? duration}) {
    _driver.put(key, value, duration: duration);
  }

  void forever(String key, String value) {
    _driver.forever(key, value);
  }

  void forget(String key) {
    _driver.forget(key);
  }

  void flush() {
    _driver.flush();
  }

  String? get(String key) {
    return _driver.get(key);
  }

  bool has(String key) {
    return _driver.has(key);
  }
}
