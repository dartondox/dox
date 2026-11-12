import 'dart:convert';
import 'dart:math';

import 'package:dox_cache/dox_cache.dart';
import 'package:dox_orm/dox_orm.dart';

/// Keeps cache items in a database table, so all servers that use the
/// same database share the cache, the locks and the sessions. It works on
/// SQLite, Postgres and MySQL (also MariaDB) through the dox_orm
/// connection.
///
/// The table (default `cache`, made by [CacheTables]) has these columns:
/// - `key`: string(255), the primary key. It is [prefix] + the key.
///   On MySQL it uses the `utf8mb4_bin` collation, so `A` and `a` are
///   two keys.
/// - `value`: text (longText on MySQL), the value as JSON text. On
///   MySQL it uses `utf8mb4_bin` too, so lock owners compare by case.
/// - `expires_at`: bigint, nullable. Unix time in milliseconds (UTC).
///   Null means it never expires.
///
/// An expired row reads as a miss. It stays in the table until the key is
/// written again, or [prune] deletes it. Run [prune] from time to time,
/// eg. in a schedule.
///
/// Locks are rows in the same table: the key is [prefix] + `lock:` +
/// name, the value is the owner token.
///
/// - `add` and lock `get` run two statements. The first deletes the row
///   of the key only when it is expired. The second inserts the row only
///   when the key is missing: this insert is the atomic step, so two
///   servers never both win.
/// - `increment`, `pull` and `touch` run in a transaction and lock the
///   row (`FOR UPDATE` on Postgres and MySQL; SQLite runs one write
///   transaction at a time).
/// - A lock release deletes the row only when the owner matches, in one
///   statement.
///
/// A full key ([prefix] + key, also for locks) may have at most 255
/// characters, the size of the `key` column. A longer key throws an
/// [ArgumentError] on every database.
///
/// Times come from the [CacheClock] of this server, not the database.
/// Keep the clocks of the servers in sync. When two clocks differ, a key
/// or a lock can end early by that difference.
///
/// Cache calls inside an app transaction on the same connection join
/// that transaction: their writes roll back with it, a lock is not seen
/// by other servers until the commit, and the row locks of `increment`,
/// `pull` and `touch` stay until the end. On Postgres a failed cache
/// query also breaks the app transaction. Give the cache store its own
/// [connection] name (with the same database settings) to keep it out
/// of app transactions. On SQLite, a second connection waits for the
/// write transaction of the first one.
///
/// Reads go to the write database, also with read replicas, so a read
/// sees the last write.
///
/// A write that fails with a deadlock runs again, up to [deadlockTries]
/// times in all, after a short random wait. A deadlock is MySQL and
/// MariaDB error 1213 (SQLSTATE 40001), and Postgres SQLSTATE 40P01 or
/// 40001. A lock wait timeout (MySQL 1205) is not retried: each wait can
/// take long. Inside an app transaction on the same connection there is
/// no retry: the deadlock rolled back the app transaction, so the error
/// goes to the caller at once.
///
/// With an [encrypter], every value is encrypted before it is written.
/// A plain `int` stays plain JSON text, the same as the Redis driver.
/// A value that can not be decrypted reads as a miss.
class DatabaseCacheDriver extends CacheDriver {
  /// A [prefix] that does not end with `:` gets one, so `flush` of the
  /// prefix `app` never deletes the keys of `app2`.
  DatabaseCacheDriver({
    this.connection,
    this.table = defaultTable,
    String prefix = CacheConstants.defaultPrefix,
    this._clock = const CacheClock(),
    this.encrypter,
    this.database,
  }) : prefix = RedisDriver.withSeparator(prefix);

  /// The table when the store sets none.
  static const String defaultTable = 'cache';

  /// The driver name in the store config: `'driver': 'database'`.
  static const String driverName = 'database';

  /// Store config keys of this driver.
  static const String tableOption = 'table';
  static const String connectionOption = 'connection';

  /// The size of the `key` column, in characters.
  static const int maxKeyLength = 255;

  /// Keys per query in [many]. SQLite allows only so many values in one
  /// query.
  static const int manyChunk = 500;

  /// Tries of [increment] when the row is deleted between the insert
  /// and the transaction.
  static const int incrementTries = 5;

  /// Runs of a write that fails with a deadlock, the first run included.
  static const int deadlockTries = 5;

  static final Random _random = Random();

  /// The dox_orm connection name. Null: the default connection.
  final String? connection;

  /// The database driver to use instead of the one of [connection].
  /// Null (the default): the driver of [connection].
  final DBDriver? database;

  /// The cache table.
  final String table;

  @override
  final String prefix;

  final CacheClock _clock;

  /// Encrypts the values. Null means plain JSON.
  final CacheEncrypter? encrypter;

  static final RegExp _plainInt = RegExp(r'^-?\d+$');

  /// The driver of [connection]. With read replicas, the write database.
  DBDriver get _db {
    DBDriver db = database ?? SqlQueryBuilder().getDBDriver(connection);
    return db is ReplicaDriver ? db.writer : db;
  }

  /// [prefix] + [key]. Throws an [ArgumentError] when it is longer than
  /// the `key` column. MySQL without strict mode would cut it, so two
  /// long keys would share one row.
  String _key(String key) {
    String full = prefix + key;
    if (full.runes.length > maxKeyLength) {
      throw ArgumentError.value(
        key,
        'key',
        'Cache key with prefix is longer than $maxKeyLength characters',
      );
    }
    return full;
  }

  /// Run [work], and run it again when it fails with a deadlock, up to
  /// [deadlockTries] runs. Inside a transaction of [db] it runs once.
  Future<R> _retry<R>(DBDriver db, Future<R> Function() work) async {
    if (db.hasOpenTransaction) return work();
    for (int run = 1; ; run++) {
      try {
        return await work();
      } catch (error) {
        if (run >= deadlockTries || !isDeadlock(error)) rethrow;
        await Future<void>.delayed(
          Duration(milliseconds: 1 + _random.nextInt(10 * run)),
        );
      }
    }
  }

  /// True when [error] is a deadlock that the database rolled back:
  /// MySQL and MariaDB error 1213 (or SQLSTATE 40001), Postgres SQLSTATE
  /// 40P01 or 40001. A lock wait timeout (MySQL 1205) is false.
  static bool isDeadlock(Object error) {
    if (error is MysqlException) {
      return error.code == 1213 ||
          (error.sqlState == '40001' && error.code != 1205);
    }
    if (error is PgServerException) {
      return error.code == '40P01' || error.code == '40001';
    }
    return false;
  }

  @override
  Future<dynamic> get(String key) async {
    return _decode(await _liveValue(_key(key)));
  }

  /// The stored JSON text. No decode.
  @override
  Future<String?> getRaw(String key) async {
    String? text = _plainText(await _liveValue(_key(key)));
    return text == null ? null : CacheDriver.liveText(text);
  }

  @override
  Future<bool> has(String key) async {
    return await getRaw(key) != null;
  }

  /// One SELECT for each [manyChunk] keys.
  @override
  Future<Map<String, dynamic>> many(List<String> keys) async {
    Map<String, dynamic> result = <String, dynamic>{};
    if (keys.isEmpty) return result;
    DBDriver db = _db;
    List<String> fullKeys = <String>[for (String key in keys) _key(key)];
    Map<String, Object?> found = <String, Object?>{};
    for (int start = 0; start < fullKeys.length; start += manyChunk) {
      int end = start + manyChunk < fullKeys.length
          ? start + manyChunk
          : fullKeys.length;
      Map<String, dynamic> values = <String, dynamic>{'now': _clock.nowMs()};
      List<String> names = <String>[];
      for (int i = start; i < end; i++) {
        values['k$i'] = fullKeys[i];
        names.add('@k$i');
      }
      List<Map<String, dynamic>> rows = await db.query(
        'SELECT ${_col(db, 'key')}, ${_col(db, 'value')} '
        'FROM ${_col(db, table)} '
        'WHERE ${_col(db, 'key')} IN (${names.join(', ')}) AND ${_live(db)}',
        substitutionValues: values,
      );
      for (Map<String, dynamic> row in rows) {
        found[_text(row['key'] as Object)] = row['value'];
      }
    }
    for (int i = 0; i < keys.length; i++) {
      result[keys[i]] = _decode(found[fullKeys[i]]);
    }
    return result;
  }

  /// All upserts in one transaction.
  @override
  Future<void> putMany(Map<String, Object?> values, Duration? ttl) async {
    if (values.isEmpty) return;
    DBDriver db = _db;
    await _retry(db, () {
      return db.transaction(() async {
        for (MapEntry<String, Object?> entry in values.entries) {
          await put(entry.key, entry.value, ttl);
        }
      });
    });
  }

  /// One upsert: insert the row, or replace the value and expiry time.
  @override
  Future<void> put(String key, Object? value, Duration? ttl) async {
    DBDriver db = _db;
    String k = _col(db, 'key');
    String v = _col(db, 'value');
    String e = _col(db, 'expires_at');
    String update = db.getName() == Driver.mysql
        ? 'ON DUPLICATE KEY UPDATE $v = @value, $e = @expires'
        : 'ON CONFLICT ($k) DO UPDATE SET $v = @value, $e = @expires';
    Map<String, dynamic> values = <String, dynamic>{
      'key': _key(key),
      'value': _encode(value),
      'expires': _expiresAt(ttl),
    };
    await _retry(db, () {
      return db.execute(
        'INSERT INTO ${_col(db, table)} ($k, $v, $e) '
        'VALUES (@key, @value, @expires) $update',
        substitutionValues: values,
      );
    });
  }

  @override
  Future<bool> add(String key, Object? value, Duration? ttl) async {
    return _insertIfMissing(_key(key), _encode(value), _expiresAt(ttl));
  }

  /// Reads and writes the locked row in a transaction. A missing or
  /// expired key starts at 0 with no expiry time.
  @override
  Future<int> increment(String key, int by) async {
    DBDriver db = _db;
    String fullKey = _key(key);
    for (int i = 0; i < incrementTries; i++) {
      // The row must be there before the transaction: a missing row can
      // not be locked, and on MySQL two transactions that both insert a
      // missing row can deadlock. So insert it first, on its own.
      await _insertIfMissing(fullKey, '0', null);
      int? next = await _retry(db, () => _incrementLocked(db, fullKey, by));
      if (next != null) return next;
    }
    throw StateError(
      'Cache increment of "$key" failed: the row was deleted '
      '$incrementTries times in a row',
    );
  }

  /// The new value of [fullKey], or null when the row is gone.
  Future<int?> _incrementLocked(DBDriver db, String fullKey, int by) {
    return db.transaction(() async {
      Map<String, dynamic>? row = await _lockedRow(db, fullKey);
      // deleted or expired since the insert: try again
      if (row == null) return null;
      String? text = _plainText(row['value']);
      Object? current = text == null ? null : jsonDecode(text);
      if (current is! int) {
        throw StateError(
          'Cache value of "${fullKey.substring(prefix.length)}" '
          'is not an integer',
        );
      }
      int value = current + by;
      await db.execute(
        'UPDATE ${_col(db, table)} SET ${_col(db, 'value')} = @value '
        'WHERE ${_col(db, 'key')} = @key',
        substitutionValues: <String, dynamic>{
          'key': fullKey,
          'value': '$value',
        },
      );
      return value;
    });
  }

  /// Reads and deletes the locked row in a transaction, so only one
  /// caller gets the value. A missing key is read first with no lock:
  /// on MySQL a lock on a missing row also locks the gap around it.
  @override
  Future<dynamic> pull(String key) async {
    DBDriver db = _db;
    String fullKey = _key(key);
    if (await _liveValue(fullKey) == null) return null;
    return _retry(db, () {
      return db.transaction(() async {
        Map<String, dynamic>? row = await _lockedRow(db, fullKey);
        if (row == null) return null;
        await _delete(db, fullKey);
        return _decode(row['value']);
      });
    });
  }

  @override
  Future<bool> touch(String key, Duration? ttl) async {
    DBDriver db = _db;
    String fullKey = _key(key);
    // no lock on a missing key, see [pull]
    if (await _liveValue(fullKey) == null) return false;
    return _retry(db, () => _touchLocked(db, fullKey, ttl));
  }

  Future<bool> _touchLocked(DBDriver db, String fullKey, Duration? ttl) {
    return db.transaction(() async {
      if (await _lockedRow(db, fullKey) == null) return false;
      // MySQL counts only changed rows, so the count of this UPDATE can
      // not tell if the key is there. The locked row tells it.
      await db.execute(
        'UPDATE ${_col(db, table)} SET ${_col(db, 'expires_at')} = @expires '
        'WHERE ${_col(db, 'key')} = @key',
        substitutionValues: <String, dynamic>{
          'key': fullKey,
          'expires': _expiresAt(ttl),
        },
      );
      return true;
    });
  }

  /// True when a row was deleted. A row that expired but was not deleted
  /// yet counts too.
  @override
  Future<bool> forget(String key) async {
    return await _delete(_db, _key(key)) > 0;
  }

  /// Delete the rows of this store: the keys that start with [prefix].
  /// Its locks go too. Other stores in the same table keep their rows.
  @override
  Future<void> flush() async {
    if (prefix.isEmpty) {
      throw StateError(
        'DatabaseCacheDriver.flush needs a prefix. '
        'It will not delete the whole table.',
      );
    }
    DBDriver db = _db;
    await _retry(db, () {
      return db.execute(
        'DELETE FROM ${_col(db, table)} WHERE ${_prefixMatch(db)}',
        substitutionValues: _prefixValues(db),
      );
    });
  }

  /// Delete the expired rows of this store. Returns how many.
  /// With an empty [prefix] it deletes every expired row of the table,
  /// also the rows of other stores.
  Future<int> prune() {
    DBDriver db = _db;
    Map<String, dynamic> values = <String, dynamic>{
      ..._prefixValues(db),
      'now': _clock.nowMs(),
    };
    return _retry(db, () {
      return db.affectingStatement(
        'DELETE FROM ${_col(db, table)} WHERE ${_prefixMatch(db)} '
        'AND ${_col(db, 'expires_at')} <= @now',
        substitutionValues: values,
      );
    });
  }

  @override
  CacheLock lock(String name, Duration? ttl, [String? owner]) {
    return DatabaseCacheLock(this, name, ttl, owner);
  }

  /// Insert the lock row when the lock is free. True when taken.
  Future<bool> acquireLock(String name, String owner, Duration? ttl) async {
    return _insertIfMissing(_lockKey(name), owner, _expiresAt(ttl));
  }

  /// Delete the lock row only when [owner] holds it and it has not
  /// expired. An expired row stays: the next lock `get` replaces it.
  Future<bool> releaseLock(String name, String owner) async {
    DBDriver db = _db;
    Map<String, dynamic> values = <String, dynamic>{
      'key': _lockKey(name),
      'owner': owner,
      'now': _clock.nowMs(),
    };
    int deleted = await _retry(db, () {
      return db.affectingStatement(
        'DELETE FROM ${_col(db, table)} WHERE ${_col(db, 'key')} = @key '
        'AND ${_col(db, 'value')} = @owner AND ${_live(db)}',
        substitutionValues: values,
      );
    });
    return deleted > 0;
  }

  /// Delete the lock row, whoever holds it.
  Future<bool> forceReleaseLock(String name) async {
    return await _delete(_db, _lockKey(name)) > 0;
  }

  String _lockKey(String name) {
    return _key('${CacheConstants.lockKeyPart}$name');
  }

  /// Delete the row of [fullKey] when it is expired, then insert the row
  /// only when the key is missing. Each is one atomic statement, so of
  /// two callers at the same time only one inserts. The delete can not
  /// remove a live row: a row is only deleted when it is expired.
  Future<bool> _insertIfMissing(String fullKey, String text, int? expiresAt) {
    DBDriver db = _db;
    return _retry(db, () => _insertIfMissingOnce(db, fullKey, text, expiresAt));
  }

  Future<bool> _insertIfMissingOnce(
    DBDriver db,
    String fullKey,
    String text,
    int? expiresAt,
  ) async {
    String k = _col(db, 'key');
    String e = _col(db, 'expires_at');
    await db.execute(
      'DELETE FROM ${_col(db, table)} WHERE $k = @key AND $e <= @now',
      substitutionValues: <String, dynamic>{
        'key': fullKey,
        'now': _clock.nowMs(),
      },
    );
    // MySQL: a no-op update, not INSERT IGNORE. IGNORE would also turn
    // errors (like a key that is too long) into warnings. A row that
    // does not change counts 0 rows.
    String ignore = db.getName() == Driver.mysql
        ? 'ON DUPLICATE KEY UPDATE $k = $k'
        : 'ON CONFLICT ($k) DO NOTHING';
    int inserted = await db.affectingStatement(
      'INSERT INTO ${_col(db, table)} ($k, ${_col(db, 'value')}, $e) '
      'VALUES (@key, @value, @expires) $ignore',
      substitutionValues: <String, dynamic>{
        'key': fullKey,
        'value': text,
        'expires': expiresAt,
      },
    );
    return inserted == 1;
  }

  /// The live row of [fullKey], locked until the transaction ends.
  /// SQLite has no `FOR UPDATE`: its write transaction locks the file.
  Future<Map<String, dynamic>?> _lockedRow(DBDriver db, String fullKey) async {
    String lock = db.getName() == Driver.sqlite ? '' : ' FOR UPDATE';
    List<Map<String, dynamic>> rows = await db.query(
      'SELECT ${_col(db, 'value')}, ${_col(db, 'expires_at')} '
      'FROM ${_col(db, table)} WHERE ${_col(db, 'key')} = @key '
      'AND ${_live(db)}$lock',
      substitutionValues: <String, dynamic>{
        'key': fullKey,
        'now': _clock.nowMs(),
      },
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// The stored value of a live [fullKey], or null.
  Future<Object?> _liveValue(String fullKey) async {
    DBDriver db = _db;
    List<Map<String, dynamic>> rows = await db.query(
      'SELECT ${_col(db, 'value')} FROM ${_col(db, table)} '
      'WHERE ${_col(db, 'key')} = @key AND ${_live(db)}',
      substitutionValues: <String, dynamic>{
        'key': fullKey,
        'now': _clock.nowMs(),
      },
    );
    return rows.isEmpty ? null : rows.first['value'];
  }

  Future<int> _delete(DBDriver db, String fullKey) {
    return _retry(db, () {
      return db.affectingStatement(
        'DELETE FROM ${_col(db, table)} WHERE ${_col(db, 'key')} = @key',
        substitutionValues: <String, dynamic>{'key': fullKey},
      );
    });
  }

  /// A row that has not expired at `@now`.
  String _live(DBDriver db) {
    String e = _col(db, 'expires_at');
    return '($e IS NULL OR $e > @now)';
  }

  /// The keys that start with [prefix], case sensitive.
  /// - SQLite: LIKE ignores the case of ASCII letters there, so it
  ///   compares the start of the key with `substr`.
  /// - Postgres and MySQL: LIKE, which is case sensitive there (the
  ///   `key` column is `utf8mb4_bin` on MySQL). `!` escapes the LIKE
  ///   wildcards, so the `_` in `dox_cache:` is a plain `_`.
  ///
  /// On Postgres with a collation other than `C`, LIKE can not use the
  /// index of the `key` column, so [flush] and [prune] read the whole
  /// table. This is slow only on very big tables.
  String _prefixMatch(DBDriver db) {
    String k = _col(db, 'key');
    if (db.getName() == Driver.sqlite) {
      return 'substr($k, 1, ${prefix.runes.length}) = @prefix';
    }
    return "$k LIKE @pattern ESCAPE '!'";
  }

  /// The value of [_prefixMatch].
  Map<String, dynamic> _prefixValues(DBDriver db) {
    if (db.getName() == Driver.sqlite) {
      return <String, dynamic>{'prefix': prefix};
    }
    String escaped = prefix.replaceAllMapped(RegExp(r'[!%_]'), _escapeLike);
    return <String, dynamic>{'pattern': '$escaped%'};
  }

  static String _escapeLike(Match match) {
    return '!${match[0]}';
  }

  /// [name] quoted as a column or table name. `key` is a reserved word
  /// in MySQL.
  static String _col(DBDriver db, String name) {
    String q = db.getName() == Driver.mysql ? '`' : '"';
    return '$q${name.replaceAll(q, '$q$q')}$q';
  }

  int? _expiresAt(Duration? ttl) {
    return ttl == null ? null : _clock.nowMs() + ttl.inMilliseconds;
  }

  /// The text to store. A plain int stays plain, the same as Redis.
  String _encode(Object? value) {
    String plain = jsonEncode(value);
    CacheEncrypter? secret = encrypter;
    return secret == null || value is int ? plain : secret.encrypt(plain);
  }

  /// The JSON text of a stored value, decrypted when needed. Null for a
  /// miss, also when it can not be decrypted.
  String? _plainText(Object? stored) {
    if (stored == null) return null;
    String text = _text(stored);
    CacheEncrypter? secret = encrypter;
    if (secret == null || _plainInt.hasMatch(text)) return text;
    try {
      return secret.decrypt(text);
    } on Object {
      return null;
    }
  }

  dynamic _decode(Object? stored) {
    String? text = _plainText(stored);
    return text == null ? null : jsonDecode(text);
  }

  /// MariaDB gives JSON looking text of a long text column as a Map or
  /// a List. Turn it back into text.
  static String _text(Object value) {
    if (value is String) return value;
    if (value is Map || value is List) return jsonEncode(value);
    return '$value';
  }
}

/// Lock kept as a row of the cache table. Works across servers.
class DatabaseCacheLock extends CacheLock {
  DatabaseCacheLock(this._driver, super.name, super.ttl, [super.owner]);

  final DatabaseCacheDriver _driver;

  @override
  Future<bool> get() {
    return _driver.acquireLock(name, owner, ttl);
  }

  @override
  Future<bool> release() {
    return _driver.releaseLock(name, owner);
  }

  @override
  Future<bool> forceRelease() {
    return _driver.forceReleaseLock(name);
  }
}

/// Builds a [DatabaseCacheDriver]. Options: table (default `cache`),
/// connection (a dox_orm connection name, default the default
/// connection), prefix, encrypt (needs an encrypter).
///
/// ```
/// Dox().cache.extend(
///   'database',
///   DatabaseCacheDriverFactory(Dox().cache.config.encrypter),
/// );
/// ```
class DatabaseCacheDriverFactory implements CacheDriverFactory {
  const DatabaseCacheDriverFactory([
    this._encrypter,
    this._clock = const CacheClock(),
  ]);

  final CacheEncrypter? _encrypter;
  final CacheClock _clock;

  @override
  CacheDriver create(Map<String, dynamic> options) {
    return DatabaseCacheDriver(
      connection: options[DatabaseCacheDriver.connectionOption] as String?,
      table:
          options[DatabaseCacheDriver.tableOption] as String? ??
          DatabaseCacheDriver.defaultTable,
      prefix:
          options[CacheConstants.prefixOption] as String? ??
          CacheConstants.defaultPrefix,
      clock: _clock,
      encrypter: options[CacheConstants.encryptOption] == true
          ? _encrypter
          : null,
    );
  }
}
