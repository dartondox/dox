import 'package:dox_query_builder/dox_query_builder.dart';

import 'table.column.dart';
import 'table.shared_mixin.dart';

mixin TableUpdate implements TableSharedMixin {
  String get _table => dbDriver.wrap(tableName);

  Future<void> update() async {
    for (TableColumn col in columns) {
      if (col.shouldDrop == true) {
        await _handleDrop(col);
      } else if (col.renameTo != null) {
        await _handleRename(col);
      } else {
        List<String> existingColumns = await getTableColumns();
        if (!existingColumns.contains(col.name)) {
          await _handleAdd(col);
        } else {
          await _handleAlter(col);
        }
      }
    }
  }

  /// ` DEFAULT 'value'` with quotes escaped, or empty string.
  /// bool default is TRUE/FALSE on postgres and 1/0 on mysql.
  String defaultQuery(TableColumn col) {
    dynamic value = col.defaultValue;
    if (value == null) {
      return '';
    }
    bool isMysql = dbDriver.getName() == Driver.mysql;
    if (value is bool) {
      String text = isMysql ? (value ? '1' : '0') : (value ? 'TRUE' : 'FALSE');
      return ' DEFAULT $text';
    }
    String text = value.toString();
    if (isMysql) {
      /// mysql read backslash as escape char inside strings
      text = text.replaceAll(r'\', r'\\');
    }
    return " DEFAULT '${text.replaceAll("'", "''")}'";
  }

  Future<void> _handleDrop(TableColumn col) async {
    String query = 'ALTER TABLE $_table DROP COLUMN ${dbDriver.wrap(col.name)}';
    await _runQuery(query);
  }

  Future<void> _handleRename(TableColumn col) async {
    String query =
        'ALTER TABLE $_table RENAME COLUMN ${dbDriver.wrap(col.name)} TO ${dbDriver.wrap(col.renameTo!)}';
    await _runQuery(query);
  }

  Future<void> _handleAdd(TableColumn col) async {
    String unique = col.isUnique ? ' UNIQUE' : '';
    String query =
        "ALTER TABLE $_table ADD COLUMN ${dbDriver.wrap(col.name)} ${col.type} ${col.isNullable ? 'NULL' : 'NOT NULL'}${defaultQuery(col)}$unique";
    await _runQuery(query);
  }

  Future<void> _handleAlter(TableColumn col) async {
    List<String> queries = <String>[];
    String name = dbDriver.wrap(col.name);

    if (dbDriver.getName() == Driver.mysql) {
      /// mysql MODIFY need the type and reset all column options,
      /// so type, null and default must go in one query
      queries.add(
          "MODIFY COLUMN $name ${col.type} ${col.isNullable ? 'NULL' : 'NOT NULL'}${defaultQuery(col)}");
    } else {
      /// changing type
      if (col.type != null) {
        queries.add("ALTER COLUMN $name TYPE ${col.type}");
      }

      /// changing default value
      if (col.defaultValue != null) {
        queries.add("ALTER COLUMN $name SET${defaultQuery(col)}");
      }

      /// set null
      queries.add(
          "ALTER COLUMN $name ${col.isNullable ? 'DROP NOT NULL' : 'SET NOT NULL'}");
    }

    /// set unique, only when the column is not unique yet
    if (col.isUnique && !await _isUnique(col.name)) {
      queries.add(
          "ADD CONSTRAINT ${dbDriver.wrap('unique_${tableName}_${col.name}')} UNIQUE ($name)");
    }

    /// run all queries
    for (String q in queries) {
      String query = "ALTER TABLE $_table $q";
      await _runQuery(query);
    }
  }

  /// true when the column already has a unique constraint
  Future<bool> _isUnique(String column) async {
    String schema =
        dbDriver.getName() == Driver.mysql ? 'DATABASE()' : 'current_schema()';
    List<Map<String, dynamic>> result = await dbDriver.query(
      "SELECT tc.constraint_name AS name FROM information_schema.table_constraints tc "
      "JOIN information_schema.key_column_usage kcu "
      "ON tc.constraint_name = kcu.constraint_name "
      "AND tc.table_schema = kcu.table_schema "
      "AND tc.table_name = kcu.table_name "
      "WHERE tc.constraint_type = 'UNIQUE' AND tc.table_schema = $schema "
      "AND tc.table_name = @table AND kcu.column_name = @column",
      substitutionValues: <String, dynamic>{
        'table': tableName,
        'column': column,
      },
    );
    return result.isNotEmpty;
  }

  Future<void> _runQuery(String query) async {
    if (debug) {
      logger.log(query); // coverage:ignore-line
    }
    await dbDriver.execute(query);
  }

  Future<List<String>> getTableColumns() async {
    String query =
        "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @table AND TABLE_SCHEMA = ${dbDriver.getName() == Driver.mysql ? 'DATABASE()' : 'current_schema()'}";
    List<Map<String, dynamic>> result = await dbDriver.query(query,
        substitutionValues: <String, dynamic>{'table': tableName});

    List<String> columns = <String>[];

    for (Map<String, dynamic> element in result) {
      element.forEach((String key2, dynamic value2) {
        columns.add(value2.toString());
      });
    }
    return columns;
  }
}
