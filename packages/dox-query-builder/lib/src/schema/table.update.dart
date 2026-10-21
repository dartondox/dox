import 'package:dox_query_builder/dox_query_builder.dart';

import 'table.column.dart';
import 'table.shared_mixin.dart';

mixin TableUpdate implements TableSharedMixin {
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

  Future<void> _handleDrop(TableColumn col) async {
    String query = 'ALTER TABLE $tableName DROP COLUMN ${col.name}';
    await _runQuery(query);
  }

  Future<void> _handleRename(TableColumn col) async {
    String query =
        'ALTER TABLE $tableName RENAME COLUMN ${col.name} TO ${col.renameTo}';
    await _runQuery(query);
  }

  Future<void> _handleAdd(TableColumn col) async {
    String defaultQuery =
        col.defaultValue != null ? " DEFAULT '${col.defaultValue}'" : '';
    String unique = col.isUnique ? ' UNIQUE' : '';
    String query =
        "ALTER TABLE $tableName ADD COLUMN ${col.name} ${col.type} ${col.isNullable ? 'NULL' : 'NOT NULL'}$defaultQuery$unique";
    await _runQuery(query);
  }

  Future<void> _handleAlter(TableColumn col) async {
    List<String> queries = <String>[];

    String defaultQuery =
        col.defaultValue != null ? " DEFAULT '${col.defaultValue}'" : '';

    if (dbDriver.getName() == Driver.mysql) {
      /// mysql MODIFY need the type and reset all column options,
      /// so type, null and default must go in one query
      queries.add(
          "MODIFY COLUMN ${col.name} ${col.type} ${col.isNullable ? 'NULL' : 'NOT NULL'}$defaultQuery");
    } else {
      /// changing type
      if (col.type != null) {
        queries.add("ALTER COLUMN ${col.name} TYPE ${col.type}");
      }

      /// changing default value
      if (col.defaultValue != null) {
        queries
            .add("ALTER COLUMN ${col.name} SET DEFAULT '${col.defaultValue}'");
      }

      /// set null
      queries.add(
          "ALTER COLUMN ${col.name} ${col.isNullable ? 'DROP NOT NULL' : 'SET NOT NULL'}");
    }

    /// set unique
    if (col.isUnique) {
      queries.add(
          "ADD CONSTRAINT unique_${tableName}_${col.name} UNIQUE (${col.name})");
    }

    /// run all queries
    for (String q in queries) {
      String query = "ALTER TABLE $tableName $q";
      await _runQuery(query);
    }
  }

  Future<void> _runQuery(String query) async {
    if (debug) {
      logger.log(query); // coverage:ignore-line
    }
    await dbDriver.execute(query);
  }

  Future<List<String>> getTableColumns() async {
    String query =
        "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '$tableName' AND TABLE_SCHEMA = ${dbDriver.getName() == Driver.mysql ? 'DATABASE()' : 'current_schema()'}";
    List<Map<String, dynamic>> result = await dbDriver.query(query);

    List<String> columns = <String>[];

    for (Map<String, dynamic> element in result) {
      element.forEach((String key2, dynamic value2) {
        columns.add(value2.toString());
      });
    }
    return columns;
  }
}
