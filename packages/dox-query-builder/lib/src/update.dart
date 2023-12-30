import 'shared_mixin.dart';

mixin Update<T> implements SharedMixin<T> {
  /// where raw condition
  ///
  /// ```
  /// Blog blog = await Blog().where('id', 1).update({
  ///   "title" : "new title",
  /// });
  /// ```
  Future<void> update(Map<String, dynamic> data) async {
    String q;
    q = "UPDATE $tableName SET ";

    List<String> columnToUpdate = <String>[];
    data.forEach((String column, dynamic value) {
      String columnKey = helper.parseColumnKey(column);
      columnToUpdate.add("$column = $columnKey");
      addSubstitutionValues(columnKey, value);
    });
    q += columnToUpdate.join(',');
    q += helper.getCommonQuery();
    await helper.runQuery(q);
  }
}
