// ignore_for_file: file_names
import 'package:dox_migration/dox_migration.dart';
import 'package:dox_queue_database/dox_queue_database.dart';

/// The jobs and failed_jobs tables of dox_queue_database.
class CreateQueueTables extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await QueueTables.up(schema);
  }

  @override
  Future<void> down(Schema schema) async {
    await QueueTables.down(schema);
  }
}
