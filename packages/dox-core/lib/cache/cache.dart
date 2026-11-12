import 'dart:async';

import 'package:dox_core/dox_core.dart';

/// Cache facade on top of `dox_cache`.
///
/// Stores come from `AppConfig.cache`. Each store is built once per isolate.
/// ```
/// await Cache().put('foo', 'bar', duration: Duration(minutes: 5));
/// await Cache().store('redis').get('foo');
/// await Cache().tag('users').flush();
/// ```
/// Values must be JSON types (Map, List, String, num, bool).
class Cache {
  /// [manager] is the `dox_cache` CacheManager. Default is `Dox().cache`.
  Cache({this._manager});

  final CacheManager? _manager;
  String? _store;
  List<String>? _tags;

  /// Use the store with this name from the config.
  /// ```
  /// Cache().store('file').put('key', 'value');
  /// ```
  /// It changes this `Cache` and gives it back. With
  /// `CoreFlags.cacheCopies` it gives a new `Cache`, and this one does
  /// not change.
  Cache store(String store) {
    Cache target = _target();
    target._store = store;
    return target;
  }

  /// Put the items under a tag, so you can flush only this tag.
  /// ```
  /// Cache().tag('users').put('u1', 'Ann');
  /// Cache().tag('users').flush();
  /// ```
  Cache tag(String name) {
    return tags(<String>[name]);
  }

  /// Same as [tag], with many tags.
  Cache tags(List<String> names) {
    Cache target = _target();
    target._tags = names;
    return target;
  }

  /// this, or a copy with `CoreFlags.cacheCopies`
  Cache _target() {
    if (!Dox().flags.cacheCopies) return this;
    return Cache(manager: _manager)
      .._store = _store
      .._tags = _tags;
  }

  /// [config] where each Redis store with no `prefix` gets
  /// `<app name>_cache:`, so two apps on one Redis do not share keys.
  /// `My Shop` gives `my_shop_cache:`. An empty [appName] changes nothing,
  /// so the dox_cache default stays for the prefix.
  ///
  /// When the config has no `encrypter`, the result gets one built on
  /// `Crypt` (the `APP_KEY`). A store then only needs `'encrypt': true`.
  static CacheConfig withAppPrefix(CacheConfig config, String appName) {
    String name = appName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    Map<String, Map<String, dynamic>> stores = name.isEmpty
        ? config.stores
        : <String, Map<String, dynamic>>{
            for (MapEntry<String, Map<String, dynamic>> store
                in config.stores.entries)
              store.key:
                  store.value['driver'] == 'redis' &&
                      store.value['prefix'] == null
                  ? <String, dynamic>{
                      ...store.value,
                      'prefix': '${name}_cache:',
                    }
                  : store.value,
          };
    return CacheConfig(
      defaultStore: config.defaultStore,
      stores: stores,
      flags: config.flags,
      encrypter: config.encrypter ?? const CryptCacheEncrypter(),
    );
  }

  /// The `dox_cache` store, for the methods that are not here.
  CacheStore get repository {
    CacheStore store = (_manager ?? Dox().cache).store(_store);
    List<String>? names = _tags;
    return names == null ? store : store.tags(names);
  }

  /// Store a value. No duration means forever.
  /// ```
  /// await Cache().put('foo', 'bar');
  /// await Cache().put('foo', 'bar', duration: Duration(hours: 24));
  /// ```
  Future<void> put(String key, Object? value, {Duration? duration}) {
    return repository.put(key, value, duration);
  }

  /// Store a value forever.
  Future<void> forever(String key, Object? value) {
    return repository.forever(key, value);
  }

  /// Store only when the key is missing. True when it was stored.
  Future<bool> add(String key, Object? value, {Duration? duration}) {
    return repository.add(key, value, duration);
  }

  /// Get a value, or [defaultValue] when it is missing.
  /// ```
  /// String? value = await Cache().get('foo');
  /// ```
  Future<dynamic> get(String key, [Object? defaultValue]) {
    return repository.get(key, defaultValue);
  }

  /// The stored value as JSON text, with no decode. Null when missing.
  /// Fast way to send a cached value as a JSON response.
  /// ```
  /// String? json = await Cache().getRaw('posts');
  /// ```
  Future<String?> getRaw(String key) {
    return repository.getRaw(key);
  }

  /// Many values at once. A missing key gives null.
  /// ```
  /// Map<String, dynamic> values = await Cache().many(<String>['a', 'b']);
  /// ```
  Future<Map<String, dynamic>> many(List<String> keys) {
    return repository.many(keys);
  }

  /// Store many values. No duration means forever.
  /// ```
  /// await Cache().putMany(<String, Object?>{'a': 1, 'b': 2});
  /// ```
  Future<void> putMany(Map<String, Object?> values, {Duration? duration}) {
    return repository.putMany(values, duration);
  }

  /// True when the key has a value.
  Future<bool> has(String key) {
    return repository.has(key);
  }

  /// Remove a key.
  Future<bool> forget(String key) {
    return repository.forget(key);
  }

  /// Remove all items of the store (or of the tag).
  Future<void> flush() {
    return repository.flush();
  }

  /// Get a value and remove it.
  Future<dynamic> pull(String key, [Object? defaultValue]) {
    return repository.pull(key, defaultValue);
  }

  /// Add [by] to an integer. A missing key starts at 0.
  Future<int> increment(String key, [int by = 1]) {
    return repository.increment(key, by);
  }

  /// Take [by] from an integer. A missing key starts at 0.
  Future<int> decrement(String key, [int by = 1]) {
    return repository.decrement(key, by);
  }

  /// The cached value, or run [compute] and store the result.
  /// The value is stored as JSON, so return maps, lists, strings and
  /// numbers, not models:
  /// ```
  /// List<dynamic> posts = await Cache().remember(
  ///   'posts',
  ///   Duration(minutes: 5),
  ///   () async => (await Post().all()).map((Post p) => p.toJson()).toList(),
  /// );
  /// ```
  ///
  /// [decode] turns the stored JSON back into [T] on a cache hit, eg.
  /// `decode: (Object? j) => (j as List<dynamic>).cast<String>()`.
  /// Without it, [T] must be a JSON type like `List<dynamic>`.
  /// With [lock], only one caller on all isolates and servers runs
  /// [compute]. The others wait for its value.
  Future<T> remember<T>(
    String key,
    Duration? duration,
    FutureOr<T> Function() compute, {
    T Function(Object? json)? decode,
    bool lock = false,
  }) {
    return repository.remember<T>(
      key,
      duration,
      compute,
      decode: decode,
      lock: lock,
    );
  }

  /// Like [remember], but the value never expires.
  Future<T> rememberForever<T>(
    String key,
    FutureOr<T> Function() compute, {
    T Function(Object? json)? decode,
    bool lock = false,
  }) {
    return repository.rememberForever<T>(
      key,
      compute,
      decode: decode,
      lock: lock,
    );
  }

  /// Stale while revalidate. For [fresh] the value is served as it is.
  /// After that, until [fresh] + [stale], the old value is still served
  /// at once, and one caller runs [compute] in the background.
  /// A null [stale] keeps the old value until a refresh replaces it, so a
  /// failing [compute] never leaves callers with nothing.
  /// ```
  /// await Cache().flexible('stats', Duration(minutes: 1),
  ///     Duration(minutes: 5), () => loadStats());
  /// ```
  Future<T> flexible<T>(
    String key,
    Duration fresh,
    Duration? stale,
    FutureOr<T> Function() compute, {
    T Function(Object? json)? decode,
  }) {
    return repository.flexible<T>(key, fresh, stale, compute, decode: decode);
  }

  /// Give [key] a new [duration] (null: forever). False when not found.
  Future<bool> touch(String key, {Duration? duration}) {
    return repository.touch(key, duration);
  }

  /// An atomic lock. Memory, file and Redis stores support it.
  CacheLock lock(String name, [Duration? ttl, String? owner]) {
    return repository.lock(name, ttl, owner);
  }
}
