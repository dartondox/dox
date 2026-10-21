import 'grammars/schema_grammar.dart';
import 'table.column.dart';

enum CommandType {
  drop,
  dropIfExists,
  rename,
  dropColumn,
  renameColumn,
  addIndex,
  unique,
  primary,
  dropIndex,
  dropUnique,
  foreign,
  dropForeign,
}

/// one table level change (index, foreign key, drop, rename, ...)
class TableCommand {
  final CommandType type;
  final List<String> columns;
  final String? name;
  final String? to;
  final ForeignKeyDefinition? foreign;

  const TableCommand(
    this.type, {
    this.columns = const <String>[],
    this.name,
    this.to,
    this.foreign,
  });
}

/// the blueprint of a table: its columns and commands.
/// `Schema` gives it to your callback, then runs its sql.
///
/// ```
/// await schema.create('posts', (Table table) {
///   table.id();
///   table.foreignId('user_id').constrained().cascadeOnDelete();
///   table.string('title');
///   table.timestamps();
/// });
/// ```
class Table {
  final String name;

  /// true in `Schema.create`, false in `Schema.table`
  final bool creating;

  final List<ColumnDefinition> columns = <ColumnDefinition>[];
  final List<TableCommand> commands = <TableCommand>[];

  Table(this.name, {this.creating = false});

  /// sql for this table, for the database of [grammar]
  List<String> toSql(SchemaGrammar grammar) => grammar.compile(this);

  ColumnDefinition _add(ColumnDefinition column) {
    columns.add(column);
    return column;
  }

  ColumnDefinition _col(String name, ColumnType type) {
    return _add(ColumnDefinition(name, type));
  }

  // ---------------------------------------------------------------
  // ids
  // ---------------------------------------------------------------

  /// auto increment big integer primary key
  ColumnDefinition id([String name = 'id']) => bigIncrements(name);

  ColumnDefinition bigIncrements(String name) {
    return _col(name, ColumnType.bigIncrements)
      ..autoIncrement = true
      ..isUnsigned = true;
  }

  ColumnDefinition increments(String name) {
    return _col(name, ColumnType.increments)
      ..autoIncrement = true
      ..isUnsigned = true;
  }

  // ---------------------------------------------------------------
  // text
  // ---------------------------------------------------------------

  ColumnDefinition char(String name, [int length = 255]) {
    return _add(ColumnDefinition(name, ColumnType.char, length: length));
  }

  ColumnDefinition string(String name, [int length = 255]) {
    return _add(ColumnDefinition(name, ColumnType.string, length: length));
  }

  ColumnDefinition text(String name) => _col(name, ColumnType.text);

  ColumnDefinition mediumText(String name) {
    return _col(name, ColumnType.mediumText);
  }

  ColumnDefinition longText(String name) => _col(name, ColumnType.longText);

  // ---------------------------------------------------------------
  // numbers
  // ---------------------------------------------------------------

  ColumnDefinition integer(String name) => _col(name, ColumnType.integer);

  ColumnDefinition bigInteger(String name) {
    return _col(name, ColumnType.bigInteger);
  }

  ColumnDefinition smallInteger(String name) {
    return _col(name, ColumnType.smallInteger);
  }

  ColumnDefinition tinyInteger(String name) {
    return _col(name, ColumnType.tinyInteger);
  }

  ColumnDefinition unsignedInteger(String name) => integer(name).unsigned();

  ColumnDefinition unsignedBigInteger(String name) {
    return bigInteger(name).unsigned();
  }

  ColumnDefinition unsignedSmallInteger(String name) {
    return smallInteger(name).unsigned();
  }

  ColumnDefinition unsignedTinyInteger(String name) {
    return tinyInteger(name).unsigned();
  }

  ColumnDefinition float(String name) => _col(name, ColumnType.float);

  ColumnDefinition double(String name) => _col(name, ColumnType.double);

  ColumnDefinition decimal(String name, [int precision = 8, int scale = 2]) {
    return _add(
      ColumnDefinition(
        name,
        ColumnType.decimal,
        precision: precision,
        scale: scale,
      ),
    );
  }

  // ---------------------------------------------------------------
  // other types
  // ---------------------------------------------------------------

  ColumnDefinition boolean(String name) => _col(name, ColumnType.boolean);

  ColumnDefinition date(String name) => _col(name, ColumnType.date);

  ColumnDefinition dateTime(String name) => _col(name, ColumnType.dateTime);

  ColumnDefinition dateTimeTz(String name) {
    return _col(name, ColumnType.dateTimeTz);
  }

  ColumnDefinition time(String name) => _col(name, ColumnType.time);

  ColumnDefinition timestamp(String name) {
    return _col(name, ColumnType.timestamp);
  }

  ColumnDefinition timestampTz(String name) {
    return _col(name, ColumnType.timestampTz);
  }

  ColumnDefinition json(String name) => _col(name, ColumnType.json);

  ColumnDefinition jsonb(String name) => _col(name, ColumnType.jsonb);

  ColumnDefinition uuid([String name = 'uuid']) {
    return _col(name, ColumnType.uuid);
  }

  ColumnDefinition binary(String name) => _col(name, ColumnType.binary);

  /// a column that only takes one of [values].
  /// ENUM on mysql, a CHECK constraint on postgres and sqlite.
  ColumnDefinition enumeration(String name, List<String> values) {
    return _add(
      ColumnDefinition(name, ColumnType.enumeration, allowed: values),
    );
  }

  /// big unsigned integer for a foreign key, add `.constrained()`
  ForeignIdColumnDefinition foreignId(String name) {
    ForeignIdColumnDefinition col = ForeignIdColumnDefinition(
      this,
      name,
      ColumnType.bigInteger,
    )..isUnsigned = true;
    columns.add(col);
    return col;
  }

  /// uuid column for a foreign key, add `.constrained()`
  ForeignIdColumnDefinition foreignUuid(String name) {
    ForeignIdColumnDefinition col = ForeignIdColumnDefinition(
      this,
      name,
      ColumnType.uuid,
    );
    columns.add(col);
    return col;
  }

  /// nullable `created_at` and `updated_at`
  /// (TIMESTAMPTZ on postgres, TIMESTAMP on others)
  void timestamps() {
    timestampTz('created_at').nullable();
    timestampTz('updated_at').nullable();
  }

  /// nullable `deleted_at`, used by `SoftDeletes`
  ColumnDefinition softDeletes([String name = 'deleted_at']) {
    return timestampTz(name).nullable();
  }

  /// nullable `remember_token` VARCHAR(100)
  ColumnDefinition rememberToken() {
    return string('remember_token', 100).nullable();
  }

  /// `{name}_id` and `{name}_type` with an index on both
  void morphs(String name) {
    unsignedBigInteger('${name}_id');
    string('${name}_type');
    index(<String>['${name}_type', '${name}_id']);
  }

  // ---------------------------------------------------------------
  // columns changes
  // ---------------------------------------------------------------

  void dropColumn(String name) {
    commands.add(TableCommand(CommandType.dropColumn, columns: <String>[name]));
  }

  void dropColumns(List<String> names) {
    for (String name in names) {
      dropColumn(name);
    }
  }

  void renameColumn(String from, String to) {
    commands.add(
      TableCommand(CommandType.renameColumn, columns: <String>[from], to: to),
    );
  }

  // ---------------------------------------------------------------
  // indexes and keys. [columns] is a String or a List<String>.
  // ---------------------------------------------------------------

  /// `{table}_{columns}_{type}`, eg. `users_email_unique`
  String indexName(String type, List<String> columns) {
    return '${name}_${columns.join('_')}_$type'.toLowerCase().replaceAll(
      RegExp(r'[-.]'),
      '_',
    );
  }

  void _index(CommandType type, String suffix, Object columns, String? name) {
    List<String> cols = columnList(columns);
    commands.add(
      TableCommand(type, columns: cols, name: name ?? indexName(suffix, cols)),
    );
  }

  void index(Object columns, [String? name]) {
    _index(CommandType.addIndex, 'index', columns, name);
  }

  void unique(Object columns, [String? name]) {
    _index(CommandType.unique, 'unique', columns, name);
  }

  void primary(Object columns) {
    commands.add(
      TableCommand(CommandType.primary, columns: columnList(columns)),
    );
  }

  ForeignKeyDefinition foreign(Object columns, [String? name]) {
    List<String> cols = columnList(columns);
    ForeignKeyDefinition fk = ForeignKeyDefinition(
      cols,
      name ?? indexName('foreign', cols),
    );
    commands.add(TableCommand(CommandType.foreign, foreign: fk));
    return fk;
  }

  /// [index] is the index name, or its columns (`List<String>`)
  void dropIndex(Object index) => _drop(CommandType.dropIndex, 'index', index);

  void dropUnique(Object index) {
    _drop(CommandType.dropUnique, 'unique', index);
  }

  void dropForeign(Object index) {
    _drop(CommandType.dropForeign, 'foreign', index);
  }

  void _drop(CommandType type, String suffix, Object index) {
    String name = index is String
        ? index
        : indexName(suffix, columnList(index));
    commands.add(TableCommand(type, name: name));
  }

  // ---------------------------------------------------------------
  // table
  // ---------------------------------------------------------------

  void drop() => commands.add(const TableCommand(CommandType.drop));

  void dropIfExists() {
    commands.add(const TableCommand(CommandType.dropIfExists));
  }

  void rename(String to) {
    commands.add(TableCommand(CommandType.rename, to: to));
  }

  /// sqlite can not change a column or add/drop a foreign key with ALTER,
  /// `Schema` rebuilds the table for these
  bool get needsSqliteRebuild {
    return !creating &&
        (columns.any((ColumnDefinition c) => c.isChange) ||
            commands.any(_isForeignCommand));
  }

  /// this table without the changes that need a sqlite rebuild
  Table withoutSqliteRebuild() {
    Table table = Table(name);
    table.columns.addAll(columns.where((ColumnDefinition c) => !c.isChange));
    table.commands.addAll(
      commands.where((TableCommand c) => !_isForeignCommand(c)),
    );
    return table;
  }

  static bool _isForeignCommand(TableCommand c) {
    return c.type == CommandType.foreign || c.type == CommandType.dropForeign;
  }
}
