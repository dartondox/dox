import 'shared_mixin.dart';

mixin Insert<T> implements SharedMixin<T> {
  /// create/insert a record
  ///
  /// ```
  /// Blog blog = await Blog().create({
  ///   "title" : "Blog title",
  ///   "body" : "Lorem",
  /// });
  /// ```
  // ignore: always_specify_types
  Future create(Map<String, dynamic> data) async {
    return await insert(data);
  }

  /// insert/create a record
  ///
  /// ```
  /// Blog blog = await Blog().insert({
  ///   "title" : "Blog title",
  ///   "body" : "Lorem",
  /// });
  /// ```
  // ignore: always_specify_types
  Future insert(Map<String, dynamic> data) async {
    // ignore: always_specify_types
    List<Map<String, Map<String, dynamic>>> result =
        await insertMultiple(<Map<String, dynamic>>[data]);
    if (result.isNotEmpty) {
      Map<String, Map<String, dynamic>> insertedData = result.first;
      int id = insertedData[tableName]?[primaryKey] ?? 0;
      resetSubstitutionValues();
      return await queryBuilder.find(id);
    }
    return null;
  }

  /// insert/create multiple records
  ///
  /// ```
  /// Blog blog = await Blog().insert([
  ///   {"title" : "Blog title"},
  ///   {"title" : "Another blog title"},
  /// ]);
  /// ```
  Future<List<Map<String, Map<String, dynamic>>>> insertMultiple(
      List<Map<String, dynamic>> list) async {
    List<String> columns = <String>[];
    List<String> values = <String>[];

    // creating columns (col1, col2);
    list.first.forEach((String key, dynamic value) {
      columns.add(key);
    });

    // creating values to insert (value1, val2);
    for (Map<String, dynamic> data in list) {
      List<String> ret = <String>[];
      data.forEach((String key, dynamic value) {
        String columnKey = helper.parseColumnKey(key);
        ret.add("@$columnKey");
        addSubstitutionValues(columnKey, value);
      });
      values.add("(${ret.join(',')})");
    }

    String query =
        "INSERT INTO $tableName (${columns.join(',')}) VALUES ${values.join(',')} RETURNING $primaryKey";
    return await helper.runQuery(query);
  }
}
