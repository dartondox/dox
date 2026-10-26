import 'dart:async';

import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/models/user/user.model.dart';

/// Work on a timer. `setup()` runs in every isolate, so the timer is
/// started on isolate 1 only. Otherwise 8 isolates do the same job.
class CleanupProvider extends DoxProvider {
  @override
  void setup() {
    if (Dox().isolateId != 1) return;
    Timer.periodic(const Duration(hours: 1), _run);
  }

  Future<void> _run(Timer timer) async {
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
}
