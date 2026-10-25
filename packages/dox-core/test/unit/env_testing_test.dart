import 'dart:io';
import 'dart:isolate';

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('dox_env_testing');
    File('${dir.path}/.env').writeAsStringSync('DB_NAME=app\nKEEP=yes\n');
    File('${dir.path}/.env.testing').writeAsStringSync('DB_NAME=app_test\n');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Map<String, String> load({required bool testing}) {
    Map<String, String> saved = Env().env;
    Env().env = <String, String>{};
    Env().load(file: File('${dir.path}/.env'), testing: testing);
    Map<String, String> result = Env().env;
    Env().env = saved;
    return result;
  }

  test('runs under dart test', () {
    expect(Env.isTesting, isTrue);
  });

  test('.env.testing wins over .env in tests', () {
    expect(load(testing: true), <String, String>{
      'DB_NAME': 'app_test',
      'KEEP': 'yes',
    });
  });

  test('.env.testing is not read outside tests', () {
    expect(load(testing: false)['DB_NAME'], 'app');
  });

  test('APP_ENV=testing reads .env.testing and a real env var wins', () async {
    File script = File('${dir.path}/main.dart')
      ..writeAsStringSync('''
import 'package:dox_core/env/env.dart';
import 'package:dox_core/env/env_reader.dart';

void main() {
  Env().load();
  print([Env.get('DB_NAME'), Env.get('KEEP'), EnvReader().raw('DB_NAME')]);
}
''');
    Uri? packages = await Isolate.packageConfig;
    Future<String> run(Map<String, String> environment) async {
      ProcessResult result = await Process.run(
        Platform.resolvedExecutable,
        <String>['--packages=${packages!.toFilePath()}', script.path],
        workingDirectory: dir.path,
        environment: environment,
        includeParentEnvironment: false,
      );
      expect(result.exitCode, 0, reason: '${result.stderr}');
      return (result.stdout as String).trim();
    }

    expect(await run(<String, String>{}), '[app, yes, app]');
    expect(
      await run(<String, String>{'APP_ENV': 'testing'}),
      '[app_test, yes, app_test]',
    );
    expect(
      await run(<String, String>{'APP_ENV': 'testing', 'DB_NAME': 'shell'}),
      '[shell, yes, shell]',
    );
  });
}
