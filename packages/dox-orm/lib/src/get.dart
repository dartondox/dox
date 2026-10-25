import 'dart:async';

import 'package:dox_orm/dox_orm.dart';

import 'limit.dart';
import 'shared_mixin.dart';

mixin Get<T> implements SharedMixin<T> {
  /// build query to run
  String _buildQuery() {
    if (queryBuilder.getRawQuery().isNotEmpty) {
      return queryBuilder.getRawQuery();
    }
    String q = "SELECT $selectQueryString FROM ${helper.wrap(tableName)}";
    q += helper.getCommonQuery();
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
  Future<T?> find(dynamic arg1, [dynamic arg2]) {
    String column = arg2 == null ? primaryKey : arg1;
    dynamic value = arg2 ?? arg1;
    QueryBuilder<T> qb = queryBuilder;
    if (value == null || !_isPlain(qb)) {
      qb.where(column, value).limit(1);
      return _first(_buildQuery());
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

      /// the where value is the first, the LIMIT value comes after it
      String key = substitutionValues.keys.first;

      /// ponytail: cleared when full, column names are a small set
      if (sqls.length >= 100) sqls.clear();
      sqls[column] = (sql, key);
      return _first(sql);
    }
    substitutionValues[hit.$2] = value;
    substitutionValues[Limit.limitKey] = 1;
    return _first(hit.$1);
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
        qb.getSelectQuery() == '*' &&
        !qb.hasAggregates &&
        !qb.hasGlobalScopes;
  }

  /// Get records
  ///
  /// ```
  /// List<Blog> blogs = await Blog().where('status', 'active').get();
  /// ```
  Future<List<T>> get() async {
    return _typed(
      await helper.formatResult(await helper.runQuery(_buildQuery())),
    );
  }

  /// a model query with groupBy() or rawQuery() gives plain rows (maps),
  /// not models. Say so, instead of a type error later.
  // ignore: always_specify_types
  List<T> _typed(List rows) {
    if (rows is List<T>) return rows;
    throw StateError(
      'This query gives plain rows, not $T models. '
      'Use QueryBuilder.table() for groupBy() and rawQuery().',
    );
  }

  /// paginate
  ///
  /// ```
  /// Pagination pagination = await Blog().paginate(
  ///  currentPage: 1,
  ///  perPage: 10,
  /// );
  /// ```
  Future<Pagination<T>> paginate({
    required int currentPage,
    required int perPage,
  }) async {
    int offset = (currentPage - 1) * perPage;

    int total = await queryBuilder.count();

    List<T> data = await queryBuilder.limit(perPage).offset(offset).get();

    return Pagination<T>(
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
  /// Blog? blog = await Blog().where('status', 'active').getFirst();
  /// ```
  Future<T?> getFirst() {
    queryBuilder.limit(1);
    return _first(_buildQuery());
  }

  /// run [sql] and return the first row, or null
  Future<T?> _first(String sql) async {
    // ignore: always_specify_types
    FutureOr<List> rows = helper.formatResult(await helper.runQuery(sql));
    // ignore: always_specify_types
    List result = rows is Future<List> ? await rows : rows;
    return result.isEmpty ? null : _typed(result).first;
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
  /// List<Blog> blogs = await Blog().all();
  /// ```
  Future<List<T>> all() async {
    /// the where part adds soft deletes and global scopes
    String query =
        "SELECT $selectQueryString FROM ${helper.wrap(tableName)}"
        "${queryBuilder.getWhereQuery()}";
    return _typed(await helper.formatResult(await helper.runQuery(query)));
  }
}
