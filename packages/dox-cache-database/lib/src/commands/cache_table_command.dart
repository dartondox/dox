import 'dart:io';

import 'package:dox_core/command.dart';

/// `dox cache:table`: write a migration that makes the table of the
/// database cache store (`CacheTables`).
///
/// Flag: `--table=<name>` sets the table name. The default is `cache`.
class CacheTableCommand extends Command {
  /// [migrations] is `MigrationFile()` (`db/migration`) by default
  CacheTableCommand({MigrationFile? migrations})
    : _migrations = migrations ?? MigrationFile();

  final MigrationFile _migrations;

  /// a table name. Nothing else goes into the migration code.
  static final RegExp _identifier = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

  static const String _tableFlag = '--table=';

  @override
  String get name => 'cache:table';

  @override
  String get description => 'Create a migration for the cache table';

  @override
  String get usage => 'cache:table [--table=<name>]';

  @override
  Future<void> run(List<String> args) async {
    String? table;
    for (String arg in args) {
      if (!arg.startsWith(_tableFlag) || table != null) {
        _fail('Unknown or repeated option "$arg". Usage: dox $usage');
        return;
      }
      table = arg.substring(_tableFlag.length);
      if (!_identifier.hasMatch(table)) {
        _fail('--table needs a table name, like --table=cache.');
        return;
      }
    }
    String? path = _migrations.create('create_cache_table', source(table));
    if (path == null) {
      _fail(
        'A create_cache_table migration is already in db/migration. '
        'For a second cache table, write a migration by hand that calls '
        "CacheTables.up(schema, table: '<name>').",
      );
      return;
    }
    String file = File(path).uri.pathSegments.last;
    print('\x1B[32m$file migration created successfully.\x1B[0m');
    if (table != null) {
      print("Set 'table': '$table' in the options of the cache store too.");
    }
    print('Run `dox migrate` to make the table.');
  }

  void _fail(String message) {
    print(message);
    exitCode = 1;
  }

  /// the migration file. [table] is the table name, null for the default.
  static String source([String? table]) {
    String args = table == null ? 'schema' : "schema, table: '$table'";
    return '''
// ignore_for_file: file_names
import 'package:dox_cache_database/dox_cache_database.dart';
import 'package:dox_migration/dox_migration.dart';

/// The cache table of dox_cache_database.
class CreateCacheTable extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await CacheTables.up($args);
  }

  @override
  Future<void> down(Schema schema) async {
    await CacheTables.down($args);
  }
}
''';
  }
}
