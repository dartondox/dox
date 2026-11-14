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

  /// [dotEnv] null: no `.env` file. [body] is the code of `main()`.
  Future<String> runCode(
    String body,
    String? dotEnv,
    Map<String, String> shell,
  ) async {
    if (dotEnv != null) File('${dir.path}/.env').writeAsStringSync(dotEnv);
    File script = File('${dir.path}/main.dart')
      ..writeAsStringSync('''
import 'dart:io';

import 'package:dox_core/dox_core.dart';

void main() {
  $body
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

  Future<String> run(
    String expression,
    String? dotEnv,
    Map<String, String> shell,
  ) {
    return runCode('print($expression);', dotEnv, shell);
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

  test('Env.get read first gives the value of the .env file', () async {
    expect(await run("Env.get('DB_NAME')", 'DB_NAME=file\n', noShell), 'file');
    expect(
      await run("Env.get<int>('APP_PORT', 1)", 'APP_PORT=4000\n', noShell),
      '4000',
    );
  });

  test('Env.get read first: the shell still wins', () async {
    expect(
      await run("Env.get('DB_NAME')", 'DB_NAME=file\n', <String, String>{
        'DB_NAME': 'shell',
      }),
      'shell',
    );
  });

  test(
    'Env.get read first: a missing file or empty key gives the default',
    () async {
      expect(await run("Env.get('DB_NAME', 'dflt')", null, noShell), 'dflt');
      expect(
        await run("Env.get('DB_NAME', 'dflt')", 'DB_NAME=\n', noShell),
        'dflt',
      );
    },
  );

  test('the file is read once: a .env made later is not read', () async {
    String code = '''
  print(Env.get('DB_NAME', 'dflt'));
  File('.env').writeAsStringSync('DB_NAME=late\\n');
  print(Env.get('DB_NAME', 'dflt'));
  print(Env.appEnv);
''';
    expect(await runCode(code, null, noShell), 'dflt\ndflt');
  });

  test('a map set on purpose is not mixed with the .env file', () async {
    String dotEnv = 'DB_NAME=file\nKEEP=yes\n';
    expect(
      await runCode(
        "Env().env = <String, String>{};\n  print(Env.get('DB_NAME', 'dflt'));",
        dotEnv,
        noShell,
      ),
      'dflt',
    );
    expect(
      await runCode(
        "Env().env = <String, String>{'DB_NAME': 'set'};\n"
        "  print([Env.get('DB_NAME'), Env.get('KEEP', 'no')]);",
        dotEnv,
        noShell,
      ),
      '[set, no]',
    );
    // an explicit load() on an empty map still reads the file
    expect(
      await runCode(
        'Env().env = <String, String>{};\n  Env().load();\n'
        "  print(Env.get('DB_NAME'));",
        dotEnv,
        noShell,
      ),
      'file',
    );
    // EnvReader with its own maps reads no file
    expect(
      await runCode(
        "print(EnvReader(environment: {}, dotEnv: {}).raw('DB_NAME'));",
        dotEnv,
        noShell,
      ),
      'null',
    );
  });
}
