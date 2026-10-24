import 'package:dox_orm/dox_orm.dart';
import 'package:test/test.dart';

import 'connection.dart';
import 'models/blog/blog.model.dart';
import 'models/blog_info/blog_info.model.dart';

/// keeps the sql of each query
class _SqlRecorder implements QueryPrinter {
  List<String> queries = <String>[];

  @override
  void log(String query, List<String> params) {
    queries.add(query);
  }
}

/// the sql that [callback] runs, for models with debug(true)
Future<List<String>> _record(Future<void> Function() callback) async {
  _SqlRecorder recorder = _SqlRecorder();
  QueryPrinter old = SqlQueryBuilder().printer;
  SqlQueryBuilder().printer = recorder;
  try {
    await callback();
  } finally {
    SqlQueryBuilder().printer = old;
  }
  return recorder.queries;
}

void main() async {
  await initQueryBuilder();

  group('save() |', () {
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

    test('a new row is one INSERT, no SELECT', () async {
      Blog blog = Blog()
        ..title = 'a'
        ..description = 'b'
        ..debug(true);
      List<String> sql = await _record(blog.save);
      expect(sql.length, 1);
      expect(sql.first, startsWith('INSERT'));
      expect(blog.uid, isNotNull);
      expect((await Blog().find(blog.uid))?.title, 'a');
    });

    test('after a fetch, only the changed column is sent', () async {
      Blog blog = Blog()
        ..title = 'a'
        ..description = 'b';
      await blog.save();
      Blog fresh = (await Blog().find(blog.uid))!;
      fresh.description = 'new body';
      fresh.debug(true);
      List<String> sql = await _record(fresh.save);
      expect(sql.length, 1);
      expect(sql.first, startsWith('UPDATE'));
      expect(sql.first, contains('body'));
      expect(sql.first, contains('updated_at'));
      expect(sql.first, isNot(contains('title')));
      expect((await Blog().find(blog.uid))?.description, 'new body');
    });

    test('nothing changed: no query, updated_at stays', () async {
      Blog blog = Blog()
        ..title = 'a'
        ..description = 'b';
      await blog.save();
      Blog fresh = (await Blog().find(blog.uid))!;
      DateTime? updatedAt = fresh.updatedAt;
      fresh.debug(true);
      blog.debug(true);
      expect(await _record(fresh.save), isEmpty);
      expect(fresh.updatedAt, updatedAt);

      /// the same after a save
      expect(await _record(blog.save), isEmpty);
    });

    test('timestamps change when a column changes', () async {
      Blog blog = Blog()
        ..title = 'a'
        ..description = 'b';
      await blog.save();
      DateTime createdAt = blog.createdAt!;
      DateTime updatedAt = blog.updatedAt!;
      await Future<void>.delayed(Duration(milliseconds: 5));
      blog.title = 'b';
      await blog.save();
      expect(blog.createdAt, createdAt);
      expect(blog.updatedAt!.isAfter(updatedAt), true);
      Blog fresh = (await Blog().find(blog.uid))!;
      expect(fresh.title, 'b');
      expect(fresh.updatedAt!.isAfter(updatedAt), true);
    });

    test('soft delete, restore, then save keeps the row', () async {
      Blog blog = Blog()
        ..title = 'a'
        ..description = 'b';
      await blog.save();
      await blog.delete();
      expect(await Blog().count(), 0);

      Blog trashed = (await Blog().withTrash().find(blog.uid))!;
      expect(trashed.deletedAt, isNotNull);
      await trashed.restore();
      expect(await Blog().count(), 1);

      /// deleted_at did not change in the model, so it is not sent again
      trashed.title = 'c';
      await trashed.save();
      expect(await Blog().count(), 1);
      expect((await Blog().find(blog.uid))?.title, 'c');
    });

    test('a map changed in place is saved', () async {
      BlogInfo info = BlogInfo()
        ..info = <String, dynamic>{'a': 1}
        ..blogId = 1;
      await info.save();
      BlogInfo fresh = (await BlogInfo().find(info.id))!;
      fresh.info!['a'] = 2;
      await fresh.save();
      expect((await BlogInfo().find(info.id))?.info, <String, dynamic>{'a': 2});
    });

    test('an int column change is saved', () async {
      BlogInfo info = BlogInfo()
        ..info = <String, dynamic>{'a': 1}
        ..blogId = 1;
      await info.save();
      BlogInfo fresh = (await BlogInfo().find(info.id))!;
      fresh.blogId = 2;
      await fresh.save();
      expect((await BlogInfo().find(info.id))?.blogId, 2);
    });

    test(
      'dates of a fetched row are DateTime, toMap(original) has text',
      () async {
        BlogInfo info = BlogInfo()
          ..info = <String, dynamic>{'a': 1}
          ..blogId = 1;
        await info.save();
        BlogInfo fresh = (await BlogInfo().find(info.id))!;
        expect(fresh.createdAt, isA<DateTime>());
        expect(
          fresh.createdAt!.toIso8601String(),
          info.createdAt!.toIso8601String(),
        );
        expect(fresh.toMap(original: true)['created_at'], isA<String>());
      },
    );
  });
}
