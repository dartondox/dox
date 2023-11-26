import 'shared_mixin.dart';

mixin Count<T> implements SharedMixin<T> {
  /// count the record
  /// count() cannot use with select()
  /// ```
  /// await Blog().count();
  /// ```
  // ignore: always_specify_types
  Future<int> count() async {
    String q = "SELECT count(*) as total FROM $tableName";
    q += helper.getCommonQuery(isCountQuery: true);
    List<dynamic> result = helper.getMapResult(await helper.runQuery(q));
    if (result.isNotEmpty) {
      if (result.first['total'] != null) {
        return int.parse(result.first['total'].toString());
      }
    }
    return 0;
  }
}
