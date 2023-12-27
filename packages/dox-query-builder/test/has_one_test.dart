import 'package:dox_query_builder/dox_query_builder.dart';
import 'package:test/test.dart';

import 'connection.dart';
import 'models/blog/blog.model.dart';
import 'models/blog_info/blog_info.model.dart';

void main() async {
  SqlQueryBuilder.initialize(database: await poolConnection());

  group('Has One |', () {
    setUp(() async {
      SqlQueryBuilder.initialize(database: await poolConnection());
      await Schema.create('blog', (Table table) {
        table.id('uid');
        table.string('title');
        table.string('status').withDefault('active');
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

    test('check reload refresh eager loading', () async {
      Blog blog = Blog();
      blog.title = 'Awesome blog';
      blog.description = 'Awesome blog body';
      await blog.save();

      BlogInfo blogInfo = BlogInfo();
      blogInfo.info = <String, String>{"name": "query builder"};
      blogInfo.blogId = blog.uid;
      await blogInfo.save();

      await blog.reload();
      expect(blog.blogInfo?.info?['name'], 'query builder');
    });

    test('eager load hasOne', () async {
      Blog blog = Blog();
      blog.title = 'Awesome blog';
      blog.description = 'Awesome blog body';
      await blog.save();

      BlogInfo blogInfo = BlogInfo();
      blogInfo.info = <String, String>{"name": "query builder"};
      blogInfo.blogId = blog.uid;
      await blogInfo.save();

      Blog? b = await Blog().getFirst();
      expect(b?.blogInfo?.info?['name'], 'query builder');
    });
  });
}
