// Made by `dox make:seeder` and `dox db:seed`.
// Do not edit, it is made again from the files in this folder.
import 'package:dox_migration/dox_migration.dart';

import 'database.seeder.dart';
import 'user.seeder.dart';

/// all seeders of db/seeders
final List<Seeder> seeders = <Seeder>[DatabaseSeeder(), UserSeeder()];
