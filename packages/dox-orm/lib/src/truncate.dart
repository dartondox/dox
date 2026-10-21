import 'package:dox_orm/dox_orm.dart';

import 'shared_mixin.dart';

mixin Truncate<T> implements SharedMixin<T> {
  /// Truncate table
  ///
  /// ```
  /// await Blog().truncate();
  /// await Blog().truncate(resetId: true);
  /// ```
  Future<void> truncate({bool resetId = true}) async {
    /// sqlite has no TRUNCATE, delete all rows and reset the id counter
    if (queryBuilder.dbDriver.getName() == Driver.sqlite) {
      await helper.runQuery("DELETE FROM ${helper.wrap(tableName)}");
      if (resetId) {
        await _resetSqliteSequence();
      }
      return;
    }
    String reset = resetId
        ? queryBuilder.dbDriver.getName() == Driver.postgres
            ? 'RESTART IDENTITY CASCADE'
            : ''
        : '';
    String query = "TRUNCATE TABLE ${helper.wrap(tableName)} $reset";
    await helper.runQuery(query);
  }

  /// sqlite_sequence only exists after a table with AUTOINCREMENT is made
  Future<void> _resetSqliteSequence() async {
    List<Map<String, dynamic>> exists = await queryBuilder.dbDriver.query(
      "SELECT 1 FROM sqlite_schema WHERE name = 'sqlite_sequence'",
    );
    if (exists.isNotEmpty) {
      await queryBuilder.dbDriver.execute(
        'DELETE FROM sqlite_sequence WHERE name = @table',
        substitutionValues: <String, dynamic>{'table': tableName},
      );
    }
  }
}
