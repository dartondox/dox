import 'package:dox_queue/dox_queue.dart';
import 'package:my_app/generated/jobs.g.dart';

/// Queue settings
/// -------------------------------
/// `driver`: sync, database or redis. The database driver needs the
/// jobs tables (db/migration/..._create_queue_tables.dart).
/// `jobs`: every @Job class, from lib/generated/jobs.g.dart.
/// `workInProcess`: true runs jobs inside the web server. Heavy jobs
/// slow it down, so the default runs `dart run bin/queue.dart work`
/// next to the server.
QueueConfig queueConfig = QueueConfig(driver: 'database', jobs: jobRegistry);
