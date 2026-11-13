import 'dart:io';

import 'package:dox_cache_database/commands.dart';
import 'package:dox_core/command.dart';
import 'package:test/test.dart';

void main() {
  late Directory folder;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('dox_cache_table_');
  });

  tearDown(() {
    exitCode = 0;
    folder.deleteSync(recursive: true);
  });

  List<File> files() => folder.listSync().whereType<File>().toList();

  CacheTableCommand command() {
    return CacheTableCommand(migrations: MigrationFile(folder: folder));
  }

  test('commands has cache:table', () {
    expect(commands.map((Command c) => c.name), contains('cache:table'));
  });

  test('writes the migration once', () async {
    await command().run(<String>[]);
    expect(files(), hasLength(1));
    expect(files().first.path, endsWith('_create_cache_table.dart'));
    String source = files().first.readAsStringSync();
    expect(source, contains('CacheTables.up(schema);'));
    expect(source, contains('CacheTables.down(schema);'));
    expect(exitCode, 0);

    await command().run(<String>[]);
    expect(files(), hasLength(1));
    expect(exitCode, 1);
  });

  test('--table sets the table name', () async {
    await command().run(<String>['--table=app_cache']);
    expect(exitCode, 0);
    expect(
      files().first.readAsStringSync(),
      contains("CacheTables.up(schema, table: 'app_cache');"),
    );
  });

  // Analyzes the written migration in a small app that uses this package.
  // It needs the root pubspec_overrides.yaml of the workspace (written by
  // ci/use-siblings.sh): without it, the unreleased Dox packages are not
  // there.
  test('the migration compiles', () async {
    String root = Directory.current.parent.parent.path;
    File overrides = File('$root/pubspec_overrides.yaml');
    if (!overrides.existsSync()) {
      markTestSkipped('no pubspec_overrides.yaml at the workspace root');
      return;
    }
    await command().run(<String>['--table=app_cache']);
    Directory app = Directory('${folder.path}/app')..createSync();
    Directory('${app.path}/lib').createSync();
    files().first.copySync('${app.path}/lib/migration.dart');
    File('${app.path}/pubspec.yaml').writeAsStringSync('''
name: migration_check
environment:
  sdk: ^3.14.0
dependencies:
  dox_cache_database: any
  dox_migration: any
''');
    // the overrides of the workspace, plus every package of the workspace
    StringBuffer text = StringBuffer(overrides.readAsStringSync());
    for (FileSystemEntity entity in Directory('$root/packages').listSync()) {
      File pubspec = File('${entity.path}/pubspec.yaml');
      if (!pubspec.existsSync()) continue;
      String name = RegExp(
        r'^name: (\S+)',
        multiLine: true,
      ).firstMatch(pubspec.readAsStringSync())![1]!;
      text.write('\n  $name:\n    path: ${entity.path}\n');
    }
    File('${app.path}/pubspec_overrides.yaml')
        .writeAsStringSync(text.toString());
    ProcessResult get = await Process.run('dart', <String>[
      'pub',
      'get',
      '--offline',
    ], workingDirectory: app.path);
    expect(get.exitCode, 0, reason: '${get.stdout}${get.stderr}');
    ProcessResult analyze = await Process.run('dart', <String>[
      'analyze',
      '--fatal-infos',
      'lib',
    ], workingDirectory: app.path);
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}');
  }, timeout: Timeout(Duration(minutes: 3)));

  test('a bad flag writes nothing', () async {
    for (List<String> args in <List<String>>[
      <String>['--nope'],
      <String>['--table=cache; drop'],
      <String>['--table='],
      <String>['--table=a', '--table=b'],
    ]) {
      exitCode = 0;
      await command().run(args);
      expect(exitCode, 1, reason: '$args');
      expect(files(), isEmpty, reason: '$args');
    }
  });
}
