import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'cache_driver.dart';
import 'cache_lock.dart';
import 'constants/cache_constants.dart';

/// The main cache API for one store. Wraps a [CacheDriver].
///
/// Values must be JSON-encodable: Map, List, String, num, bool or null.
/// They are stored as JSON, so a Map comes back as `Map<String, dynamic>`
/// and a List as `List<dynamic>`. A stored null reads as a miss.
///
/// A null ttl means forever. A zero or negative ttl removes the key.
class CacheStore {
  CacheStore(this.driver);

  /// The backend of this store.
  final CacheDriver driver;

  /// The value, or [defaultValue] when missing or expired.
  Future<dynamic> get(String key, [Object? defaultValue]) async {
    dynamic value = await driver.get(await itemKey(key));
    return value ?? defaultValue;
  }

  /// True when the key has a non-null value.
  Future<bool> has(String key) async {
    return await get(key) != null;
  }

  /// Store a value. Null [ttl] means forever.
  Future<void> put(String key, Object? value, [Duration? ttl]) async {
    if (_isGone(ttl)) {
      await forget(key);
      return;
    }
    await driver.put(await itemKey(key), value, ttl);
  }

  /// Store a value that never expires.
  Future<void> forever(String key, Object? value) async {
    await put(key, value);
  }

  /// Store only when the key is missing. True when stored.
  Future<bool> add(String key, Object? value, [Duration? ttl]) async {
    if (_isGone(ttl)) {
      return false;
    }
    return await driver.add(await itemKey(key), value, ttl);
  }

  /// Many values at once. Missing keys map to null.
  Future<Map<String, dynamic>> many(List<String> keys) async {
    List<String> itemKeys = <String>[];
    for (String key in keys) {
      itemKeys.add(await itemKey(key));
    }
    Map<String, dynamic> found = await driver.many(itemKeys);
    Map<String, dynamic> result = <String, dynamic>{};
    for (int i = 0; i < keys.length; i++) {
      result[keys[i]] = found[itemKeys[i]];
    }
    return result;
  }

  /// Store many values with the same ttl.
  Future<void> putMany(Map<String, Object?> values, [Duration? ttl]) async {
    if (_isGone(ttl)) {
      for (String key in values.keys) {
        await forget(key);
      }
      return;
    }
    Map<String, Object?> items = <String, Object?>{};
    for (MapEntry<String, Object?> entry in values.entries) {
      items[await itemKey(entry.key)] = entry.value;
    }
    await driver.putMany(items, ttl);
  }

  /// Add [by] to an integer value. A missing key starts at 0.
  Future<int> increment(String key, [int by = 1]) async {
    return await driver.increment(await itemKey(key), by);
  }

  /// Subtract [by] from an integer value. A missing key starts at 0.
  Future<int> decrement(String key, [int by = 1]) async {
    return await driver.increment(await itemKey(key), -by);
  }

  /// Remove a key. True when it existed.
  Future<bool> forget(String key) async {
    return await driver.forget(await itemKey(key));
  }

  /// Remove every item of this store.
  Future<void> flush() async {
    await driver.flush();
  }

  /// Get the value and remove it.
  Future<dynamic> pull(String key, [Object? defaultValue]) async {
    dynamic value = await get(key, defaultValue);
    await forget(key);
    return value;
  }

  /// The cached value, or run [compute], store its result for [ttl]
  /// and return it. [T] should be a JSON type.
  Future<T> remember<T>(
    String key,
    Duration? ttl,
    FutureOr<T> Function() compute,
  ) async {
    dynamic cached = await get(key);
    if (cached != null) {
      return cached as T;
    }
    T value = await compute();
    await put(key, value, ttl);
    return value;
  }

  /// Like [remember], but the value never expires.
  Future<T> rememberForever<T>(
    String key,
    FutureOr<T> Function() compute,
  ) async {
    return await remember<T>(key, null, compute);
  }

  /// An atomic lock. Supported by memory and redis drivers.
  /// Null [ttl] means the lock never expires by itself.
  CacheLock lock(String name, [Duration? ttl, String? owner]) {
    return driver.lock(name, ttl, owner);
  }

  /// A view of this store where keys belong to [names].
  /// `tags(['a']).flush()` removes only items stored with tag 'a'.
  TaggedCache tags(List<String> names) {
    return TaggedCache(driver, names);
  }

  /// Key sent to the driver. Tagged caches change it.
  Future<String> itemKey(String key) async {
    return key;
  }

  bool _isGone(Duration? ttl) {
    return ttl != null && ttl <= Duration.zero;
  }
}

/// Tagged items. Each tag has a version number in the cache.
/// Keys get a namespace made from the versions. Flushing a tag raises
/// its version, so old items are not found anymore.
///
/// Old items are not deleted right away. They stay until their ttl ends
/// (or LRU removes them). Items stored forever stay until a full flush.
class TaggedCache extends CacheStore {
  TaggedCache(super.driver, this.names);

  /// Tag names of this view.
  final List<String> names;

  /// Raise the version of every tag. Does not touch other items.
  @override
  Future<void> flush() async {
    for (String name in names) {
      await driver.increment(_tagKey(name), 1);
    }
  }

  @override
  Future<String> itemKey(String key) async {
    List<String> versions = <String>[];
    for (String name in names) {
      dynamic version = await driver.get(_tagKey(name));
      versions.add('$name=${version ?? 0}');
    }
    String namespace = sha1.convert(utf8.encode(versions.join('|'))).toString();
    return '${CacheConstants.tagKeyPart}$namespace:$key';
  }

  String _tagKey(String name) {
    return '${CacheConstants.tagKeyPart}$name';
  }
}
