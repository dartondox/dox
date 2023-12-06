import 'package:dox_core/cache/drivers/file/file_cache_driver.dart';
import 'package:dox_core/dox_core.dart';

class Cache {
  String _tag = 'default';
  String? _store;

  Map<String, CacheDriverInterface> cacheDrivers =
      <String, CacheDriverInterface>{
    'file': FileCacheDriver(),
    ...Dox().config.cache.drivers,
  };

  /// Set where to store the cache.
  /// The name you set in the cache drivers configuration
  /// Example `drivers => {'file' : FileCacheDriver()}`,
  /// then store name is `file`
  Cache store(String store) {
    _store = store;
    return this;
  }

  /// set tag for the cache
  /// This is the categorize the cache and
  /// useful when you want to flush only specific tag
  /// ```
  /// Cache().tag('tag').put('key', 'value');
  /// ```
  Cache tag(String name) {
    _tag = name;
    return this;
  }

  /// get the cache driver
  CacheDriverInterface get _driver {
    _store ??= Dox().config.cache.defaultDriver;
    CacheDriverInterface d = cacheDrivers[_store] ??
        cacheDrivers[Dox().config.cache.defaultDriver] ??
        FileCacheDriver();
    d.setTag(_tag);
    return d;
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
