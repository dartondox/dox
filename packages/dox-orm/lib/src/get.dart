import 'dart:async';

import 'package:dox_orm/dox_orm.dart';

import 'shared_mixin.dart';

mixin Get<T> implements SharedMixin<T> {
  /// build query to run
  String _buildQuery() {
    if (queryBuilder.getRawQuery().isNotEmpty) {
      return queryBuilder.getRawQuery();
    }
    String q = "SELECT $selectQueryString FROM ${helper.wrap(tableName)}";
    q += helper.getCommonQuery();
    if (q.contains('  ')) {
      q = q.replaceAll(RegExp(' +'), ' ');
    }
    return q;
  }

  /// Find a record
  ///
  /// ```
  /// await Blog().find(1);
  /// await Blog().find('name', 'John');
  /// ```
  /// If only [arg1] is provided, it will as as id value,
  /// If both [arg1] and [arg2] ar provided, [arg1] is column name and
  /// [arg2] is value of column
  /// This cannot be use with other query such as, where, join, delete.
  // ignore: always_specify_types
  Future find(dynamic arg1, [dynamic arg2]) {
    String column = arg2 == null ? primaryKey : arg1;
    dynamic value = arg2 ?? arg1;
    QueryBuilder<T> qb = queryBuilder;
    if (value == null || !_isPlain(qb)) {
      qb.where(column, value).limit(1);
      return _first<T>(_buildQuery());
    }

    /// a plain find: the sql is the same every time, so build it once
    /// for each driver, table and column.
    bool soft = isSoftDeletes && !withTrashed;
    Map<String, (String, String)> sqls =
        ((soft ? _softFindSql : _findSql)[dbDriver] ??=
                <String, Map<String, (String, String)>>{})[tableName] ??=
            <String, (String, String)>{};
    (String, String)? hit = sqls[column];
    qb.limit(1);
    if (hit == null) {
      qb.where(column, value);
      String sql = _buildQuery();
      String key = substitutionValues.keys.single;

      /// ponytail: cleared when full, column names are a small set
      if (sqls.length >= 100) sqls.clear();
      sqls[column] = (sql, key);
      return _first<T>(sql);
    }
    substitutionValues[hit.$2] = value;
    return _first<T>(hit.$1);
  }

  /// find sql of each driver, then table, then column: (sql, param key)
  static final Expando<Map<String, Map<String, (String, String)>>> _findSql =
      Expando<Map<String, Map<String, (String, String)>>>();

  /// the same, for soft delete models without trashed rows
  static final Expando<Map<String, Map<String, (String, String)>>>
  _softFindSql = Expando<Map<String, Map<String, (String, String)>>>();

  /// true when nothing was added to the query yet
  static bool _isPlain(QueryBuilder<dynamic> qb) {
    return !qb.hasWhere &&
        qb.substitutionValues.isEmpty &&
        qb.getRawQuery().isEmpty &&
        qb.getJoinQuery().isEmpty &&
        qb.getGroupByQuery().isEmpty &&
        qb.getOrderByQuery().isEmpty &&
        qb.getLimitQuery().isEmpty &&
        qb.getSelectQuery() == '*';
  }

  /// Get records
  ///
  /// ```
  /// List blogs = await Blog().where('status', 'active').get();
  /// ```
  // ignore: always_specify_types
  Future get() async {
    return await helper.formatResult(await helper.runQuery(_buildQuery()));
  }

  /// paginate
  ///
  /// ```
  /// Pagination pagination = await Blog().paginate(
  ///  currentPage: 1,
  ///  perPage: 10,
  /// );
  /// ```
  // ignore: always_specify_types
  Future<Pagination> paginate({
    required int currentPage,
    required int perPage,
  }) async {
    int offset = (currentPage - 1) * perPage;

    int total = await queryBuilder.count();

    // ignore: always_specify_types
    List data = await queryBuilder.limit(perPage).offset(offset).get();

    return Pagination(
      total: total,
      perPage: perPage,
      lastPage: (total / perPage).ceil(),
      currentPage: currentPage,
      data: data,
    );
  }

  /// Get records
  ///
  /// ```
  /// Blog blogs = await Blog().where('status', 'active').getFirst();
  /// ```
  // ignore: always_specify_types
  Future getFirst() {
    queryBuilder.limit(1);
    return _first<dynamic>(_buildQuery());
  }

  /// run [sql] and return the first row, or null.
  /// find() uses [R] = T, so Model.find() gets a `Future<T?>`.
  Future<R?> _first<R>(String sql) async {
    // ignore: always_specify_types
    FutureOr<List> rows = helper.formatResult(
      await helper.runQuery(sql, clean: queryBuilder.getRawQuery().isEmpty),
    );
    // ignore: always_specify_types
    List result = rows is Future<List> ? await rows : rows;
    return result.isEmpty ? null : result.first as R?;
  }

  /// Get Sql string
  ///
  /// ```
  /// String query = Blog().where('status', 'active').toSql();
  /// ```
  String toSql() {
    String q = _buildQuery();
    Map<String, dynamic> values = queryBuilder.substitutionValues;
    return q.replaceAllMapped(RegExp(r'@(\w+)'), (Match m) {
      String key = m.group(1)!;
      return values.containsKey(key) ? values[key].toString() : m.group(0)!;
    });
  }

  /// Get all record from table
  ///
  /// ```
  /// await Blog().all();
  /// ```
  // ignore: always_specify_types
  Future all() async {
    String query = "SELECT $selectQueryString FROM ${helper.wrap(tableName)}";
    if (isSoftDeletes && !withTrashed) {
      query += " WHERE ${helper.wrap('$tableName.deleted_at')} IS NULL";
    }
    return helper.formatResult(await helper.runQuery(query));
  }
}
