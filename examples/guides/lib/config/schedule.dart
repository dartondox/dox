import 'package:dox_scheduler/dox_scheduler.dart';
import 'package:my_app/app/models/user/user.model.dart';

/// `inProcess: false`: run `dox schedule:work` next to the server.
ScheduleConfig scheduleConfig = const ScheduleConfig();

/// The tasks. `dox schedule:list` shows them.
void schedule(Schedule s) {
  s.call('cleanup', cleanupUsers).hourly();
}

/// Removes the users that were soft deleted more than 30 days ago.
Future<void> cleanupUsers() async {
  DateTime limit = DateTime.now().subtract(const Duration(days: 30));
  List<User> old = await User()
      .withTrash()
      .where('deleted_at', '<', limit)
      .get();
  int removed = 0;
  for (User user in old) {
    removed += await user.forceDelete();
  }
  print('cleanup: removed $removed users');
}
