import 'package:dox_orm/dox_orm.dart';
import 'package:dox_orm/src/drivers/mysql_driver.dart';
import 'package:dox_orm/src/drivers/sqlite_driver.dart';

enum Driver { postgres, mysql, sqlite }

/// interface for database driver
abstract class DBDriver {
  Driver getName();

  /// true when insert can use `RETURNING` to get the new id
  bool get supportsReturning => false;

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
  Future<R> transaction<R>(Future<R> Function() callback);

  /// quote a table or column name, `"name"` on postgres and sqlite and
  /// `` `name` `` on mysql. it handles `table.column`, `*` and `column as alias`.
  /// a value with `(` is a raw expression and is not changed.
  String wrap(String value) {
    value = value.trim();
    if (value.contains('(')) {
      return value;
    }
    List<String> alias = value.split(RegExp(r'\s+as\s+', caseSensitive: false));
    if (alias.length == 2) {
      return '${wrap(alias[0])} as ${_wrapPart(alias[1].trim())}';
    }
    return value.split('.').map(_wrapPart).join('.');
  }

  String _wrapPart(String part) {
    if (part == '*') {
      return part;
    }
    String q = getName() == Driver.mysql ? '`' : '"';
    return '$q${part.replaceAll(q, '$q$q')}$q';
  }
}

/// get database driver to run queries.
/// [statementCacheSize] is the max prepared statements kept per connection.
DBDriver getDatabaseDriver(
  Driver driver,
  dynamic database, {
  int statementCacheSize = defaultStatementCacheSize,
}) {
  if (driver == Driver.postgres) {
    return PostgresDriver(
      conn: database,
      statementCacheSize: statementCacheSize,
    );
  } else if (driver == Driver.mysql) {
    return MysqlDriver(conn: database);
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
