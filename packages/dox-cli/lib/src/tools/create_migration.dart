import 'dart:io';

import 'package:dox/src/utils/utils.dart';

/// folder of the migrations, `db/migration`
Directory migrationDirectory() {
  return Directory('${Directory.current.path}/db/migration');
}

/// the app entry point that runs Dart migrations
File migrateEntryFile() => File('${Directory.current.path}/bin/migrate.dart');

/// make a migration file in `db/migration` and return its path.
/// a Dart migration (default) also updates `db/migration/migrations.dart`
/// and makes `bin/migrate.dart` when it is missing.
/// [sql] makes the old `.sql` file with `-- up` and `-- down`.
String createMigration(String name, {bool sql = false}) {
  String snake = pascalToSnake(name.replaceAll(RegExp(r'[^\w]'), ''));
  Directory dir = migrationDirectory();
  String fileName =
      '${_timestamp(nextMigrationTime(dir, DateTime.now()))}_$snake';
  File file = File('${dir.path}/$fileName.${sql ? 'sql' : 'dart'}');
  file.createSync(recursive: true);
  file.writeAsStringSync(sql ? _sampleSql : dartMigrationSource(snake));
  if (!sql) {
    writeMigrationRegistry();
    File entry = migrateEntryFile();
    if (!entry.existsSync()) {
      entry.createSync(recursive: true);
      entry.writeAsStringSync(migrateEntrySource);
      print('\x1B[32mbin/migrate.dart created.\x1B[0m');
    }
  }
  print('\x1B[32m$fileName migration created successfully.\x1B[0m');
  return file.path;
}

final RegExp _stamp = RegExp(
  r'^(\d{4})_(\d{2})_(\d{2})_(\d{2})(\d{2})(\d{2})_',
);

/// the time for a new migration in [dir]. Migrations run sorted by file
/// name, so the new file must sort after every file already there. When
/// [now] is not later than the newest file (same second, or a file with a
/// future date), use the newest time + 1 second.
DateTime nextMigrationTime(Directory dir, DateTime now) {
  DateTime time = DateTime(
    now.year,
    now.month,
    now.day,
    now.hour,
    now.minute,
    now.second,
  );
  if (!dir.existsSync()) return time;
  for (File f in dir.listSync().whereType<File>()) {
    RegExpMatch? m = _stamp.firstMatch(f.uri.pathSegments.last);
    if (m == null) continue;
    List<int> p = List<int>.generate(6, (int i) => int.parse(m.group(i + 1)!));
    DateTime last = DateTime(p[0], p[1], p[2], p[3], p[4], p[5]);
    if (!time.isAfter(last)) time = last.add(const Duration(seconds: 1));
  }
  return time;
}

/// `2026_10_21_120000`
String _timestamp(DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${now.year}_${two(now.month)}_${two(now.day)}_'
      '${two(now.hour)}${two(now.minute)}${two(now.second)}';
}

final RegExp _migrationFile = RegExp(r'^\d{4}_\d{2}_\d{2}_\d+_\w+\.dart$');
final RegExp _migrationClass = RegExp(r'class\s+(\w+)\s+extends\s+Migration\b');

/// true when `db/migration` has Dart migration files
bool hasDartMigrations() {
  Directory dir = migrationDirectory();
  if (!dir.existsSync()) return false;
  return dir.listSync().whereType<File>().any(
    (File f) => _migrationFile.hasMatch(f.uri.pathSegments.last),
  );
}

/// write `db/migration/migrations.dart`: every Dart migration file of
/// the folder, sorted by name. Dart can not load files at run time
/// (AOT), so the app imports this list.
void writeMigrationRegistry() {
  Directory dir = migrationDirectory();
  List<File> files = dir.existsSync()
      ? (dir
            .listSync()
            .whereType<File>()
            .where((File f) => _migrationFile.hasMatch(f.uri.pathSegments.last))
            .toList()
          ..sort((File a, File b) => a.path.compareTo(b.path)))
      : <File>[];

  StringBuffer imports = StringBuffer();
  StringBuffer entries = StringBuffer();
  int i = 0;
  for (File file in files) {
    String fileName = file.uri.pathSegments.last;
    String name = fileName.substring(0, fileName.length - '.dart'.length);
    RegExpMatch? match = _migrationClass.firstMatch(file.readAsStringSync());
    if (match == null) {
      print('\x1B[33mSkip $fileName: no class that extends Migration.\x1B[0m');
      continue;
    }
    i++;
    imports.writeln("import '$fileName' as m$i;");

    /// one argument per line, so the file is already `dart format`ed
    entries
      ..writeln('  MigrationEntry(')
      ..writeln("    '$name',")
      ..writeln('    m$i.${match.group(1)}(),')
      ..writeln('  ),');
  }

  File registry = File('${dir.path}/migrations.dart');
  String source =
      '''
// Made by `dox make:migration` and the `dox migration:*` commands.
// Do not edit, it is made again from the files in this folder.
import 'package:dox_migration/dox_migration.dart';

$imports
/// all Dart migrations of db/migration, sorted by name
final List<MigrationEntry> migrations = <MigrationEntry>[
$entries];
''';
  if (registry.existsSync() && registry.readAsStringSync() == source) return;
  registry.createSync(recursive: true);
  registry.writeAsStringSync(source);
}

/// source of a Dart migration. `create_x_table` makes table x,
/// `add_y_to_x_table` changes table x.
String dartMigrationSource(String snakeName) {
  String className = snakeToPascal(snakeName);
  if (RegExp(r'^\d').hasMatch(className)) className = 'M$className';

  RegExpMatch? create = RegExp(r'^create_(\w+)_table$').firstMatch(snakeName);
  RegExpMatch? change = RegExp(r'^\w+_(?:to|from|in|on)_(\w+)_table$')
      .firstMatch(snakeName);

  String up;
  String down;
  if (create != null) {
    String table = create.group(1)!;
    up =
        '''
    await schema.create('$table', (Table table) {
      table.id();
      table.timestamps();
    });''';
    down = "    await schema.dropIfExists('$table');";
  } else if (change != null) {
    String table = change.group(1)!;
    up =
        '''
    await schema.table('$table', (Table table) {
      // table.string('name').nullable();
    });''';
    down =
        '''
    await schema.table('$table', (Table table) {
      // table.dropColumn('name');
    });''';
  } else {
    up = '    // await schema.create(...);';
    down = '    // await schema.dropIfExists(...);';
  }

  return '''
// ignore_for_file: file_names
import 'package:dox_migration/dox_migration.dart';

class $className extends Migration {
  @override
  Future<void> up(Schema schema) async {
$up
  }

  @override
  Future<void> down(Schema schema) async {
$down
  }
}
''';
}

/// source of `bin/migrate.dart`
const String migrateEntrySource = '''
import 'dart:io';

import 'package:dox_migration/dox_migration.dart';

import '../db/migration/migrations.dart';

/// run the migrations of db/migration (Dart and .sql files):
/// `dart run bin/migrate.dart <run|rollback [--step=n]|reset|refresh|status>`.
/// `dox migration:*` commands run this file.
/// the database is from `.env` (DB_CONNECTION, DB_HOST, DB_PORT, ...).
Future<void> main(List<String> args) async {
  exitCode = await Migrator(migrations: migrations).run(args);
}
''';

const String _sampleSql = '''
-- up
-- Write your up query here. Do not remove `-- up` comment.

-- down
-- Write your down query here. Do not remove `-- down` comment.
''';
