import 'dart:io';

import 'package:dox_migration/dox_migration.dart';

import '../db/seeders/seeders.dart';

/// run a seeder of db/seeders:
/// `dart run bin/seed.dart [--class=UserSeeder]`, default DatabaseSeeder.
/// `dox db:seed` runs this file.
/// the database is from `.env` (DB_CONNECTION, DB_HOST, DB_PORT, ...).
Future<void> main(List<String> args) async {
  exitCode = await SeederRunner(seeders: seeders).run(args);
}
