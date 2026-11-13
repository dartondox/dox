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
    expect(installer.lines, <String>[
      'added    DB_NAME to .env',
      'skipped  DB_NAME in .env.example (already there)',
      'skipped  DB_NAME in .env.example, .env (already there)',
    ]);
  });

  test('addEnv sees a key with export, spaces or CRLF', () {
    for (String text in <String>[
      'export DB_NAME=a\n',
      'DB_NAME = a\n',
      '  DB_NAME\t=a\n',
      'APP=1\r\nDB_NAME=a\r\n',
      'DB_NAME=',
    ]) {
      File('${root.path}/.env').writeAsStringSync(text);
      installer.addEnv('DB_NAME', 'b');
      expect(read('.env'), text, reason: text);
    }
  });

  test('addEnv adds a key that is only in a comment or a longer key', () {
    File('${root.path}/.env').writeAsStringSync('# DB_NAME=a\nDB_NAME_X=1');
    installer.addEnv('DB_NAME', 'b');
    expect(read('.env'), '# DB_NAME=a\nDB_NAME_X=1\nDB_NAME=b\n');
  });

  test('addEnv says so when there is no .env file', () {
    installer.addEnv('DB_NAME', 'x');
    expect(File('${root.path}/.env').existsSync(), isFalse);
    expect(installer.lines, <String>[
      'skipped  DB_NAME: there is no .env or .env.example',
    ]);
  });

  void writeEnv(String text) {
    File('${root.path}/lib/config/env.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);
  }

  test('addEnvGetter adds a getter to AppEnv once', () {
    writeEnv(envDart);
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
    expect(installer.lines, <String>[
      'added    dbName to AppEnv in lib/config/env.dart',
      'skipped  dbName in AppEnv (already there)',
      'skipped  appName in AppEnv (already there)',
    ]);
    expect(installer.ok, isTrue);
  });

  test('addEnvGetter keeps the doc comment of the getter', () {
    writeEnv('abstract class AppEnv {}\n');
    installer.addEnvGetter('/// the port\n  int? get dbPort;');
    expect(
      read('lib/config/env.dart'),
      'abstract class AppEnv {\n  /// the port\n  int? get dbPort;\n}\n',
    );
  });

  test('addEnvGetter finds the end of the class by its braces', () {
    writeEnv('''
abstract class AppEnv {
  String get a => '}';
  // a } in a comment
  Map<String, int> get b => <String, int>{};
}

class Other {
}
''');
    installer.addEnvGetter('String get c;');
    expect(read('lib/config/env.dart'), '''
abstract class AppEnv {
  String get a => '}';
  // a } in a comment
  Map<String, int> get b => <String, int>{};

  String get c;
}

class Other {
}
''');
  });

  test('addEnvGetter skips a member with the same name', () {
    String text =
        "abstract class AppEnv {\n  static const String dbHost = 'x';\n}\n";
    writeEnv(text);
    installer.addEnvGetter('String get dbHost;');
    expect(read('lib/config/env.dart'), text);
    expect(installer.ok, isTrue);
  });

  test('addEnvGetter changes nothing when it is not sure', () {
    for (String text in <String>[
      'abstract class AppEnvironment {\n}\n',
      '/// abstract class AppEnv {\nclass Other {\n}\n',
      'abstract class AppEnv {\n  String get a;\n',
      'class AppEnv {\n}\n',
    ]) {
      writeEnv(text);
      installer = Installer(root: root, runner: runner);
      installer.addEnvGetter('String get dbName;');
      expect(read('lib/config/env.dart'), text, reason: text);
      expect(installer.ok, isFalse, reason: text);
      expect(
        installer.lines.single,
        'failed   dbName: add `String get dbName;` to AppEnv in '
        'lib/config/env.dart',
      );
    }
  });

  test('addEnvGetter fails with a hint when there is no env.dart', () {
    installer.addEnvGetter('String get dbName;');
    expect(installer.ok, isFalse);
    expect(installer.lines.single, contains('add `String get dbName;`'));
  });

  test('lines is read only, note adds a line', () {
    installer.note('added    hooks to pubspec.yaml');
    expect(installer.lines, <String>['added    hooks to pubspec.yaml']);
    expect(() => installer.lines.add('x'), throwsUnsupportedError);
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
