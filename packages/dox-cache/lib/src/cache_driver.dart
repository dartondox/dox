import 'dart:convert';

import 'cache_lock.dart';

/// A cache backend. Values are JSON-encodable: Map, List, String, num,
/// bool or null. Each driver adds its [prefix] to every key.
///
/// A null ttl means the item never expires.
abstract class CacheDriver {
  /// Added in front of every key.
  String get prefix;

  /// The value, or null when missing or expired.
  Future<dynamic> get(String key);

  /// The stored value as JSON text, or null when missing or expired.
  /// Drivers that keep JSON text return it as is, with no decode.
  Future<String?> getRaw(String key) async {
    Object? value = await get(key);
    return value == null ? null : jsonEncode(value);
  }

  /// [text] from the backend, or null when it is a stored null.
  /// A stored null reads as a miss, the same as in [get].
  static String? liveText(String text) {
    return text == 'null' ? null : text;
  }

  /// Store a value.
  Future<void> put(String key, Object? value, Duration? ttl);

  /// Store a value only when the key is missing. True when stored.
  Future<bool> add(String key, Object? value, Duration? ttl);

  /// Add [by] to an integer value and return the new value.
  /// A missing key starts at 0. The expiry time is kept.
  Future<int> increment(String key, int by);

  /// Remove a key. True when it existed.
  Future<bool> forget(String key);

  /// Remove every item of this store.
  Future<void> flush();

  /// Many values at once. Missing keys map to null.
  Future<Map<String, dynamic>> many(List<String> keys) async {
    Map<String, dynamic> result = <String, dynamic>{};
    for (String key in keys) {
      result[key] = await get(key);
    }
    return result;
  }

  /// Store many values with the same ttl.
  Future<void> putMany(Map<String, Object?> values, Duration? ttl) async {
    for (MapEntry<String, Object?> entry in values.entries) {
      await put(entry.key, entry.value, ttl);
    }
  }

  /// Close the connections of this driver. Safe to call twice. The
  /// default does nothing (memory, file and null drivers).
  Future<void> close() async {}

  /// An atomic lock. Drivers without lock support throw [UnsupportedError].
  CacheLock lock(String name, Duration? ttl, [String? owner]) {
    throw UnsupportedError('$runtimeType does not support locks');
  }
}

/// Builds a driver from the options of one store in the config.
/// Register your own with `CacheManager.extend`.
abstract class CacheDriverFactory {
  CacheDriver create(Map<String, dynamic> options);
}
