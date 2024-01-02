import 'package:dox_query_builder/dox_query_builder.dart';
import 'package:test/test.dart';

import 'connection.dart';
import 'models/blog/blog.model.dart';
import 'models/blog_info/blog_info.model.dart';

void main() async {
  await initQueryBuilder();

  group('Has One |', () {
    setUp(() async {
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

    test('eager load hasMany', () async {
      Blog blog = Blog();
      blog.title = 'Awesome blog';
      blog.description = 'Awesome blog body';
      await blog.save();

      BlogInfo blogInfo = BlogInfo();
      blogInfo.info = <String, String>{"name": "awesome"};
      blogInfo.blogId = blog.uid;
      await blogInfo.save();

      await blog.reload();

      expect(blog.blogInfos.first.info?['name'], 'awesome');
    });

    test('eager load hasMany', () async {
      Blog blog = Blog();
      blog.title = 'Awesome blog';
      blog.description = 'Awesome blog body';
      await blog.save();

      BlogInfo blogInfo = BlogInfo();
      blogInfo.info = <String, String>{"name": "awesome"};
      blogInfo.blogId = blog.uid;
      await blogInfo.save();

      Blog? b = await Blog().getFirst();
      expect(b?.blogInfos.first.info?['name'], 'awesome');
    });
  });
}
