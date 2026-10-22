import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dox_mysql_native/src/pool.dart';
import 'package:dox_orm/dox_orm.dart';

/// zone key to find the open transactions
const Symbol _txKey = #doxMysqlNativeTransaction;

/// Dox ORM driver for MySQL and MariaDB on [MysqlNativePool].
/// It returns the same types as the Dart driver (mysql_dart) of dox_orm.
class MysqlNativeDriver extends DBDriver {
  /// connect lazily with the settings of [config]:
  /// host, port, user, password, database, useSSL and the `extra` keys
  /// `maxConnectionCount`, `maxConnectionAge` and
  /// `preparedStatementCacheSize`.
  MysqlNativeDriver(ConnectionConfig config) : _config = config;

  /// use a pool that is already open
  MysqlNativeDriver.withPool(MysqlNativePool pool)
    : _config = null,
      _ready = pool;

  final ConnectionConfig? _config;
  MysqlNativePool? _ready;
  Future<MysqlNativePool>? _opening;

  @override
  Driver getName() => Driver.mysql;

  /// the pool, opened on the first query
  Future<MysqlNativePool> get pool async {
    MysqlNativePool? ready = _ready;
    if (ready != null) return ready;
    return _ready = await (_opening ??= _open());
  }

  Future<MysqlNativePool> _open() {
    ConnectionConfig c = _config!;
    Map<String, dynamic> extra = c.extra;
    return MysqlNativePool.connect(
      host: c.host,
      port: c.port == 0 ? 3306 : c.port,
      user: c.user,
      password: c.password,
      database: c.database,
      secure: c.useSSL,
      maxConnections: extra['maxConnectionCount'] as int? ?? 10,
      maxConnectionAge:
          extra['maxConnectionAge'] as Duration? ?? const Duration(hours: 12),
      statementCacheSize: extra['preparedStatementCacheSize'] as int? ?? 32,
    );
  }

  Future<MysqlNativeResult> _run(
    String sql,
    Map<String, dynamic>? values,
    bool rows,
  ) async {
    MysqlNativePool p = _ready ?? await pool;
    var (String query, List<Object?> params) = toPositionalParams(
      sql,
      values,
      _toMysqlValue,
    );
    MysqlNativeTransaction? tx = _openTx()?[p];
    if (tx != null) {
      return rows ? tx.query(query, params) : tx.execute(query, params);
    }
    return rows ? p.query(query, params) : p.execute(query, params);
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String query, {
    String? primaryKey,
    Map<String, dynamic>? substitutionValues,
  }) async {
    MysqlNativeResult result = await _run(query, substitutionValues, true);

    /// insert query returns the new auto increment id
    if (result.columns.isEmpty) {
      if (result.insertId > 0 && primaryKey != null) {
        return <Map<String, dynamic>>[
          <String, dynamic>{primaryKey: result.insertId},
        ];
      }
      return <Map<String, dynamic>>[];
    }
    return result.rows;
  }

  @override
  Future<void> execute(
    String query, {
    Map<String, dynamic>? substitutionValues,
  }) async {
    await _run(query, substitutionValues, false);
  }

  /// one pooled connection runs the whole transaction.
  /// note: in mysql, schema changes (create/alter/drop table) commit the
  /// transaction right away, they can not be rolled back.
  @override
  Future<R> transaction<R>(Future<R> Function() callback) async {
    MysqlNativePool p = await pool;
    Map<dynamic, MysqlNativeTransaction>? open = _openTx();

    /// ponytail: a nested transaction joins the outer one (no savepoint)
    if (open?[p] != null) {
      return await callback();
    }
    return p.transaction((MysqlNativeTransaction tx) {
      return runZoned(
        callback,
        zoneValues: <Symbol, dynamic>{
          _txKey: <dynamic, MysqlNativeTransaction>{...?open, p: tx},
        },
      );
    });
  }

  static Map<dynamic, MysqlNativeTransaction>? _openTx() {
    return Zone.current[_txKey] as Map<dynamic, MysqlNativeTransaction>?;
  }

  /// same as the mysql_dart driver of dox_orm
  static Object? _toMysqlValue(dynamic value) {
    if (value == null ||
        value is int ||
        value is double ||
        value is Uint8List) {
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
