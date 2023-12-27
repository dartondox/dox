import 'package:dox_query_builder/dox_query_builder.dart';
import 'package:postgres/postgres.dart';

/// driver for postgres SQL
/// support PostgreSQLConnection and PgPool
class PostgresDriver extends DBDriver {
  final Connection conn;

  /// constructor
  PostgresDriver({required this.conn});

  /// run query and return map result
  @override
  Future<Result> execute(
    String query, {
    Map<String, dynamic>? substitutionValues,
  }) async {
    Result result = await conn.runTx((TxSession s) async {
      return await s.execute(Sql.named(query), parameters: substitutionValues);
    });
    return result;
  }

  /// run query and return map result
  @override
  Future<List<Map<String, dynamic>>> mappedResultsQuery(
    String query, {
    Map<String, dynamic>? substitutionValues,
  }) async {
    Result result =
        await execute(query, substitutionValues: substitutionValues);
    return result.toMapList();
  }

  /// only run query
  @override
  Future<void> query(String query,
      {Map<String, dynamic>? substitutionValues}) async {
    await conn.runTx((TxSession s) async {
      await s.execute(Sql.named(query), parameters: substitutionValues);
    });
  }
}

/// extension on postgres
extension ToMapList on Result {
  List<Map<String, dynamic>> toMapList() {
    return map((ResultRow element) => element.toColumnMap()).toList();
  }
}
