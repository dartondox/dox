import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import '../cache_clock.dart';
import '../cache_driver.dart';
import '../cache_lock.dart';
import '../constants/cache_constants.dart';

/// Keeps items in a map inside this isolate.
///
/// Not shared: each Dox isolate has its own copy. Use Redis to share.
/// Expired items are removed when read, by each write when they are the
/// oldest items, and by a sweep that runs after many writes. With
/// [maxSize], the least recently used item is removed when the map is
/// full (LRU). Each step is O(1).
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
  final HashMap<String, _Node> _items = HashMap<String, _Node>();

  /// The items in use order. The first one is the least recently used
  /// (or, with no [maxSize], the least recently written).
  final LinkedList<_Node> _order = LinkedList<_Node>();

  final Map<String, MemoryEntry> _locks = <String, MemoryEntry>{};

  /// Writes left until the next sweep of expired items and locks.
  int _writesUntilSweep = _minSweepWrites;

  /// A sweep runs at least this many writes apart. The gap grows with
  /// the map size, so a sweep costs O(1) per write on average.
  static const int _minSweepWrites = 1000;

  /// Number of stored items, expired ones included.
  int get length {
    return _items.length;
  }

  @override
  Future<dynamic> get(String key) async {
    MemoryEntry? entry = _live(prefix + key);
    return entry == null ? null : jsonDecode(entry.value);
  }

  /// The stored JSON text. No decode.
  @override
  Future<String?> getRaw(String key) async {
    MemoryEntry? entry = _live(prefix + key);
    return entry == null ? null : CacheDriver.liveText(entry.value);
  }

  /// No decode: only checks the stored text.
  @override
  Future<bool> has(String key) async {
    MemoryEntry? entry = _live(prefix + key);
    return entry != null && CacheDriver.liveText(entry.value) != null;
  }

  /// Read and remove with no await in between, so it is atomic here.
  @override
  Future<dynamic> pull(String key) async {
    String fullKey = prefix + key;
    MemoryEntry? entry = _live(fullKey);
    if (entry == null) {
      return null;
    }
    _remove(fullKey);
    return jsonDecode(entry.value);
  }

  @override
  Future<bool> touch(String key, Duration? ttl) async {
    String fullKey = prefix + key;
    MemoryEntry? entry = _live(fullKey);
    if (entry == null) {
      return false;
    }
    _items[fullKey]!.entry = MemoryEntry(entry.value, _expiresAt(ttl));
    return true;
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
    MemoryEntry? entry = _remove(prefix + key);
    return entry != null && !_isExpired(entry);
  }

  @override
  Future<void> flush() async {
    _items.clear();
    _order.clear();
  }

  @override
  CacheLock lock(String name, Duration? ttl, [String? owner]) {
    return MemoryLock(this, name, ttl, owner);
  }

  /// Take the lock for [owner] when it is free or expired.
  bool acquireLock(String name, String owner, Duration? ttl) {
    MemoryEntry? held = _locks[name];
    if (held != null && !_isExpired(held)) {
      return false;
    }
    _locks[name] = MemoryEntry(owner, _expiresAt(ttl));
    _countWrite();
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

  /// Free the lock, whoever holds it.
  bool forceReleaseLock(String name) {
    MemoryEntry? held = _locks.remove(name);
    return held != null && !_isExpired(held);
  }

  /// The entry when it exists and is not expired. With [maxSize], marks
  /// it as recently used. Without a limit the order does not matter.
  MemoryEntry? _live(String fullKey) {
    _Node? node = _items[fullKey];
    if (node == null) {
      return null;
    }
    MemoryEntry entry = node.entry;
    if (_isExpired(entry)) {
      _remove(fullKey);
      return null;
    }
    if (maxSize != null) {
      node.unlink();
      _order.add(node);
    }
    return entry;
  }

  void _write(String fullKey, MemoryEntry entry) {
    _Node? node = _items[fullKey];
    if (node == null) {
      node = _items[fullKey] = _Node(fullKey, entry);
    } else {
      node.entry = entry;
      node.unlink();
    }
    _order.add(node);
    int? limit = maxSize;
    while (limit != null && _items.length > limit) {
      _remove(_order.first.key);
    }
    _dropExpiredFront();
    _countWrite();
  }

  /// Remove [fullKey]. Gives its entry, or null when it was not there.
  MemoryEntry? _remove(String fullKey) {
    _Node? node = _items.remove(fullKey);
    node?.unlink();
    return node?.entry;
  }

  /// Remove up to two expired items from the front (the oldest). Items
  /// with the same ttl expire in write order, so this keeps up with them
  /// at O(1) per write, long before the next sweep.
  void _dropExpiredFront() {
    for (int i = 0; i < 2 && _order.isNotEmpty; i++) {
      _Node first = _order.first;
      if (!_isExpired(first.entry)) return;
      _remove(first.key);
    }
  }

  /// Remove expired items and locks once every so many writes, so keys
  /// that are written once and never read again do not stay forever.
  void _countWrite() {
    if (--_writesUntilSweep > 0) {
      return;
    }
    int now = _clock.nowMs();
    _Node? node = _order.isEmpty ? null : _order.first;
    while (node != null) {
      _Node? next = node.next;
      if (node.entry.isExpired(now)) _remove(node.key);
      node = next;
    }
    _locks.removeWhere((String key, MemoryEntry e) => e.isExpired(now));
    _writesUntilSweep = max(_minSweepWrites, _items.length + _locks.length);
  }

  int? _expiresAt(Duration? ttl) {
    return ttl == null ? null : _clock.nowMs() + ttl.inMilliseconds;
  }

  /// Items with no expiry never read the clock.
  bool _isExpired(MemoryEntry entry) {
    return entry.expiresAt != null && entry.isExpired(_clock.nowMs());
  }

  int _toInt(Object? value, String key) {
    if (value is int) {
      return value;
    }
    throw StateError('Cache value of "$key" is not an integer');
  }
}

/// One item in the map and in the use order list.
final class _Node extends LinkedListEntry<_Node> {
  _Node(this.key, this.entry);

  final String key;
  MemoryEntry entry;
}

/// One stored value with its expiry time.
class MemoryEntry {
  MemoryEntry(this.value, this.expiresAt);

  final String value;

  /// Expiry time in milliseconds since epoch. Null means never.
  final int? expiresAt;

  bool isExpired(int nowMs) {
    int? at = expiresAt;
    return at != null && nowMs >= at;
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

  @override
  Future<bool> forceRelease() async {
    return _driver.forceReleaseLock(name);
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
