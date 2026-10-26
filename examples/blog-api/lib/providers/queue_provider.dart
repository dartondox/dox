import 'package:dox_queue/dox_queue.dart';
import 'package:blog/config/queue.dart';

/// Queue provider
/// --------------------------
/// Sets up the queue, so jobs can be dispatched.
/// If this project does not need a queue, delete this file
/// (Dox finds every DoxProvider class, see lib/generated/container.g.dart).
class AppQueueProvider extends QueueProvider {
  AppQueueProvider() : super(queueConfig);
}
