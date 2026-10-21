// ignore_for_file: file_names
import 'package:dox_migration/dox_migration.dart';

class CreateBlogTable extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await schema.create('blog', (Table table) {
      table.id();
      table.integer('user_id');
      table.string('title');
      table.string('slug');
      table.text('description').nullable();
      table.softDeletes();
      table.timestamps();
    });
  }

  @override
  Future<void> down(Schema schema) async {
    await schema.dropIfExists('blog');
  }
}
