import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dox_orm/dox_orm.dart';
import 'package:dox_postgres_native/dox_postgres_native.dart';

/// zone key to find the open transaction of a pool
const Symbol _txKey = #doxPostgresNativeTransaction;

/// The Dox ORM driver for Postgres, on [PgNativePool]
/// (dox_postgres_native). Errors from the server are [PgServerException],
/// other errors are [PgException].
class PostgresNativeDriver extends DBDriver {
  PostgresNativeDriver(this.pool);

  /// Makes the pool from a Dox [ConnectionConfig]. A host that starts with
  /// `/` is a Unix socket folder. The TLS mode is
  /// [ConnectionConfig.postgresSslMode]. Reads `maxConnectionCount`
  /// (default 10), `timeZone` (default UTC), `applicationName` and
  /// `threads` (default 1) from `extra`. Isolates with the same settings
  /// share one pool, so `maxConnectionCount` is for the whole process.
  /// Throws an [UnsupportedError] when the native library does not load.
  factory PostgresNativeDriver.fromConfig(ConnectionConfig config) {
    NativeDrivers.ensureAvailable(Driver.postgres);
    Map<String, dynamic> extra = config.extra;
    return PostgresNativeDriver(
      PgNativePool.open(
        // a Unix socket is a folder, like libpq. Drop the file name when
        // it is given, eg. `/cloudsql/p:r:i/.s.PGSQL.5432`.
        host: config.host.replaceFirst(RegExp(r'/\.s\.PGSQL\.\d+$'), ''),
        port: config.port == 0 ? 5432 : config.port,
        user: config.user,
        password: config.password,
        database: config.database,
        sslMode: config.postgresSslMode,
        maxConnections: extra['maxConnectionCount'] as int? ?? 10,
        timeZone: extra['timeZone'] as String? ?? 'UTC',
        applicationName: extra['applicationName'] as String?,
        threads: extra['threads'] as int? ?? 1,
      ),
    );
  }

  final PgNativePool pool;

  @override
  Driver getName() => Driver.postgres;

  @override
  bool get supportsReturning => true;

  /// a list goes into a json column, so it is sent as json text. bytes
  /// (Uint8List) stay bytes. where-in lists do not come here, they are
  /// arrays.
  @override
  Object? columnValue(dynamic value) =>
      value is List && value is! Uint8List ? jsonEncode(value) : value;

  int get _tx => (Zone.current[_txKey] as Map<PgNativePool, int>?)?[pool] ?? 0;

  bool _closed = false;

  /// let go of the pool. isolates with the same settings share one pool,
  /// and it closes when the last one lets go. running queries finish.
  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    pool.close();
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String query, {
    String? primaryKey,
    Map<String, dynamic>? substitutionValues,
  }) {
    // no async/await here: one `then` is less work per query
    return pool
        .query(query, parameters: substitutionValues, transaction: _tx)
        .then(_rows);
  }

  static List<Map<String, dynamic>> _rows(PgNativeResult result) => result.rows;

  @override
  Future<void> execute(
    String query, {
    Map<String, dynamic>? substitutionValues,
  }) {
    return pool.query(query, parameters: substitutionValues, transaction: _tx);
  }

  @override
  Future<R> transaction<R>(Future<R> Function() callback) async {
    Map<PgNativePool, int>? open =
        Zone.current[_txKey] as Map<PgNativePool, int>?;

    /// a nested transaction uses a savepoint on the same connection
    if (open?[pool] != null) {
      return savepoint(callback);
    }
    int tx = await pool.begin();
    R result;
    try {
      result = await runZoned(
        callback,
        zoneValues: <Symbol, dynamic>{
          _txKey: <PgNativePool, int>{...?open, pool: tx},
        },
      );
    } catch (_) {
      try {
        await pool.rollback(tx);
      } catch (_) {
        // keep the first error: it tells what went wrong
      }
      rethrow;
    }
    await pool.commit(tx);
    return result;
  }
}
