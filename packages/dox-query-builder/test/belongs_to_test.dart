import 'package:dox_query_builder/dox_query_builder.dart';
import 'package:test/test.dart';

import 'connection.dart';
import 'models/blog/blog.model.dart';
import 'models/blog_info/blog_info.model.dart';

void main() async {
  SqlQueryBuilder.initialize(database: await connection());

  group('Belongs To |', () {
    setUp(() async {
      SqlQueryBuilder.initialize(database: poolConnection());
      await Schema.create('blog', (Table table) {
        table.id('uid');
        table.string('title');
        table.char('status').withDefault('active');
        table.text('body');
        table.string('slug').nullable();
        table.softDeletes();
        table.timestamps();
      });

      await Schema.create('blog_info', (Table table) {
        table.id('id');
        table.json('info');
        table.integer('blog_id');
        table.timestamps();
      });

      await Schema.create('comment', (Table table) {
        table.id('id');
        table.string('comment').nullable();
        table.integer('blog_id');
        table.timestamps();
      });
    });

    tearDown(() async {
      await Schema.drop('blog');
      await Schema.drop('blog_info');
      await Schema.drop('comment');
    });

    test('belongs To', () async {
      Blog blog = Blog();
      blog.title = 'Awesome blog';
      blog.description = 'Awesome blog body';
      await blog.save();

      BlogInfo blogInfo = BlogInfo();
      blogInfo.info = <String, String>{"name": "awesome"};
      blogInfo.blogId = blog.uid;
      await blogInfo.save();

      /// using $getRelation()
      BlogInfo? info = await BlogInfo().preload('blog').getFirst();
      expect(info?.blog?.title, 'Awesome blog');

      /// using preload()
      BlogInfo? info2 = await BlogInfo().getFirst();
      await info2?.$getRelation('blog');
      expect(info2?.blog?.title, 'Awesome blog');

      /// using related()
      BlogInfo? info3 = await BlogInfo().getFirst();
      Blog? b = await info3?.related<Blog>('blog')?.getFirst();
      expect(b?.title, 'Awesome blog');
    });
  });
}
