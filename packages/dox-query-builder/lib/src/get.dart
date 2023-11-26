import 'package:dox_query_builder/src/types/pagination_result.dart';

import 'shared_mixin.dart';

mixin Get<T> implements SharedMixin<T> {
  /// build query to run
  String _buildQuery() {
    if (queryBuilder.getRawQuery().isNotEmpty) {
      return queryBuilder.getRawQuery();
    }
    String q = "SELECT $selectQueryString FROM $tableName";
    q += helper.getCommonQuery();
    q = q.replaceAll(RegExp(' +'), ' ');
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
  Future find(dynamic arg1, [dynamic arg2]) async {
    String column = arg2 == null ? primaryKey : arg1;
    dynamic value = arg2 ?? arg1;
    return await queryBuilder.where(column, value).limit(1).getFirst();
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
  Future getFirst() async {
    queryBuilder.limit(1);
    // ignore: always_specify_types
    List result =
        await helper.formatResult(await helper.runQuery(_buildQuery()));
    return result.isEmpty ? null : result.first;
  }

  /// Get Sql string
  ///
  /// ```
  /// String query = Blog().where('status', 'active').toSql();
  /// ```
  String toSql() {
    String q = _buildQuery();
    Map<String, dynamic> values = queryBuilder.substitutionValues;
    String query = '';
    values.forEach((String key, dynamic value) {
      query += q.replaceAll('@$key', value);
    });
    return query;
  }

  /// Get all record from table
  ///
  /// ```
  /// await Blog().all();
  /// ```
  // ignore: always_specify_types
  Future all() async {
    String query = "SELECT $selectQueryString FROM $tableName";
    if (isSoftDeletes) {
      query += ' WHERE $tableName.deleted_at IS NULL';
    }
    return helper.formatResult(await helper.runQuery(query));
  }
}
