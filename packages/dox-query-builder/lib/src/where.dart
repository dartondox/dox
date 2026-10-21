import 'query_builder.dart';
import 'shared_mixin.dart';

mixin Where<T> implements SharedMixin<T> {
  final List<String> _wheres = <String>[];

  String getWhereQuery() {
    /// wrap user conditions in brackets so an OR can not skip the
    /// soft delete check.
    if (isSoftDeletes) {
      String softDelete = "$tableName.deleted_at IS NULL";
      if (_wheres.isEmpty) {
        return " WHERE $softDelete";
      }
      return " WHERE (${_wheres.join(' ')}) AND $softDelete";
    }
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
    /// empty list match nothing (`in ()` is not valid sql)
    String condition = '1 = 0';
    if (ids.isNotEmpty) {
      List<String> keys = <String>[];
      for (dynamic id in ids) {
        String columnKey = helper.parseColumnKey(column);
        keys.add(columnKey);
        addSubstitutionValues(columnKey, id);
      }
      condition = "$column in (${keys.join(',')})";
    }
    if (_wheres.isEmpty) {
      _wheres.add(condition);
    } else {
      _wheres.add("AND $condition");
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
    dynamic value = arg2;
    if (arg3 != null) {
      condition = arg2;
      value = arg3;
    }

    /// `= null` never match in sql, use IS NULL
    if (value == null) {
      return _rawQuery(type, "$column IS NULL");
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
