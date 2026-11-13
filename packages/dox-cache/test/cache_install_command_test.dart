import 'dart:io';

import 'package:dox_annotation/install.dart';
import 'package:dox_cache/commands.dart';
import 'package:test/test.dart';

/// records the `dart` commands, runs nothing
class FakeRunner extends ProcessRunner {
  final List<String> calls = <String>[];

  @override
  Future<int> run(String executable, List<String> args, String folder) async {
    calls.add(args.join(' '));
    return 0;
  }
}

const String envDart = '''
abstract class AppEnv {
  String get appName => 'dox';
}
''';

const String appDart = '''
import 'package:dox_core/dox_core.dart';
import 'package:my_app/config/env.dart';

AppConfig appConfig = AppConfig(
  // keep this comment
  appKey: env.appKey,
);
''';

void main() {
  late Directory root;
  late FakeRunner runner;

  setUp(() {
    root = Directory.systemTemp.createTempSync('dox_cache_install_');
    File(
      '${root.path}/pubspec.yaml',
    ).writeAsStringSync('name: my_app\n\ndependencies:\n  dox_core: ^3.1.0\n');
    File('${root.path}/.env').writeAsStringSync('APP_KEY=x\n');
    File('${root.path}/lib/config/env.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync(envDart);
    File('${root.path}/lib/config/app.dart').writeAsStringSync(appDart);
    runner = FakeRunner();
    exitCode = 0;
  });

  tearDown(() {
    root.deleteSync(recursive: true);
  });

  String read(String path) => File('${root.path}/$path').readAsStringSync();

  Future<void> install(List<String> args) {
    return CacheInstallCommand(root: root, runner: runner).run(args);
  }

  /// every file of the app and its text
  Map<String, String> snapshot() {
    Map<String, String> files = <String, String>{};
    for (FileSystemEntity f in root.listSync(recursive: true)) {
      if (f is File) files[f.path] = f.readAsStringSync();
    }
    return files;
  }

  test('sets up the file store by default', () async {
    await install(<String>[]);
    expect(exitCode, 0);
    expect(runner.calls, <String>[
      'pub add dox_cache',
      'run build_runner build',
    ]);
    expect(
      read('lib/config/cache.dart'),
      contains("import 'package:my_app/config/env.dart';"),
    );
    expect(read('lib/config/cache.dart'), isNot(contains("'redis'")));
    expect(read('.env'), contains('CACHE_STORE=file\n'));
    expect(read('lib/config/env.dart'), contains("cacheStore => 'file'"));
    expect(
      read('lib/config/app.dart'),
      contains("import 'package:my_app/config/cache.dart';"),
    );
    expect(read('lib/config/app.dart'), contains('  cache: cache,\n'));
    expect(read('lib/config/app.dart'), contains('// keep this comment'));
  });

  test('redis adds its store, getters and keys', () async {
    await install(<String>['--store=redis']);
    expect(exitCode, 0);
    expect(read('lib/config/cache.dart'), contains("'driver': 'redis'"));
    expect(read('lib/config/env.dart'), contains('int get redisPort => 6379;'));
    expect(read('.env'), contains('CACHE_STORE=redis\n'));
    expect(read('.env'), contains('REDIS_HOST=127.0.0.1\n'));
  });

  test('memory sets CACHE_STORE', () async {
    await install(<String>['--store', 'memory']);
    expect(read('.env'), contains('CACHE_STORE=memory\n'));
  });

  test('database without the ORM adds the driver and a hint', () async {
    await install(<String>['--store=database']);
    expect(exitCode, 0);
    expect(runner.calls, contains('pub add dox_cache_database'));
    expect(
      read('lib/providers/cache_provider.dart'),
      contains('DatabaseCacheDriverFactory'),
    );
    expect(read('lib/config/cache.dart'), contains("'driver': 'database'"));
    expect(Directory('${root.path}/db/migration').existsSync(), isFalse);
  });

  test('database with the ORM writes the table migration once', () async {
    File('${root.path}/pubspec.yaml').writeAsStringSync(
      'name: my_app\n\ndependencies:\n  dox_orm: ^3.1.0\n'
      '  dox_migration: ^3.1.0\n',
    );
    await install(<String>['--store=database']);
    List<String> names = Directory('${root.path}/db/migration')
        .listSync()
        .map((FileSystemEntity f) => f.uri.pathSegments.last)
        .toList();
    expect(names.single, endsWith('_create_cache_table.dart'));
    expect(read('db/migration/${names.single}'), contains('CacheTables.up'));
    Map<String, String> before = snapshot();
    await install(<String>['--store=database']);
    expect(snapshot(), before);
  });

  test('a second run changes nothing', () async {
    await install(<String>['--store=redis']);
    File('${root.path}/lib/config/cache.dart').writeAsStringSync('mine');
    Map<String, String> before = snapshot();
    await install(<String>['--store=memory']);
    expect(snapshot(), before);
  });

  test('a bad option stops with exit code 1 and writes nothing', () async {
    for (List<String> args in <List<String>>[
      <String>['--store=s3'],
      <String>['--stor=redis'],
      <String>['--store'],
      <String>['--store='],
      <String>['redis'],
    ]) {
      Map<String, String> before = snapshot();
      await install(args);
      expect(exitCode, 1, reason: '$args');
      expect(runner.calls, isEmpty, reason: '$args');
      expect(snapshot(), before, reason: '$args');
      exitCode = 0;
    }
  });

  test('an app.dart with its own cache stays the same', () async {
    String mine = appDart.replaceFirst('appKey', 'cache: myCache,\n  appKey');
    File('${root.path}/lib/config/app.dart').writeAsStringSync(mine);
    await install(<String>[]);
    expect(read('lib/config/app.dart'), mine);
  });

  test(
    'without AppEnv it gives a hint, exit code 1, and changes nothing',
    () async {
      for (String? env in <String?>[null, 'class Other {\n}\n']) {
        File file = File('${root.path}/lib/config/env.dart');
        if (env == null) {
          file.deleteSync();
        } else {
          file.writeAsStringSync(env);
        }
        Map<String, String> before = snapshot();
        await install(<String>[]);
        expect(exitCode, 1);
        expect(runner.calls, isEmpty);
        expect(snapshot(), before);
        exitCode = 0;
      }
    },
  );
}
