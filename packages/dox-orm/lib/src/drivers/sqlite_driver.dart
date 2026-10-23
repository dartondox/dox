import 'dart:async';
import 'dart:convert';

import 'package:dox_orm/dox_orm.dart';
import 'package:sqlite3/sqlite3.dart';

/// zone key to find the databases that have an open transaction
const Symbol _txKey = #doxSqliteTransaction;

/// declared column kinds that need a conversion on read
const int _kBool = 1;
const int _kJson = 2;
const int _kDate = 3;

/// driver for sqlite (package `sqlite3`, ffi).
///
/// ponytail: sqlite3 is synchronous, so a query blocks this isolate while it
/// runs. there is one connection per isolate, and while a transaction is
/// open, other queries of this isolate wait until it ends. good for dev,
/// tests and small apps. use postgres or mysql when you need more.
class SqliteDriver extends DBDriver {
  dynamic conn;

  /// max prepared statements kept for the database
  final int statementCacheSize;

  /// constructor
  SqliteDriver({
    required this.conn,
    this.statementCacheSize = defaultStatementCacheSize,
  });

  /// prepared statements of each database, by sql text
  static final Expando<StatementCache<PreparedStatement>> _caches =
      Expando<StatementCache<PreparedStatement>>();

  static final Expando<Future<void>> _transactionDone = Expando<Future<void>>();

  static final Expando<_Schema> _schemas = Expando<_Schema>();

  /// RETURNING is in sqlite 3.35 and newer
  static final bool _hasReturning = sqlite3.version.versionNumber >= 3035000;

  @override
  Driver getName() {
    return Driver.sqlite;
  }

  @override
  bool get supportsReturning => _hasReturning;

  Future<Database> _getConnection() async {
    if (conn is Future) {
      conn = await conn;
    }
    Database db = conn;

    /// wait for a transaction from outside this zone to end
    if (!_inTransaction(db)) {
      while (_transactionDone[db] != null) {
        await _transactionDone[db];
      }
    }
    return db;
  }

  /// close the kept statements and the database
  @override
  Future<void> close() async {
    Object? c = conn;
    try {
      if (c is Future) c = conn = await c;
    } catch (_) {
      conn = null;
      return;
    }
    if (c is! Database) return;
    clearStatementCache();
    conn = null;
    c.close();
  }

  bool _inTransaction(Database db) {
    Set<Database>? open = Zone.current[_txKey];
    return open?.contains(db) ?? false;
  }

  /// run query and return map result
  @override
  Future<List<Map<String, dynamic>>> query(
    String query, {
    String? primaryKey,
    Map<String, dynamic>? substitutionValues,
  }) async {
    Database db = await _getConnection();
    var (String sql, List<Object?> params) = toPositionalParams(
      query,
      substitutionValues,
      _toSqliteValue,
    );
    PreparedStatement statement = _statement(db, sql);
    ResultSet result;
    try {
      result = statement.select(params);
    } finally {
      statement.reset();
    }

    if (result.columnNames.isEmpty) {
      /// old sqlite without RETURNING: give the new row id of an insert
      if (primaryKey != null &&
          db.updatedRows > 0 &&
          sql.trimLeft().toUpperCase().startsWith('INSERT')) {
        return <Map<String, dynamic>>[
          <String, dynamic>{primaryKey: db.lastInsertRowId},
        ];
      }
      return <Map<String, dynamic>>[];
    }
    return _toMapList(db, sql, result);
  }

  /// only run query
  @override
  Future<void> execute(
    String query, {
    Map<String, dynamic>? substitutionValues,
  }) async {
    Database db = await _getConnection();
    var (String sql, List<Object?> params) = toPositionalParams(
      query,
      substitutionValues,
      _toSqliteValue,
    );

    /// no params: sqlite can run many statements in one text
    if (params.isEmpty) {
      db.execute(sql);
      return;
    }
    PreparedStatement statement = _statement(db, sql);
    try {
      statement.execute(params);
    } finally {
      statement.reset();
    }
  }

  /// the statement cache of [db], or null when it has none yet
  StatementCache<PreparedStatement>? statementCacheOf(Database db) {
    return _caches[db];
  }

  /// close all kept statements, eg. before you close the database
  void clearStatementCache() {
    if (conn is! Database) {
      return;
    }
    for (PreparedStatement statement
        in _caches[conn]?.clear() ?? <PreparedStatement>[]) {
      statement.close();
    }
  }

  /// the kept statement of [sql], prepared once
  PreparedStatement _statement(Database db, String sql) {
    StatementCache<PreparedStatement> cache = _caches[db] ??=
        StatementCache<PreparedStatement>(statementCacheSize);
    PreparedStatement? statement = cache.get(sql);
    if (statement != null) {
      return statement;
    }
    statement = db.prepare(sql, persistent: true, checkNoTail: true);
    cache.put(sql, statement)?.close();
    return statement;
  }

  @override
  Future<R> transaction<R>(Future<R> Function() callback) async {
    Database db = await _getConnection();

    /// ponytail: a nested transaction joins the outer one (no savepoint)
    if (_inTransaction(db)) {
      return await callback();
    }

    /// another transaction can start while we wait, so check again
    while (_transactionDone[db] != null) {
      await _transactionDone[db];
    }
    Completer<void> done = Completer<void>();
    _transactionDone[db] = done.future;

    Set<Database> open = <Database>{...?Zone.current[_txKey], db};
    try {
      /// IMMEDIATE takes the write lock now, so two isolates do not both
      /// read and then fail to upgrade to a write
      db.execute('BEGIN IMMEDIATE');
      R result = await runZoned(
        callback,
        zoneValues: <Symbol, dynamic>{_txKey: open},
      );
      db.execute('COMMIT');
      return result;
    } catch (error) {
      if (!db.autocommit) {
        db.execute('ROLLBACK');
      }
      rethrow;
    } finally {
      _transactionDone[db] = null;
      done.complete();
    }
  }

  /// sqlite gives int, double, String, Uint8List or null. it has no bool,
  /// json or date type, so convert by the declared column type:
  /// BOOLEAN to bool, JSON to map/list, DATE/DATETIME/TIMESTAMP to DateTime.
  List<Map<String, dynamic>> _toMapList(
    Database db,
    String sql,
    ResultSet result,
  ) {
    List<String> names = result.columnNames;
    Map<String, int> kinds = _schemaOf(db).kindsFor(sql);
    List<int> columnKinds = <int>[for (String n in names) kinds[n] ?? 0];
    bool convert = columnKinds.any((int k) => k != 0);
    int length = names.length;

    List<Map<String, dynamic>> list = <Map<String, dynamic>>[];
    for (List<Object?> row in result.rows) {
      Map<String, dynamic> data = <String, dynamic>{};
      for (int i = 0; i < length; i++) {
        Object? value = row[i];
        data[names[i]] = convert && value != null
            ? _convert(columnKinds[i], value)
            : value;
      }
      list.add(data);
    }
    return list;
  }

  dynamic _convert(int kind, Object value) {
    if (kind == _kBool && value is int) {
      return value != 0;
    }
    if (kind == _kJson && value is String) {
      try {
        return jsonDecode(value);
      } catch (error) {
        /// not json, keep the text
        return value;
      }
    }
    if (kind == _kDate && value is String) {
      return parseDbDate(value);
    }
    return value;
  }

  _Schema _schemaOf(Database db) {
    _Schema schema = _schemas[db] ??= _Schema();
    schema.refresh(db);
    return schema;
  }

  static Object? _toSqliteValue(dynamic value) {
    if (value == null || value is int || value is double || value is String) {
      return value;
    } else if (value is bool) {
      return value ? 1 : 0;
    } else if (value is Map || value is List) {
      return jsonEncode(value);
    } else if (value is DateTime) {
      /// ISO text in UTC, so text order is time order
      return value.toUtc().toIso8601String();
    }
    return value.toString();
  }
}

/// declared column kinds of each table, read again when the schema changes
class _Schema {
  int _version = -1;

  /// table name => column name => kind
  Map<String, Map<String, int>> _tables = <String, Map<String, int>>{};

  /// result of [kindsFor] for each sql text
  final Map<String, Map<String, int>> _bySql = <String, Map<String, int>>{};

  PreparedStatement? _versionStatement;

  void refresh(Database db) {
    PreparedStatement statement = _versionStatement ??= db.prepare(
      'PRAGMA schema_version',
      persistent: true,
    );
    int version;
    try {
      version = statement.select().first.columnAt(0) as int;
    } finally {
      statement.reset();
    }
    if (version == _version) {
      return;
    }
    _bySql.clear();
    Map<String, Map<String, int>> tables = <String, Map<String, int>>{};
    ResultSet rows = db.select(
      "SELECT m.name AS t, p.name AS c, p.type AS ty FROM sqlite_schema m "
      "JOIN pragma_table_info(m.name) p WHERE m.type = 'table'",
    );
    for (Row row in rows) {
      int kind = _kindOf((row['ty'] as String).toUpperCase());
      if (kind != 0) {
        (tables[row['t'] as String] ??= <String, int>{})[row['c'] as String] =
            kind;
      }
    }
    _tables = tables;
    _version = version;
  }

  int _kindOf(String type) {
    if (type.contains('BOOL')) return _kBool;
    if (type == 'JSON' || type == 'JSONB') return _kJson;
    if (type.contains('DATE') || type.contains('TIMESTAMP')) return _kDate;
    return 0;
  }

  /// ponytail: sqlite (as bundled) can not tell which table a result column
  /// comes from. so use the typed columns of every table whose name is in
  /// [sql]. an alias or a same-named column of another table may be
  /// converted too, cast in sql if that matters.
  Map<String, int> kindsFor(String sql) {
    Map<String, int>? known = _bySql[sql];
    if (known != null) {
      return known;
    }
    if (_bySql.length >= 2000) {
      _bySql.clear();
    }
    Map<String, int> kinds = _bySql[sql] = <String, int>{};
    for (MapEntry<String, Map<String, int>> table in _tables.entries) {
      if (sql.contains(table.key)) {
        for (MapEntry<String, int> col in table.value.entries) {
          kinds.putIfAbsent(col.key, () => col.value);
        }
      }
    }
    return kinds;
  }
}
