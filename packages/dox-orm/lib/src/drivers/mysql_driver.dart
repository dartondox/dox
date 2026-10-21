import 'dart:async';
import 'dart:convert';

import 'package:dox_orm/dox_orm.dart';
import 'package:mysql_dart/mysql_dart.dart';
import 'package:mysql_dart/mysql_protocol.dart';

/// zone key to find the connections that have an open transaction
const Symbol _txKey = #doxMysqlTransaction;

/// driver for mysql and mariadb, uses a `MySQLConnectionPool`.
/// values are sent as bound params of prepared statements.
class MysqlDriver extends DBDriver {
  dynamic conn;

  /// constructor
  MysqlDriver({required this.conn});

  /// true when the server is mariadb, saved per pool
  static final Expando<bool> _isMariaDb = Expando<bool>();

  @override
  Driver getName() {
    return Driver.mysql;
  }

  Future<MySQLConnectionPool> _getPool() async {
    /// if connection is future, we need to connect first.
    /// the pool is kept on this driver, so each named connection
    /// keeps its own pool.
    if (conn is Future) {
      conn = await conn;
    }
    MySQLConnectionPool pool = conn;
    if (_isMariaDb[pool] == null) {
      IResultSet version = await pool.execute('SELECT VERSION()');
      _isMariaDb[pool] = version.rows.first
          .colAt(0)
          .toString()
          .contains('MariaDB');
    }
    return pool;
  }

  /// run [sql] in the open transaction if any, else on a free pooled
  /// connection
  Future<IResultSet> _run(String sql, Map<String, dynamic>? values) async {
    MySQLConnectionPool pool = await _getPool();
    var (String query, List<Object?> params) = toPositionalParams(
      sql,
      values,
      _toMysqlValue,
    );

    /// no params: text protocol, one round trip.
    /// params: prepared statement (cached per connection by the driver).
    Object? args = params.isEmpty ? null : params;
    MySQLConnection? tx = Zone.current[_txKey]?[pool];
    if (tx != null) {
      return await tx.execute(query, args);
    }
    return await pool.withConnection((MySQLConnection c) {
      return c.execute(query, args);
    });
  }

  /// run query and return map result
  @override
  Future<List<Map<String, dynamic>>> query(
    String query, {
    String? primaryKey,
    Map<String, dynamic>? substitutionValues,
  }) async {
    IResultSet result = await _run(query, substitutionValues);

    /// insert query returns the new auto increment id
    if (result.numOfColumns == 0) {
      int id = result.lastInsertID.toInt();
      if (id > 0 && primaryKey != null) {
        return <Map<String, dynamic>>[
          <String, dynamic>{primaryKey: id},
        ];
      }
      return <Map<String, dynamic>>[];
    }
    return _toMapList(result, _isMariaDb[conn] ?? false);
  }

  /// only run query
  @override
  Future<void> execute(
    String query, {
    Map<String, dynamic>? substitutionValues,
  }) async {
    await _run(query, substitutionValues);
  }

  /// one pooled connection runs the whole transaction. other queries use
  /// other connections of the pool.
  /// note: in mysql, schema changes (create/alter/drop table) commit the
  /// transaction right away, they can not be rolled back.
  @override
  Future<R> transaction<R>(Future<R> Function() callback) async {
    MySQLConnectionPool pool = await _getPool();
    Map<dynamic, MySQLConnection>? open = Zone.current[_txKey];

    /// ponytail: a nested transaction joins the outer one (no savepoint)
    if (open?[pool] != null) {
      return await callback();
    }
    return await pool.withConnection((MySQLConnection c) {
      return c.transactional((MySQLConnection tx) {
        return runZoned(
          callback,
          zoneValues: <Symbol, dynamic>{
            _txKey: <dynamic, MySQLConnection>{...?open, pool: tx},
          },
        );
      });
    });
  }

  /// convert each value by its column type.
  /// - TINYINT(1) (used by boolean()) is bool.
  /// - mysql: only JSON columns are decoded (objects and arrays).
  /// - mariadb: JSON is a LONGTEXT column, so the type is unknown.
  ///   text that starts with `{` or `[` and is valid json is decoded.
  /// - DATE, DATETIME and TIMESTAMP are DateTime in UTC.
  /// - DECIMAL is double.
  List<Map<String, dynamic>> _toMapList(IResultSet result, bool isMariaDb) {
    List<ResultSetColumn> cols = result.cols.toList();
    List<String> names = <String>[for (ResultSetColumn c in cols) c.name];
    List<int> types = <int>[for (ResultSetColumn c in cols) _kindOf(c)];
    int length = cols.length;

    List<Map<String, dynamic>> list = <Map<String, dynamic>>[];
    for (ResultSetRow row in result.rows) {
      Map<String, dynamic> data = <String, dynamic>{};
      for (int i = 0; i < length; i++) {
        dynamic value = row.colAt(i);
        data[names[i]] = value == null
            ? null
            : _convert(types[i], value, isMariaDb);
      }
      list.add(data);
    }
    return list;
  }

  static const int _kText = 0;
  static const int _kBool = 1;
  static const int _kInt = 2;
  static const int _kDouble = 3;
  static const int _kDate = 4;
  static const int _kJson = 5;
  static const int _kLongText = 6;

  int _kindOf(ResultSetColumn col) {
    switch (col.type.intVal) {
      case mysqlColumnTypeTiny:
        return col.length == 1 ? _kBool : _kInt;
      case mysqlColumnTypeShort:
      case mysqlColumnTypeLong:
      case mysqlColumnTypeLongLong:
      case mysqlColumnTypeInt24:
      case mysqlColumnTypeYear:
        return _kInt;
      case mysqlColumnTypeFloat:
      case mysqlColumnTypeDouble:
      case mysqlColumnTypeDecimal:
      case mysqlColumnTypeNewDecimal:
        return _kDouble;
      case mysqlColumnTypeDate:
      case mysqlColumnTypeNewDate:
      case mysqlColumnTypeDateTime:
      case mysqlColumnTypeDateTime2:
      case mysqlColumnTypeTimestamp:
      case mysqlColumnTypeTimestamp2:
        return _kDate;
      case mysqlColumnTypeJson:
        return _kJson;
      case mysqlColumnTypeBlob:
      case mysqlColumnTypeLongBlob:
      case mysqlColumnTypeMediumBlob:
      case mysqlColumnTypeTinyBlob:
        return _kLongText;
      default:
        return _kText;
    }
  }

  dynamic _convert(int kind, dynamic value, bool isMariaDb) {
    switch (kind) {
      case _kBool:
        return value is bool ? value : value.toString() != '0';
      case _kInt:
        return value is int ? value : int.tryParse(value.toString()) ?? value;
      case _kDouble:
        return value is double
            ? value
            : double.tryParse(value.toString()) ?? value;
      case _kDate:

        /// mysql has no time zone in DATETIME, read it as UTC
        return parseDbDate(value);
      case _kJson:
        return value is String ? jsonDecode(value) : value;
      case _kLongText:
        if (isMariaDb && value is String && _looksLikeJson(value)) {
          try {
            return jsonDecode(value);
          } catch (error) {
            /// not json, keep the text
          }
        }
        return value;
    }
    return value;
  }

  bool _looksLikeJson(String value) {
    String text = value.trimLeft();
    return text.startsWith('{') || text.startsWith('[');
  }

  static Object? _toMysqlValue(dynamic value) {
    if (value == null || value is int || value is double) {
      return value;
    } else if (value is bool) {
      return value ? 1 : 0;
    } else if (value is Map || value is List) {
      return jsonEncode(value);
    } else if (value is DateTime) {
      return value.toIso8601String().split('.').first;
    }
    String text = value.toString();

    /// iso date string with `Z` (eg. from model timestamps), mysql
    /// DATETIME do not accept the `Z`
    if (text.endsWith('Z')) {
      DateTime? date = DateTime.tryParse(text);
      if (date != null) {
        return date.toIso8601String().split('.').first;
      }
    }
    return text;
  }
}
