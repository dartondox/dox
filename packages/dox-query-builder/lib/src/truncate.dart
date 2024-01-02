import 'package:dox_query_builder/dox_query_builder.dart';

import 'shared_mixin.dart';

mixin Truncate<T> implements SharedMixin<T> {
  /// Truncate table
  ///
  /// ```
  /// await Blog().truncate();
  /// await Blog().truncate(resetId: true);
  /// ```
  Future<void> truncate({bool resetId = true}) async {
    String reset = resetId
        ? queryBuilder.dbDriver.getName() == Driver.postgres
            ? 'RESTART IDENTITY CASCADE'
            : ''
        : '';
    String query = "TRUNCATE TABLE $tableName $reset";
    await helper.runQuery(query);
  }
}
