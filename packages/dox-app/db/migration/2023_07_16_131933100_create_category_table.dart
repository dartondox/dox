// ignore_for_file: file_names
import 'package:dox_migration/dox_migration.dart';

class CreateCategoryTable extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await schema.create('category', (Table table) {
      table.id();
      table.string('name').unique();
      table.softDeletes();
      table.timestamps();
    });
  }

  @override
  Future<void> down(Schema schema) async {
    await schema.dropIfExists('category');
  }
}
