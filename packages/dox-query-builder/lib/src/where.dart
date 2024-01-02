import 'query_builder.dart';
import 'shared_mixin.dart';

mixin Where<T> implements SharedMixin<T> {
  final List<String> _wheres = <String>[];

  String getWhereQuery() {
    if (_wheres.isNotEmpty) {
      return " WHERE ${_wheres.join(' ')}";
    }
    return '';
  }

  /// where condition
  ///
  /// ```
  /// List blogs = await where('id', 1).get();
  /// ```
  QueryBuilder<T> where(String arg1, [dynamic arg2, dynamic arg3]) {
    return _query('AND', arg1, arg2, arg3);
  }

  /// where condition
  ///
  /// ```
  /// List blogs = await whereIn('id', [1, 2, 3]).get();
  /// ```
  QueryBuilder<T> whereIn(String column, List<dynamic> ids) {
    String val = "(${ids.join(',')})";
    if (_wheres.isEmpty) {
      _wheres.add("$column in $val");
    } else {
      _wheres.add("AND $column in $val");
    }
    return queryBuilder;
  }

  /// or where condition
  ///
  /// ```
  /// List blogs = await orWhere('id', 1).get();
  /// ```
  QueryBuilder<T> orWhere(String arg1, [dynamic arg2, dynamic arg3]) {
    return _query('OR', arg1, arg2, arg3);
  }

  /// where raw condition
  ///
  /// ```
  /// List blogs = await whereRaw('id = @id', {"id" : 1}).get();
  /// ```
  QueryBuilder<T> whereRaw(String rawQuery, [dynamic params]) {
    return _rawQuery('AND', rawQuery, params);
  }

  /// where raw condition
  ///
  /// ```
  /// List blogs = await orWhereRaw('id = @id', {"id" : 1}).get();
  /// ```
  QueryBuilder<T> orWhereRaw(String rawQuery, [dynamic params]) {
    return _rawQuery('OR', rawQuery, params);
  }

  QueryBuilder<T> _query(String type, dynamic arg1,
      [dynamic arg2, dynamic arg3]) {
    String column = arg1.toString();
    String condition = '=';
    String value = arg2.toString();
    if (arg3 != null) {
      condition = arg2;
      value = arg3.toString();
    }
    String columnKey = helper.parseColumnKey(column);
    if (_wheres.isEmpty) {
      _wheres.add("$column $condition $columnKey");
    } else {
      _wheres.add("$type $column $condition $columnKey");
    }
    addSubstitutionValues(columnKey, value);
    return queryBuilder;
  }

  QueryBuilder<T> _rawQuery(String type, String rawQuery, [dynamic params]) {
    if (_wheres.isEmpty) {
      _wheres.add(rawQuery);
    } else {
      _wheres.add("$type $rawQuery");
    }
    if (params is Map<String, dynamic>) {
      params.forEach((String key, dynamic value) {
        addSubstitutionValues(key, value);
      });
    }
    return queryBuilder;
  }
}
