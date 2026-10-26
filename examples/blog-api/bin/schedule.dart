import 'dart:io';

import 'package:blog/config/app.dart';
import 'package:blog/config/schedule.dart';
import 'package:dox_scheduler/dox_scheduler.dart';

/// run the scheduled tasks of lib/config/schedule.dart:
/// `dart run bin/schedule.dart <work|run|list|test <name>>`, default work.
/// - work: run due tasks at every minute, until Ctrl+C or SIGTERM.
/// - run: run the tasks due this minute once (for a system cron).
/// - list: show each task, its schedule and next run time.
/// - test cleanup: run the task named cleanup now.
/// the app providers (like the database) start first.
Future<void> main(List<String> args) async {
  exitCode = await SchedulerRunner(
    schedule: schedule,
    app: appConfig,
    config: scheduleConfig,
  ).run(args);
}
