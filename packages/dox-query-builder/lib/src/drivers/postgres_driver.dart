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
  Future<List<Map<String, Map<String, dynamic>>>> mappedResultsQuery(
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
  List<Map<String, Map<String, dynamic>>> toMapList() {
    List<Map<String, Map<String, dynamic>>> data =
        <Map<String, Map<String, dynamic>>>[];
    forEach((ResultRow element) {
      data.add(element.toMappedColumns());
    });
    return data;
  }
}

extension ToMappedColumns on ResultRow {
  Map<String, Map<String, dynamic>> toMappedColumns() {
    Map<String, Map<String, dynamic>> data = <String, Map<String, dynamic>>{};

    for (var (int i, ResultSchemaColumn col) in schema.columns.indexed) {
      String tableId = col.tableOid.toString();
      if (col.columnName case String name) {
        if (data[tableId] == null) {
          data[tableId] = <String, dynamic>{};
        }
        Map<String, dynamic> table = data[tableId]!;
        table[name] = this[i];
      } else {
        if (data[tableId] == null) {
          data[tableId] = <String, dynamic>{};
        }
        Map<String, dynamic> table = data[tableId]!;
        String name = '[$i]';
        table[name] = this[i];
      }
    }
    return data;
  }
}
