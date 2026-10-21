import 'shared_mixin.dart';

mixin Count<T> implements SharedMixin<T> {
  /// count the record
  /// count() cannot use with select().
  /// limit, offset and order by are not used.
  /// with groupBy() it returns the number of groups.
  /// ```
  /// await Blog().count();
  /// ```
  // ignore: always_specify_types
  Future<int> count() async {
    String table = helper.wrap(tableName);
    String q = "SELECT count(*) as total FROM $table";
    q += helper.getCommonQuery(isCountQuery: true);
    if (queryBuilder.getGroupByQuery().isNotEmpty) {
      q = "SELECT count(*) as total FROM (SELECT 1 as one FROM $table"
          "${helper.getCommonQuery(isCountQuery: true)}) as dox_count";
    }
    List<dynamic> result = helper.getMapResult(await helper.runQuery(q));
    if (result.isNotEmpty) {
      if (result.first['total'] != null) {
        return int.parse(result.first['total'].toString());
      }
    }
    return 0;
  }
}
