import 'package:dox_query_builder/dox_query_builder.dart';
import 'package:postgres/postgres.dart';

Connection? _globalPostgresConnection;

/// driver for postgres SQL
/// support PostgreSQLConnection and PgPool
class PostgresDriver extends DBDriver {
  dynamic conn;

  /// constructor
  PostgresDriver({required this.conn});

  @override
  Driver getName() {
    return Driver.postgres;
  }

  Future<Connection> _getConnection() async {
    /// preventing to create duplicate mysql connection
    if (_globalPostgresConnection != null) {
      return _globalPostgresConnection!;
    }

    /// if connection is future, we need to connect first
    if (conn is Future) {
      conn = await conn;
    }

    /// assign to global
    _globalPostgresConnection = conn;

    /// return connection
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

  /// run query and return map result
  Future<T> _internalQuery<T>(
    String query, {
    Map<String, dynamic>? substitutionValues,
  }) async {
    Connection c = await _getConnection();
    Result result = await c.runTx((TxSession s) async {
      return await s.execute(Sql.named(query), parameters: substitutionValues);
    });
    return result as T;
  }
}

/// extension on postgres
extension ToMapList on Result {
  List<Map<String, dynamic>> toMapList() {
    return map((ResultRow element) => element.toColumnMap()).toList();
  }
}
