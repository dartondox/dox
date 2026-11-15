---
icon: lucide/bell
---

# Model events

A model fires events when you save, delete or restore it, so you can run your own code at these moments.

There are two ways to listen:

- **Hooks** are methods in the model class. Use them for code that belongs to the model, like filling a value.
- **Observers** are separate classes. Use them for code that needs other services, like a mailer.

Events fire only on one model object. A query write like `Post().where('draft', true).update({...})`, `Post().where(...).delete()`, `insertMultiple()`, `upsert()`, `increment()`, `decrement()` or `Post().where(...).touch()` runs one query and fires no events.

## Defining hooks

Override an `on...` method in the model, then run `dart run build_runner build`. The hooks must be in the model class itself, because the generator looks there:

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

```dart
Post post = Post()..title = 'Hello World';
await post.save(); // onSaving runs first, so slug is 'hello-world'
```

Hooks come in pairs. A before hook runs before the query, so you can change values or [cancel the operation](#cancelling-an-operation). An after hook runs after the query, when the row is written and a new model has its `id`. Use it for side effects.

| Before hook | After hook | Runs on |
| --- | --- | --- |
| `onSaving` | `onSaved` | every `save()`: a new or a loaded model |
| `onCreating` | `onCreated` | `save()` or `create()` on a new model (INSERT) |
| `onUpdating` | `onUpdated` | `save()` on a loaded model (UPDATE) |
| `onDeleting` | `onDeleted` | `delete()` |
| `onForceDeleting` | `onForceDeleted` | `forceDelete()`: really removes a soft-deleted row |
| `onRestoring` | `onRestored` | `restore()`: brings back a soft-deleted row |

`onTrashed` runs after `onDeleted` when a soft delete changed the row. It has no before hook.

### Setting a value only on create

If a value should be set once, when the row is new, use `onCreating`. Updates do not run it:

```dart
@override
Future<void> onCreating() async {
  status ??= 'draft';
  publicId = Uuid().v4(); // from package:uuid
}
```

### Doing something after a change

After hooks are good for side effects, because the row is already in the database:

```dart
@override
Future<void> onSaved() async {
  await Cache().forget('post:$id'); // the next read gets the new data
}
```

```dart
@override
Future<void> onDeleted() async {
  if (coverPath != null) {
    await Storage().delete(coverPath!); // remove the file of the post
  }
}
```

## Cancelling an operation

Sometimes a save or delete must not happen. Throw `CancelModelEvent` in a before hook, and the query does not run:

```dart title="lib/app/models/post/post.model.dart"
@override
Future<void> onDeleting() async {
  if (status == 'published') {
    throw CancelModelEvent('unpublish the post first');
  }
}
```

The caller sees the cancel in the return value. `save()` and `restore()` return `false`, and `delete()` and `forceDelete()` return `0`:

```dart title="lib/app/http/controllers/post.controller.dart"
Future<Map<String, String>> destroy(DoxRequest req, int id) async {
  Post? post = await Post().find(id);
  if (post == null) throw NotFoundHttpException();

  int deleted = await post.delete();
  if (deleted == 0) {
    throw BadRequestException(message: 'Unpublish the post first');
  }
  return <String, String>{'message': 'deleted'};
}
```

`create({...})` returns the unsaved model, so its `id` is `null`. Any other error from a hook is thrown to the caller.

## Observers

An observer is a class that listens to one model. Use it when the code needs other objects, like a mailer, or when you do not want the code in the model.

Extend `ModelObserver<T>` and override only the methods you need. They have the same names as the hooks, and each one gets the model:

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

A before method, like `onCreating(T model)`, can also cancel the operation with `CancelModelEvent`.

### Registering observers

Add the observer in the `setup()` of a [provider](../../digging-deeper/providers.md). Observers live in memory, and each isolate has its own memory, so this must run in every isolate. A provider does this for you:

```dart title="lib/providers/observer_provider.dart"
class ObserverProvider extends DoxProvider {
  @override
  void setup() {
    Model.observe<User>(UserObserver(Mailer()));
  }
}
```

Dox finds `ObserverProvider` by itself, like every `DoxProvider`. Run `dart run build_runner build` after you add it. You can add more than one observer to a model.

### Listening to soft deletes

If you want to know when a row is soft deleted, add the `TrashedObserver` mixin and override `onTrashed(T model)`:

```dart
class PostObserver extends ModelObserver<Post> with TrashedObserver<Post> {
  @override
  void onTrashed(Post post) => print('trashed ${post.id}');
}
```

## Saving without events

Sometimes you do not want the events to run, for example in imports, seed data or tests. `saveQuietly()` saves one model with no events:

```dart
await user.saveQuietly(); // save without events
```

`Model.withoutEvents()` turns off events for everything inside the callback:

```dart
await Model.withoutEvents(() async {
  await user.save();
  await post.delete();
});
```

## Events and transactions

`save()` does not start a transaction, so if an after hook throws, the row stays written. If you want to undo the row when a hook fails, wrap the call in a [transaction](../transactions.md):

```dart
await QueryBuilder.transaction(() async {
  await user.save(); // if onCreated() throws, the INSERT is rolled back
});
```

## Details

### Order of events

| Call | Events, in order |
|------|------------------|
| `save()` on a new model | `saving` → `creating` → *INSERT* → `created` → `saved` |
| `save()` on a loaded model | `saving` → `updating` → *UPDATE* → `updated` → `saved` |
| `create({...})` | the same as `save()` on a new model |
| `firstOrCreate()`, `updateOrCreate()` | the same as `save()` when they create or update a row |
| `delete()` | `deleting` → *DELETE or soft delete* → `deleted` (→ `trashed` after a soft delete) |
| `forceDelete()` | `forceDeleting` → `deleting` → *DELETE* → `deleted` → `forceDeleted` |
| `restore()` | `restoring` → *UPDATE deleted_at = NULL and updated_at* → `restored` |
| `touch()` | `saving` → `updating` → *UPDATE updated_at* → `updated` → `saved` (`touchQuietly()` fires none) |

The model hook runs first. Then the observers run, in the order you added them.

### Other cases

- `save()` on a loaded model with no changes fires the same events, but runs no UPDATE. A model with a `Map` or `List` field is always sent, because the field can change in place.
- With the [`skipCleanUpdateEvents` flag](../index.md#orm-flags), a save with no changes fires only `saving` and `saved`. With this flag on, a save with changes runs `beforeSave` two times, and a save with no changes runs it one time.
- When a model has events, `create({...})` saves only the `@Column` fields.
- `Model.forgetObservers<User>()` removes the observers of `User`. `Model.forgetObservers()` removes all.
- A model with no hooks and no observers does no event work.
