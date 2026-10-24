import 'package:dox_orm/dox_orm.dart';
import 'package:test/test.dart';

import 'connection.dart';
import 'models/blog/blog.model.dart';
import 'models/blog_info/blog_info.model.dart';

void main() async {
  await initQueryBuilder();

  group('Belongs To |', () {
    setUp(() async {
      await Schema().create('blog', (Table table) {
        table.id('uid');
        table.string('title');
        table.string('status').withDefault('active');
        table.text('body');
        table.string('slug').nullable();
        table.softDeletes();
        table.timestamps();
      });

      await Schema().create('blog_info', (Table table) {
        table.id();
        table.json('info');
        table.integer('blog_id');
        table.timestamps();
      });

      await Schema().create('comment', (Table table) {
        table.id();
        table.string('comment').nullable();
        table.integer('blog_id');
        table.timestamps();
      });
    });

    tearDown(() async {
      await Schema().dropIfExists('blog');
      await Schema().dropIfExists('blog_info');
      await Schema().dropIfExists('comment');
    });

    test('belongs to loads each owner once, not once per child', () async {
      Blog blog = Blog()
        ..title = 'one'
        ..description = 'b';
      await blog.save();
      Blog other = Blog()
        ..title = 'two'
        ..description = 'b';
      await other.save();

      /// many children of one blog, and one child of the other
      for (int i = 0; i < 3; i++) {
        await (BlogInfo()
              ..info = <String, String>{'n': '$i'}
              ..blogId = blog.uid)
            .save();
      }
      await (BlogInfo()
            ..info = <String, String>{'n': 'x'}
            ..blogId = other.uid)
          .save();

      List<BlogInfo> infos = await BlogInfo().preload('blog').get();
      expect(infos.length, 4);
      expect(infos.map((BlogInfo i) => i.blog?.title), <String>[
        'one',
        'one',
        'one',
        'two',
      ]);

      /// the relation query finds two blogs, not one row per child
      Blog? query = infos.first.related<Blog>('blog');
      expect((await query!.get()).length, 1);
      Blog? all = BlogInfoGenerator.queryBlog(infos);
      expect((await all!.get()).length, 2);
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
