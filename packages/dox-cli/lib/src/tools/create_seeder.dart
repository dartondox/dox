import 'dart:io';

import '../utils/utils.dart';

/// folder of the seeders, `db/seeders`
Directory seederDirectory() {
  return Directory('${Directory.current.path}/db/seeders');
}

/// the app entry point that runs the seeders
File seedEntryFile() => File('${Directory.current.path}/bin/seed.dart');

String _getSample(String className) {
  return '''
import 'package:dox_migration/dox_migration.dart';

class ${className}Seeder extends Seeder {
  @override
  Future<void> run() async {
    // await UserFactory().count(10).create();
    // await call(<Seeder>[UserSeeder()]);
  }
}
''';
}

/// `dox make:seeder UserSeeder` makes `db/seeders/user.seeder.dart`,
/// updates `db/seeders/seeders.dart` and makes `bin/seed.dart` when it
/// is missing
bool createSeeder(String name) {
  String filename = pascalToSnake(name).replaceAll(RegExp(r'_?seeder$'), '');
  String className = snakeToPascal(filename);
  String seederName = '$filename.seeder';
  File file = File('${seederDirectory().path}/$seederName.dart');
  if (file.existsSync()) {
    print('\x1B[32m$seederName already exists\x1B[0m');
    return false;
  }
  file.createSync(recursive: true);
  file.writeAsStringSync(_getSample(className));
  writeSeederRegistry();
  File entry = seedEntryFile();
  if (!entry.existsSync()) {
    entry.createSync(recursive: true);
    entry.writeAsStringSync(seedEntrySource);
    print('\x1B[32mbin/seed.dart created.\x1B[0m');
  }
  print('\x1B[32m$seederName created successfully.\x1B[0m');
  return true;
}

final RegExp _seederClass = RegExp(r'class\s+(\w+)\s+extends\s+Seeder\b');

/// write `db/seeders/seeders.dart`: every seeder class of the folder.
/// Dart can not find classes at run time (AOT), so the app imports this
/// list.
void writeSeederRegistry() {
  Directory dir = seederDirectory();
  List<File> files = dir.existsSync()
      ? (dir
            .listSync()
            .whereType<File>()
            .where(
              (File f) =>
                  f.path.endsWith('.dart') &&
                  f.uri.pathSegments.last != 'seeders.dart',
            )
            .toList()
          ..sort((File a, File b) => a.path.compareTo(b.path)))
      : <File>[];

  StringBuffer imports = StringBuffer();
  List<String> entries = <String>[];
  for (File file in files) {
    Iterable<RegExpMatch> classes = _seederClass.allMatches(
      file.readAsStringSync(),
    );
    if (classes.isEmpty) continue;
    imports.writeln("import '${file.uri.pathSegments.last}';");
    for (RegExpMatch match in classes) {
      entries.add('${match.group(1)}()');
    }
  }

  /// same layout as `dart format`: one line when it fits in 80 chars
  String list = '<Seeder>[${entries.join(', ')}];';
  if ('final List<Seeder> seeders = $list'.length > 80) {
    list = '<Seeder>[\n${entries.map((String e) => '  $e,\n').join()}];';
  }

  File registry = File('${dir.path}/seeders.dart');
  String source =
      '''
// Made by `dox make:seeder` and `dox db:seed`.
// Do not edit, it is made again from the files in this folder.
import 'package:dox_migration/dox_migration.dart';

$imports
/// all seeders of db/seeders
final List<Seeder> seeders = $list
''';
  if (registry.existsSync() && registry.readAsStringSync() == source) return;
  registry.createSync(recursive: true);
  registry.writeAsStringSync(source);
}

/// source of `bin/seed.dart`
const String seedEntrySource = '''
import 'dart:io';

import 'package:dox_migration/dox_migration.dart';

import '../db/seeders/seeders.dart';

/// run a seeder of db/seeders:
/// `dart run bin/seed.dart [--class=UserSeeder]`, default DatabaseSeeder.
/// `dox db:seed` runs this file.
/// the database is from `.env` (DB_CONNECTION, DB_HOST, DB_PORT, ...).
Future<void> main(List<String> args) async {
  exitCode = await SeederRunner(seeders: seeders).run(args);
}
''';
