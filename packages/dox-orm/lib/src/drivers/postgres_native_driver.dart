import 'dart:async';

import 'package:dox_orm/dox_orm.dart';
import 'package:dox_postgres_native/dox_postgres_native.dart';

/// zone key to find the open transaction of a pool
const Symbol _txKey = #doxPostgresNativeTransaction;

/// The default Dox ORM driver for Postgres, on [PgNativePool]
/// (dox_postgres_native). It acts like the Dart postgres driver: the same
/// SQL, values and exceptions.
class PostgresNativeDriver extends DBDriver {
  PostgresNativeDriver(this.pool);

  /// Makes the pool from a Dox [ConnectionConfig]. A host that starts with
  /// `/` is a Unix socket folder. Reads `maxConnectionCount`
  /// (default 10), `timeZone` (default UTC), `applicationName` and
  /// `threads` (default 1) from `extra`.
  factory PostgresNativeDriver.fromConfig(ConnectionConfig config) {
    if (config.useSSL) {
      // ponytail: no TLS yet. Add tokio-postgres-rustls when it is needed.
      throw UnsupportedError('dox_postgres_native does not support SSL yet');
    }
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

  int get _tx => (Zone.current[_txKey] as Map<PgNativePool, int>?)?[pool] ?? 0;

  bool _closed = false;

  /// close the pool of this driver. running queries finish first.
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
          _txKey: <PgNativePool, int>{...?open, pool: tx},
        },
      );
    } catch (_) {
      await pool.rollback(tx);
      rethrow;
    }
    await pool.commit(tx);
    return result;
  }
}
