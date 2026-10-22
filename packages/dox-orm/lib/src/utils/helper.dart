import 'package:dox_orm/dox_orm.dart';

final RegExp _notWord = RegExp(r'[^\w]');
final RegExp _manySpaces = RegExp(' +');

/// snake case table name of each model type, made once
final Map<Type, String> _snakeNames = <Type, String>{};

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

  Future<List<Map<String, dynamic>>> runQuery(String query) {
    Map<String, dynamic> values = queryBuilder.substitutionValues;
    if (queryBuilder.shouldDebug) queryBuilder.logger.log(query, values);
    if (query.contains('  ')) {
      query = query.replaceAll(_manySpaces, ' ');
    }
    return queryBuilder.dbDriver.query(
      query,
      substitutionValues: values,
      primaryKey: queryBuilder.primaryKey,
    );
  }

  /// dates become iso strings (models read them as strings).
  /// the rows are new maps from the driver, so they are changed in place.
  List<Map<String, dynamic>> getMapResult(
    List<Map<String, dynamic>> queryResult,
  ) {
    for (Map<String, dynamic> data in queryResult) {
      for (MapEntry<String, dynamic> e in data.entries) {
        if (e.value is DateTime) {
          data[e.key] = (e.value as DateTime).toIso8601String();
        }
      }
    }
    return queryResult;
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

    dynamic self = queryBuilder.self;
    if (self != null && self != dynamic) {
      List<String> preloads = self.customPreloadList;
      List<T> ret = <T>[];
      for (Map<String, dynamic> e in result) {
        dynamic res = self.fromMap(e);
        res.originalMap = e;
        for (String preload in preloads) {
          res.preload(preload);
        }
        ret.add(res as T);
      }

      /// no relations to load: skip the preload work
      if (ret.isNotEmpty && queryBuilder.getPreload().isNotEmpty) {
        await queryBuilder.initPreload(ret as List<Model<T>>);
      }
      return ret;
    }
    return result;
  }

  /// snake case name of the model type, eg. `BlogInfo` is `blog_info`
  String tableNameOf(Type type) {
    return _snakeNames[type] ??= toSnakeCase(type.toString());
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
