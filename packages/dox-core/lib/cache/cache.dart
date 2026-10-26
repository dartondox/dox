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
  Cache store(String store) {
    _store = store;
    return this;
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
    _tags = names;
    return this;
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
  Future<T> remember<T>(
    String key,
    Duration? duration,
    FutureOr<T> Function() compute,
  ) {
    return repository.remember<T>(key, duration, compute);
  }

  /// Like [remember], but the value never expires.
  Future<T> rememberForever<T>(String key, FutureOr<T> Function() compute) {
    return repository.rememberForever<T>(key, compute);
  }

  /// An atomic lock. Memory and Redis stores support it.
  CacheLock lock(String name, [Duration? ttl, String? owner]) {
    return repository.lock(name, ttl, owner);
  }
}
