import 'package:dox_scheduler/dox_scheduler.dart';

/// Scheduler settings
/// -------------------------------
/// `store`: the cache store for the locks (config/cache.dart). Default:
/// the default store. Use a Redis store when many servers run the
/// schedule, so each task runs once per minute.
/// `inProcess`: run the schedule inside the server
/// (lib/providers/schedule_provider.dart). Off: run
/// `dart run bin/schedule.dart work` next to the server.
ScheduleConfig scheduleConfig = const ScheduleConfig();

/// Scheduled tasks
/// -------------------------------
/// Add a task with `s.call(name, function)` and a frequency.
/// `dart run bin/schedule.dart list` shows them and their next run time.
/// The times are UTC unless you call `timezone('Asia/Yangon')`.
void schedule(Schedule s) {
  // s.call('cleanup', cleanup).dailyAt('02:00');
  // s.call('report', () => SendReport().dispatch()).hourly();
}
