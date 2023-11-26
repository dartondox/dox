import 'query_builder.dart';
import 'shared_mixin.dart';

mixin Join<T> implements SharedMixin<T> {
  final List<String> _joins = <String>[];

  String getJoinQuery() {
    if (_joins.isNotEmpty) {
      return " ${_joins.join(' ')}";
    }
    return '';
  }

  /// left join
  ///
  /// ```
  /// List admins = await Admin().leftJoin('admin_info', 'admin_info.admin_id', 'admin.id').get();
  /// ```
  QueryBuilder<T> leftJoin(String arg1, String arg2, String arg3,
      [dynamic arg4]) {
    return _query('LEFT JOIN', arg1, arg2, arg3, arg4);
  }

  /// right join
  ///
  /// ```
  /// List admins = await Admin().rightJoin('admin_info', 'admin_info.admin_id', 'admin.id').get();
  /// ```
  QueryBuilder<T> rightJoin(String arg1, String arg2, String arg3,
      [dynamic arg4]) {
    return _query('RIGHT JOIN', arg1, arg2, arg3, arg4);
  }

  /// join
  ///
  /// ```
  /// List admins = await Admin().join('admin_info', 'admin_info.admin_id', 'admin.id').get();
  /// ```
  QueryBuilder<T> join(String arg1, String arg2, String arg3, [dynamic arg4]) {
    return _query('JOIN', arg1, arg2, arg3, arg4);
  }

  /// join raw
  ///
  /// ```
  /// List admins = await Admin().joinRaw('admin_info on admin_info.admin_id = admin.id').get();
  /// ```
  QueryBuilder<T> joinRaw(String rawQuery, [dynamic params]) {
    return _rawQuery('JOIN', rawQuery, params);
  }

  /// left join raw
  ///
  /// ```
  /// List admins = await Admin().leftJoinRaw('admin_info on admin_info.admin_id = admin.id').get();
  /// ```
  QueryBuilder<T> leftJoinRaw(String rawQuery, [dynamic params]) {
    return _rawQuery('LEFT JOIN', rawQuery, params);
  }

  /// right join raw
  ///
  /// ```
  /// List admins = await Admin().rightJoinRaw('admin_info on admin_info.admin_id = admin.id').get();
  /// ```
  QueryBuilder<T> rightJoinRaw(String rawQuery, [dynamic params]) {
    return _rawQuery('RIGHT JOIN', rawQuery, params);
  }

  QueryBuilder<T> _query(String type, String arg1, String arg2, String arg3,
      [dynamic arg4]) {
    String condition = '=';
    String joinTable = arg1;
    String firstJoinColumn = arg2;
    String secondJoinColumn = arg3;
    if (arg4 != null) {
      condition = arg3;
      secondJoinColumn = arg4;
    }
    _joins.add(
        "$type $joinTable on $firstJoinColumn $condition $secondJoinColumn");
    return queryBuilder;
  }

  QueryBuilder<T> _rawQuery(String type, String rawQuery, [dynamic params]) {
    _joins.add('$type $rawQuery');
    if (params != null && params is Map<String, dynamic>) {
      params.forEach((String key, dynamic value) {
        addSubstitutionValues(key, value);
      });
    }
    return queryBuilder;
  }
}
