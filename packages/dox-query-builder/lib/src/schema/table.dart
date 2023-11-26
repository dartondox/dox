import 'package:dox_query_builder/dox_query_builder.dart';

import '../utils/logger.dart';
import 'table.column.dart';
import 'table.update.dart';

class Table with TableUpdate {
  @override
  final List<TableColumn> columns = <TableColumn>[];
  @override
  String tableName = '';

  @override
  bool debug = SqlQueryBuilder().debug;

  @override
  DBDriver get db => SqlQueryBuilder().db;

  // coverage:ignore-start
  @override
  Logger get logger => Logger();
  // coverage:ignore-end

  Table table(String table) {
    tableName = table;
    return this;
  }

  void id([dynamic column]) {
    columns.add(TableColumn(name: column ?? 'id', type: "SERIAL PRIMARY KEY"));
  }

  TableColumn uuid([dynamic column]) {
    TableColumn col = TableColumn(name: column ?? 'uuid', type: 'UUID');
    columns.add(col);
    return col;
  }

  TableColumn integer(String name) {
    TableColumn col = TableColumn(name: name, type: 'INTEGER');
    columns.add(col);
    return col;
  }

  TableColumn bigInteger(String name) {
    TableColumn col = TableColumn(name: name, type: 'BIGINT');
    columns.add(col);
    return col;
  }

  TableColumn string(String name, [dynamic length]) {
    TableColumn col =
        TableColumn(name: name, type: "VARCHAR(${length ?? '100'})");
    columns.add(col);
    return col;
  }

  TableColumn char(String name, [dynamic length]) {
    TableColumn col = TableColumn(name: name, type: "CHAR(${length ?? '8'})");
    columns.add(col);
    return col;
  }

  TableColumn money(String name) {
    TableColumn col = TableColumn(name: name, type: "MONEY");
    columns.add(col);
    return col;
  }

  TableColumn json(String name) {
    TableColumn col = TableColumn(name: name, type: "JSON");
    columns.add(col);
    return col;
  }

  TableColumn jsonb(String name) {
    TableColumn col = TableColumn(name: name, type: "JSONB");
    columns.add(col);
    return col;
  }

  TableColumn decimal(String name, [dynamic length, dynamic decimalPoint]) {
    TableColumn col = TableColumn(
        name: name, type: "DECIMAL(${length ?? '8'}, ${decimalPoint ?? '2'})");
    columns.add(col);
    return col;
  }

  TableColumn float4(String name) {
    TableColumn col = TableColumn(name: name, type: "float4");
    columns.add(col);
    return col;
  }

  TableColumn float8(String name) {
    TableColumn col = TableColumn(name: name, type: "float8");
    columns.add(col);
    return col;
  }

  TableColumn text(String name) {
    TableColumn col = TableColumn(name: name, type: 'TEXT');
    columns.add(col);
    return col;
  }

  TableColumn timestamp(String name) {
    TableColumn col = TableColumn(name: name, type: 'TIMESTAMP');
    columns.add(col);
    return col;
  }

  TableColumn date(String name) {
    TableColumn col = TableColumn(name: name, type: 'DATE');
    columns.add(col);
    return col;
  }

  TableColumn time(String name) {
    TableColumn col = TableColumn(name: name, type: 'TIME');
    columns.add(col);
    return col;
  }

  TableColumn timestampTz(String name) {
    TableColumn col = TableColumn(name: name, type: 'TIMESTAMPTZ');
    columns.add(col);
    return col;
  }

  TableColumn softDeletes([dynamic name]) {
    TableColumn col =
        TableColumn(name: name ?? 'deleted_at', type: 'TIMESTAMPTZ').nullable();
    columns.add(col);
    return col;
  }

  void timestamps() {
    TableColumn createdAt =
        TableColumn(name: 'created_at', type: 'TIMESTAMPTZ').nullable();
    TableColumn updatedAt =
        TableColumn(name: 'updated_at', type: 'TIMESTAMPTZ').nullable();
    columns.add(createdAt);
    columns.add(updatedAt);
  }

  void dropColumn(String name) {
    TableColumn col = TableColumn(name: name, shouldDrop: true);
    columns.add(col);
  }

  void renameColumn(String from, String to) {
    TableColumn col = TableColumn(name: from, renameTo: to);
    columns.add(col);
  }

  Future<void> create() async {
    String query = "CREATE TABLE IF NOT EXISTS $tableName (";

    List<String> ret = <String>[];
    for (TableColumn col in columns) {
      String defaultQuery =
          col.defaultValue != null ? " DEFAULT '${col.defaultValue}'" : '';
      String unique = col.isUnique ? ' UNIQUE' : '';

      ret.add(
          "${col.name} ${col.type} ${col.isNullable ? 'NULL' : 'NOT NULL'}$defaultQuery$unique");
    }

    query += ret.join(',');
    query += ")";
    if (debug) {
      logger.log(query); // coverage:ignore-line
    }
    await db.mappedResultsQuery(query);
  }
}
