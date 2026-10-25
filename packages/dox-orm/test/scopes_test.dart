import 'package:dox_orm/dox_orm.dart';
import 'package:test/test.dart';

import 'connection.dart';
import 'models/scoped_post/scoped_post.model.dart';

void main() async {
  await initQueryBuilder();

  group('Scopes |', () {
    setUp(() async {
      await Schema().dropIfExists('scoped_post');
      await Schema().create('scoped_post', (Table table) {
        table.id();
        table.string('title');
        table.boolean('published');
        table.boolean('archived').nullable();
        table.integer('views');
      });
      await ScopedPost().insertMultiple(<Map<String, dynamic>>[
        <String, dynamic>{
          'title': 'a',
          'published': true,
          'archived': false,
          'views': 10,
        },
        <String, dynamic>{
          'title': 'b',
          'published': false,
          'archived': false,
          'views': 20,
        },
        <String, dynamic>{
          'title': 'c',
          'published': true,
          'archived': true,
          'views': 30,
        },
        <String, dynamic>{'title': 'd', 'published': true, 'views': 40},
      ]);
    });

    tearDown(() async {
      await Schema().dropIfExists('scoped_post');
    });

    List<String?> titles(List<ScopedPost> list) {
      return <String?>[for (ScopedPost p in list) p.title]..sort();
    }

    test('global scope is on every query', () async {
      expect(titles(await ScopedPost().all()), <String>['a', 'b', 'd']);
      expect(titles(await ScopedPost().get()), <String>['a', 'b', 'd']);
      expect(await ScopedPost().count(), 3);
      expect(await ScopedPost().find(3), isNull);
      expect((await ScopedPost().find(1))?.title, 'a');
    });

    test('global scope and orWhere', () async {
      /// (title = c OR title = b) AND (hidden = false OR hidden IS NULL)
      List<ScopedPost> list = await ScopedPost()
          .where('title', 'c')
          .orWhere('title', 'b')
          .get();
      expect(titles(list), <String>['b']);
    });

    test('withoutGlobalScope', () async {
      expect(
        titles(await ScopedPost().withoutGlobalScope('visible').get()),
        <String>['a', 'b', 'c', 'd'],
      );
      expect(await ScopedPost().withoutGlobalScopes().count(), 4);
      expect((await ScopedPost().withoutGlobalScopes().find(3))?.title, 'c');
    });

    test('local scopes', () async {
      expect(titles(await ScopedPost().isPublished().get()), <String>[
        'a',
        'd',
      ]);
      expect(
        titles(await ScopedPost().where('views', '>', 15).isPublished().get()),
        <String>['d'],
      );
      expect(titles(await ScopedPost().minViews(20).get()), <String>['b', 'd']);
      expect(titles(await ScopedPost().minViews(20, '<').get()), <String>['a']);
      expect(titles(await ScopedPost().titled(title: 'b').get()), <String>[
        'b',
      ]);
      expect(
        await ScopedPost()
            .withoutGlobalScopes()
            .isPublished()
            .minViews(30)
            .count(),
        2,
      );
    });

    test('update and delete use the global scope', () async {
      await ScopedPost().update(<String, dynamic>{'views': 0});
      ScopedPost? hidden = await ScopedPost().withoutGlobalScopes().find(3);
      expect(hidden?.views, 30);

      await ScopedPost().delete();
      expect(await ScopedPost().withoutGlobalScopes().count(), 1);
    });

    test('save of a model is not changed by the global scope', () async {
      ScopedPost? post = await ScopedPost().withoutGlobalScopes().find(3);
      post!.views = 99;
      await post.save();
      ScopedPost? again = await ScopedPost().withoutGlobalScopes().find(3);
      expect(again?.views, 99);
    });
  });
}
