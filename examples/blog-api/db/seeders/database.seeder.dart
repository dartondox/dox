import 'package:dox_migration/dox_migration.dart';

import 'user.seeder.dart';

class DatabaseSeeder extends Seeder {
  @override
  Future<void> run() async {
    await call(<Seeder>[UserSeeder()]);
  }
}
