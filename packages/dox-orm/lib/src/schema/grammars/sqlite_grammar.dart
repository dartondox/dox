import '../table.column.dart';
import '../table.dart';
import 'schema_grammar.dart';

/// sqlite. change(), foreign keys on an existing table and dropForeign
/// need a table rebuild; `Schema` runs it on the database
/// (`SqliteTableRebuilder`), so [compile] can not give sql for them.
class SqliteGrammar extends SchemaGrammar {
  const SqliteGrammar();

  @override
  String get quote => '"';

  @override
  String typeOf(ColumnDefinition column) {
    switch (column.type) {
      case ColumnType.bigIncrements:
      case ColumnType.increments:
      case ColumnType.integer:
      case ColumnType.bigInteger:
      case ColumnType.smallInteger:
      case ColumnType.tinyInteger:
        return 'INTEGER';
      case ColumnType.char:
        return 'CHAR(${column.length})';
      case ColumnType.string:
        return 'VARCHAR(${column.length})';
      case ColumnType.text:
      case ColumnType.mediumText:
      case ColumnType.longText:
      case ColumnType.uuid:
        return 'TEXT';
      case ColumnType.float:
        return 'FLOAT';
      case ColumnType.double:
        return 'DOUBLE';
      case ColumnType.decimal:
        return 'DECIMAL(${column.precision}, ${column.scale})';
      case ColumnType.boolean:
        return 'BOOLEAN';
      case ColumnType.date:
        return 'DATE';
      case ColumnType.dateTime:
      case ColumnType.dateTimeTz:
        return 'DATETIME';
      case ColumnType.time:
        return 'TIME';
      case ColumnType.timestamp:
      case ColumnType.timestampTz:
        return 'TIMESTAMP';

      /// the sqlite driver decodes columns declared as JSON
      case ColumnType.json:
      case ColumnType.jsonb:
        return 'JSON';
      case ColumnType.binary:
        return 'BLOB';
      case ColumnType.enumeration:
        return 'VARCHAR(255)';
    }
  }

  @override
  String columnSql(Table table, ColumnDefinition column) {
    StringBuffer sql = StringBuffer('${wrap(column.name)} ${typeOf(column)}');
    if (!column.isNullable) sql.write(' NOT NULL');
    sql.write(defaultSql(column));
    if (column.autoIncrement) {
      sql.write(' PRIMARY KEY AUTOINCREMENT');
    } else if (column.isPrimary) {
      sql.write(' PRIMARY KEY');
    }
    sql.write(enumCheck(column));
    return sql.toString();
  }

  /// sqlite ADD COLUMN takes one column per statement
  @override
  List<String> compileAdd(Table table, List<ColumnDefinition> columns) {
    return <String>[
      for (ColumnDefinition c in columns)
        'ALTER TABLE ${wrap(table.name)} ADD COLUMN ${columnSql(table, c)}',
    ];
  }

  @override
  List<String> compileChange(Table table, ColumnDefinition column) {
    throw UnsupportedError(
      'sqlite: change() rebuilds the table, it only runs on a database',
    );
  }

  @override
  List<String> compileCommand(Table table, TableCommand command) {
    if (!table.creating &&
        (command.type == CommandType.foreign ||
            command.type == CommandType.dropForeign)) {
      throw UnsupportedError(
        'sqlite: foreign keys on an existing table rebuild the table, '
        'it only runs on a database',
      );
    }
    if (!table.creating && command.type == CommandType.primary) {
      throw UnsupportedError(
        'sqlite: can not add a primary key to an existing table',
      );
    }
    return super.compileCommand(table, command);
  }

  /// no constraint name, sqlite does not keep it
  @override
  String foreignSql(ForeignKeyDefinition fk) => foreignBody(fk);

  @override
  String compileTableExists() {
    return "SELECT 1 FROM sqlite_schema WHERE type = 'table' AND name = @table";
  }

  @override
  String compileColumnListing() {
    return 'SELECT name FROM pragma_table_info(@table)';
  }
}
