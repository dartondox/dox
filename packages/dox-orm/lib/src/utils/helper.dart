import 'package:dox_orm/dox_orm.dart';

final RegExp _notWord = RegExp(r'[^\w]');

class QueryBuilderHelper<T> {
  final QueryBuilder<T> queryBuilder;
  QueryBuilderHelper(this.queryBuilder);

  /// number of param keys made by this query
  int _paramCount = 0;

  /// a param key that is unique in this query. the same query gives the
  /// same keys every time, so the sql text is the same and the drivers can
  /// reuse their prepared statements.
  String parseColumnKey(String column) {
    return '@${column.replaceAll(_notWord, '')}_p${_paramCount++}';
  }

  /// quote a table or column name for the current driver
  String wrap(String value) => queryBuilder.dbDriver.wrap(value);

  /// count query do not need order by, limit and offset
  String getCommonQuery({bool isCountQuery = false}) {
    String query = "";
    query += queryBuilder.getJoinQuery();
    query += queryBuilder.getWhereQuery();
    query += queryBuilder.getGroupByQuery();
    if (!isCountQuery) {
      query += queryBuilder.getOrderByQuery();
      query += queryBuilder.getLimitQuery();
    }
    return query;
  }

  Future<List<Map<String, dynamic>>> runQuery(String query) async {
    Map<String, dynamic> values = queryBuilder.substitutionValues;
    if (queryBuilder.shouldDebug) queryBuilder.logger.log(query, values);
    query = query.replaceAll(RegExp(' +'), ' ');
    return await queryBuilder.dbDriver.query(
      query,
      substitutionValues: values,
      primaryKey: queryBuilder.primaryKey,
    );
  }

  List<Map<String, dynamic>> getMapResult(
    List<Map<String, dynamic>> queryResult,
  ) {
    List<Map<String, dynamic>> result = <Map<String, dynamic>>[];
    // setting key values format from query result
    for (Map<String, dynamic> data in queryResult) {
      Map<String, dynamic> ret = <String, dynamic>{};

      (data).forEach((String key, dynamic value) {
        ret[key] = value is DateTime ? value.toIso8601String() : value;
      });

      result.add(ret);
    }
    return result;
  }

  // ignore: always_specify_types
  Future<List> formatResult(List<Map<String, dynamic>> queryResult) async {
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
        snakeCase += '_'; // Add an underscore if it's uppercase and not the first character
      }
      snakeCase += char.toLowerCase(); // Convert the character to lowercase and add it to the result
    }
    return snakeCase.replaceAll(RegExp(r'_+'), '_');
  }
}
