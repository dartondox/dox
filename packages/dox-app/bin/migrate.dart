import 'dart:io';

import 'package:dox_migration/dox_migration.dart';

import '../db/migration/migrations.dart';

/// run the migrations of db/migration (Dart and .sql files):
/// `dart run bin/migrate.dart <run|rollback [--step=n]|reset|refresh|status>`.
/// `dox migration:*` commands run this file.
/// the database is from `.env` (DB_CONNECTION, DB_HOST, DB_PORT, ...).
Future<void> main(List<String> args) async {
  exitCode = await Migrator(migrations: migrations).run(args);
}
