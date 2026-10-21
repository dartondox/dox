import 'dart:convert';

import '../../drivers/db_driver.dart';
import '../table.column.dart';
import '../table.dart';
import 'mysql_grammar.dart';
import 'postgres_grammar.dart';
import 'sqlite_grammar.dart';

/// turns a [Table] blueprint into sql statements for one database.
/// [PostgresGrammar], [MysqlGrammar] and [SqliteGrammar] give the types
/// and the parts that are different per database.
abstract class SchemaGrammar {
  const SchemaGrammar();

  factory SchemaGrammar.of(Driver driver) {
    switch (driver) {
      case Driver.postgres:
        return const PostgresGrammar();
      case Driver.mysql:
        return const MysqlGrammar();
      case Driver.sqlite:
        return const SqliteGrammar();
    }
  }

  /// `"` on postgres and sqlite, `` ` `` on mysql
  String get quote;

  /// sql type of [column], eg. `VARCHAR(255)`
  String typeOf(ColumnDefinition column);

  /// full column sql, eg. `"email" VARCHAR(255) NOT NULL`
  String columnSql(Table table, ColumnDefinition column);

  /// sql to change an existing column
  List<String> compileChange(Table table, ColumnDefinition column);

  /// sql that gives one row when the table exists, uses `@table`
  String compileTableExists();

  /// sql that lists the column names (first column), uses `@table`
  String compileColumnListing();

  String wrap(String name) {
    return name
        .split('.')
        .map((String part) =>
            '$quote${part.replaceAll(quote, '$quote$quote')}$quote')
        .join('.');
  }

  String columnize(List<String> columns) => columns.map(wrap).join(', ');

  /// all statements of [table], in order: create or add columns,
  /// change columns, then the commands.
  List<String> compile(Table table) {
    List<String> sql = <String>[];
    if (table.creating) {
      sql.add(compileCreate(table));
      sql.addAll(columnExtras(table, table.columns));
    } else {
      List<ColumnDefinition> adds = <ColumnDefinition>[
        for (ColumnDefinition c in table.columns)
          if (!c.isChange) c,
      ];
      if (adds.isNotEmpty) {
        sql.addAll(compileAdd(table, adds));
        sql.addAll(columnExtras(table, adds));
      }
      for (ColumnDefinition c in table.columns) {
        if (c.isChange) {
          sql.addAll(compileChange(table, c));
          sql.addAll(columnExtras(table, <ColumnDefinition>[c]));
        }
      }
    }
    for (TableCommand command in table.commands) {
      sql.addAll(compileCommand(table, command));
    }
    return sql;
  }

  String compileCreate(Table table) {
    List<String> defs = <String>[
      for (ColumnDefinition c in table.columns) columnSql(table, c),
    ];
    for (TableCommand command in table.commands) {
      if (command.type == CommandType.primary) {
        defs.add('PRIMARY KEY (${columnize(command.columns)})');
      } else if (command.type == CommandType.foreign) {
        defs.add(foreignSql(command.foreign!));
      }
    }
    return 'CREATE TABLE ${wrap(table.name)} (${defs.join(', ')})';
  }

  /// one ALTER TABLE for all new columns
  List<String> compileAdd(Table table, List<ColumnDefinition> columns) {
    String adds = columns
        .map((ColumnDefinition c) => 'ADD COLUMN ${columnSql(table, c)}')
        .join(', ');
    return <String>['ALTER TABLE ${wrap(table.name)} $adds'];
  }

  /// column level index, unique index and comment
  List<String> columnExtras(Table table, List<ColumnDefinition> columns) {
    List<String> sql = <String>[];
    for (ColumnDefinition c in columns) {
      List<String> cols = <String>[c.name];
      if (c.isUnique) {
        sql.add(compileIndex(
            table, 'UNIQUE INDEX', table.indexName('unique', cols), cols));
      }
      if (c.isIndex) {
        sql.add(
            compileIndex(table, 'INDEX', table.indexName('index', cols), cols));
      }
      String? comment = compileComment(table, c);
      if (comment != null) {
        sql.add(comment);
      }
    }
    return sql;
  }

  /// postgres only, as a separate statement
  String? compileComment(Table table, ColumnDefinition column) => null;

  List<String> compileCommand(Table table, TableCommand command) {
    String t = wrap(table.name);
    switch (command.type) {
      case CommandType.drop:
        return <String>['DROP TABLE $t'];
      case CommandType.dropIfExists:
        return <String>['DROP TABLE IF EXISTS $t'];
      case CommandType.rename:
        return <String>['ALTER TABLE $t RENAME TO ${wrap(command.to!)}'];
      case CommandType.dropColumn:
        return <String>[
          'ALTER TABLE $t DROP COLUMN ${wrap(command.columns.first)}',
        ];
      case CommandType.renameColumn:
        return <String>[
          'ALTER TABLE $t RENAME COLUMN ${wrap(command.columns.first)} TO ${wrap(command.to!)}',
        ];
      case CommandType.addIndex:
        return <String>[
          compileIndex(table, 'INDEX', command.name!, command.columns)
        ];
      case CommandType.unique:
        return <String>[
          compileIndex(table, 'UNIQUE INDEX', command.name!, command.columns),
        ];
      case CommandType.primary:
        if (table.creating) return <String>[];
        return <String>[
          'ALTER TABLE $t ADD PRIMARY KEY (${columnize(command.columns)})'
        ];
      case CommandType.dropIndex:
      case CommandType.dropUnique:
        return <String>[compileDropIndex(table, command.name!)];
      case CommandType.foreign:
        if (table.creating) return <String>[];
        return <String>['ALTER TABLE $t ADD ${foreignSql(command.foreign!)}'];
      case CommandType.dropForeign:
        return <String>[compileDropForeign(table, command.name!)];
    }
  }

  String compileIndex(
      Table table, String kind, String name, List<String> columns) {
    return 'CREATE $kind ${wrap(name)} ON ${wrap(table.name)} (${columnize(columns)})';
  }

  String compileDropIndex(Table table, String name) =>
      'DROP INDEX ${wrap(name)}';

  String compileDropForeign(Table table, String name) {
    return 'ALTER TABLE ${wrap(table.name)} DROP CONSTRAINT ${wrap(name)}';
  }

  /// `CONSTRAINT name FOREIGN KEY (...) REFERENCES t (...) ON DELETE ...`
  String foreignSql(ForeignKeyDefinition fk) {
    return 'CONSTRAINT ${wrap(fk.name)} ${foreignBody(fk)}';
  }

  String foreignBody(ForeignKeyDefinition fk) {
    if (fk.onTable == null) {
      throw StateError('foreign key ${fk.name}: call on(table)');
    }
    StringBuffer sql = StringBuffer(
      'FOREIGN KEY (${columnize(fk.columns)}) REFERENCES ${wrap(fk.onTable!)} (${columnize(fk.referenceColumns)})',
    );
    if (fk.deleteAction != null) {
      sql.write(' ON DELETE ${fk.deleteAction!.toUpperCase()}');
    }
    if (fk.updateAction != null) {
      sql.write(' ON UPDATE ${fk.updateAction!.toUpperCase()}');
    }
    return sql.toString();
  }

  /// ` DEFAULT ...` or empty string
  String defaultSql(ColumnDefinition column) {
    if (column.rawDefault != null) {
      return ' DEFAULT ${column.rawDefault}';
    }
    if (!column.hasDefault) {
      return '';
    }
    return ' DEFAULT ${literal(column.defaultValue)}';
  }

  /// a value as escaped sql
  String literal(Object? value) {
    if (value == null) return 'NULL';
    if (value is bool) return value ? 'TRUE' : 'FALSE';
    if (value is num) return value.toString();
    if (value is Map || value is List) return quoteString(jsonEncode(value));
    if (value is DateTime) return quoteString(value.toIso8601String());
    return quoteString(value.toString());
  }

  String quoteString(String value) => "'${value.replaceAll("'", "''")}'";

  /// ` CHECK ("col" IN ('a', 'b'))` for enumeration columns, else empty
  String enumCheck(ColumnDefinition column) {
    if (column.type != ColumnType.enumeration) return '';
    return ' CHECK (${wrap(column.name)} IN (${column.allowed.map(quoteString).join(', ')}))';
  }
}
