// ignore_for_file: file_names
import 'package:dox_migration/dox_migration.dart';

/// The `users` table for `dox_auth`. Works on Postgres, MySQL and SQLite.
class CreateUsersTable extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await schema.create('users', (Table table) {
      table.id();
      table.string('name');
      table.string('email').unique();
      table.string('password');
      table.softDeletes();
      table.timestamps();
    });
  }

  @override
  Future<void> down(Schema schema) async {
    await schema.dropIfExists('users');
  }
}
