import 'package:dox_query_builder/dox_query_builder.dart';

import 'table.column.dart';
import 'table.shared_mixin.dart';

mixin TableUpdate implements TableSharedMixin {
  String get _table => dbDriver.wrap(tableName);

  bool get _isSqlite => dbDriver.getName() == Driver.sqlite;

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
    /// sqlite can not add a UNIQUE column, add a unique index after it
    String unique = col.isUnique && !_isSqlite ? ' UNIQUE' : '';
    String query =
        "ALTER TABLE $_table ADD COLUMN ${dbDriver.wrap(col.name)} ${col.type} ${col.isNullable ? 'NULL' : 'NOT NULL'}${defaultQuery(col)}$unique";
    await _runQuery(query);
    if (col.isUnique && _isSqlite) {
      await _runQuery(_sqliteUniqueIndex(col.name));
    }
  }

  String _sqliteUniqueIndex(String column) {
    return "CREATE UNIQUE INDEX IF NOT EXISTS ${dbDriver.wrap('unique_${tableName}_$column')} ON $_table (${dbDriver.wrap(column)})";
  }

  Future<void> _handleAlter(TableColumn col) async {
    List<String> queries = <String>[];
    String name = dbDriver.wrap(col.name);

    if (_isSqlite) {
      await _rebuildSqliteTable(col);
      if (col.isUnique && !await _isUnique(col.name)) {
        await _runQuery(_sqliteUniqueIndex(col.name));
      }
      return;
    }

    if (dbDriver.getName() == Driver.mysql) {
      /// mysql MODIFY need the type and reset all column options,
      /// so type, null and default must go in one query
      queries.add(
        "MODIFY COLUMN $name ${col.type} ${col.isNullable ? 'NULL' : 'NOT NULL'}${defaultQuery(col)}",
      );
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
        "ALTER COLUMN $name ${col.isNullable ? 'DROP NOT NULL' : 'SET NOT NULL'}",
      );
    }

    /// set unique, only when the column is not unique yet
    if (col.isUnique && !await _isUnique(col.name)) {
      queries.add(
        "ADD CONSTRAINT ${dbDriver.wrap('unique_${tableName}_${col.name}')} UNIQUE ($name)",
      );
    }

    /// run all queries
    for (String q in queries) {
      String query = "ALTER TABLE $_table $q";
      await _runQuery(query);
    }
  }

  /// true when the column already has a unique constraint
  Future<bool> _isUnique(String column) async {
    if (_isSqlite) {
      List<Map<String, dynamic>> rows = await dbDriver.query(
        "SELECT l.name FROM pragma_index_list(@table) l "
        "JOIN pragma_index_info(l.name) i "
        "WHERE l.\"unique\" = 1 AND i.name = @column "
        "AND (SELECT COUNT(*) FROM pragma_index_info(l.name)) = 1",
        substitutionValues: <String, dynamic>{
          'table': tableName,
          'column': column,
        },
      );
      return rows.isNotEmpty;
    }
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
    String query = _isSqlite
        ? 'SELECT name FROM pragma_table_info(@table)'
        : "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @table AND TABLE_SCHEMA = ${dbDriver.getName() == Driver.mysql ? 'DATABASE()' : 'current_schema()'}";
    List<Map<String, dynamic>> result = await dbDriver.query(
      query,
      substitutionValues: <String, dynamic>{'table': tableName},
    );

    List<String> columns = <String>[];

    for (Map<String, dynamic> element in result) {
      element.forEach((String key2, dynamic value2) {
        columns.add(value2.toString());
      });
    }
    return columns;
  }

  /// sqlite can not change a column (type, null, default). so make the
  /// table again with the new column, copy the rows, drop the old table and
  /// rename the new one. it keeps the columns, primary key, AUTOINCREMENT,
  /// foreign keys, unique constraints and indexes. it does NOT keep CHECK
  /// constraints, triggers or generated columns (it throws on those).
  Future<void> _rebuildSqliteTable(TableColumn col) async {
    Map<String, dynamic> table = <String, dynamic>{'table': tableName};
    List<Map<String, dynamic>> info = await dbDriver.query(
      'SELECT * FROM pragma_table_xinfo(@table)',
      substitutionValues: table,
    );
    if (info.any((Map<String, dynamic> c) => c['hidden'] != 0)) {
      throw UnsupportedError(
        'sqlite: can not change a column of $tableName, it has generated columns',
      );
    }
    List<Map<String, dynamic>> createSql = await dbDriver.query(
      "SELECT sql FROM sqlite_schema WHERE type = 'table' AND name = @table",
      substitutionValues: table,
    );
    String oldSql = createSql.first['sql'].toString().toUpperCase();
    if (oldSql.contains('CHECK')) {
      throw UnsupportedError(
        'sqlite: can not change a column of $tableName, it has CHECK constraints',
      );
    }

    List<Map<String, dynamic>> pk =
        info.where((Map<String, dynamic> c) => (c['pk'] as int) > 0).toList()
          ..sort(
            (Map<String, dynamic> a, Map<String, dynamic> b) =>
                (a['pk'] as int).compareTo(b['pk'] as int),
          );
    bool autoIncrement = pk.length == 1 && oldSql.contains('AUTOINCREMENT');

    List<String> defs = <String>[];
    for (Map<String, dynamic> c in info) {
      String name = c['name'] as String;
      String def;
      if (name == col.name) {
        def =
            "${dbDriver.wrap(name)} ${col.type ?? c['type']} ${col.isNullable ? 'NULL' : 'NOT NULL'}${defaultQuery(col)}";
      } else {
        def = "${dbDriver.wrap(name)} ${c['type']}"
            "${c['notnull'] == 1 ? ' NOT NULL' : ''}"
            "${c['dflt_value'] != null ? ' DEFAULT ${c['dflt_value']}' : ''}";
      }
      if (autoIncrement && name == pk.first['name']) {
        def += ' PRIMARY KEY AUTOINCREMENT';
      }
      defs.add(def);
    }
    if (pk.isNotEmpty && !autoIncrement) {
      defs.add(
        'PRIMARY KEY (${pk.map((Map<String, dynamic> c) => dbDriver.wrap(c['name'] as String)).join(', ')})',
      );
    }

    /// foreign keys, one row per column, grouped by id
    Map<int, List<Map<String, dynamic>>> fks =
        <int, List<Map<String, dynamic>>>{};
    for (Map<String, dynamic> fk in await dbDriver.query(
      'SELECT * FROM pragma_foreign_key_list(@table) ORDER BY id, seq',
      substitutionValues: table,
    )) {
      (fks[fk['id'] as int] ??= <Map<String, dynamic>>[]).add(fk);
    }
    for (List<Map<String, dynamic>> fk in fks.values) {
      String from = fk
          .map((Map<String, dynamic> f) => dbDriver.wrap(f['from'] as String))
          .join(', ');
      String to = fk.first['to'] == null
          ? ''
          : ' (${fk.map((Map<String, dynamic> f) => dbDriver.wrap(f['to'] as String)).join(', ')})';
      defs.add(
        'FOREIGN KEY ($from) REFERENCES ${dbDriver.wrap(fk.first['table'] as String)}$to '
        'ON UPDATE ${fk.first['on_update']} ON DELETE ${fk.first['on_delete']}',
      );
    }

    /// indexes made with CREATE INDEX keep their sql. UNIQUE constraints
    /// (auto indexes, no sql) are made again as unique indexes.
    List<String> indexes = <String>[
      for (Map<String, dynamic> i in await dbDriver.query(
        "SELECT sql FROM sqlite_schema WHERE type = 'index' AND tbl_name = @table AND sql IS NOT NULL",
        substitutionValues: table,
      ))
        i['sql'] as String,
    ];
    for (Map<String, dynamic> i in await dbDriver.query(
      "SELECT name FROM pragma_index_list(@table) WHERE origin = 'u'",
      substitutionValues: table,
    )) {
      List<Map<String, dynamic>> cols = await dbDriver.query(
        'SELECT name FROM pragma_index_info(@index) ORDER BY seqno',
        substitutionValues: <String, dynamic>{'index': i['name']},
      );
      List<String> names = <String>[
        for (Map<String, dynamic> c in cols) c['name'] as String,
      ];
      indexes.add(
        'CREATE UNIQUE INDEX IF NOT EXISTS ${dbDriver.wrap('unique_${tableName}_${names.join('_')}')} '
        'ON $_table (${names.map(dbDriver.wrap).join(', ')})',
      );
    }

    String temp = dbDriver.wrap('__dox_new_$tableName');
    String columns = info
        .map((Map<String, dynamic> c) => dbDriver.wrap(c['name'] as String))
        .join(', ');

    /// foreign_keys can only be changed outside a transaction
    List<Map<String, dynamic>> fkState = await dbDriver.query(
      'PRAGMA foreign_keys',
    );
    bool fkOn = fkState.first.values.first == 1;
    if (fkOn) await _runQuery('PRAGMA foreign_keys = OFF');
    try {
      await dbDriver.transaction(() async {
        await _runQuery('CREATE TABLE $temp (${defs.join(', ')})');
        await _runQuery(
          'INSERT INTO $temp ($columns) SELECT $columns FROM $_table',
        );
        await _runQuery('DROP TABLE $_table');
        await _runQuery('ALTER TABLE $temp RENAME TO $_table');
        for (String index in indexes) {
          await _runQuery(index);
        }
        List<Map<String, dynamic>> broken = await dbDriver.query(
          'PRAGMA foreign_key_check(${dbDriver.wrap(tableName)})',
        );
        if (broken.isNotEmpty) {
          throw StateError(
            'sqlite: changing $tableName.${col.name} breaks foreign keys',
          );
        }
      });
    } finally {
      if (fkOn) await _runQuery('PRAGMA foreign_keys = ON');
    }
  }
}
