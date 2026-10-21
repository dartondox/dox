import '/dox_orm.dart';
import 'schema/sqlite_rebuilder.dart';

export 'schema/grammars/mysql_grammar.dart';
export 'schema/grammars/postgres_grammar.dart';
export 'schema/grammars/schema_grammar.dart';
export 'schema/grammars/sqlite_grammar.dart';
export 'schema/table.column.dart';

/// create, change and drop tables, the same way on postgres, mysql,
/// mariadb and sqlite.
///
/// ```
/// Schema schema = Schema(); // uses the query builder connection
/// await schema.create('posts', (Table table) {
///   table.id();
///   table.foreignId('user_id').constrained().cascadeOnDelete();
///   table.string('title');
///   table.enumeration('status', <String>['draft', 'published'])
///       .defaultTo('draft');
///   table.timestamps();
/// });
/// await schema.table('posts', (Table table) {
///   table.text('body').nullable();
///   table.string('title', 500).change();
/// });
/// await schema.dropIfExists('posts');
/// ```
class Schema {
  final DBDriver driver;
  final SchemaGrammar grammar;

  /// [driver] default is the query builder driver (`SqlQueryBuilder`)
  factory Schema([DBDriver? driver]) {
    return Schema._(driver ?? SqlQueryBuilder().dbDriver);
  }

  Schema._(this.driver) : grammar = SchemaGrammar.of(driver.getName());

  /// create a table
  Future<void> create(String table, void Function(Table table) callback) {
    Table blueprint = Table(table, creating: true);
    callback(blueprint);
    return build(blueprint);
  }

  /// change a table: add columns, `change()` columns, indexes, keys
  Future<void> table(String table, void Function(Table table) callback) {
    Table blueprint = Table(table);
    callback(blueprint);
    return build(blueprint);
  }

  Future<void> drop(String table) => build(Table(table)..drop());

  Future<void> dropIfExists(String table) {
    return build(Table(table)..dropIfExists());
  }

  Future<void> rename(String from, String to) {
    return build(Table(from)..rename(to));
  }

  Future<bool> hasTable(String table) async {
    List<Map<String, dynamic>> rows = await driver.query(
      grammar.compileTableExists(),
      substitutionValues: <String, dynamic>{'table': table},
    );
    return rows.isNotEmpty;
  }

  Future<bool> hasColumn(String table, String column) async {
    return (await getColumnListing(table)).contains(column);
  }

  Future<List<String>> getColumnListing(String table) async {
    List<Map<String, dynamic>> rows = await driver.query(
      grammar.compileColumnListing(),
      substitutionValues: <String, dynamic>{'table': table},
    );
    return <String>[
      for (Map<String, dynamic> row in rows) row.values.first.toString(),
    ];
  }

  /// run the sql of [table], one statement at a time
  Future<void> build(Table table) async {
    if (grammar is SqliteGrammar && table.needsSqliteRebuild) {
      await _run(grammar.compile(table.withoutSqliteRebuild()));
      await SqliteTableRebuilder(
        driver,
        grammar as SqliteGrammar,
      ).rebuild(table);
      return;
    }
    await _run(grammar.compile(table));
  }

  Future<void> _run(List<String> statements) async {
    for (String sql in statements) {
      await driver.execute(sql);
    }
  }
}
