import 'package:blog/config/schedule.dart';
import 'package:dox_scheduler/dox_scheduler.dart';

/// Scheduler provider
/// --------------------------
/// Runs the schedule inside the server when `scheduleConfig.inProcess`
/// is true (lib/config/schedule.dart). Only the first isolate runs it.
/// When it is off, this provider does nothing.
class ScheduleProvider extends SchedulerProvider {
  ScheduleProvider() : super(schedule: schedule, config: scheduleConfig);
}
