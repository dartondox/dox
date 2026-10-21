import 'dart:convert';

import 'package:dox_orm/dox_orm.dart';
import 'package:test/test.dart';

import 'connection.dart';
import 'models/blog/blog.model.dart';
import 'models/blog_info/blog_info.model.dart';

void main() async {
  await initQueryBuilder();

  group('Computed |', () {
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

    test('computed getter is in toJson and toMap', () async {
      Blog blog = Blog()
        ..title = 'hello'
        ..description = 'body';
      expect(blog.toJson()['title_length'], 5);
      expect(blog.toMap()['title_length'], 5);
    });

    test('hidden hides a computed value', () async {
      Blog blog = Blog()..title = 'hello';
      expect(blog.toJson().containsKey('secret_note'), false);
      expect(blog.toMap()['secret_note'], 'hidden');
    });

    test('computed value is never a column', () async {
      Blog blog = Blog()
        ..title = 'hello'
        ..description = 'body';
      expect(blog.tableColumns.contains('title_length'), false);
      expect(
        blog.toMap(removeRelations: true).containsKey('title_length'),
        false,
      );

      /// insert and update would fail on an unknown column
      await blog.save();
      blog.title = 'hello world';
      await blog.save();

      Blog? found = await Blog().find(blog.uid);
      expect(found?.title, 'hello world');
      expect(found?.toJson()['title_length'], 11);
    });

    test(
      'computed value of an eager loaded relation is in nested json',
      () async {
        Blog blog = await Blog().create(<String, dynamic>{
          'title': 'hello',
          'body': 'body',
        });
        BlogInfo info = BlogInfo()
          ..blogId = blog.uid
          ..info = <String, dynamic>{'a': 1};
        await info.save();

        Blog? found = await Blog().find(blog.uid);
        Map<String, dynamic> json =
            jsonDecode(jsonEncode(found)) as Map<String, dynamic>;
        expect(json['title_length'], 5);
        expect(json['blog_info']['has_info'], true);
        expect(json['blog_infos'][0]['has_info'], true);
      },
    );
  });
}
