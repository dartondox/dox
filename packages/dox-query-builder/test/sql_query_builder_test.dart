import 'dart:convert';

import 'package:dox_query_builder/dox_query_builder.dart';
import 'package:test/test.dart';

import 'connection.dart';
import 'models/blog/blog.model.dart';
import 'models/blog_info/blog_info.model.dart';

void main() async {
  SqlQueryBuilder.initialize(database: poolConnection());

  group('Query Builder', () {
    setUp(() async {
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

    test('truncate', () async {
      Blog blog = Blog();
      blog.title = 'Awesome blog';
      blog.description = 'Awesome blog body';
      await blog.save();

      await Blog().truncate();
      int total = await Blog().count();
      expect(total, 0);
    });

    test('limit', () async {
      await Blog().insertMultiple(<Map<String, dynamic>>[
        <String, dynamic>{
          'title': 'dox query builder',
          'body': 'Best orm for the dart'
        },
        <String, dynamic>{
          'title': 'dox core',
          'body': 'dart web framework',
        }
      ]);

      List<Blog> blogs = await Blog().limit(1).get();
      expect(blogs.length, 1);

      List<Blog> blogs2 = await Blog().limit(2).get();
      expect(blogs2.length, 2);

      List<Blog> blogs3 = await Blog().take(1).get();
      expect(blogs3.length, 1);

      List<Blog> blogs4 = await Blog().take(2).get();
      expect(blogs4.length, 2);
    });

    test('offset', () async {
      await Blog().insertMultiple(<Map<String, dynamic>>[
        <String, dynamic>{
          'title': 'dox query builder',
          'body': 'Best orm for the dart'
        },
        <String, dynamic>{
          'title': 'dox core',
          'body': 'dart web framework',
        }
      ]);

      List<Blog> blog = await Blog().offset(0).limit(1).get();
      expect(blog.first.title, 'dox query builder');

      List<Blog> blog2 = await Blog().offset(1).limit(1).get();
      expect(blog2.first.title, 'dox core');
    });

    test('test query builder with map result', () async {
      Blog blog = Blog();
      blog.title = 'Awesome blog';
      blog.description = 'Awesome blog body';
      await blog.save();

      Map<String, dynamic> b = await QueryBuilder.table('blog')
          .where('title', 'Awesome blog')
          .getFirst();

      expect(b['uid'], 1);
    });

    test('order by', () async {
      await Blog().insertMultiple(<Map<String, dynamic>>[
        <String, dynamic>{'title': 'b', 'body': 'body'},
        <String, dynamic>{'title': 'a', 'body': 'body'},
      ]);

      List<Blog> blogs = await Blog().orderBy('title').get();
      expect(blogs.first.title, 'a');

      List<Blog> blogs2 = await Blog().orderBy('title', 'desc').get();
      expect(blogs2.first.title, 'b');
    });

    test('query', () async {
      Blog blog = Blog();
      blog.title = 'Awesome blog';
      blog.description = 'Awesome blog body';
      await blog.save();

      List<Map<String, Map<String, dynamic>>> b =
          await QueryBuilder.query('select * from blog');

      expect(b.first['blog']?['uid'], 1);
      expect(b.first['blog']?['title'], 'Awesome blog');
      expect(b.first['blog']?['body'], 'Awesome blog body');
    });

    test('group by', () async {
      await Blog().insertMultiple(<Map<String, dynamic>>[
        <String, dynamic>{'title': 'title 1', 'body': 'body'},
        <String, dynamic>{'title': 'title 1', 'body': 'body2'},
        <String, dynamic>{'title': 'title 2', 'body': 'body'},
      ]);

      int total = await Blog().groupBy('status').count();
      expect(total, 3);

      int total2 = await Blog().groupBy(<String>['status', 'title']).count();
      expect(total2, 2);

      List<Map<String, dynamic>> data2 = await Blog()
          .select(<String>['title', 'count(*) as total'])
          .groupBy('title')
          .get();

      expect(data2.first['title'], 'title 1');
      expect(data2.first['total'], 2);

      expect(data2.last['title'], 'title 2');
      expect(data2.last['total'], 1);
    });

    test('rawQuery', () async {
      Blog blog = Blog();
      blog.title = 'Awesome blog';
      blog.description = 'Awesome blog body';
      await blog.save();

      Map<String, dynamic> b = await Blog().rawQuery(
        "select * from blog where title = @title",
        <String, dynamic>{'title': 'Awesome blog'},
      ).getFirst();

      expect(b['uid'], 1);
      expect(b['title'], 'Awesome blog');
      expect(b['body'], 'Awesome blog body');
    });

    test('where', () async {
      Blog blog = Blog();
      blog.title = 'dox query builder';
      blog.description = 'Best Orm';
      await blog.save();

      Blog? findBlog =
          await Blog().where('title', 'dox query builder').getFirst();
      expect(findBlog?.title, 'dox query builder');
      expect(findBlog?.uid, blog.uid);
    });

    test('or where', () async {
      Blog blog = Blog();
      blog.title = 'title 1';
      blog.description = 'Best Orm';
      await blog.save();

      Blog blog2 = Blog();
      blog2.title = 'title 2';
      blog2.description = 'Best Orm';
      await blog2.save();

      List<Blog> blogs = await Blog()
          .where('title', 'title 1')
          .orWhere('title', 'title 2')
          .get();

      expect(blogs.first.title, 'title 1');
      expect(blogs.last.title, 'title 2');
    });

    test('or where raw', () async {
      Blog blog = Blog();
      blog.title = 'title 1';
      blog.description = 'Best Orm';
      await blog.save();

      Blog blog2 = Blog();
      blog2.title = 'title 2';
      blog2.description = 'Best Orm';
      await blog2.save();

      List<Blog> blogs = await Blog().where('title', 'title 1').orWhereRaw(
          'title = @title', <String, String>{'title': 'title 2'}).get();

      expect(blogs.first.title, 'title 1');
      expect(blogs.last.title, 'title 2');
    });

    test('where in', () async {
      Blog blog = Blog();
      blog.title = 'title 1';
      blog.description = 'Best Orm';
      await blog.save();

      Blog blog2 = Blog();
      blog2.title = 'title 2';
      blog2.description = 'Best Orm';
      await blog2.save();

      List<Blog> blogs = await Blog()
          .where('status', '=', 'active')
          .whereIn('uid', <int>[1, 2]).get();

      expect(blogs.first.title, 'title 1');
      expect(blogs.last.title, 'title 2');
    });

    test('where raw', () async {
      Blog blog = Blog();
      blog.title = 'title 1';
      blog.description = 'Best Orm';
      await blog.save();

      Blog blog2 = Blog();
      blog2.title = 'title 2';
      blog2.description = 'Best Orm';
      await blog2.save();

      Blog? findBlog = await Blog()
          .where('status', '=', 'active')
          .whereRaw('uid = @id', <String, String>{'id': '1'}).getFirst();

      expect(findBlog?.uid, 1);
      expect(findBlog?.title, 'title 1');
    });

    test('left join', () async {
      Blog blog = Blog();
      blog.title = 'title 1';
      blog.description = 'Best Orm';
      await blog.save();

      BlogInfo info = BlogInfo();
      info.blogId = blog.uid;
      info.info = <String, String>{"foo": 'bar'};
      await info.save();

      Blog? data = await Blog()
          .leftJoin('blog_info', 'blog_info.blog_id', 'blog.uid')
          .getFirst();

      Map<String, dynamic>? map = data?.toMap(original: true);

      expect(map?['uid'], 1);
      expect(map?['title'], 'title 1');
      expect(map?['id'], 1);
      expect(map?['info']['foo'], 'bar');

      Blog? data2 = await Blog().leftJoinRaw(
          'blog_info on blog_info.blog_id = blog.uid and blog.uid = @id',
          <String, int>{'id': 1}).getFirst();

      Map<String, dynamic>? map2 = data2?.toMap(original: true);

      expect(map2?['uid'], 1);
      expect(map2?['title'], 'title 1');
      expect(map2?['id'], 1);
      expect(map2?['info']['foo'], 'bar');
    });

    test('right join', () async {
      Blog blog = Blog();
      blog.title = 'title 1';
      blog.description = 'Best Orm';
      await blog.save();

      BlogInfo info = BlogInfo();
      info.blogId = blog.uid;
      info.info = <String, String>{"foo": 'bar'};
      await info.save();

      Blog? data = await Blog()
          .rightJoin('blog_info', 'blog_info.blog_id', 'blog.uid')
          .getFirst();

      Map<String, dynamic>? map = data?.toMap(original: true);

      expect(map?['uid'], 1);
      expect(map?['title'], 'title 1');
      expect(map?['id'], 1);
      expect(map?['info']['foo'], 'bar');

      Blog? data2 = await Blog()
          .rightJoinRaw('blog_info on blog_info.blog_id = blog.uid')
          .getFirst();

      Map<String, dynamic>? map2 = data2?.toMap(original: true);

      expect(map2?['uid'], 1);
      expect(map2?['title'], 'title 1');
      expect(map2?['id'], 1);
      expect(map2?['info']['foo'], 'bar');
    });

    test('join', () async {
      Blog blog = Blog();
      blog.title = 'title 1';
      blog.description = 'Best Orm';
      await blog.save();

      BlogInfo info = BlogInfo();
      info.blogId = blog.uid;
      info.info = <String, String>{"foo": 'bar'};
      await info.save();

      Blog? data = await Blog()
          .join('blog_info', 'blog_info.blog_id', 'blog.uid')
          .getFirst();

      Map<String, dynamic>? map = data?.toMap(original: true);

      expect(map?['uid'], 1);
      expect(map?['title'], 'title 1');
      expect(map?['id'], 1);
      expect(map?['info']['foo'], 'bar');

      Blog? data2 = await Blog()
          .joinRaw('blog_info on blog_info.blog_id = blog.uid')
          .getFirst();

      Map<String, dynamic>? map2 = data2?.toMap(original: true);

      expect(map2?['uid'], 1);
      expect(map2?['title'], 'title 1');
      expect(map2?['id'], 1);
      expect(map2?['info']['foo'], 'bar');
    });

    test('paginate', () async {
      List<Map<String, dynamic>> data = <Map<String, dynamic>>[];
      for (int i = 0; i < 43; i++) {
        data.add(<String, dynamic>{
          'title': 'dox query builder',
          'body': 'Best orm for the dart'
        });
      }

      await Blog().insertMultiple(data);

      Pagination pagination = await Blog().paginate(
        currentPage: 1,
        perPage: 10,
      );

      expect(pagination.total, 43);
      expect(pagination.lastPage, 5);
      expect(pagination.perPage, 10);
      expect(pagination.currentPage, 1);
      expect(pagination.data.length, 10);

      Pagination pagination2 = await Blog().paginate(
        currentPage: 5,
        perPage: 10,
      );

      expect(pagination2.total, 43);
      expect(pagination2.lastPage, 5);
      expect(pagination2.perPage, 10);
      expect(pagination2.currentPage, 5);
      expect(pagination2.data.length, 3);

      List<Blog> blogs = pagination2.getData<Blog>();
      expect(blogs.length, 3);

      String json = jsonEncode(pagination2);
      expect(json.contains('total'), true);
    });
  });
}
