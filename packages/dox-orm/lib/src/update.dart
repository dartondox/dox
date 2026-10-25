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
    q = "UPDATE ${helper.wrap(tableName)} SET ";

    List<String> columnToUpdate = <String>[];
    data.forEach((String column, dynamic value) {
      String columnKey = helper.parseColumnKey(column);
      columnToUpdate.add("${helper.wrap(column)} = $columnKey");
      addSubstitutionValues(
        columnKey,
        queryBuilder.dbDriver.columnValue(value),
      );
    });
    q += columnToUpdate.join(',');
    q += helper.getCommonQuery();
    await helper.runQuery(q);
  }
}
