import 'dart:convert';

import '../cache_clock.dart';
import '../cache_driver.dart';
import '../cache_lock.dart';
import '../constants/cache_constants.dart';

/// Keeps items in a map inside this isolate.
///
/// Not shared: each Dox isolate has its own copy. Use Redis to share.
/// Expired items are removed when read. With [maxSize], the least
/// recently used item is removed when the map is full (LRU).
class MemoryDriver extends CacheDriver {
  MemoryDriver({
    this.prefix = CacheConstants.defaultPrefix,
    this.maxSize,
    this._clock = const CacheClock(),
  });

  @override
  final String prefix;

  /// Max number of items. Null means no limit.
  final int? maxSize;

  final CacheClock _clock;

  /// Values are kept as JSON text, so callers can not change them later.
  /// A Dart map keeps insert order. The first key is the least recently used.
  final Map<String, MemoryEntry> _items = <String, MemoryEntry>{};

  final Map<String, MemoryEntry> _locks = <String, MemoryEntry>{};

  /// Number of stored items, expired ones included.
  int get length {
    return _items.length;
  }

  @override
  Future<dynamic> get(String key) async {
    MemoryEntry? entry = _live(prefix + key);
    return entry == null ? null : jsonDecode(entry.value);
  }

  @override
  Future<void> put(String key, Object? value, Duration? ttl) async {
    _write(prefix + key, MemoryEntry(jsonEncode(value), _expiresAt(ttl)));
  }

  @override
  Future<bool> add(String key, Object? value, Duration? ttl) async {
    if (_live(prefix + key) != null) {
      return false;
    }
    await put(key, value, ttl);
    return true;
  }

  @override
  Future<int> increment(String key, int by) async {
    String fullKey = prefix + key;
    MemoryEntry? entry = _live(fullKey);
    int current = entry == null ? 0 : _toInt(jsonDecode(entry.value), key);
    int next = current + by;
    _write(fullKey, MemoryEntry(jsonEncode(next), entry?.expiresAt));
    return next;
  }

  @override
  Future<bool> forget(String key) async {
    MemoryEntry? entry = _items.remove(prefix + key);
    return entry != null && !entry.isExpired(_clock.now());
  }

  @override
  Future<void> flush() async {
    _items.clear();
  }

  @override
  CacheLock lock(String name, Duration? ttl, [String? owner]) {
    return MemoryLock(this, name, ttl, owner);
  }

  /// Take the lock for [owner] when it is free or expired.
  bool acquireLock(String name, String owner, Duration? ttl) {
    MemoryEntry? held = _locks[name];
    if (held != null && !held.isExpired(_clock.now())) {
      return false;
    }
    _locks[name] = MemoryEntry(owner, _expiresAt(ttl));
    return true;
  }

  /// Free the lock when [owner] holds it.
  bool releaseLock(String name, String owner) {
    MemoryEntry? held = _locks[name];
    if (held == null || held.value != owner) {
      return false;
    }
    _locks.remove(name);
    return true;
  }

  /// The entry when it exists and is not expired. Marks it as recently used.
  MemoryEntry? _live(String fullKey) {
    MemoryEntry? entry = _items.remove(fullKey);
    if (entry == null || entry.isExpired(_clock.now())) {
      return null;
    }
    _items[fullKey] = entry;
    return entry;
  }

  void _write(String fullKey, MemoryEntry entry) {
    _items.remove(fullKey);
    _items[fullKey] = entry;
    int? limit = maxSize;
    while (limit != null && _items.length > limit) {
      _items.remove(_items.keys.first);
    }
  }

  DateTime? _expiresAt(Duration? ttl) {
    return ttl == null ? null : _clock.now().add(ttl);
  }

  int _toInt(Object? value, String key) {
    if (value is int) {
      return value;
    }
    throw StateError('Cache value of "$key" is not an integer');
  }
}

/// One stored value with its expiry time.
class MemoryEntry {
  MemoryEntry(this.value, this.expiresAt);

  final String value;
  final DateTime? expiresAt;

  bool isExpired(DateTime now) {
    DateTime? at = expiresAt;
    return at != null && !now.isBefore(at);
  }
}

/// Lock kept in a [MemoryDriver]. Only works inside one isolate.
class MemoryLock extends CacheLock {
  MemoryLock(this._driver, super.name, super.ttl, [super.owner]);

  final MemoryDriver _driver;

  @override
  Future<bool> get() async {
    return _driver.acquireLock(name, owner, ttl);
  }

  @override
  Future<bool> release() async {
    return _driver.releaseLock(name, owner);
  }
}

/// Builds a [MemoryDriver]. Options: prefix, max_size.
class MemoryDriverFactory implements CacheDriverFactory {
  const MemoryDriverFactory([this._clock = const CacheClock()]);

  final CacheClock _clock;

  @override
  CacheDriver create(Map<String, dynamic> options) {
    return MemoryDriver(
      prefix:
          options[CacheConstants.prefixOption] as String? ??
          CacheConstants.defaultPrefix,
      maxSize: options[CacheConstants.maxSizeOption] as int?,
      clock: _clock,
    );
  }
}
