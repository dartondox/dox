import '/dox_query_builder.dart';

class Schema {
  /// create table with schema
  ///
  /// ```
  /// await Schema.create('table', (Table table) {
  ///   table.id();
  ///   table.string('title').nullable();
  ///   table.string('status').withDefault('active');
  ///   table.text('body');
  ///   table.softDeletes();
  ///   table.timestamps();
  /// });
  /// ```
  static Future<void> create(String tableName, Function(Table) callback) async {
    Table table = Table().table(tableName);
    callback(table);
    await table.create();
  }

  /// update table with schema
  ///
  /// ```
  /// await Schema.table('table', (Table table) {
  ///   table.id();
  ///   table.string('title').nullable();
  ///   table.string('status').withDefault('active');
  ///   table.text('body');
  ///   table.softDeletes();
  ///   table.timestamps();
  /// });
  /// ```
  static Future<void> table(String tableName, Function(Table) callback) async {
    Table table = Table().table(tableName);
    callback(table);
    await table.update();
  }

  /// drop table
  ///
  /// ```
  /// await Schema.drop('table');
  /// ```
  static Future<void> drop(String tableName) async {
    await SqlQueryBuilder()
        .db
        .query("DROP TABLE IF EXISTS $tableName RESTRICT");
  }
}
