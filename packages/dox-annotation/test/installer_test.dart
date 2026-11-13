import 'dart:io';

import 'package:dox_annotation/install.dart';
import 'package:test/test.dart';

/// records the commands and returns [code]
class FakeRunner extends ProcessRunner {
  FakeRunner([this.code = 0]);

  final int code;
  final List<String> calls = <String>[];

  @override
  Future<int> run(String executable, List<String> args, String folder) async {
    calls.add(args.join(' '));
    return code;
  }
}

const String pubspec = '''
name: my_app

dependencies:
  dox_core: ^3.1.0

dev_dependencies:
  dox_builder: ^3.1.0

dependency_overrides:
  dox_orm:
    path: ../dox-orm
''';

const String envDart = '''
@DoxEnv()
abstract class AppEnv {
  String get appName => 'dox';
}

final AppEnv env = AppEnv.load();
''';

void main() {
  late Directory root;
  late FakeRunner runner;
  late Installer installer;

  setUp(() {
    root = Directory.systemTemp.createTempSync('dox_installer_');
    File('${root.path}/pubspec.yaml').writeAsStringSync(pubspec);
    runner = FakeRunner();
    installer = Installer(root: root, runner: runner);
  });

  tearDown(() {
    root.deleteSync(recursive: true);
  });

  String read(String path) => File('${root.path}/$path').readAsStringSync();

  test('appName reads the pubspec name', () {
    expect(installer.appName, 'my_app');
  });

  test('writeFile makes a file once and never overwrites it', () {
    expect(installer.writeFile('lib/config/a.dart', 'one'), isTrue);
    expect(installer.writeFile('lib/config/a.dart', 'two'), isFalse);
    expect(read('lib/config/a.dart'), 'one');
    expect(installer.lines, <String>[
      'created  lib/config/a.dart',
      'skipped  lib/config/a.dart (already there)',
    ]);
  });

  test('makeFolder makes a folder once', () {
    installer.makeFolder('db/migration');
    installer.makeFolder('db/migration');
    expect(Directory('${root.path}/db/migration').existsSync(), isTrue);
    expect(installer.lines, <String>['created  db/migration/']);
  });

  test('addEnv adds a key to both files only when it is missing', () {
    File('${root.path}/.env').writeAsStringSync('APP_KEY=x');
    File('${root.path}/.env.example').writeAsStringSync('DB_NAME=keep\n');
    installer.addEnv('DB_NAME', 'db/dox.sqlite');
    installer.addEnv('DB_NAME', 'other');
    expect(read('.env'), 'APP_KEY=x\nDB_NAME=db/dox.sqlite\n');
    expect(read('.env.example'), 'DB_NAME=keep\n');
  });

  test('addEnv skips a file that is not there', () {
    installer.addEnv('DB_NAME', 'x');
    expect(File('${root.path}/.env').existsSync(), isFalse);
    expect(installer.lines, isEmpty);
  });

  test('addEnvGetter adds a getter to AppEnv once', () {
    File('${root.path}/lib/config/env.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync(envDart);
    installer.addEnvGetter("String get dbName => 'db/dox.sqlite';");
    installer.addEnvGetter("String get dbName => 'other';");
    installer.addEnvGetter("String get appName => 'other';");
    expect(read('lib/config/env.dart'), '''
@DoxEnv()
abstract class AppEnv {
  String get appName => 'dox';

  String get dbName => 'db/dox.sqlite';
}

final AppEnv env = AppEnv.load();
''');
    expect(installer.ok, isTrue);
  });

  test('addEnvGetter fails with a hint when there is no AppEnv', () {
    installer.addEnvGetter('String get dbName;');
    expect(installer.ok, isFalse);
    expect(installer.lines.single, contains('add `String get dbName;`'));
  });

  test('hasDependency looks only in dependencies and dev_dependencies', () {
    expect(installer.hasDependency('dox_core'), isTrue);
    expect(installer.hasDependency('dox_builder'), isTrue);
    expect(installer.hasDependency('dox_orm'), isFalse);
  });

  test('addDependency runs dart pub add only when it is missing', () async {
    await installer.addDependency('dox_core');
    await installer.addDependency('dox_migration');
    await installer.addDependency('build_runner', dev: true);
    expect(runner.calls, <String>[
      'pub add dox_migration',
      'pub add --dev build_runner',
    ]);
  });

  test('a failed command sets ok to false', () async {
    installer = Installer(root: root, runner: FakeRunner(1));
    expect(await installer.buildRunner(), isFalse);
    expect(installer.ok, isFalse);
    expect(installer.lines.single, 'failed   build_runner');
  });
}
