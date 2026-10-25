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

    test('relations load inside and outside a transaction', () async {
      Blog blog = Blog()
        ..title = 'title'
        ..description = 'body';
      await blog.save();
      await QueryBuilder.table('blog_info')
          .insert(<String, dynamic>{'info': '{}', 'blog_id': blog.uid});

      /// Blog has two eager relations
      Blog? outside = await Blog().find(blog.uid);
      Blog? inside = await QueryBuilder.transaction(() {
        expect(DBDriver.inTransaction, true);
        return Blog().find(blog.uid);
      });
      expect(DBDriver.inTransaction, false);
      for (Blog? b in <Blog?>[outside, inside]) {
        expect(b?.blogInfo?.blogId, blog.uid);
        expect(b?.blogInfos.length, 1);
      }
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

    Future<void> add(String title) =>
        Blog().create(<String, dynamic>{'title': title, 'body': 'b'});

    Future<List<String>> titles() async {
      List<Map<String, dynamic>> rows = await QueryBuilder.table('blog')
          .select('title')
          .orderBy('title')
          .get();
      return <String>[for (Map<String, dynamic> r in rows) '${r['title']}'];
    }

    test('nested error that is caught keeps the outer work', () async {
      await QueryBuilder.transaction(() async {
        await add('outer');
        try {
          await QueryBuilder.transaction(() async {
            await add('inner');
            throw StateError('stop');
          });
        } on StateError {
          // the caller goes on
        }
        await add('outer 2');
      });
      expect(await titles(), <String>['outer', 'outer 2']);
    });

    /// postgres stops a transaction after a failed query, the savepoint
    /// rollback makes it usable again
    test('nested sql error that is caught keeps the outer work', () async {
      await QueryBuilder.transaction(() async {
        await add('outer');
        try {
          await QueryBuilder.transaction(() async {
            await add('inner');
            await QueryBuilder.table('x')
                .rawQuery('SELECT * FROM no_such_table')
                .get();
          });
        } catch (_) {
          // the caller goes on
        }
        await add('outer 2');
      });
      expect(await titles(), <String>['outer', 'outer 2']);
    });

    test('nested success keeps both', () async {
      String result = await QueryBuilder.transaction(() async {
        await add('outer');
        return QueryBuilder.transaction(() async {
          await add('inner');
          return 'done';
        });
      });
      expect(result, 'done');
      expect(await titles(), <String>['inner', 'outer']);
    });

    test('outer rollback drops the nested work too', () async {
      Future<void> run() {
        return QueryBuilder.transaction(() async {
          await add('outer');
          await QueryBuilder.transaction(() => add('inner'));
          throw StateError('stop');
        });
      }

      await expectLater(run(), throwsStateError);
      expect(await Blog().count(), 0);
    });

    test('three levels deep', () async {
      await QueryBuilder.transaction(() async {
        await add('a');
        await QueryBuilder.transaction(() async {
          await add('b');
          try {
            await QueryBuilder.transaction(() async {
              await add('c');
              throw StateError('stop');
            });
          } on StateError {
            // only level 3 is undone
          }
          await QueryBuilder.transaction(() => add('d'));
        });
        try {
          await QueryBuilder.transaction(() async {
            await add('e');
            await QueryBuilder.transaction(() => add('f'));
            throw StateError('stop');
          });
        } on StateError {
          // level 2 is undone with its level 3
        }
      });
      expect(await titles(), <String>['a', 'b', 'd']);
    });

    test('nested error that is not caught rolls back all', () async {
      Future<void> run() {
        return QueryBuilder.transaction(() async {
          await add('outer');
          await QueryBuilder.transaction(() async {
            await add('inner');
            throw StateError('stop');
          });
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
