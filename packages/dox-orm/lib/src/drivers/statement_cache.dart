import 'dart:collection';

/// default max prepared statements kept per connection
const int defaultStatementCacheSize = 100;

/// prepared statements of one connection, by sql text.
/// when it is full, the statement that was not used for the longest time
/// is removed (LRU). the driver closes the removed statement.
class StatementCache<S> {
  /// max statements kept
  final int capacity;

  final LinkedHashMap<String, S> _items = LinkedHashMap<String, S>();

  /// times a statement was found in the cache
  int hits = 0;

  /// times a statement was not found and had to be prepared
  int misses = 0;

  /// statements removed because the cache was full
  int evictions = 0;

  StatementCache([this.capacity = defaultStatementCacheSize]);

  /// number of statements kept now
  int get length => _items.length;

  /// sql texts in the cache, oldest use first
  Iterable<String> get keys => _items.keys;

  /// the statement of [sql], it becomes the newest one
  S? get(String sql) {
    S? statement = _items.remove(sql);
    if (statement == null) {
      misses++;
      return null;
    }
    hits++;
    _items[sql] = statement;
    return statement;
  }

  /// keep [statement] for [sql]. it returns the statement that was removed
  /// to make room, the caller must close it.
  S? put(String sql, S statement) {
    _items[sql] = statement;
    if (_items.length <= capacity) {
      return null;
    }
    String oldest = _items.keys.first;
    evictions++;
    return _items.remove(oldest);
  }

  /// remove the statement of [sql], the caller must close it
  S? remove(String sql) => _items.remove(sql);

  /// remove all statements and return them, the caller must close them
  List<S> clear() {
    List<S> all = _items.values.toList();
    _items.clear();
    return all;
  }
}
