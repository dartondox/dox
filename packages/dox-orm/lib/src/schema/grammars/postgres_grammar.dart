import '../table.column.dart';
import '../table.dart';
import 'schema_grammar.dart';

class PostgresGrammar extends SchemaGrammar {
  const PostgresGrammar();

  @override
  String get quote => '"';

  @override
  String typeOf(ColumnDefinition column) {
    switch (column.type) {
      case ColumnType.bigIncrements:
        return 'BIGSERIAL';
      case ColumnType.increments:
        return 'SERIAL';
      case ColumnType.char:
        return 'CHAR(${column.length})';
      case ColumnType.string:
        return 'VARCHAR(${column.length})';
      case ColumnType.text:
      case ColumnType.mediumText:
      case ColumnType.longText:
        return 'TEXT';
      case ColumnType.integer:
        return 'INTEGER';
      case ColumnType.bigInteger:
        return 'BIGINT';
      case ColumnType.smallInteger:
      case ColumnType.tinyInteger:
        return 'SMALLINT';
      case ColumnType.float:
        return 'REAL';
      case ColumnType.double:
        return 'DOUBLE PRECISION';
      case ColumnType.decimal:
        return 'DECIMAL(${column.precision}, ${column.scale})';
      case ColumnType.boolean:
        return 'BOOLEAN';
      case ColumnType.date:
        return 'DATE';
      case ColumnType.dateTime:
      case ColumnType.timestamp:
        return 'TIMESTAMP';
      case ColumnType.dateTimeTz:
      case ColumnType.timestampTz:
        return 'TIMESTAMPTZ';
      case ColumnType.time:
        return 'TIME';
      case ColumnType.json:
      case ColumnType.jsonb:
        return 'JSONB';
      case ColumnType.uuid:
        return 'UUID';
      case ColumnType.binary:
        return 'BYTEA';
      case ColumnType.enumeration:
        return 'VARCHAR(255)';
    }
  }

  @override
  String columnSql(Table table, ColumnDefinition column) {
    StringBuffer sql = StringBuffer('${wrap(column.name)} ${typeOf(column)}');
    if (!column.isNullable) sql.write(' NOT NULL');
    sql.write(defaultSql(column));
    if (column.autoIncrement || column.isPrimary) sql.write(' PRIMARY KEY');
    sql.write(enumCheck(column));
    return sql.toString();
  }

  /// one ALTER TABLE: type, null, default and the enum check.
  /// the old check (auto named `{table}_{column}_check`) is dropped first.
  @override
  List<String> compileChange(Table table, ColumnDefinition column) {
    if (column.autoIncrement) {
      throw UnsupportedError(
        'postgres: change() of an auto increment column is not supported',
      );
    }
    String col = wrap(column.name);
    String type = typeOf(column);
    String def = defaultSql(column);
    String check = wrap('${table.name}_${column.name}_check');
    List<String> parts = <String>[
      'ALTER COLUMN $col TYPE $type USING $col::$type',
      'ALTER COLUMN $col ${column.isNullable ? 'DROP NOT NULL' : 'SET NOT NULL'}',
      'ALTER COLUMN $col ${def.isEmpty ? 'DROP DEFAULT' : 'SET$def'}',
      'DROP CONSTRAINT IF EXISTS $check',
      if (column.type == ColumnType.enumeration)
        'ADD CONSTRAINT $check${enumCheck(column)}',
    ];
    return <String>['ALTER TABLE ${wrap(table.name)} ${parts.join(', ')}'];
  }

  @override
  String? compileComment(Table table, ColumnDefinition column) {
    if (column.commentText == null) return null;
    return 'COMMENT ON COLUMN ${wrap(table.name)}.${wrap(column.name)} IS ${quoteString(column.commentText!)}';
  }

  @override
  String compileTableExists() {
    return 'SELECT 1 FROM information_schema.tables '
        'WHERE table_schema = current_schema() AND table_name = @table';
  }

  @override
  String compileColumnListing() {
    return 'SELECT column_name FROM information_schema.columns '
        'WHERE table_schema = current_schema() AND table_name = @table '
        'ORDER BY ordinal_position';
  }
}
