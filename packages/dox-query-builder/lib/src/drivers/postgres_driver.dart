import 'dart:async';

import 'package:dox_query_builder/dox_query_builder.dart';
import 'package:postgres/postgres.dart';

/// zone key to find the open transaction of a connection
const Symbol _txKey = #doxPostgresTransaction;

/// driver for postgres SQL
/// support postgres `Connection` and `Pool`
class PostgresDriver extends DBDriver {
  dynamic conn;

  /// constructor
  PostgresDriver({required this.conn});

  @override
  Driver getName() {
    return Driver.postgres;
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

  /// run query and return map result
  @override
  Future<List<Map<String, dynamic>>> query(
    String query, {
    String? primaryKey,
    Map<String, dynamic>? substitutionValues,
  }) async {
    Result result =
        await _internalQuery(query, substitutionValues: substitutionValues);
    return result.toMapList();
  }

  /// only run query
  @override
  Future<void> execute(String query,
      {Map<String, dynamic>? substitutionValues}) async {
    await _internalQuery(query, substitutionValues: substitutionValues);
  }

  @override
  Future<R> transaction<R>(Future<R> Function() callback) async {
    dynamic c = await _getConnection();
    Map<dynamic, TxSession>? open = Zone.current[_txKey];

    /// ponytail: a nested transaction joins the outer one (no savepoint)
    if (open?[c] != null) {
      return await callback();
    }
    return await c.runTx((TxSession session) {
      return runZoned(callback, zoneValues: <Symbol, dynamic>{
        _txKey: <dynamic, TxSession>{...?open, c: session},
      });
    });
  }

  /// run query in the open transaction if any, else on the connection/pool
  Future<Result> _internalQuery(
    String query, {
    Map<String, dynamic>? substitutionValues,
  }) async {
    dynamic c = await _getConnection();
    Session session = Zone.current[_txKey]?[c] ?? c;
    return await session.execute(
      Sql.named(query),
      parameters: substitutionValues,
    );
  }
}

/// extension on postgres
extension ToMapList on Result {
  List<Map<String, dynamic>> toMapList() {
    return map((ResultRow element) => element.toColumnMap()).toList();
  }
}
