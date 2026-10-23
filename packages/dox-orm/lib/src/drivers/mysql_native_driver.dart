import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dox_mysql_native/dox_mysql_native.dart';
import 'package:dox_orm/dox_orm.dart';

/// zone key to find the open transaction of a pool
const Symbol _txKey = #doxMysqlNativeTransaction;

/// The default Dox ORM driver for MySQL and MariaDB, on [MysqlNativePool]
/// (dox_mysql_native). It acts like the Dart mysql driver (mysql_dart):
/// the same SQL, values and exceptions.
class MysqlNativeDriver extends DBDriver {
  MysqlNativeDriver(this.pool);

  /// Makes the pool from a Dox [ConnectionConfig]. Reads
  /// `maxConnectionCount` (default 10), `maxConnectionAge` (default 12
  /// hours), `preparedStatementCacheSize` (default 100) and `threads`
  /// (default 1) from `extra`. `useSSL` turns on TLS. A host that starts
  /// with `/` is a Unix socket file.
  factory MysqlNativeDriver.fromConfig(ConnectionConfig config) {
    Map<String, dynamic> extra = config.extra;
    return MysqlNativeDriver(
      MysqlNativePool.open(
        host: config.host,
        port: config.port == 0 ? 3306 : config.port,
        user: config.user,
        password: config.password,
        database: config.database,
        secure: config.useSSL,
        maxConnections: extra['maxConnectionCount'] as int? ?? 10,
        maxConnectionAge:
            extra['maxConnectionAge'] as Duration? ?? const Duration(hours: 12),
        statementCacheSize: config.statementCacheSize,
        threads: extra['threads'] as int? ?? 1,
      ),
    );
  }

  final MysqlNativePool pool;

  @override
  Driver getName() => Driver.mysql;

  int get _tx =>
      (Zone.current[_txKey] as Map<MysqlNativePool, int>?)?[pool] ?? 0;

  bool _closed = false;

  /// let go of the pool. isolates with the same settings share one pool,
  /// and it closes when the last one lets go. running queries finish.
  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    pool.close();
  }

  Future<MysqlNativeResult> _run(
    String sql,
    Map<String, dynamic>? values,
    bool rows,
  ) {
    var (String query, List<Object?> params) = toPositionalParams(
      sql,
      values,
      _toMysqlValue,
    );
    return rows
        ? pool.query(query, parameters: params, transaction: _tx)
        : pool.execute(query, parameters: params, transaction: _tx);
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
  }) {
    return _run(query, substitutionValues, false);
  }

  /// one pooled connection runs the whole transaction.
  /// note: in mysql, schema changes (create/alter/drop table) commit the
  /// transaction right away, they can not be rolled back.
  @override
  Future<R> transaction<R>(Future<R> Function() callback) async {
    Map<MysqlNativePool, int>? open =
        Zone.current[_txKey] as Map<MysqlNativePool, int>?;

    /// ponytail: a nested transaction joins the outer one (no savepoint)
    if (open?[pool] != null) {
      return await callback();
    }
    int tx = await pool.begin();
    R result;
    try {
      result = await runZoned(
        callback,
        zoneValues: <Symbol, dynamic>{
          _txKey: <MysqlNativePool, int>{...?open, pool: tx},
        },
      );
    } catch (_) {
      await pool.rollback(tx);
      rethrow;
    }
    await pool.commit(tx);
    return result;
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
