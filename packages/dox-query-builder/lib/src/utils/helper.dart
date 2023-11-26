import 'package:dox_query_builder/dox_query_builder.dart';

class QueryBuilderHelper<T> {
  final QueryBuilder<T> queryBuilder;
  QueryBuilderHelper(this.queryBuilder);

  String parseColumnKey(String column) {
    String timestamp = DateTime.now().microsecondsSinceEpoch.toString();
    return "$column$timestamp".replaceAll(RegExp(r'[^\w]'), "");
  }

  String getCommonQuery({bool isCountQuery = false}) {
    if (queryBuilder.isSoftDeletes) {
      queryBuilder.whereRaw("${queryBuilder.tableName}.deleted_at IS NULL");
    }
    String query = "";
    query += queryBuilder.getJoinQuery();
    query += queryBuilder.getWhereQuery();
    if (!isCountQuery) {
      query += queryBuilder.getOrderByQuery();
    }
    query += queryBuilder.getGroupByQuery();
    query += queryBuilder.getLimitQuery();
    return query;
  }

  Future<List<Map<String, Map<String, dynamic>>>> runQuery(String query) async {
    Map<String, dynamic> values = queryBuilder.substitutionValues;
    if (queryBuilder.shouldDebug) queryBuilder.logger.log(query, values);
    DBDriver db = queryBuilder.db;
    query = query.replaceAll(RegExp(' +'), ' ');
    return await db.mappedResultsQuery(query, substitutionValues: values);
  }

  List<Map<String, dynamic>> getMapResult(
    List<Map<String, Map<String, dynamic>>> queryResult,
  ) {
    List<Map<String, dynamic>> result = <Map<String, dynamic>>[];
    // setting key values format from query result
    for (Map<String, Map<String, dynamic>> row in queryResult) {
      Map<String, dynamic> ret = <String, dynamic>{};
      (row).forEach((String mainKey, Map<String, dynamic> data) {
        (data).forEach((String key, dynamic value) {
          if (ret[key] == null) {
            ret[key] = value is DateTime ? value.toIso8601String() : value;
          } else {
            ret["${mainKey}_$key"] =
                value is DateTime ? value.toIso8601String() : value;
          }
        });
      });
      result.add(ret);
    }
    return result;
  }

  // ignore: always_specify_types
  Future<List> formatResult(
    List<Map<String, Map<String, dynamic>>> queryResult,
  ) async {
    List<Map<String, dynamic>> result = getMapResult(queryResult);

    if (queryBuilder.getRawQuery().isNotEmpty) {
      return result;
    }

    if (queryBuilder.getGroupByQuery().isNotEmpty) {
      return result;
    }

    if (queryBuilder.self != null &&
        queryBuilder.self.toString() != 'dynamic') {
      List<T> ret = <T>[];
      for (Map<String, dynamic> e in result) {
        dynamic res = queryBuilder.self.fromMap(e);
        res.originalMap = e;
        List<String> preloads = queryBuilder.self.customPreloadList;
        for (String preload in preloads) {
          res.preload(preload);
        }
        ret.add(res as T);
      }
      await queryBuilder.initPreload(ret as List<Model<T>>);
      return ret;
    }
    return result;
  }

  String toSnakeCase(String input) {
    String snakeCase = '';
    for (int i = 0; i < input.length; i++) {
      String char = input[i];
      // Check if the current character is uppercase
      if (char == char.toUpperCase() && i > 0) {
        snakeCase +=
            '_'; // Add an underscore if it's uppercase and not the first character
      }
      snakeCase += char
          .toLowerCase(); // Convert the character to lowercase and add it to the result
    }
    return snakeCase.replaceAll(RegExp(r'_+'), '_');
  }
}
