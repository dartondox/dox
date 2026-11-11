import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'cache_clock.dart';
import 'cache_config.dart';
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
  CacheStore(
    this.driver, {
    this.clock = const CacheClock(),
    this.flags = const CacheFlags(),
  });

  /// The backend of this store.
  final CacheDriver driver;

  /// Time source of [flexible].
  final CacheClock clock;

  /// The flags of the config. [lock] gives them to each lock.
  final CacheFlags flags;

  /// Running computes of `remember`, per driver and key. Tagged views of
  /// one store share it, because they share the driver.
  static final Expando<Map<String, Future<Object?>>> _inFlight =
      Expando<Map<String, Future<Object?>>>();

  /// The value, or [defaultValue] when missing or expired.
  /// [defaultValue] can be a function. It runs only on a miss:
  /// `get('a', loadA)`.
  Future<dynamic> get(String key, [Object? defaultValue]) {
    FutureOr<String> fullKey = itemKey(key);
    // Fast path: no extra async step when the key is ready.
    if (fullKey is String && defaultValue == null) {
      return driver.get(fullKey);
    }
    return _getOrDefault(fullKey, defaultValue);
  }

  /// The stored value as JSON text, with no decode, or null when missing.
  /// Use it to send a cached value as a JSON response as is.
  /// A stored String comes back with its quotes: `"bar"`.
  Future<String?> getRaw(String key) async {
    FutureOr<String> fullKey = itemKey(key);
    if (fullKey is String) {
      return driver.getRaw(fullKey);
    }
    return driver.getRaw(await fullKey);
  }

  /// True when the key has a non-null value. Does not decode the value.
  Future<bool> has(String key) async {
    return await driver.has(await itemKey(key));
  }

  /// Store a value. Null [ttl] means forever.
  Future<void> put(String key, Object? value, [Duration? ttl]) async {
    await _put(await itemKey(key), value, ttl);
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
    List<String> fullKeys = await itemKeys(keys);
    Map<String, dynamic> found = await driver.many(fullKeys);
    Map<String, dynamic> result = <String, dynamic>{};
    for (int i = 0; i < keys.length; i++) {
      result[keys[i]] = found[fullKeys[i]];
    }
    return result;
  }

  /// Store many values with the same ttl.
  Future<void> putMany(Map<String, Object?> values, [Duration? ttl]) async {
    List<String> keys = values.keys.toList();
    List<String> fullKeys = await itemKeys(keys);
    if (_isGone(ttl)) {
      for (String fullKey in fullKeys) {
        await driver.forget(fullKey);
      }
      return;
    }
    Map<String, Object?> items = <String, Object?>{};
    for (int i = 0; i < keys.length; i++) {
      items[fullKeys[i]] = values[keys[i]];
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

  /// Get the value and remove it. The built-in drivers do this in one
  /// atomic step. [defaultValue] can be a function, like in [get].
  Future<dynamic> pull(String key, [Object? defaultValue]) async {
    Object? value = await driver.pull(await itemKey(key));
    return value ?? await _resolve(defaultValue);
  }

  /// Set a new [ttl] on a key and keep its value. Null [ttl] means
  /// forever. True when the key was there.
  Future<bool> touch(String key, Duration? ttl) async {
    String fullKey = await itemKey(key);
    if (_isGone(ttl)) {
      return await driver.forget(fullKey);
    }
    return await driver.touch(fullKey, ttl);
  }

  /// The cached value, or run [compute], store its result for [ttl]
  /// and return it.
  ///
  /// A cached value comes back as JSON: a Map is `Map<String, dynamic>`
  /// and a List is `List<dynamic>`. So without [decode], [T] must be a
  /// raw JSON type: `int`, `String`, `Map<String, dynamic>`,
  /// `List<dynamic>` or `dynamic`. For other types, pass [decode]. It
  /// turns the cached JSON into [T]:
  /// ```
  /// List<String> names = await cache.remember<List<String>>(
  ///   'names',
  ///   ttl,
  ///   loadNames,
  ///   decode: (Object? json) => List<String>.from(json as List<dynamic>),
  /// );
  /// ```
  ///
  /// Calls for the same key in one isolate wait for the first [compute]
  /// and do not run it again. With [lock], callers in other isolates and
  /// servers wait too, by a cache lock. The driver must support locks.
  Future<T> remember<T>(
    String key,
    Duration? ttl,
    FutureOr<T> Function() compute, {
    T Function(Object? json)? decode,
    bool lock = false,
  }) async {
    String fullKey = await itemKey(key);
    Object? cached = await driver.get(fullKey);
    if (cached != null) {
      return _decode<T>(cached, decode);
    }
    if (lock) {
      return await _once<T>(
        fullKey,
        () => _computeLocked<T>(fullKey, ttl, compute, decode),
      );
    }
    return await _once<T>(
      fullKey,
      () => _computeAndPut<T>(fullKey, ttl, compute),
    );
  }

  /// Like [remember], but the value never expires.
  Future<T> rememberForever<T>(
    String key,
    FutureOr<T> Function() compute, {
    T Function(Object? json)? decode,
    bool lock = false,
  }) async {
    return await remember<T>(key, null, compute, decode: decode, lock: lock);
  }

  /// Stale while revalidate. The value is fresh for [fresh]. After that
  /// it is stale for [stale] more: it is still returned right away, and
  /// one caller refreshes it in the background. After [fresh] + [stale]
  /// it is gone, and the next call waits for [compute].
  ///
  /// A null [stale] keeps the value until a refresh replaces it. Use it
  /// when an old value beats none, like rates from a provider that can be
  /// down: when [compute] fails, callers still get the last good value.
  /// [decode] works like in [remember]. The driver must support locks.
  /// ```
  /// int count = await cache.flexible<int>(
  ///   'users',
  ///   Duration(minutes: 5),
  ///   Duration(minutes: 10),
  ///   countUsers,
  /// );
  /// ```
  Future<T> flexible<T>(
    String key,
    Duration fresh,
    Duration? stale,
    FutureOr<T> Function() compute, {
    T Function(Object? json)? decode,
  }) async {
    String fullKey = await itemKey(key);
    String createdKey = '${CacheConstants.flexibleCreatedPart}$fullKey';
    Map<String, dynamic> found = await driver.many(<String>[
      fullKey,
      createdKey,
    ]);
    Object? cached = found[fullKey];
    Object? created = found[createdKey];
    if (cached == null || created is! int) {
      return await _once<T>(
        fullKey,
        () => _computeFlexible<T>(fullKey, createdKey, fresh, stale, compute),
      );
    }
    if (clock.nowMs() - created >= fresh.inMilliseconds) {
      _refreshFlexible<T>(fullKey, createdKey, fresh, stale, compute).ignore();
    }
    return _decode<T>(cached, decode);
  }

  /// An atomic lock. Supported by memory, file and redis drivers.
  /// Null [ttl] means the lock never expires by itself.
  CacheLock lock(String name, [Duration? ttl, String? owner]) {
    return driver.lock(name, ttl, owner)..throwOnTimeout = flags.lockThrows;
  }

  /// A view of this store where keys belong to [names].
  /// `tags(['a']).flush()` removes only items stored with tag 'a'.
  TaggedCache tags(List<String> names) {
    return TaggedCache(driver, names, clock: clock, flags: flags);
  }

  /// Key sent to the driver. Tagged caches change it.
  /// Plain stores return it right away, with no async step.
  FutureOr<String> itemKey(String key) {
    return key;
  }

  /// Keys sent to the driver for many [keys]. Tagged caches read the
  /// tag versions once for all keys.
  FutureOr<List<String>> itemKeys(List<String> keys) {
    return keys;
  }

  Future<dynamic> _getOrDefault(
    FutureOr<String> fullKey,
    Object? defaultValue,
  ) async {
    dynamic value = await driver.get(await fullKey);
    return value ?? await _resolve(defaultValue);
  }

  /// The value, or the result of calling it when it is a function.
  Future<Object?> _resolve(Object? defaultValue) async {
    if (defaultValue is Object? Function()) {
      Object? result = defaultValue();
      return result is Future<Object?> ? await result : result;
    }
    return defaultValue;
  }

  /// Run [start] once per key in this isolate. Later callers get the
  /// result of the running one.
  Future<T> _once<T>(String fullKey, Future<T> Function() start) async {
    Map<String, Future<Object?>> running = _inFlight[driver] ??=
        <String, Future<Object?>>{};
    Future<Object?>? first = running[fullKey];
    if (first != null) {
      return await first as T;
    }
    Future<T> future = start();
    running[fullKey] = future;
    try {
      return await future;
    } finally {
      if (identical(running[fullKey], future)) {
        unawaited(running.remove(fullKey));
      }
    }
  }

  Future<void> _put(String fullKey, Object? value, Duration? ttl) async {
    if (_isGone(ttl)) {
      await driver.forget(fullKey);
      return;
    }
    await driver.put(fullKey, value, ttl);
  }

  Future<T> _computeAndPut<T>(
    String fullKey,
    Duration? ttl,
    FutureOr<T> Function() compute,
  ) async {
    T value = await compute();
    await _put(fullKey, value, ttl);
    return value;
  }

  /// Wait for the lock, then look again: the holder may have stored it.
  /// When the wait times out, compute anyway.
  Future<T> _computeLocked<T>(
    String fullKey,
    Duration? ttl,
    FutureOr<T> Function() compute,
    T Function(Object? json)? decode,
  ) async {
    CacheLock computeLock = driver.lock(
      '${CacheConstants.rememberLockPart}$fullKey',
      CacheConstants.computeLockTtl,
    );
    bool taken = await computeLock.block<bool>(CacheConstants.computeLockTtl);
    try {
      if (taken) {
        Object? cached = await driver.get(fullKey);
        if (cached != null) {
          return _decode<T>(cached, decode);
        }
      }
      return await _computeAndPut<T>(fullKey, ttl, compute);
    } finally {
      if (taken) {
        await computeLock.release();
      }
    }
  }

  /// Store the value and its "created at" time, both for fresh + stale.
  Future<T> _computeFlexible<T>(
    String fullKey,
    String createdKey,
    Duration fresh,
    Duration? stale,
    FutureOr<T> Function() compute,
  ) async {
    T value = await compute();
    await driver.putMany(<String, Object?>{
      fullKey: value,
      createdKey: clock.nowMs(),
    }, stale == null ? null : fresh + stale);
    return value;
  }

  /// Refresh a stale value when no other caller does it right now.
  /// Errors are dropped: the stale value stays until it ends.
  Future<void> _refreshFlexible<T>(
    String fullKey,
    String createdKey,
    Duration fresh,
    Duration? stale,
    FutureOr<T> Function() compute,
  ) async {
    CacheLock refreshLock = driver.lock(
      '${CacheConstants.flexibleLockPart}$fullKey',
      CacheConstants.computeLockTtl,
    );
    if (!await refreshLock.get()) {
      return;
    }
    try {
      await _computeFlexible<T>(fullKey, createdKey, fresh, stale, compute);
    } on Object {
      // Keep the stale value.
    } finally {
      await refreshLock.release();
    }
  }

  T _decode<T>(Object? json, T Function(Object? json)? decode) {
    return decode == null ? json as T : decode(json);
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
  TaggedCache(super.driver, this.names, {super.clock, super.flags});

  /// Tag names of this view.
  final List<String> names;

  /// Raise the version of every tag. Does not touch other items.
  @override
  Future<void> flush() async {
    await Future.wait(<Future<int>>[
      for (String name in names) driver.increment(_tagKey(name), 1),
    ]);
  }

  @override
  Future<String> itemKey(String key) async {
    return '${await namespace()}$key';
  }

  /// Reads the tag versions once for all keys.
  @override
  Future<List<String>> itemKeys(List<String> keys) async {
    String space = await namespace();
    return <String>[for (String key in keys) '$space$key'];
  }

  /// Key start made from the current tag versions: `tag:<sha1>:`.
  Future<String> namespace() async {
    /// one call for all tags (one MGET on Redis)
    List<String> tagKeys = <String>[for (String name in names) _tagKey(name)];
    Map<String, dynamic> found = await driver.many(tagKeys);
    List<String> versions = <String>[];
    for (int i = 0; i < names.length; i++) {
      versions.add('${names[i]}=${found[tagKeys[i]] ?? 0}');
    }
    String hash = sha1.convert(utf8.encode(versions.join('|'))).toString();
    return '${CacheConstants.tagKeyPart}$hash:';
  }

  String _tagKey(String name) {
    return '${CacheConstants.tagKeyPart}$name';
  }
}
