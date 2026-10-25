import 'package:dox_orm/dox_orm.dart';

import 'relationships/keys.dart';
import 'shared_mixin.dart';

/// one withCount(), withSum() or withMax() of a query
class _Aggregate {
  final String relation;
  final String function;
  final String column;
  final String key;
  final void Function(QueryBuilder<dynamic> query)? where;

  const _Aggregate(
    this.relation,
    this.function,
    this.column,
    this.key,
    this.where,
  );
}

mixin WithCount<T> implements SharedMixin<T> {
  List<_Aggregate>? _aggregates;

  /// true when the query has a withCount(), withSum() or withMax()
  bool get hasAggregates => _aggregates != null;

  /// the result keys, like `posts_count`
  List<String> get aggregateKeys => <String>[
    for (_Aggregate a in _aggregates ?? const <_Aggregate>[]) a.key,
  ];

  /// adds `<relation>_count`, the number of related rows, with a
  /// subquery. Works with hasOne, hasMany and manyToMany relations.
  /// [where] adds conditions to the related rows.
  /// `'posts as published_count'` sets the key.
  ///
  /// ```
  /// List<User> users = await User().withCount('posts').get();
  /// users.first.countOf('posts');
  ///
  /// await User()
  ///     .withCount('posts as published_count', (QueryBuilder<dynamic> q) {
  ///       q.where('published', true);
  ///     })
  ///     .get();
  /// users.first.aggregate('published_count');
  /// ```
  QueryBuilder<T> withCount(
    String relation, [
    void Function(QueryBuilder<dynamic> query)? where,
  ]) {
    return _add(relation, 'count', '*', where);
  }

  /// adds `<relation>_sum_<column>`, the sum of [column] of the related
  /// rows. It is null when there is no related row.
  ///
  /// ```
  /// User? user = await User().withSum('posts', 'views').find(1);
  /// user?.aggregate('posts_sum_views');
  /// ```
  QueryBuilder<T> withSum(
    String relation,
    String column, [
    void Function(QueryBuilder<dynamic> query)? where,
  ]) {
    return _add(relation, 'sum', column, where);
  }

  /// adds `<relation>_max_<column>`, the biggest [column] of the
  /// related rows. It is null when there is no related row.
  QueryBuilder<T> withMax(
    String relation,
    String column, [
    void Function(QueryBuilder<dynamic> query)? where,
  ]) {
    return _add(relation, 'max', column, where);
  }

  QueryBuilder<T> _add(
    String relation,
    String function,
    String column,
    void Function(QueryBuilder<dynamic> query)? where,
  ) {
    List<String> parts = relation.split(RegExp(r'\s+as\s+'));
    String name = parts.first.trim();
    String snake = helper.toSnakeCase(name);
    String key = parts.length > 1
        ? parts[1].trim()
        : function == 'count'
        ? '${snake}_count'
        : '${snake}_${function}_$column';
    (_aggregates ??= <_Aggregate>[]).add(
      _Aggregate(name, function, column, key, where),
    );
    return queryBuilder;
  }

  /// the subqueries for the select part, like
  /// `, (SELECT COUNT(*) FROM post WHERE ...) AS "posts_count"`
  String aggregateSelects() {
    List<_Aggregate>? list = _aggregates;
    if (list == null) return '';
    QueryBuilder<T> owner = queryBuilder;
    if (owner is! Model<T>) {
      throw StateError('withCount() needs a model query, like User().');
    }
    String sql = '';
    for (int i = 0; i < list.length; i++) {
      _Aggregate a = list[i];
      QueryBuilder<dynamic> q = _relationQuery(owner, a.relation);
      q.helper.keyPrefix = 'dox_agg${i}_';
      a.where?.call(q);
      String column = a.column == '*'
          ? '*'
          : q.helper.wrap(
              a.column.contains('.') ? a.column : '${q.tableName}.${a.column}',
            );
      String inner =
          'SELECT ${a.function.toUpperCase()}($column) '
          'FROM ${q.helper.wrap(q.tableName)}'
          '${q.helper.getCommonQuery(isCountQuery: true)}';
      substitutionValues.addAll(q.substitutionValues);
      sql += ', ($inner) AS ${helper.wrap(a.key)}';
    }
    return sql;
  }

  /// the query of [relation], matched to the parent row by a column
  QueryBuilder<dynamic> _relationQuery(Model<T> owner, String relation) {
    Function? make = owner.relationsQueryMatcher[relation];
    if (make == null) {
      throw ArgumentError.value(relation, 'relation', 'is not a relation');
    }
    relationSubquery = true;
    try {
      return Function.apply(make, <dynamic>[
        <Model<T>>[owner],
      ]) as QueryBuilder<dynamic>;
    } finally {
      relationSubquery = false;
    }
  }
}
