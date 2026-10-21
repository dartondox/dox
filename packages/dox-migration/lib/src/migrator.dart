import 'dart:io';

import 'package:dox_orm/dox_orm.dart';

import 'migration.dart';
import 'migrations/sql_ext_migration.dart';
import 'utils/db_connection.dart';
import 'utils/env.dart';
import 'utils/file_extension.dart';
import 'utils/logger.dart';
import 'utils/migration_driver.dart';
import 'utils/utils.dart';

/// state of one migration, from [Migrator.status]
class MigrationStatus {
  final String name;

  /// batch number, null when it did not run yet
  final int? batch;

  /// false when it ran but its file is gone
  final bool exists;

  const MigrationStatus(this.name, this.batch, {this.exists = true});

  bool get ran => batch != null;
}

/// runs the Dart migrations of [migrations] and the `.sql` files of
/// `db/migration`, sorted by name. ran migrations are saved in the
/// `dox_db_migration` table with a batch number (one batch per run).
///
/// ```
/// await Migrator(migrations: migrations).migrate();
/// ```
class Migrator {
  /// the Dart migrations, eg. from `db/migration/migrations.dart`
  final List<MigrationEntry> migrations;

  /// postgres `Connection`/`Pool`, mysql `MySQLConnection`/
  /// `MySQLConnectionPool` or sqlite `Database`.
  /// null: open one from `.env` (or the environment variables).
  final dynamic connection;

  /// folder of the `.sql` migrations, default `db/migration`
  final Directory? directory;

  const Migrator({
    this.migrations = const <MigrationEntry>[],
    this.connection,
    this.directory,
  });

  /// run the migrations that did not run yet
  Future<void> migrate() => _withDriver(_migrate);

  /// undo the last batch, or the last [step] migrations, newest first
  Future<void> rollback({int? step}) {
    return _withDriver((MigrationDriver d) => _rollback(d, step: step));
  }

  /// undo all migrations, newest first
  Future<void> reset() {
    return _withDriver((MigrationDriver d) => _rollback(d, all: true));
  }

  /// undo all migrations, then run them again
  Future<void> refresh() {
    return _withDriver((MigrationDriver d) async {
      await _rollback(d, all: true);
      await _migrate(d);
    });
  }

  /// every known migration with its batch (null when it did not run)
  Future<List<MigrationStatus>> status() => _withDriver(_status);

  /// run a command from the command line and give the exit code:
  /// `run` (or `migrate`), `rollback [--step=<n>]`, `reset`, `refresh`,
  /// `status`. `migration:` or `migrate:` in front is fine too.
  Future<int> run(List<String> args) async {
    String command = args.isEmpty
        ? 'run'
        : args.first.replaceFirst(RegExp(r'^(migration|migrate):'), '');
    try {
      switch (command) {
        case 'run':
        case 'migrate':
          await migrate();
        case 'rollback':
          await rollback(step: _step(args.skip(1).toList()));
        case 'reset':
          await reset();
        case 'refresh':
          await refresh();
        case 'status':
          printStatus(await status());
        default:
          Logger.danger(
            'Unknown migration command: $command '
            '(use run, rollback, reset, refresh or status)',
          );
          return 1;
      }
      return 0;
    } catch (error) {
      Logger.danger(error);
      return 1;
    }
  }

  /// print [list] as a table
  static void printStatus(List<MigrationStatus> list) {
    if (list.isEmpty) {
      Logger.info('No migrations found.');
      return;
    }
    int width = list
        .map((MigrationStatus s) => s.name.length)
        .reduce((int a, int b) => a > b ? a : b);
    print('${'Migration'.padRight(width)}  Batch  Status');
    for (MigrationStatus s in list) {
      String state = !s.exists ? 'Missing file' : (s.ran ? 'Ran' : 'Pending');
      print(
        '${s.name.padRight(width)}  ${(s.batch?.toString() ?? '').padRight(5)}  $state',
      );
    }
  }

  /// `--step=2` or `--step 2`
  static int? _step(List<String> args) {
    if (args.isEmpty) return null;
    String value = args.first == '--step' && args.length > 1
        ? args[1]
        : args.first.replaceFirst('--step=', '');
    int? step = int.tryParse(value);
    if (step == null || step < 1 || !args.first.startsWith('--step')) {
      throw ArgumentError(
        'Invalid option ${args.join(' ')}, use --step=<count>',
      );
    }
    return step;
  }

  /// one connection for the whole run
  Future<T> _withDriver<T>(Future<T> Function(MigrationDriver d) task) async {
    DbConnection conn = connection != null
        ? DbConnection(connection)
        : await _open();
    try {
      MigrationDriver driver = MigrationDriver(conn);
      await createMigrationTableIfNotExist(conn);
      return await task(driver);
    } finally {
      /// a given connection belongs to the caller
      if (connection == null) await conn.close();
    }
  }

  Future<DbConnection> _open() async {
    try {
      return await DbConnection.open(loadEnv());
    } catch (e) {
      throw Exception('Could not connect to database: $e');
    }
  }

  /// Dart entries and `.sql` files by name, sorted by name
  Map<String, Object> _all() {
    Map<String, Object> all = <String, Object>{};
    for (MigrationEntry entry in migrations) {
      all[entry.name] = entry.migration;
    }
    for (File file in getFilesFromDirectory(
      directory ?? getMigrationDirectory(),
    )) {
      if (all.containsKey(file.name)) {
        throw StateError(
          'Migration ${file.name} is both a Dart and a .sql migration',
        );
      }
      all[file.name] = file;
    }
    List<String> names = all.keys.toList()..sort();
    return <String, Object>{for (String name in names) name: all[name]!};
  }

  Future<Map<String, int>> _ran(MigrationDriver d) async {
    List<Map<String, dynamic>> rows = await d.conn.execute(
      'SELECT migration, batch FROM dox_db_migration ORDER BY id',
    );
    return <String, int>{
      for (Map<String, dynamic> row in rows)
        row['migration'].toString(): int.parse(row['batch'].toString()),
    };
  }

  Future<void> _migrate(MigrationDriver d) async {
    Map<String, int> ran = await _ran(d);
    int batch = await getNextBatchNumber(d.conn);
    int count = 0;
    for (MapEntry<String, Object> m in _all().entries) {
      if (ran.containsKey(m.key)) continue;
      await _runOne(d, m.key, m.value, MigrationType.up, batch);
      count++;
    }
    if (count == 0) {
      Logger.info('Migrations are already up to date!');
    }
  }

  Future<void> _rollback(
    MigrationDriver d, {
    int? step,
    bool all = false,
  }) async {
    String query = 'SELECT migration FROM dox_db_migration';
    if (step != null && !all) {
      query += ' ORDER BY id DESC LIMIT $step';
    } else if (!all) {
      query +=
          ' WHERE batch = (SELECT MAX(batch) FROM dox_db_migration)'
          ' ORDER BY id DESC';
    } else {
      query += ' ORDER BY id DESC';
    }
    List<Map<String, dynamic>> rows = await d.conn.execute(query);
    Map<String, Object> known = _all();
    for (Map<String, dynamic> row in rows) {
      String name = row['migration'].toString();
      Object? migration = known[name];
      if (migration == null) {
        throw MigrationException(name, 'migration file not found');
      }
      await _runOne(d, name, migration, MigrationType.down, 0);
    }
    if (rows.isEmpty) {
      Logger.info('Nothing to rollback!');
    }
  }

  Future<List<MigrationStatus>> _status(MigrationDriver d) async {
    Map<String, int> ran = await _ran(d);
    Map<String, Object> known = _all();
    List<String> names = <String>{...known.keys, ...ran.keys}.toList()..sort();
    return <MigrationStatus>[
      for (String name in names)
        MigrationStatus(name, ran[name], exists: known.containsKey(name)),
    ];
  }

  /// run one migration (a [Migration] or a `.sql` [File]) and save it.
  /// it runs in one transaction, unless the migration says no.
  Future<void> _runOne(
    MigrationDriver d,
    String name,
    Object migration,
    MigrationType type,
    int batch,
  ) async {
    bool up = type == MigrationType.up;
    Logger.info('${up ? 'Migrating' : 'Rolling back'}: $name');

    /// sqlite: foreign keys are off while it runs, so a table rebuild can
    /// drop a table that others point to. they are checked before commit.
    bool sqliteFk =
        d.conn.isSqlite &&
        (await d.conn.execute('PRAGMA foreign_keys')).first.values.first == 1;

    Future<void> body() async {
      if (migration is Migration) {
        Schema schema = Schema(d);
        up ? await migration.up(schema) : await migration.down(schema);
      } else {
        await SqlExtMigration(migration as File).run(d.conn, type);
      }
      if (sqliteFk) await _checkSqliteForeignKeys(d);
      await saveMigratedRecord(d.conn, name, batch, type);
    }

    bool transaction = migration is Migration
        ? migration.withinTransaction
        : true;

    if (sqliteFk) await d.conn.execute('PRAGMA foreign_keys = OFF');
    try {
      transaction ? await d.transaction(body) : await body();
    } catch (error) {
      throw MigrationException(name, error);
    } finally {
      if (sqliteFk) await d.conn.execute('PRAGMA foreign_keys = ON');
    }
    Logger.info('${up ? 'Migrated' : 'Rolled back'}: $name');
  }

  Future<void> _checkSqliteForeignKeys(MigrationDriver d) async {
    List<Map<String, dynamic>> broken = await d.conn.execute(
      'PRAGMA foreign_key_check',
    );
    if (broken.isNotEmpty) {
      throw StateError(
        'foreign key check failed: ${broken.first['table']} '
        'points to a missing ${broken.first['parent']} row',
      );
    }
  }
}
