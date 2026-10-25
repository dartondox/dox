import 'dart:io';

import '../utils/run_script.dart';

/// message for `dox queue:*` when `bin/queue.dart` is missing
const String queueMissingMessage =
    'bin/queue.dart is missing.\n'
    '1. Add dox_queue to pubspec.yaml: `dart pub add dox_queue`\n'
    '2. Run `dox make:job <name>` once. It makes the job and bin/queue.dart.\n'
    '3. Run `dox build_runner:build`.';

/// message for `dox schedule:*` when `bin/schedule.dart` is missing
const String scheduleMissingMessage =
    'bin/schedule.dart is missing.\n'
    '1. Add dox_scheduler to pubspec.yaml: `dart pub add dox_scheduler`\n'
    '2. Make bin/schedule.dart and lib/config/schedule.dart.\n'
    '   See the Task Scheduling docs page for the two small files.';

/// `dox queue:*`: run `dart run bin/queue.dart <sub> <args>`
Future<void> runQueue(String sub, List<String> args) {
  return _run('bin/queue.dart', queueMissingMessage, sub, args);
}

/// `dox schedule:*`: run `dart run bin/schedule.dart <sub> <args>`
Future<void> runSchedule(String sub, List<String> args) {
  return _run('bin/schedule.dart', scheduleMissingMessage, sub, args);
}

/// run the app script. Print [missing] and set exit code 1 when the
/// file is not there. Else set the exit code of the child.
Future<void> _run(
  String script,
  String missing,
  String sub,
  List<String> args,
) async {
  if (!File('${Directory.current.path}/$script').existsSync()) {
    print(missing);
    exitCode = 1;
    return;
  }
  int code = await runScript(script, <String>[sub, ...args]);
  if (code != 0) exitCode = code;
}
