import 'dart:convert';

import 'package:dox_orm/dox_orm.dart';
import 'package:test/test.dart';

import 'connection.dart';
import 'models/blog/blog.model.dart';
import 'models/blog_info/blog_info.model.dart';

void main() async {
  await initQueryBuilder();

  group('Query Builder', () {
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
          'body': 'Best orm for the dart',
        },
        <String, dynamic>{'title': 'dox core', 'body': 'dart web framework'},
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
          'body': 'Best orm for the dart',
        },
        <String, dynamic>{'title': 'dox core', 'body': 'dart web framework'},
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

      Map<String, dynamic>? b = await QueryBuilder.table('blog')
          .where('title', 'Awesome blog')
          .getFirst();

      expect(b?['uid'], 1);
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
      List<Map<String, dynamic>> res = await QueryBuilder.query(
        'select * from blog',
      );
      expect(res.first['title'], 'Awesome blog');
      expect(res.first['body'], 'Awesome blog body');
      expect(res.first['uid'], 1);
    });

    test('group by', () async {
      await Blog().insertMultiple(<Map<String, dynamic>>[
        <String, dynamic>{'title': 'title 1', 'body': 'body'},
        <String, dynamic>{'title': 'title 1', 'body': 'body2'},
        <String, dynamic>{'title': 'title 2', 'body': 'body'},
      ]);

      /// count() with groupBy returns the number of groups
      int total = await Blog().groupBy('status').count();
      expect(total, 1);

      int total2 = await Blog().groupBy(<String>['status', 'title']).count();
      expect(total2, 2);

      /// groupBy() rows are maps, so use QueryBuilder.table()
      List<Map<String, dynamic>> data2 = await QueryBuilder.table('blog')
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

      Map<String, dynamic>? b = await QueryBuilder.table('blog').rawQuery(
        "select * from blog where title = @title",
        <String, dynamic>{'title': 'Awesome blog'},
      ).getFirst();

      expect(b?['uid'], 1);
      expect(b?['title'], 'Awesome blog');
      expect(b?['body'], 'Awesome blog body');

      /// get() on a model gives models, so plain rows are an error
      await expectLater(
        Blog().rawQuery('select * from blog').get(),
        throwsStateError,
      );
      List<Blog> blogs = await Blog().where('title', 'Awesome blog').get();
      expect(blogs.first.title, 'Awesome blog');
    });

    test('where', () async {
      Blog blog = Blog();
      blog.title = 'dox query builder';
      blog.description = 'Best Orm';
      await blog.save();

      Blog? findBlog = await Blog()
          .where('title', 'dox query builder')
          .getFirst();
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
        'title = @title',
        <String, String>{'title': 'title 2'},
      ).get();

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

      List<Blog> blogs = await Blog().where('status', '=', 'active').whereIn(
        'uid',
        <int>[1, 2],
      ).get();

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

      Blog? findBlog = await Blog().where('status', '=', 'active').whereRaw(
        'uid = @id',
        <String, String>{'id': '1'},
      ).getFirst();

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
        <String, int>{'id': 1},
      ).getFirst();

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
          'body': 'Best orm for the dart',
        });
      }

      await Blog().insertMultiple(data);

      Pagination<Blog> pagination = await Blog().paginate(
        currentPage: 1,
        perPage: 10,
      );

      expect(pagination.total, 43);
      expect(pagination.lastPage, 5);
      expect(pagination.perPage, 10);
      expect(pagination.currentPage, 1);
      expect(pagination.data.length, 10);

      Pagination<Blog> pagination2 = await Blog().paginate(
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

    test('update with where saves the right values', () async {
      await Blog().insertMultiple(<Map<String, dynamic>>[
        <String, dynamic>{'title': 'title 1', 'body': 'body 1'},
        <String, dynamic>{'title': 'title 2', 'body': 'body 2'},
      ]);
      await QueryBuilder.table('blog')
          .where('uid', 1)
          .update(<String, dynamic>{'title': 'updated'});

      List<Map<String, dynamic>> rows = await QueryBuilder.table('blog')
          .select('uid, title')
          .orderBy('uid')
          .get();
      expect(rows.first['title'], 'updated');
      expect(rows.last['title'], 'title 2');
    });

    test('model save updates the database', () async {
      Blog blog = Blog();
      blog.title = 'title 1';
      blog.description = 'body';
      await blog.save();

      blog.title = 'new title';
      await blog.save();

      Blog? found = await Blog().find(blog.uid);
      expect(found?.title, 'new title');
    });

    test('insert multiple with different key order', () async {
      await Blog().insertMultiple(<Map<String, dynamic>>[
        <String, dynamic>{'title': 'title 1', 'body': 'body 1'},
        <String, dynamic>{'body': 'body 2', 'title': 'title 2'},
      ]);
      Map<String, dynamic>? row = await QueryBuilder.table('blog')
          .where('uid', 2)
          .getFirst();
      expect(row?['title'], 'title 2');
      expect(row?['body'], 'body 2');
    });

    test('insert null stores real null', () async {
      await QueryBuilder.table('blog')
          .setPrimaryKey('uid')
          .insert(<String, dynamic>{'title': 't', 'body': 'b', 'slug': null});
      int total = await QueryBuilder.table('blog')
          .whereRaw('slug IS NULL')
          .count();
      expect(total, 1);
    });

    test('where null', () async {
      await Blog().insertMultiple(<Map<String, dynamic>>[
        <String, dynamic>{'title': 'title 1', 'body': 'body 1', 'slug': null},
        <String, dynamic>{'title': 'title 2', 'body': 'body 2', 'slug': 's'},
      ]);
      List<Blog> blogs = await Blog().where('slug', null).get();
      expect(blogs.length, 1);
      expect(blogs.first.title, 'title 1');
    });

    test('where in with strings and empty list', () async {
      await Blog().insertMultiple(<Map<String, dynamic>>[
        <String, dynamic>{'title': 'title 1', 'body': 'body 1'},
        <String, dynamic>{'title': "it's 2", 'body': 'body 2'},
      ]);
      List<Blog> blogs = await Blog().whereIn('title', <String>[
        "it's 2",
      ]).get();
      expect(blogs.length, 1);
      expect(blogs.first.uid, 2);

      List<Blog> none = await Blog().whereIn('uid', <int>[]).get();
      expect(none.length, 0);

      List<int> ids = List<int>.generate(500, (int i) => i + 1);
      List<Blog> all = await Blog().whereIn('uid', ids).get();
      expect(all.length, 2);
    });

    test('or where does not show soft deleted rows', () async {
      await Blog().insertMultiple(<Map<String, dynamic>>[
        <String, dynamic>{'title': 'title 1', 'body': 'body 1'},
        <String, dynamic>{'title': 'title 2', 'body': 'body 2'},
      ]);
      await Blog().where('uid', 1).delete();

      int total = await Blog().where('uid', 1).orWhere('uid', 2).count();
      expect(total, 1);
    });

    test('group by with order by', () async {
      await Blog().insertMultiple(<Map<String, dynamic>>[
        <String, dynamic>{'title': 'b', 'body': 'body'},
        <String, dynamic>{'title': 'a', 'body': 'body'},
        <String, dynamic>{'title': 'a', 'body': 'body'},
      ]);
      List<Map<String, dynamic>> rows = await QueryBuilder.table('blog')
          .select('title')
          .groupBy('title')
          .orderBy('title', 'desc')
          .get();
      expect(rows.first['title'], 'b');
      expect(rows.last['title'], 'a');
    });

    test('order by rejects bad direction', () async {
      expect(
        () => Blog().orderBy('uid', 'desc; DROP TABLE blog'),
        throwsArgumentError,
      );
    });

    test('at sign inside raw string is kept', () async {
      await QueryBuilder.table('blog')
          .setPrimaryKey('uid')
          .insert(<String, dynamic>{'title': 'a@b.com', 'body': 'b'});
      int total = await QueryBuilder.table('blog')
          .whereRaw("title = 'a@b.com'")
          .where('uid', 1)
          .count();
      expect(total, 1);
    });

    test('same raw param used twice', () async {
      await QueryBuilder.table('blog')
          .setPrimaryKey('uid')
          .insert(<String, dynamic>{'title': 'x', 'body': 'x'});
      int total = await QueryBuilder.table('blog')
          .whereRaw('title = @v AND body = @v', <String, dynamic>{'v': 'x'})
          .count();
      expect(total, 1);
    });

    test('where null and where not null', () async {
      await Blog().insertMultiple(<Map<String, dynamic>>[
        <String, dynamic>{'title': 'title 1', 'body': 'body 1'},
        <String, dynamic>{'title': 'title 2', 'body': 'body 2', 'slug': 's'},
        <String, dynamic>{'title': 'title 3', 'body': 'body 3'},
      ]);
      expect(await Blog().whereNull('slug').count(), 2);
      expect(await Blog().whereNotNull('blog.slug').count(), 1);
      expect(
        await Blog().where('title', 'title 1').orWhereNull('slug').count(),
        2,
      );
      expect(
        await Blog().where('title', 'title 1').orWhereNotNull('slug').count(),
        2,
      );
    });

    test('where in, not in and or variants', () async {
      await Blog().insertMultiple(<Map<String, dynamic>>[
        <String, dynamic>{'title': 'title 1', 'body': 'body 1'},
        <String, dynamic>{'title': 'title 2', 'body': 'body 2'},
        <String, dynamic>{'title': 'title 3', 'body': 'body 3'},
      ]);
      expect(await Blog().whereNotIn('uid', <int>[1, 2]).count(), 1);
      expect(await Blog().whereNotIn('uid', <int>[]).count(), 3);
      expect(await Blog().whereIn('uid', <int>[]).count(), 0);
      expect(
        await Blog().where('uid', 1).orWhereIn('uid', <int>[2]).count(),
        2,
      );
      expect(await Blog().where('uid', 1).orWhereIn('uid', <int>[]).count(), 1);
      expect(
        await Blog().where('uid', 1).orWhereNotIn('uid', <int>[1, 2]).count(),
        2,
      );
      expect(
        await Blog().where('uid', 1).orWhereNotIn('uid', <int>[]).count(),
        3,
      );
    });

    test('select raw is not quoted', () async {
      await Blog().insertMultiple(<Map<String, dynamic>>[
        <String, dynamic>{'title': 'a', 'body': 'body'},
        <String, dynamic>{'title': 'a', 'body': 'body'},
      ]);
      List<Map<String, dynamic>> rows = await QueryBuilder.table('blog')
          .selectRaw('DISTINCT title')
          .get();
      expect(rows.length, 1);
    });

    test('toSql with many values', () async {
      String query = Blog().where('uid', 1).where('title', 'x').toSql();
      String q = SqlQueryBuilder().dbDriver.getName() == Driver.mysql
          ? '`'
          : '"';
      expect(
        query,
        "SELECT * FROM ${q}blog$q WHERE (${q}uid$q = 1 AND ${q}title$q = x) AND ${q}blog$q.${q}deleted_at$q IS NULL",
      );
    });

    test('no LIMIT or OFFSET that was not set, and no OFFSET 0', () async {
      expect(Blog().where('uid', 1).toSql().contains('LIMIT'), false);
      expect(Blog().limit(5).toSql(), endsWith(' LIMIT 5'));
      expect(Blog().limit(5).offset(0).toSql(), endsWith(' LIMIT 5'));
      expect(
        Blog().limit(5).offset(10).toSql(),
        endsWith(' LIMIT 5 OFFSET 10'),
      );

      /// OFFSET alone still works on every database
      await Blog().insertMultiple(<Map<String, dynamic>>[
        for (int i = 0; i < 3; i++)
          <String, dynamic>{'title': 't$i', 'body': 'b'},
      ]);
      List<Blog> rest = await Blog().orderBy('uid').offset(1).get();
      expect(rest.map((Blog b) => b.title), <String>['t1', 't2']);

      /// find, getFirst and paginate page 1
      _SqlRecorder recorder = _SqlRecorder();
      QueryPrinter old = SqlQueryBuilder().printer;
      SqlQueryBuilder().printer = recorder;
      try {
        await Blog().debug(true).find(1);
        await Blog().debug(true).where('title', 't0').getFirst();
        await Blog().debug(true).paginate(currentPage: 1, perPage: 2);
      } finally {
        SqlQueryBuilder().printer = old;
      }
      List<String> selects = recorder.queries
          .where((String s) => s.startsWith('SELECT *'))
          .toList();
      expect(selects.length, 3);
      for (String sql in selects) {
        expect(sql, endsWith(' LIMIT ${sql.contains('LIMIT 2') ? 2 : 1}'));
        expect(sql.contains('OFFSET'), false);
      }
    });

    test('the same query gives the same param names', () async {
      QueryBuilder<Blog> a = Blog().where('uid', 1).where('title', 'x');
      QueryBuilder<Blog> b = Blog().where('uid', 2).where('title', 'y');
      expect(a.substitutionValues.keys, b.substitutionValues.keys);
      expect(a.substitutionValues.values, <dynamic>[1, 'x']);
    });
  });
}

class _SqlRecorder implements QueryPrinter {
  List<String> queries = <String>[];

  @override
  void log(String query, List<String> params) {
    queries.add(query);
  }
}
