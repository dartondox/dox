import 'dart:io';

/// `dox openapi:generate [dir]`: run the app's `bin/openapi.dart`, which
/// writes `openapi.json` and `openapi.yaml` (default `storage/openapi`).
/// sets exit code 1 when the file is missing or the run fails.
Future<void> openApiGenerate(List<String> args) async {
  File entry = File('${Directory.current.path}/bin/openapi.dart');
  if (!entry.existsSync()) {
    print(
      'bin/openapi.dart is missing. Make it with:\n'
      "  Dox().initialize(appConfig);\n"
      "  await Dox().writeOpenApi(args.isEmpty ? 'storage/openapi' : args.first);\n"
      'See the OpenAPI docs page.',
    );
    exitCode = 1;
    return;
  }
  String exe = Platform.resolvedExecutable;
  String dart = exe.split(Platform.pathSeparator).last.startsWith('dart')
      ? exe
      : 'dart';
  Process process = await Process.start(dart, [
    'run',
    'bin/openapi.dart',
    ...args,
  ], mode: ProcessStartMode.inheritStdio);
  int code = await process.exitCode;
  if (code != 0) exitCode = code;
}
