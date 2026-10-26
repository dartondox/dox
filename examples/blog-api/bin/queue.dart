import 'dart:io';

import 'package:dox_queue/dox_queue.dart';
import 'package:blog/config/app.dart';

/// run queued jobs: `dart run bin/queue.dart [work] [flags]`, or `dox queue:work`.
/// - work: run jobs until Ctrl+C or SIGTERM.
/// - `failed`, `retry <id|all>`, `forget <id>`, `flush`: manage failed jobs.
Future<void> main(List<String> args) async {
  exitCode = await QueueWorker(app: appConfig).run(args);
}
