import 'package:dox_orm/dox_orm.dart';
import 'package:test/test.dart';

import 'connection.dart';
import 'models/blog/blog.model.dart';

void main() async {
  await initQueryBuilder();

  group('Transaction |', () {
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

    test('commit on success', () async {
      int result = await QueryBuilder.transaction(() async {
        Blog blog = Blog();
        blog.title = 'title';
        blog.description = 'body';
        await blog.save();
        await QueryBuilder.table('blog')
            .setPrimaryKey('uid')
            .insert(<String, dynamic>{'title': 't2', 'body': 'b'});
        return Blog().count();
      });
      expect(result, 2);
      expect(await Blog().count(), 2);
    });

    test('rollback on error', () async {
      Future<void> run() {
        return QueryBuilder.transaction(() async {
          await Blog().create(<String, dynamic>{'title': 't', 'body': 'b'});
          throw StateError('stop');
        });
      }

      await expectLater(run(), throwsStateError);
      expect(await Blog().count(), 0);
    });

    test('nested transaction joins the outer one', () async {
      Future<void> run() {
        return QueryBuilder.transaction(() async {
          await QueryBuilder.transaction(() async {
            await Blog().create(<String, dynamic>{'title': 't', 'body': 'b'});
          });
          throw StateError('stop');
        });
      }

      await expectLater(run(), throwsStateError);
      expect(await Blog().count(), 0);
    });

    test('queries outside do not see work that is rolled back', () async {
      Future<void> tx = QueryBuilder.transaction(() async {
        await Blog().create(<String, dynamic>{'title': 't', 'body': 'b'});
        await Future<void>.delayed(const Duration(milliseconds: 50));
        throw StateError('stop');
      });

      /// start the outside queries while the transaction is open
      await Future<void>.delayed(const Duration(milliseconds: 10));
      List<Future<int>> counts = <Future<int>>[];
      for (int i = 0; i < 10; i++) {
        counts.add(Blog().count());
      }
      await expectLater(tx, throwsStateError);
      expect(await Future.wait(counts), List<int>.filled(10, 0));
    });
  });
}
