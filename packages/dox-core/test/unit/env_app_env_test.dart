import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';

/// `Env.appEnv` and `AppConfig.isDevelopment` read as the FIRST env read of
/// a new process, so nothing else loaded `.env` before them.
void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('dox_app_env');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<String> run(
    String body,
    String dotEnv,
    Map<String, String> shell,
  ) async {
    File('${dir.path}/.env').writeAsStringSync(dotEnv);
    File script = File('${dir.path}/main.dart')
      ..writeAsStringSync('''
import 'package:dox_core/dox_core.dart';

void main() {
  print($body);
}
''');
    Uri? packages = await Isolate.packageConfig;
    ProcessResult result = await Process.run(
      Platform.resolvedExecutable,
      <String>['--packages=${packages!.toFilePath()}', script.path],
      workingDirectory: dir.path,
      environment: shell,
      includeParentEnvironment: false,
    );
    expect(result.exitCode, 0, reason: '${result.stderr}');
    return (result.stdout as String).trim();
  }

  const String appEnv = 'Env.appEnv';
  const String isDevelopment = "AppConfig(appKey: '').isDevelopment";
  const Map<String, String> noShell = <String, String>{};

  test('Env.appEnv read first gives the value of the .env file', () async {
    expect(await run(appEnv, 'APP_ENV=Development\n', noShell), 'development');
  });

  test('Env.appEnv read first: the shell still wins', () async {
    expect(
      await run(appEnv, 'APP_ENV=development\n', <String, String>{
        'APP_ENV': 'production',
      }),
      'production',
    );
  });

  test('Env.appEnv read first: not set is empty (production)', () async {
    expect(await run(appEnv, 'APP_NAME=x\n', noShell), '');
  });

  test('AppConfig.isDevelopment read first sees the .env file', () async {
    expect(await run(isDevelopment, 'APP_ENV=development\n', noShell), 'true');
    expect(await run(isDevelopment, 'APP_ENV=production\n', noShell), 'false');
    expect(await run(isDevelopment, 'APP_NAME=x\n', noShell), 'false');
  });
}
