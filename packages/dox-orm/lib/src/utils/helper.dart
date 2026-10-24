import 'dart:async';

import 'package:dox_orm/dox_orm.dart';

import '../limit.dart';

final RegExp _notWord = RegExp(r'[^\w]');

/// compare operators allowed in where() and join()
const Set<String> _operators = <String>{
  '=',
  '!=',
  '<>',
  '<',
  '>',
  '<=',
  '>=',
  'like',
  'not like',
  'ilike',
};

/// column name without the non word characters, made once
final Map<String, String> _keyNames = <String, String>{};

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
    String? name = _keyNames[column];
    if (name == null) {
      /// ponytail: cleared when full, column names are a small set
      if (_keyNames.length >= 1000) _keyNames.clear();
      name = _keyNames[column] = column.replaceAll(_notWord, '');
    }
    return '@${name}_p${_paramCount++}';
  }

  /// quote a table or column name for the current driver
  String wrap(String value) => queryBuilder.dbDriver.wrap(value);

  /// [op] when it is a known compare operator, else it throws an
  /// [ArgumentError], so user input can not add sql to a where or join
  String operator(dynamic op) {
    String value = op.toString().trim();
    if (!_operators.contains(value.toLowerCase())) {
      throw ArgumentError.value(op, 'operator', 'is not allowed');
    }
    return value;
  }

  /// count query do not need order by, limit and offset
  String getCommonQuery({bool isCountQuery = false}) {
    String query = "";
    query += queryBuilder.getJoinQuery();
    query += queryBuilder.getWhereQuery();
    query += queryBuilder.getGroupByQuery();
    if (!isCountQuery) {
      query += queryBuilder.getOrderByQuery();
      query += queryBuilder.getLimitQuery();
    } else {
      /// a count has no LIMIT, so it must not send its values
      queryBuilder.substitutionValues
        ..remove(Limit.limitKey)
        ..remove(Limit.offsetKey);
    }
    return query;
  }

  Future<List<Map<String, dynamic>>> runQuery(String query) {
    Map<String, dynamic> values = queryBuilder.substitutionValues;
    if (queryBuilder.shouldDebug) queryBuilder.logger.log(query, values);
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

  /// rows to models. It is sync when there are no relations to load,
  /// so the caller does not wait one more microtask.
  // ignore: always_specify_types
  FutureOr<List> formatResult(List<Map<String, dynamic>> queryResult) {
    dynamic self = queryBuilder.self;
    if (self is! Model ||
        queryBuilder.getRawQuery().isNotEmpty ||
        queryBuilder.getGroupByQuery().isNotEmpty) {
      return getMapResult(queryResult);
    }

    /// a generated fromMap() reads the dates of the driver as they are
    List<Map<String, dynamic>> result = self.readsRowDates
        ? queryResult
        : getMapResult(queryResult);
    List<String> preloads = self.customPreloadList;
    List<T> ret = <T>[];
    for (Map<String, dynamic> e in result) {
      Model<dynamic> res = self.fromMap(e);
      res.originalMap = e;

      /// so save() and delete() on this model use the same connection
      res.connection = queryBuilder.connection;
      for (String preload in preloads) {
        res.preload(preload);
      }
      ret.add(res as T);
    }

    /// no relations to load: skip the preload work
    if (ret.isNotEmpty && queryBuilder.getPreload().isNotEmpty) {
      return _preload(ret);
    }
    return ret;
  }

  Future<List<T>> _preload(List<T> ret) async {
    await queryBuilder.initPreload(ret as List<Model<T>>);
    return ret;
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
