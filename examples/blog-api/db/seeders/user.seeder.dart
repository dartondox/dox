import 'package:dox_migration/dox_migration.dart';
import 'package:blog/app/models/user/user.model.dart';

import '../factories/user.factory.dart';

class UserSeeder extends Seeder {
  @override
  Future<void> run() async {
    await UserFactory()
        .count(5)
        .sequence((User u, int i) => u..email = 'user$i@example.com')
        .create();
  }
}
