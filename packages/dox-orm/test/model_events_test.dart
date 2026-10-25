import 'package:dox_orm/dox_orm.dart';
import 'package:test/test.dart';

import 'connection.dart';
import 'models/event_post/event_post.model.dart';
import 'models/user/user.model.dart';

class PostObserver extends ModelObserver<EventPost> {
  final String name;

  PostObserver(this.name);

  @override
  void onCreating(EventPost model) => EventPost.log.add('$name:creating');

  @override
  Future<void> onSaved(EventPost model) async =>
      EventPost.log.add('$name:saved');
}

class UserObserver extends ModelObserver<User> {
  List<String> log = <String>[];

  @override
  void onCreating(User model) {
    log.add('creating');
    model.name = model.name?.toUpperCase();
  }

  @override
  void onUpdating(User model) {
    log.add('updating');
    if (model.name == 'stop') throw CancelModelEvent();
  }

  @override
  void onDeleted(User model) => log.add('deleted');
}

Future<int> _count() async {
  return await EventPost().withTrash().count();
}

void main() async {
  await initQueryBuilder();

  group('Model events |', () {
    setUp(() async {
      EventPost.log = <String>[];
      EventPost.cancelOn = null;
      EventPost.failOn = null;
      Model.forgetObservers();
      await Schema().create('event_posts', (Table table) {
        table.id();
        table.string('title').nullable();
        table.softDeletes();
        table.timestamps();
      });
      await Schema().create('users', (Table table) {
        table.id();
        table.string('name').nullable();
        table.softDeletes();
        table.timestamps();
      });
    });

    tearDown(() async {
      Model.forgetObservers();
      await Schema().dropIfExists('event_posts');
      await Schema().dropIfExists('users');
    });

    test('create and update fire hooks in order', () async {
      EventPost post = EventPost()..title = '  hello  ';
      expect(await post.save(), true);
      expect(EventPost.log, <String>['saving', 'creating', 'created', 'saved']);

      /// a "before" hook can change the model before the query
      EventPost? found = await EventPost().find(post.id);
      expect(found?.title, 'hello');

      EventPost.log.clear();
      post.title = 'new';
      await post.save();
      expect(EventPost.log, <String>['saving', 'updating', 'updated', 'saved']);
    });

    test('create() fires the hooks', () async {
      EventPost post = await EventPost().create(<String, dynamic>{
        'title': ' a ',
      });
      expect(post.id, isNotNull);
      expect(post.title, 'a');
      expect(EventPost.log, <String>['saving', 'creating', 'created', 'saved']);
    });

    test('a before hook cancels', () async {
      EventPost.cancelOn = 'creating';
      EventPost post = EventPost()..title = 'x';
      expect(await post.save(), false);
      expect(post.id, isNull);
      expect(await _count(), 0);
      expect(EventPost.log, <String>['saving', 'creating']);

      EventPost created = await EventPost().create(<String, dynamic>{
        'title': 'y',
      });
      expect(created.id, isNull);
      expect(await _count(), 0);

      EventPost.cancelOn = null;
      await post.save();
      EventPost.cancelOn = 'deleting';
      expect(await post.delete(), false);
      expect(await EventPost().count(), 1);
    });

    test('observers run after the model hook, in order', () async {
      Model.observe<EventPost>(PostObserver('a'));
      Model.observe<EventPost>(PostObserver('b'));
      await (EventPost()..title = 'x').save();
      expect(EventPost.log, <String>[
        'saving',
        'creating',
        'a:creating',
        'b:creating',
        'created',
        'saved',
        'a:saved',
        'b:saved',
      ]);
    });

    test('observer on a model without hooks', () async {
      UserObserver observer = UserObserver();
      Model.observe<User>(observer);

      User user = User()..name = 'john';
      await user.save();
      expect((await User().find(user.id))?.name, 'JOHN');

      user.name = 'stop';
      expect(await user.save(), false);
      expect((await User().find(user.id))?.name, 'JOHN');

      await user.delete();
      expect(observer.log, <String>['creating', 'updating', 'deleted']);

      /// a query delete fires no events
      await User().create(<String, dynamic>{'name': 'a'});
      await User().where('name', 'A').delete();
      expect(observer.log.last, 'creating');
    });

    test('saveQuietly and withoutEvents skip the hooks', () async {
      Model.observe<EventPost>(PostObserver('a'));
      EventPost post = EventPost()..title = 'x';
      await post.saveQuietly();
      await Model.withoutEvents(() async {
        post.title = 'y';
        await post.save();
        await post.delete();
      });
      expect(EventPost.log, isEmpty);
      expect(await _count(), 1);
    });

    test('an after hook error rolls back inside a transaction', () async {
      EventPost.failOn = 'created';
      await expectLater(
        QueryBuilder.transaction(() async {
          await (EventPost()..title = 'x').save();
        }),
        throwsStateError,
      );
      expect(await _count(), 0);

      /// without a transaction the row stays
      await expectLater((EventPost()..title = 'x').save(), throwsStateError);
      expect(await _count(), 1);
    });

    test('soft delete, restore and force delete', () async {
      EventPost post = EventPost()..title = 'x';
      await post.save();
      EventPost.log.clear();

      await post.delete();
      expect(EventPost.log, <String>['deleting', 'deleted']);
      expect(await EventPost().count(), 0);

      EventPost.log.clear();
      expect(await post.restore(), true);
      expect(EventPost.log, <String>['restoring', 'restored']);
      expect(await EventPost().count(), 1);

      EventPost.log.clear();
      await post.forceDelete();
      expect(EventPost.log, <String>[
        'forceDeleting',
        'deleting',
        'deleted',
        'forceDeleted',
      ]);
      expect(await _count(), 0);
    });
  });
}
