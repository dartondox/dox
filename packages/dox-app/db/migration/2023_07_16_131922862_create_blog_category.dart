// ignore_for_file: file_names
import 'package:dox_migration/dox_migration.dart';

class CreateBlogCategory extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await schema.create('blog_category', (Table table) {
      table.id();
      table.bigInteger('blog_id');
      table.bigInteger('category_id');
    });
  }

  @override
  Future<void> down(Schema schema) async {
    await schema.dropIfExists('blog_category');
  }
}
