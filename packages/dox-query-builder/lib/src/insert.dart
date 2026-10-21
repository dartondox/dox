import 'package:dox_query_builder/dox_query_builder.dart';

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
    List<Map<String, dynamic>> result = await insertMultiple(
      <Map<String, dynamic>>[data],
    );

    /// id can be any type (int, uuid string...).
    /// mysql only returns auto increment ids, so use the given id if any.
    dynamic id = result.isNotEmpty ? result.first[primaryKey] : null;
    id ??= data[primaryKey];
    resetSubstitutionValues();
    if (id != null) {
      return await queryBuilder.find(id);
    }
    return <String, dynamic>{};
  }

  /// insert/create multiple records
  ///
  /// ```
  /// Blog blog = await Blog().insert([
  ///   {"title" : "Blog title"},
  ///   {"title" : "Another blog title"},
  /// ]);
  /// ```
  /// columns are all keys from all rows.
  /// a row without a key uses the column default value.
  Future<List<Map<String, dynamic>>> insertMultiple(
    List<Map<String, dynamic>> list,
  ) async {
    if (list.isEmpty) {
      return <Map<String, dynamic>>[];
    }
    List<String> columns = <String>{
      for (Map<String, dynamic> data in list) ...data.keys,
    }.toList();

    /// sqlite has no `DEFAULT` in VALUES, so rows with missing keys are
    /// inserted one by one
    if (queryBuilder.dbDriver.getName() == Driver.sqlite &&
        list.length > 1 &&
        list.any((Map<String, dynamic> d) => d.length != columns.length)) {
      List<Map<String, dynamic>> result = <Map<String, dynamic>>[];
      for (Map<String, dynamic> data in list) {
        result.addAll(await insertMultiple(<Map<String, dynamic>>[data]));
        resetSubstitutionValues();
      }
      return result;
    }
    List<String> values = <String>[];

    // creating values to insert (value1, val2);
    for (Map<String, dynamic> data in list) {
      List<String> ret = <String>[];

      /// follow the same column order for every row, so values do not go
      /// to the wrong column when rows have keys in a different order
      for (String key in columns) {
        if (!data.containsKey(key)) {
          ret.add('DEFAULT');
          continue;
        }
        String columnKey = helper.parseColumnKey(key);
        ret.add(columnKey);
        addSubstitutionValues(columnKey, data[key]);
      }
      values.add("(${ret.join(',')})");
    }

    String returningQuery = queryBuilder.dbDriver.supportsReturning
        ? 'RETURNING ${helper.wrap(primaryKey)}'
        : '';

    String query =
        "INSERT INTO ${helper.wrap(tableName)} (${columns.map(helper.wrap).join(',')}) VALUES ${values.join(',')} $returningQuery";
    return await helper.runQuery(query);
  }
}
