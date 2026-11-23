---
icon: lucide/bell
---

# Model events

A model fires events when you save, delete or restore it, so you can run your own code at these moments.

There are two ways to listen. A **hook** is a method in the model class. An **observer** is a separate class, for code that needs other services, like a mailer.

Events fire only on one model object. A query write, like `Post().where('draft', true).update({...})`, runs one query and fires no events.

## Defining hooks

Override an `on...` method in the model class, then run `dart run build_runner build`:

```dart title="lib/app/models/post/post.model.dart"
@DoxModel()
class Post extends PostGenerator {
  @Column()
  String? title;

  @Column()
  String? slug;

  @override
  Future<void> onSaving() async {
    slug = title?.trim().toLowerCase().replaceAll(' ', '-');
  }
}
```

A before hook runs before the query, so it can change values or [cancel the operation](#cancelling-an-operation). An after hook runs when the row is written:

| Before hook | After hook | Runs on |
| --- | --- | --- |
| `onSaving` | `onSaved` | every `save()` |
| `onCreating` | `onCreated` | `save()` or `create()` on a new model |
| `onUpdating` | `onUpdated` | `save()` on a model from the table |
| `onDeleting` | `onDeleted` | `delete()` |
| `onForceDeleting` | `onForceDeleted` | `forceDelete()` |
| `onRestoring` | `onRestored` | `restore()` |

`onTrashed` runs after `onDeleted` when a soft delete changed the row. `touch()`, `firstOrCreate()` and `updateOrCreate()` fire the save events too.

### Order of events

The model hook runs first. Then the observers run, in the order you added them:

| Call | Events, in order |
|------|------------------|
| `save()` on a new model | saving, creating, INSERT, created, saved |
| `save()` on a model from the table | saving, updating, UPDATE, updated, saved |
| `delete()` | deleting, DELETE, deleted, then trashed after a soft delete |
| `forceDelete()` | forceDeleting, deleting, DELETE, deleted, forceDeleted |
| `restore()` | restoring, UPDATE, restored |

A save with no changes runs no UPDATE, but it fires the same events. With the [`skipCleanUpdateEvents` flag](../index.md#orm-flags), it fires only saving and saved.

### Setting a value only on create

Use `onCreating` for a value that you set one time, on a new row:

```dart
@override
Future<void> onCreating() async {
  status ??= 'draft';
}
```

### Doing something after a change

Use an after hook for side effects, because the row is already in the database:

```dart
@override
Future<void> onSaved() async {
  await Cache().forget('post:$id');
}
```

## Cancelling an operation

Throw `CancelModelEvent` in a before hook, and the query does not run:

```dart title="lib/app/models/post/post.model.dart"
@override
Future<void> onDeleting() async {
  if (status == 'published') {
    throw CancelModelEvent('unpublish the post first');
  }
}
```

`save()` and `restore()` then return false, and `delete()` and `forceDelete()` return 0. `create()` returns the unsaved model, with a null `id`.

## Observers

Extend `ModelObserver<T>` and override only the methods you need. They have the names of the hooks, and each one gets the model:

```dart title="lib/app/observers/user.observer.dart"
class UserObserver extends ModelObserver<User> {
  final Mailer mailer;

  UserObserver(this.mailer);

  @override
  Future<void> onCreated(User model) async {
    await mailer.sendWelcome(model.email!);
  }
}
```

A before method can also throw `CancelModelEvent`.

### Registering observers

Add the observer with `Model.observe()` in the `setup()` of a [provider](../../digging-deeper/providers.md). The provider runs it in every isolate:

```dart title="lib/providers/observer_provider.dart"
class ObserverProvider extends DoxProvider {
  @override
  void setup() {
    Model.observe<User>(UserObserver(Mailer()));
  }
}
```

A model can have more than one observer.

### Removing observers

`Model.forgetObservers()` removes the observers of one model, or of all models:

```dart
Model.forgetObservers<User>();
Model.forgetObservers();
```

### Listening to soft deletes

Add the `TrashedObserver` mixin and override `onTrashed`:

```dart
class PostObserver extends ModelObserver<Post> with TrashedObserver<Post> {
  @override
  void onTrashed(Post post) => print('trashed ${post.id}');
}
```

## Saving without events

`saveQuietly()` saves one model with no events, and `touchQuietly()` touches it with no events:

```dart
await user.saveQuietly();
```

`Model.withoutEvents()` turns off events for everything inside the callback:

```dart
await Model.withoutEvents(() async {
  await user.save();
  await post.delete();
});
```

## Events and transactions

`save()` does not start a transaction, so the row stays written when an after hook throws. To undo it, use a [transaction](../transactions.md):

```dart
await QueryBuilder.transaction(() async {
  await user.save(); // if onCreated() throws, the INSERT is rolled back
});
```

## Next steps

- [Model](index.md): save and delete models.
- [Providers](../../digging-deeper/providers.md): register observers.
- [Transactions](../transactions.md): undo a write when a hook fails.
