import 'package:dox_orm/dox_orm.dart';
import 'package:dox_orm/factory.dart';
import 'package:test/test.dart';

import 'connection.dart';
import 'models/blog/blog.model.dart';
import 'models/blog_info/blog_info.model.dart';

class BlogFactory extends Factory<Blog> {
  int made = 0;

  @override
  Blog definition() {
    made++;
    return Blog()
      ..title = 'Blog $made'
      ..description = 'Body';
  }
}

class BlogInfoFactory extends Factory<BlogInfo> {
  @override
  BlogInfo definition() {
    return BlogInfo()..info = <String, dynamic>{'name': 'info'};
  }
}

void main() async {
  await initQueryBuilder();

  group('Factory |', () {
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
    });

    tearDown(() async {
      await Schema().dropIfExists('blog');
      await Schema().dropIfExists('blog_info');
    });

    test('make does not save, definition runs once per model', () async {
      BlogFactory factory = BlogFactory();
      List<Blog> blogs = factory.count(3).make();
      expect(blogs.map((Blog b) => b.title), <String>[
        'Blog 1',
        'Blog 2',
        'Blog 3',
      ]);
      expect(blogs.every((Blog b) => b.uid == null), isTrue);
      expect(BlogFactory().makeOne().title, 'Blog 1');
      expect(await Blog().count(), 0);
    });

    test('create saves, with state and sequence in order', () async {
      List<Blog> blogs = await BlogFactory()
          .count(2)
          .state((Blog b) => b..description = 'From state')
          .sequence((Blog b, int i) => b..title = 'Title $i')
          .create();
      expect(blogs.every((Blog b) => b.uid != null), isTrue);
      expect(await Blog().count(), 2);
      Blog? first = await Blog().find(blogs.first.uid);
      expect(first?.title, 'Title 0');
      expect(first?.description, 'From state');
      expect((await Blog().find(blogs.last.uid))?.title, 'Title 1');
    });

    test('createOne and count(0)', () async {
      Blog blog = await BlogFactory().createOne();
      expect(blog.uid, isNotNull);
      expect(await BlogFactory().count(0).create(), isEmpty);
      expect(await Blog().count(), 1);
    });

    test('state sets a parent', () async {
      Blog blog = await BlogFactory().createOne();
      await BlogInfoFactory()
          .count(2)
          .state((BlogInfo i) => i..blogId = blog.uid)
          .create();
      expect(await BlogInfo().where('blog_id', blog.uid).count(), 2);
    });

    test('has creates the children of each parent', () async {
      List<Blog> blogs = await BlogFactory()
          .count(2)
          .has(
            BlogInfoFactory().count(3),
            (BlogInfo i, Blog b) => i..blogId = b.uid,
          )
          .create();
      expect(await BlogInfo().count(), 6);
      for (Blog blog in blogs) {
        expect(await BlogInfo().where('blog_id', blog.uid).count(), 3);
      }
    });

    test('count can not be negative', () {
      expect(() => BlogFactory().count(-1), throwsArgumentError);
    });
  });
}
