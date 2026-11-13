import 'package:dox_queue_database/dox_queue_database.dart';
import 'package:blog/config/queue.dart';

/// Queue provider
/// --------------------------
/// Sets up the queue, so jobs can be dispatched. `DatabaseQueueProvider`
/// also turns on the database driver, batches and afterCommit.
/// If this project does not need a queue, delete this file
/// (Dox finds every DoxProvider class, see lib/generated/container.g.dart).
class AppQueueProvider extends DatabaseQueueProvider {
  AppQueueProvider() : super(queueConfig);
}
