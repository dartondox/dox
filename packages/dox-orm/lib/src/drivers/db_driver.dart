import 'dart:async';

import 'package:dox_mysql_native/dox_mysql_native.dart';
import 'package:dox_orm/dox_orm.dart';
import 'package:dox_orm/src/drivers/sqlite_driver.dart';
import 'package:dox_postgres_native/dox_postgres_native.dart';

enum Driver { postgres, mysql, sqlite }

/// interface for database driver
abstract class DBDriver {
  Driver getName();

  /// true when insert can use `RETURNING` to get the new id
  bool get supportsReturning => false;

  /// [value] as it goes into a column on insert or update. postgres
  /// changes a [List] to json text, because it sends a list as an array.
  Object? columnValue(dynamic value) => value;

  /// run query and return map result
  Future<List<Map<String, dynamic>>> query(
    String query, {
    String? primaryKey,
    Map<String, dynamic>? substitutionValues,
  });

  /// run query, this function do not return any value
  Future<void> execute(
    String query, {
    Map<String, dynamic>? substitutionValues,
  });

  /// run [callback] in one database transaction.
  /// commit when it ends, rollback when it throws.
  /// all queries inside [callback] (models too) use the transaction.
  /// inside another transaction it uses a savepoint, see [savepoint].
  Future<R> transaction<R>(Future<R> Function() callback);

  /// zone key for how deep the savepoints are
  static const Symbol _savepointKey = #doxSavepointDepth;

  /// run [callback] in a savepoint of the open transaction. the drivers
  /// call it for a nested [transaction]. when [callback] throws, only its
  /// work is undone and the error is thrown again. the outer transaction
  /// stays open, so the caller can catch the error and go on.
  ///
  /// ponytail: one savepoint at a time per transaction. two nested
  /// transactions that run at the same time (eg. in `Future.wait`) mix up
  /// their savepoints, the same as any queries on one connection.
  Future<R> savepoint<R>(Future<R> Function() callback) async {
    int depth = (Zone.current[_savepointKey] as int? ?? 0) + 1;
    String name = 'sp_$depth';
    await execute('SAVEPOINT $name');
    R result;
    try {
      result = await runZoned(
        callback,
        zoneValues: <Symbol, dynamic>{_savepointKey: depth},
      );
    } catch (_) {
      try {
        await execute('ROLLBACK TO SAVEPOINT $name');
      } catch (_) {
        // keep the first error: it tells what went wrong
      }
      rethrow;
    }
    await execute('RELEASE SAVEPOINT $name');
    return result;
  }

  /// close the connections of this driver. it is safe to call it twice.
  /// do not run queries on this driver after it.
  Future<void> close() async {}

  /// zone keys the drivers use for an open transaction
  static const List<Symbol> _transactionKeys = <Symbol>[
    #doxPostgresNativeTransaction,
    #doxMysqlNativeTransaction,
    #doxSqliteTransaction,
  ];

  /// true when this code runs inside a transaction of any driver
  static bool get inTransaction {
    for (Symbol key in _transactionKeys) {
      if (Zone.current[key] != null) return true;
    }
    return false;
  }

  /// quote a table or column name, `"name"` on postgres and sqlite and
  /// `` `name` `` on mysql. it handles `table.column`, `table.*`, `*` and
  /// `column as alias`. anything else (eg. `count(*)`) throws an
  /// [ArgumentError], so user input can not add sql. use the raw methods,
  /// like `selectRaw()` or `orderByRaw()`, for expressions.
  String wrap(String value) {
    String? known = _wrapped[value];
    if (known != null) {
      return known;
    }

    /// ponytail: cleared when full, names are a small set
    if (_wrapped.length >= 1000) {
      _wrapped.clear();
    }
    return _wrapped[value] = _wrap(value);
  }

  /// quoted names, made once
  final Map<String, String> _wrapped = <String, String>{};

  String _wrap(String value) {
    value = value.trim();
    if (!_namePattern.hasMatch(value)) {
      throw ArgumentError.value(value, 'name', 'is not a plain column name');
    }
    List<String> alias = value.split(_aliasPattern);
    if (alias.length == 2) {
      return '${wrap(alias[0])} as ${_wrapPart(alias[1].trim())}';
    }
    return value.split('.').map(_wrapPart).join('.');
  }

  /// `name`, `table.name`, `table.*`, `*` and `name as alias`
  static final RegExp _namePattern = RegExp(
    r'^(?:[\p{L}\p{N}_$]+\.)*(?:[\p{L}\p{N}_$]+|\*)(?:\s+as\s+[\p{L}\p{N}_$]+)?$',
    caseSensitive: false,
    unicode: true,
  );

  static final RegExp _aliasPattern = RegExp(r'\s+as\s+', caseSensitive: false);

  String _wrapPart(String part) {
    if (part == '*') {
      return part;
    }
    String q = getName() == Driver.mysql ? '`' : '"';
    return '$q${part.replaceAll(q, '$q$q')}$q';
  }
}

/// get database driver to run queries on [database]: a [PgNativePool] for
/// postgres, a [MysqlNativePool] for mysql, or a sqlite `Database` (or a
/// `Future` of it) for sqlite.
/// [statementCacheSize] is the max prepared statements kept (sqlite).
DBDriver getDatabaseDriver(
  Driver driver,
  dynamic database, {
  int statementCacheSize = defaultStatementCacheSize,
}) {
  if (driver == Driver.postgres) {
    return PostgresNativeDriver(database as PgNativePool);
  } else if (driver == Driver.mysql) {
    return MysqlNativeDriver(database as MysqlNativePool);
  } else if (driver == Driver.sqlite) {
    return SqliteDriver(conn: database, statementCacheSize: statementCacheSize);
  }
  throw Exception('Invalid driver or not supported');
}

/// mysql and sqlite use `?` placeholders. replace each known `@key` in the
/// order it shows in [sql], and add its value (after [convert]) in the same
/// order. unknown `@word` (eg. 'a@b.com' inside a string) is kept as it is.
(String, List<Object?>) toPositionalParams(
  String sql,
  Map<String, dynamic>? values,
  Object? Function(dynamic value) convert,
) {
  if (values == null || values.isEmpty) {
    return (sql, <Object?>[]);
  }

  /// fast path: the sql was seen before and every `@key` has a value
  _QuestionSql q = _QuestionSql.of(sql);
  List<String> names = q.names;
  List<Object?> params = List<Object?>.filled(names.length, null);
  for (int i = 0; i < names.length; i++) {
    String key = names[i];
    dynamic value = values[key];
    if (value == null && !values.containsKey(key)) {
      return _toPositionalSlow(sql, values, convert);
    }
    params[i] = convert(value);
  }
  return (q.sql, params);
}

(String, List<Object?>) _toPositionalSlow(
  String sql,
  Map<String, dynamic> values,
  Object? Function(dynamic value) convert,
) {
  List<Object?> params = <Object?>[];
  sql = sql.replaceAllMapped(_paramPattern, (Match m) {
    String key = m.group(1)!;
    if (!values.containsKey(key)) {
      return m.group(0)!;
    }
    params.add(convert(values[key]));
    return '?';
  });
  return (sql, params);
}

final RegExp _paramPattern = RegExp(r'@(\w+)');

/// sql with every `@key` changed to `?`, made once per sql text
class _QuestionSql {
  final String sql;

  /// key of each `?`, in order
  final List<String> names;

  _QuestionSql(this.sql, this.names);

  /// ponytail: cleared when full, an LRU is not needed for sql texts
  static final Map<String, _QuestionSql> _cache = <String, _QuestionSql>{};

  static _QuestionSql of(String sql) {
    _QuestionSql? q = _cache[sql];
    if (q != null) {
      return q;
    }
    if (_cache.length >= 2000) {
      _cache.clear();
    }
    List<String> names = <String>[];
    String converted = sql.replaceAllMapped(_paramPattern, (Match m) {
      names.add(m.group(1)!);
      return '?';
    });
    return _cache[sql] = _QuestionSql(converted, names);
  }
}

/// parse a date from mysql or sqlite. a date without time zone is read as
/// UTC. return [value] as it is when it is not a date.
dynamic parseDbDate(dynamic value) {
  DateTime? d = value is DateTime ? value : DateTime.tryParse('$value');
  if (d == null || d.isUtc) {
    return d ?? value;
  }
  return DateTime.utc(
    d.year,
    d.month,
    d.day,
    d.hour,
    d.minute,
    d.second,
    d.millisecond,
    d.microsecond,
  );
}
