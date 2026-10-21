import '../table.column.dart';
import '../table.dart';
import 'schema_grammar.dart';

/// mysql and mariadb
class MysqlGrammar extends SchemaGrammar {
  const MysqlGrammar();

  @override
  String get quote => '`';

  @override
  String typeOf(ColumnDefinition column) {
    switch (column.type) {
      case ColumnType.bigIncrements:
      case ColumnType.bigInteger:
        return 'BIGINT';
      case ColumnType.increments:
      case ColumnType.integer:
        return 'INT';
      case ColumnType.char:
        return 'CHAR(${column.length})';
      case ColumnType.string:
        return 'VARCHAR(${column.length})';
      case ColumnType.text:
        return 'TEXT';
      case ColumnType.mediumText:
        return 'MEDIUMTEXT';
      case ColumnType.longText:
        return 'LONGTEXT';
      case ColumnType.smallInteger:
        return 'SMALLINT';
      case ColumnType.tinyInteger:
        return 'TINYINT';
      case ColumnType.float:
        return 'FLOAT';
      case ColumnType.double:
        return 'DOUBLE';
      case ColumnType.decimal:
        return 'DECIMAL(${column.precision}, ${column.scale})';
      case ColumnType.boolean:
        return 'TINYINT(1)';
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
      case ColumnType.json:
      case ColumnType.jsonb:
        return 'JSON';
      case ColumnType.uuid:
        return 'CHAR(36)';
      case ColumnType.binary:
        return 'BLOB';
      case ColumnType.enumeration:
        return 'ENUM(${column.allowed.map(quoteString).join(', ')})';
    }
  }

  /// text, blob and json columns only take a default in `(...)`
  static const Set<ColumnType> _expressionDefault = <ColumnType>{
    ColumnType.text,
    ColumnType.mediumText,
    ColumnType.longText,
    ColumnType.json,
    ColumnType.jsonb,
    ColumnType.binary,
  };

  @override
  String columnSql(Table table, ColumnDefinition column) {
    StringBuffer sql = StringBuffer('${wrap(column.name)} ${typeOf(column)}');
    if (column.isUnsigned) sql.write(' UNSIGNED');
    sql.write(column.isNullable ? ' NULL' : ' NOT NULL');
    String def = defaultSql(column);
    if (column.rawDefault == null &&
        column.hasDefault &&
        _expressionDefault.contains(column.type)) {
      def = ' DEFAULT (${literal(column.defaultValue)})';
    }
    sql.write(def);
    if (column.currentOnUpdate) sql.write(' ON UPDATE CURRENT_TIMESTAMP');
    if (column.autoIncrement) sql.write(' AUTO_INCREMENT');

    /// MODIFY of a key column must not add the primary key again
    if ((column.autoIncrement || column.isPrimary) && !column.isChange) {
      sql.write(' PRIMARY KEY');
    }
    if (column.commentText != null) {
      sql.write(' COMMENT ${quoteString(column.commentText!)}');
    }
    if (column.afterColumn != null && !table.creating) {
      sql.write(' AFTER ${wrap(column.afterColumn!)}');
    }
    return sql.toString();
  }

  @override
  List<String> compileChange(Table table, ColumnDefinition column) {
    return <String>[
      'ALTER TABLE ${wrap(table.name)} MODIFY COLUMN ${columnSql(table, column)}',
    ];
  }

  @override
  String literal(Object? value) {
    if (value is bool) return value ? '1' : '0';
    return super.literal(value);
  }

  /// mysql reads backslash as an escape char inside strings
  @override
  String quoteString(String value) {
    return super.quoteString(value.replaceAll(r'\', r'\\'));
  }

  @override
  String compileDropIndex(Table table, String name) {
    return 'DROP INDEX ${wrap(name)} ON ${wrap(table.name)}';
  }

  @override
  String compileDropForeign(Table table, String name) {
    return 'ALTER TABLE ${wrap(table.name)} DROP FOREIGN KEY ${wrap(name)}';
  }

  @override
  String compileTableExists() {
    return 'SELECT 1 FROM information_schema.tables '
        'WHERE table_schema = DATABASE() AND table_name = @table';
  }

  @override
  String compileColumnListing() {
    return 'SELECT column_name FROM information_schema.columns '
        'WHERE table_schema = DATABASE() AND table_name = @table '
        'ORDER BY ordinal_position';
  }
}
