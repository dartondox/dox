import 'dart:async';

import 'package:dox_orm/dox_orm.dart';
import 'package:postgres/postgres.dart';

/// zone key to find the open transaction of a connection
const Symbol _txKey = #doxPostgresTransaction;

/// driver for postgres SQL
/// support postgres `Connection` and `Pool`
///
/// each pooled connection keeps its prepared statements by sql text
/// (LRU, see [statementCacheSize]), so postgres parses a query once per
/// connection, not on every call.
class PostgresDriver extends DBDriver {
  dynamic conn;

  /// max prepared statements kept per connection
  final int statementCacheSize;

  /// constructor
  PostgresDriver({
    required this.conn,
    this.statementCacheSize = defaultStatementCacheSize,
  });

  /// statement cache of each connection
  static final Expando<StatementCache<Statement>> _caches =
      Expando<StatementCache<Statement>>();

  /// schema version each cache was made for
  static final Expando<int> _cacheVersions = Expando<int>();

  /// goes up when this isolate runs a query that is not
  /// select/insert/update/delete (eg. create or alter table). old statements
  /// may then have the wrong columns, so the caches start again.
  static int _schemaVersion = 0;

  @override
  Driver getName() {
    return Driver.postgres;
  }

  @override
  bool get supportsReturning => true;

  /// the statement cache of [connection] (a pooled `Connection`), or null
  /// when it has none yet
  StatementCache<Statement>? statementCacheOf(Object connection) {
    return _caches[connection];
  }

  /// `Connection` or `Pool`, both can run queries and transactions
  Future<dynamic> _getConnection() async {
    /// if connection is future, we need to connect first.
    /// the connection is kept on this driver, so each named connection
    /// keeps its own database connection.
    if (conn is Future) {
      conn = await conn;
    }
    return conn;
  }

  /// close the connection or the pool. a connect that failed has nothing
  /// to close.
  @override
  Future<void> close() async {
    Object? c = conn;
    conn = null;
    try {
      if (c is Future) c = await c;
    } catch (_) {
      return;
    }
    if (c is Pool) {
      await c.close();
    } else if (c is Connection) {
      await c.close();
    }
  }

  /// run query and return map result
  @override
  Future<List<Map<String, dynamic>>> query(
    String query, {
    String? primaryKey,
    Map<String, dynamic>? substitutionValues,
  }) async {
    Result result = await _internalQuery(query, substitutionValues);
    return result.toMapList();
  }

  /// only run query
  @override
  Future<void> execute(
    String query, {
    Map<String, dynamic>? substitutionValues,
  }) async {
    await _internalQuery(query, substitutionValues);
  }

  @override
  Future<R> transaction<R>(Future<R> Function() callback) async {
    dynamic c = conn is Future ? await _getConnection() : conn;
    Map<dynamic, _Tx>? open = Zone.current[_txKey];

    /// ponytail: a nested transaction joins the outer one (no savepoint)
    if (open?[c] != null) {
      return await callback();
    }
    if (c is Pool) {
      return await c.withConnection((Connection cn) {
        return _runTx(c, cn, open, callback);
      });
    }
    return await _runTx(c, c as Connection, open, callback);
  }

  Future<R> _runTx<R>(
    Object c,
    Connection cn,
    Map<dynamic, _Tx>? open,
    Future<R> Function() callback,
  ) {
    return cn.runTx((TxSession session) {
      return runZoned(
        callback,
        zoneValues: <Symbol, dynamic>{
          _txKey: <dynamic, _Tx>{...?open, c: _Tx(cn, session)},
        },
      );
    });
  }

  /// run query in the open transaction if any, else on the connection/pool
  Future<Result> _internalQuery(
    String query,
    Map<String, dynamic>? values,
  ) async {
    dynamic c = conn is Future ? await _getConnection() : conn;
    _Tx? tx = Zone.current[_txKey]?[c];
    _PgQuery q = _PgQuery.of(query);
    List<Object?>? params = q.params(values);

    /// a name we can not bind by position: let the postgres package do it
    /// create/alter/drop... are not kept. when they end, the kept
    /// statements are dropped, because a table may have changed.
    if (params == null || !q.dml) {
      Session session = tx?.session ?? c;
      try {
        return params == null
            ? await session.execute(Sql.named(query), parameters: values)
            : await session.execute(Sql(q.sql), parameters: params);
      } finally {
        if (!q.dml) _schemaVersion++;
      }
    }
    if (tx != null) {
      /// a statement can not be prepared on the connection while a
      /// transaction is open, but a kept one can run in it
      Statement? statement = _cacheOf(tx.connection).get(q.sql);
      if (statement != null) {
        return await statement.run(params);
      }
      return await tx.session.execute(Sql(q.sql), parameters: params);
    }
    if (c is Pool) {
      return await c.withConnection((Connection cn) {
        return _runCached(cn, q.sql, params);
      });
    }
    if (c is Connection) {
      return await _runCached(c, q.sql, params);
    }
    return await (c as Session).execute(Sql(q.sql), parameters: params);
  }

  /// run [sql] with the kept statement of [cn], prepare it once if needed
  Future<Result> _runCached(
    Connection cn,
    String sql,
    List<Object?> params,
  ) async {
    StatementCache<Statement> cache = _cacheOf(cn);
    Statement statement = cache.get(sql) ?? await _prepare(cn, cache, sql);
    try {
      return await statement.run(params);
    } on PgException catch (error) {
      /// the table changed (eg. by another app) and the old statement
      /// gives other columns. prepare it again and run once more.
      if (!error.message.contains('cached plan must not change result')) {
        rethrow;
      }
      cache.remove(sql);
      await _dispose(statement);
      statement = await _prepare(cn, cache, sql);
      return await statement.run(params);
    }
  }

  Future<Statement> _prepare(
    Connection cn,
    StatementCache<Statement> cache,
    String sql,
  ) async {
    Statement statement = await cn.prepare(Sql(sql));
    Statement? old = cache.put(sql, statement);
    if (old != null) {
      await _dispose(old);
    }
    return statement;
  }

  /// cache of [cn]. a new one after a schema change.
  StatementCache<Statement> _cacheOf(Connection cn) {
    StatementCache<Statement>? cache = _caches[cn];
    if (cache != null && _cacheVersions[cn] == _schemaVersion) {
      return cache;
    }
    if (cache != null) {
      for (Statement old in cache.clear()) {
        unawaited(_dispose(old));
      }
    } else {
      /// the connection is lost or closed: its statements are gone too
      cn.closed.catchError(_ignore).whenComplete(_forget(cn));
    }
    cache = StatementCache<Statement>(statementCacheSize);
    _caches[cn] = cache;
    _cacheVersions[cn] = _schemaVersion;
    return cache;
  }

  void Function() _forget(Connection cn) {
    return () {
      _caches[cn]?.clear();
      _caches[cn] = null;
    };
  }

  static void _ignore(Object error) {}

  /// close a statement on the server. an error is not important here,
  /// eg. the connection is already closed.
  Future<void> _dispose(Statement statement) async {
    try {
      await statement.dispose();
    } catch (_) {}
  }
}

/// an open transaction: its connection and its session
class _Tx {
  final Connection connection;
  final TxSession session;
  _Tx(this.connection, this.session);
}

/// a query with `@name` params changed to `$1, $2...`, made once per sql
/// text
class _PgQuery {
  /// sql with `$n` params. it is the original sql when [names] is null.
  final String sql;

  /// param name of each `$n` (n - 1 is the index), or null when the sql
  /// has something this simple parser does not handle. then the postgres
  /// package parses it (`Sql.named`).
  final List<String>? names;

  /// select, insert, update, delete or with
  final bool dml;

  _PgQuery(this.sql, this.names, this.dml);

  /// ponytail: cleared when full, an LRU is not needed for sql texts
  static final Map<String, _PgQuery> _cache = <String, _PgQuery>{};

  static final RegExp _dmlPattern = RegExp(
    r'^\s*(select|insert|update|delete|with)\b',
    caseSensitive: false,
  );

  static _PgQuery of(String sql) {
    _PgQuery? q = _cache[sql];
    if (q != null) {
      return q;
    }
    if (_cache.length >= 2000) {
      _cache.clear();
    }
    return _cache[sql] = _parse(sql);
  }

  /// values in `$n` order, or null when a name has no value (the postgres
  /// package then gives the error) or the sql could not be parsed
  List<Object?>? params(Map<String, dynamic>? values) {
    List<String>? keys = names;
    if (keys == null) {
      return null;
    }
    if (keys.isEmpty) {
      return const <Object?>[];
    }
    if (values == null) {
      return null;
    }
    List<Object?> list = List<Object?>.filled(keys.length, null);
    for (int i = 0; i < keys.length; i++) {
      Object? value = values[keys[i]];
      if (value == null && !values.containsKey(keys[i])) {
        return null;
      }
      list[i] = value;
    }
    return list;
  }

  static _PgQuery _parse(String sql) {
    bool dml = _dmlPattern.hasMatch(sql);
    StringBuffer out = StringBuffer();
    List<String> names = <String>[];
    int length = sql.length;
    int i = 0;
    while (i < length) {
      int char = sql.codeUnitAt(i);

      /// 'text' and "name": copy as they are
      if (char == _quote || char == _doubleQuote) {
        int end = sql.indexOf(String.fromCharCode(char), i + 1);
        if (end < 0) {
          return _PgQuery(sql, null, dml);
        }
        String part = sql.substring(i, end + 1);

        /// E'..' strings can escape a quote with a backslash
        if (part.contains(r'\')) {
          return _PgQuery(sql, null, dml);
        }
        out.write(part);
        i = end + 1;
        continue;
      }

      /// $1, $$ text $$, comments: leave them to the postgres package
      if (char == _dollar ||
          (char == _dash && _at(sql, i + 1) == _dash) ||
          (char == _slash && _at(sql, i + 1) == _star)) {
        return _PgQuery(sql, null, dml);
      }
      if (char == _atSign && _isWord(_at(sql, i + 1))) {
        int end = i + 1;
        while (end < length && _isWord(sql.codeUnitAt(end))) {
          end++;
        }

        /// @name:type is a typed param of the postgres package
        if (_at(sql, end) == _colon && _at(sql, end + 1) != _colon) {
          return _PgQuery(sql, null, dml);
        }
        String name = sql.substring(i + 1, end);
        int index = names.indexOf(name);
        if (index < 0) {
          names.add(name);
          index = names.length - 1;
        }
        out.write('\$${index + 1}');
        i = end;
        continue;
      }
      out.writeCharCode(char);
      i++;
    }
    return _PgQuery(out.toString(), names, dml);
  }

  static int _at(String s, int i) => i < s.length ? s.codeUnitAt(i) : -1;

  static bool _isWord(int c) {
    return (c >= 0x30 && c <= 0x39) ||
        (c >= 0x41 && c <= 0x5a) ||
        (c >= 0x61 && c <= 0x7a) ||
        c == 0x5f;
  }

  static const int _quote = 0x27;
  static const int _doubleQuote = 0x22;
  static const int _dollar = 0x24;
  static const int _dash = 0x2d;
  static const int _slash = 0x2f;
  static const int _star = 0x2a;
  static const int _atSign = 0x40;
  static const int _colon = 0x3a;
}

/// extension on postgres
extension ToMapList on Result {
  List<Map<String, dynamic>> toMapList() {
    return map((ResultRow element) => element.toColumnMap()).toList();
  }
}
