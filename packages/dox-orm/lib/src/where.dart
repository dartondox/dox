import 'drivers/db_driver.dart';
import 'query_builder.dart';
import 'shared_mixin.dart';

mixin Where<T> implements SharedMixin<T> {
  /// made on the first where, most rows never need it
  List<String>? _wheres;

  /// true when a where condition was added
  bool get hasWhere => _wheres != null;

  /// number of where conditions so far
  int get whereCount => _wheres?.length ?? 0;

  /// puts the conditions from index [from] to the end in one bracket,
  /// joined to the ones before with AND
  void groupWheres(int from) {
    List<String>? wheres = _wheres;
    if (wheres == null || wheres.length <= from) return;
    List<String> added = wheres.sublist(from);
    if (from > 0) added[0] = added[0].replaceFirst(_leadingType, '');
    wheres.removeRange(from, wheres.length);
    String group = '(${added.join(' ')})';
    wheres.add(from == 0 ? group : 'AND $group');
  }

  static final RegExp _leadingType = RegExp(r'^(AND|OR) ');

  String getWhereQuery() {
    queryBuilder.applyGlobalScopes();
    List<String>? wheres = _wheres;

    /// wrap user conditions in brackets so an OR can not skip the
    /// soft delete check.
    if (isSoftDeletes && !withTrashed) {
      String softDelete = "${helper.wrap('$tableName.deleted_at')} IS NULL";
      if (wheres == null) {
        return " WHERE $softDelete";
      }
      return " WHERE (${wheres.join(' ')}) AND $softDelete";
    }
    if (wheres != null) {
      return " WHERE ${wheres.join(' ')}";
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

  /// or where condition
  ///
  /// ```
  /// List blogs = await orWhere('id', 1).get();
  /// ```
  QueryBuilder<T> orWhere(String arg1, [dynamic arg2, dynamic arg3]) {
    return _query('OR', arg1, arg2, arg3);
  }

  /// where in condition. an empty list match no rows.
  ///
  /// ```
  /// List blogs = await whereIn('id', [1, 2, 3]).get();
  /// ```
  QueryBuilder<T> whereIn(String column, List<dynamic> values) {
    return _whereIn('AND', column, values, false);
  }

  /// or where in condition. an empty list match no rows.
  ///
  /// ```
  /// List blogs = await where('id', 1).orWhereIn('id', [2, 3]).get();
  /// ```
  QueryBuilder<T> orWhereIn(String column, List<dynamic> values) {
    return _whereIn('OR', column, values, false);
  }

  /// where not in condition. an empty list match all rows.
  ///
  /// ```
  /// List blogs = await whereNotIn('id', [1, 2, 3]).get();
  /// ```
  QueryBuilder<T> whereNotIn(String column, List<dynamic> values) {
    return _whereIn('AND', column, values, true);
  }

  /// or where not in condition. an empty list match all rows.
  ///
  /// ```
  /// List blogs = await where('id', 1).orWhereNotIn('id', [2, 3]).get();
  /// ```
  QueryBuilder<T> orWhereNotIn(String column, List<dynamic> values) {
    return _whereIn('OR', column, values, true);
  }

  /// where column is null
  ///
  /// ```
  /// List blogs = await whereNull('deleted_at').get();
  /// ```
  QueryBuilder<T> whereNull(String column) {
    return _rawQuery('AND', '${helper.wrap(column)} IS NULL');
  }

  /// or where column is null
  ///
  /// ```
  /// List blogs = await where('id', 1).orWhereNull('slug').get();
  /// ```
  QueryBuilder<T> orWhereNull(String column) {
    return _rawQuery('OR', '${helper.wrap(column)} IS NULL');
  }

  /// where column is not null
  ///
  /// ```
  /// List blogs = await whereNotNull('slug').get();
  /// ```
  QueryBuilder<T> whereNotNull(String column) {
    return _rawQuery('AND', '${helper.wrap(column)} IS NOT NULL');
  }

  /// or where column is not null
  ///
  /// ```
  /// List blogs = await where('id', 1).orWhereNotNull('slug').get();
  /// ```
  QueryBuilder<T> orWhereNotNull(String column) {
    return _rawQuery('OR', '${helper.wrap(column)} IS NOT NULL');
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

  QueryBuilder<T> _whereIn(
    String type,
    String column,
    List<dynamic> values,
    bool not,
  ) {
    /// `in ()` is not valid sql, so an empty list becomes
    /// "no rows" for IN and "all rows" for NOT IN
    if (values.isEmpty) {
      return _rawQuery(type, not ? '1 = 1' : '1 = 0');
    }

    /// postgres: one array param, so every list size gives the same sql
    if (dbDriver.getName() == Driver.postgres && _sameType(values)) {
      String columnKey = helper.parseColumnKey(column);
      addSubstitutionValues(columnKey, values.toList());
      return _rawQuery(
        type,
        "${helper.wrap(column)} ${not ? '<> ALL' : '= ANY'}($columnKey)",
      );
    }
    List<String> keys = <String>[];
    for (dynamic value in values) {
      String columnKey = helper.parseColumnKey(column);
      keys.add(columnKey);
      addSubstitutionValues(columnKey, value);
    }
    String operator = not ? 'NOT IN' : 'IN';
    return _rawQuery(
      type,
      "${helper.wrap(column)} $operator (${keys.join(',')})",
    );
  }

  /// true when every value is an int, or every value is a String.
  /// postgres reads these as an array of the column type. other lists
  /// (mixed types, nulls) keep one param per value.
  static bool _sameType(List<dynamic> values) {
    return values.every(_isInt) || values.every(_isString);
  }

  static bool _isInt(dynamic value) => value is int;

  static bool _isString(dynamic value) => value is String;

  QueryBuilder<T> _query(
    String type,
    dynamic arg1, [
    dynamic arg2,
    dynamic arg3,
  ]) {
    String column = arg1.toString();
    String condition = '=';
    dynamic value = arg2;
    if (arg3 != null) {
      condition = helper.operator(arg2);
      value = arg3;
    }

    /// `= null` never match in sql, use IS NULL
    if (value == null) {
      return _rawQuery(type, "${helper.wrap(column)} IS NULL");
    }
    String columnKey = helper.parseColumnKey(column);
    addSubstitutionValues(columnKey, value);
    return _rawQuery(type, "${helper.wrap(column)} $condition $columnKey");
  }

  QueryBuilder<T> _rawQuery(String type, String rawQuery, [dynamic params]) {
    List<String>? wheres = _wheres;
    if (wheres == null) {
      _wheres = <String>[rawQuery];
    } else {
      wheres.add("$type $rawQuery");
    }
    if (params is Map<String, dynamic>) {
      params.forEach((String key, dynamic value) {
        addSubstitutionValues(key, value);
      });
    }
    return queryBuilder;
  }
}
