import '../drivers/db_driver.dart';
import 'grammars/sqlite_grammar.dart';
import 'table.column.dart';
import 'table.dart';

/// sqlite can not change a column or add/drop a foreign key with ALTER.
/// so make the table again with the changes, copy the rows, drop the old
/// table and rename the new one. it keeps the columns, primary key,
/// AUTOINCREMENT, foreign keys, indexes and the enum CHECKs made by
/// `enumeration()`. it throws on other CHECKs and on generated columns.
class SqliteTableRebuilder {
  final DBDriver driver;
  final SqliteGrammar grammar;

  const SqliteTableRebuilder(this.driver, this.grammar);

  /// `CHECK ("col" IN ('a', 'b'))` as made by [SqliteGrammar.enumCheck]
  static final RegExp _enumCheck = RegExp(
    r"""CHECK \("((?:[^"]|"")+)" IN \((?:'(?:[^']|'')*'(?:, )?)*\)\)""",
  );

  static final RegExp _anyCheck = RegExp(r'\bCHECK\s*\(', caseSensitive: false);

  Future<void> rebuild(Table table) async {
    String tableName = table.name;
    String quoted = grammar.wrap(tableName);
    Map<String, dynamic> params = <String, dynamic>{'table': tableName};

    Map<String, ColumnDefinition> changed = <String, ColumnDefinition>{
      for (ColumnDefinition c in table.columns)
        if (c.isChange) c.name: c,
    };
    List<ForeignKeyDefinition> addForeign = <ForeignKeyDefinition>[
      for (TableCommand c in table.commands)
        if (c.type == CommandType.foreign) c.foreign!,
    ];
    Set<String> dropForeign = <String>{
      for (TableCommand c in table.commands)
        if (c.type == CommandType.dropForeign) c.name!,
    };

    List<Map<String, dynamic>> info = await driver.query(
      'SELECT * FROM pragma_table_xinfo(@table)',
      substitutionValues: params,
    );
    if (info.isEmpty) {
      throw StateError('sqlite: table $tableName not found');
    }
    if (info.any((Map<String, dynamic> c) => c['hidden'] != 0)) {
      throw UnsupportedError(
        'sqlite: can not rebuild $tableName, it has generated columns',
      );
    }
    Set<String> names = <String>{
      for (Map<String, dynamic> c in info) c['name'] as String,
    };
    for (String name in changed.keys) {
      if (!names.contains(name)) {
        throw StateError('sqlite: column $tableName.$name not found');
      }
    }

    List<Map<String, dynamic>> createSql = await driver.query(
      "SELECT sql FROM sqlite_schema WHERE type = 'table' AND name = @table",
      substitutionValues: params,
    );
    String oldSql = createSql.first['sql'].toString();
    Map<String, String> checks = <String, String>{
      for (RegExpMatch m in _enumCheck.allMatches(oldSql))
        m.group(1)!.replaceAll('""', '"'): m.group(0)!,
    };
    if (_anyCheck.allMatches(oldSql).length > checks.length) {
      throw UnsupportedError(
        'sqlite: can not rebuild $tableName, it has CHECK constraints',
      );
    }

    List<Map<String, dynamic>> pk =
        info.where((Map<String, dynamic> c) => (c['pk'] as int) > 0).toList()
          ..sort(
            (Map<String, dynamic> a, Map<String, dynamic> b) =>
                (a['pk'] as int).compareTo(b['pk'] as int),
          );
    bool autoIncrement =
        pk.length == 1 && oldSql.toUpperCase().contains('AUTOINCREMENT');

    List<String> defs = <String>[];
    for (Map<String, dynamic> c in info) {
      String name = c['name'] as String;
      ColumnDefinition? change = changed[name];
      String def;
      if (change != null) {
        def = grammar.columnSql(table, change);
      } else {
        def =
            '${grammar.wrap(name)} ${c['type']}'
            "${c['notnull'] == 1 ? ' NOT NULL' : ''}"
            "${c['dflt_value'] != null ? ' DEFAULT ${c['dflt_value']}' : ''}"
            "${checks[name] != null ? ' ${checks[name]}' : ''}";
      }
      if (autoIncrement &&
          name == pk.first['name'] &&
          !def.contains('PRIMARY KEY')) {
        def += ' PRIMARY KEY AUTOINCREMENT';
      }
      defs.add(def);
    }
    if (pk.isNotEmpty && !defs.any((String d) => d.contains('PRIMARY KEY'))) {
      defs.add(
        'PRIMARY KEY (${grammar.columnize(<String>[for (Map<String, dynamic> c in pk) c['name'] as String])})',
      );
    }

    /// foreign keys, one row per column, grouped by id
    Map<int, List<Map<String, dynamic>>> fks =
        <int, List<Map<String, dynamic>>>{};
    for (Map<String, dynamic> fk in await driver.query(
      'SELECT * FROM pragma_foreign_key_list(@table) ORDER BY id, seq',
      substitutionValues: params,
    )) {
      (fks[fk['id'] as int] ??= <Map<String, dynamic>>[]).add(fk);
    }
    Set<String> dropped = <String>{};
    for (List<Map<String, dynamic>> fk in fks.values) {
      List<String> from = <String>[
        for (Map<String, dynamic> f in fk) f['from'] as String,
      ];
      String name = table.indexName('foreign', from);
      if (dropForeign.contains(name)) {
        dropped.add(name);
        continue;
      }
      String to = fk.first['to'] == null
          ? ''
          : ' (${grammar.columnize(<String>[for (Map<String, dynamic> f in fk) f['to'] as String])})';
      defs.add(
        'FOREIGN KEY (${grammar.columnize(from)}) REFERENCES ${grammar.wrap(fk.first['table'] as String)}$to '
        'ON UPDATE ${fk.first['on_update']} ON DELETE ${fk.first['on_delete']}',
      );
    }
    Set<String> missing = dropForeign.difference(dropped);
    if (missing.isNotEmpty) {
      throw StateError('sqlite: foreign key ${missing.join(', ')} not found');
    }
    for (ForeignKeyDefinition fk in addForeign) {
      defs.add(grammar.foreignSql(fk));
    }

    /// indexes made with CREATE INDEX keep their sql. UNIQUE constraints
    /// (auto indexes, no sql) are made again as unique indexes.
    List<String> indexes = <String>[
      for (Map<String, dynamic> i in await driver.query(
        "SELECT sql FROM sqlite_schema WHERE type = 'index' AND tbl_name = @table AND sql IS NOT NULL",
        substitutionValues: params,
      ))
        i['sql'] as String,
    ];
    for (Map<String, dynamic> i in await driver.query(
      "SELECT name FROM pragma_index_list(@table) WHERE origin = 'u'",
      substitutionValues: params,
    )) {
      List<String> cols = <String>[
        for (Map<String, dynamic> c in await driver.query(
          'SELECT name FROM pragma_index_info(@index) ORDER BY seqno',
          substitutionValues: <String, dynamic>{'index': i['name']},
        ))
          c['name'] as String,
      ];
      indexes.add(
        'CREATE UNIQUE INDEX IF NOT EXISTS ${grammar.wrap(table.indexName('unique', cols))} '
        'ON $quoted (${grammar.columnize(cols)})',
      );
    }
    indexes.addAll(grammar.columnExtras(table, changed.values.toList()));

    String temp = grammar.wrap('__dox_new_$tableName');
    String columns = grammar.columnize(names.toList());

    /// foreign_keys can only be changed outside a transaction.
    /// in a migration it is already off (the migrator turns it off).
    List<Map<String, dynamic>> fkState = await driver.query(
      'PRAGMA foreign_keys',
    );
    bool fkOn = fkState.first.values.first == 1;
    if (fkOn) await driver.execute('PRAGMA foreign_keys = OFF');
    try {
      await driver.transaction(() async {
        await driver.execute('CREATE TABLE $temp (${defs.join(', ')})');
        await driver.execute(
          'INSERT INTO $temp ($columns) SELECT $columns FROM $quoted',
        );
        await driver.execute('DROP TABLE $quoted');
        await driver.execute('ALTER TABLE $temp RENAME TO $quoted');
        for (String index in indexes) {
          await driver.execute(index);
        }
        List<Map<String, dynamic>> broken = await driver.query(
          'PRAGMA foreign_key_check($quoted)',
        );
        if (broken.isNotEmpty) {
          throw StateError('sqlite: rebuild of $tableName breaks foreign keys');
        }
      });
    } finally {
      if (fkOn) await driver.execute('PRAGMA foreign_keys = ON');
    }
  }
}
