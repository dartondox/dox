import 'dart:async';
import 'dart:io';

/// `dart run <script> <args>` in the app, with the output on this terminal.
/// stdin, stdout and stderr go straight to the child.
/// SIGINT and SIGTERM are sent on to the child, so a long job like
/// `queue:work` can stop by itself. Returns the exit code of the child.
Future<int> runScript(String script, List<String> args) async {
  String exe = Platform.resolvedExecutable;
  String dart = exe.split(Platform.pathSeparator).last.startsWith('dart')
      ? exe
      : 'dart';
  Process process = await Process.start(dart, <String>[
    'run',
    script,
    ...args,
  ], mode: ProcessStartMode.inheritStdio);

  List<StreamSubscription<ProcessSignal>> subscriptions =
      <StreamSubscription<ProcessSignal>>[];
  subscriptions.add(
    ProcessSignal.sigint.watch().listen(
      (ProcessSignal signal) => process.kill(ProcessSignal.sigint),
    ),
  );
  // SIGTERM can not be watched on Windows
  if (!Platform.isWindows) {
    subscriptions.add(
      ProcessSignal.sigterm.watch().listen(
        (ProcessSignal signal) => process.kill(ProcessSignal.sigterm),
      ),
    );
  }
  int code = await process.exitCode;
  for (StreamSubscription<ProcessSignal> subscription in subscriptions) {
    await subscription.cancel();
  }
  return code;
}
