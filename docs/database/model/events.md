---
icon: lucide/bell
---

# Model events

A model fires events when you save, delete or restore it, and you can run your own code on them.

There are two ways to listen:

- **Hooks**: methods in the model class. Use them for code that belongs to the model, like filling a value.
- **Observers**: separate classes. Use them for code that needs other services, like a mailer.

## Hooks in the model

Override an `on...` method in the model. Then run `dart run build_runner build`.

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

All hooks come in pairs: one runs before the query, one after it.

| Before hook | After hook | Run on |
| --- | --- | --- |
| `onSaving` | `onSaved` | every `save()`: a new or a loaded model |
| `onCreating` | `onCreated` | `save()` or `create()` on a new model (INSERT) |
| `onUpdating` | `onUpdated` | `save()` on a loaded model (UPDATE) |
| `onDeleting` | `onDeleted` | `delete()` |
| `onForceDeleting` | `onForceDeleted` | `forceDelete()`: really removes a soft-deleted row |
| `onRestoring` | `onRestored` | `restore()`: brings back a soft-deleted row |

- A **before hook** runs before the query. The row is not written yet. You can change values, or [cancel](#stop-an-operation) the operation.
- An **after hook** runs after the query. The row is written, and a new model has its `id`. Use it for side effects.
- Declare the hooks in the model class itself. The generator looks there.

## Order of events

| Call | Events, in order |
|------|------------------|
| `save()` on a new model | `saving` → `creating` → *INSERT* → `created` → `saved` |
| `save()` on a loaded model | `saving` → `updating` → *UPDATE* → `updated` → `saved` |
| `create({...})` | the same as `save()` on a new model |
| `firstOrCreate()`, `updateOrCreate()` | the same as `save()` when they create or update a row |
| `delete()` | `deleting` → *DELETE or soft delete* → `deleted` |
| `forceDelete()` | `forceDeleting` → `deleting` → *DELETE* → `deleted` → `forceDeleted` |
| `restore()` | `restoring` → *UPDATE deleted_at = NULL* → `restored` |

- The model hook runs first. Then the observers run, in the order you added them.
- When a model has events, `create({...})` saves only the `@Column` fields.

!!! warning "Query updates and deletes fire no events"
    Events fire only on one model instance.
    `Post().where('draft', true).update({...})`, `Post().where(...).delete()`,
    `insertMultiple()`, `upsert()`, `increment()` and `decrement()` run one query and fire no events.

## Examples

### Set a value only on create

`onCreating` runs only for a new row. Updates do not change the value again.

```dart
@override
Future<void> onCreating() async {
  status ??= 'draft';
  publicId = Uuid().v4(); // from package:uuid
}
```

### Stop an operation

Throw `CancelModelEvent` in a before hook. The query does not run.
`save()` and `restore()` return `false`. `delete()` and `forceDelete()` return `0`.

```dart title="lib/app/models/post/post.model.dart"
@override
Future<void> onDeleting() async {
  if (status == 'published') {
    throw CancelModelEvent('unpublish the post first');
  }
}
```

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

- `save()` and `restore()` return `false` when a hook cancels.
- `delete()` and `forceDelete()` return the number of deleted rows. It is `0` when a hook cancels.
- `create({...})` returns the unsaved model. Its `id` is `null`.
- Any other error from a hook is thrown to the caller.

### Do something after a change

After hooks are for side effects. The row is already in the database.

```dart
@override
Future<void> onSaved() async {
  await Cache().forget('post:$id'); // the next read gets the new data
}

@override
Future<void> onDeleted() async {
  if (coverPath != null) {
    await Storage().delete(coverPath!); // remove the file of the post
  }
}
```

## Observers

An observer is a class that listens to one model.
Use it when the code needs other objects, like a mailer, or when you do not want it in the model.

The methods have the same names as the hooks. Each one gets the model. Override only the ones you need.

| Before method | After method | Run on |
| --- | --- | --- |
| `onSaving(T model)` | `onSaved(T model)` | every `save()`: a new or a loaded model |
| `onCreating(T model)` | `onCreated(T model)` | `save()` or `create()` on a new model (INSERT) |
| `onUpdating(T model)` | `onUpdated(T model)` | `save()` on a loaded model (UPDATE) |
| `onDeleting(T model)` | `onDeleted(T model)` | `delete()` |
| `onForceDeleting(T model)` | `onForceDeleted(T model)` | `forceDelete()` |
| `onRestoring(T model)` | `onRestored(T model)` | `restore()` |

A before method can stop the operation with `CancelModelEvent`, like a before hook.

```dart title="lib/app/observers/user.observer.dart"
class UserObserver extends ModelObserver<User> {
  final Mailer mailer;

  UserObserver(this.mailer);

  @override
  Future<void> onCreated(User user) async {
    await mailer.sendWelcome(user.email!);
  }
}
```

Add it in the `setup()` of a [provider](../../digging-deeper/providers.md).
Observers live in memory, and each isolate has its own memory, so every isolate must add them.

```dart title="lib/providers/observer_provider.dart"
class ObserverProvider extends DoxProvider {
  @override
  void setup() {
    Model.observe<User>(UserObserver(Mailer()));
  }
}
```

Dox finds `ObserverProvider` by itself, like every `DoxProvider`. Run `dart run build_runner build` after you add it.

- You can add more than one observer to a model.
- `Model.forgetObservers<User>()` removes the observers of `User`. `Model.forgetObservers()` removes all.

## Skip events

Use this for imports, seed data or tests.

```dart
await user.saveQuietly(); // save without events

await Model.withoutEvents(() async {
  await user.save();
  await post.delete();
});
```

## Transactions

`save()` does **not** start a transaction. If an after hook throws, the row stays written.
To undo the row when a hook fails, wrap the call in [`QueryBuilder.transaction()`](../transactions.md):

```dart
await QueryBuilder.transaction(() async {
  await user.save(); // if onCreated() throws, the INSERT is rolled back
});
```

A model with no hooks and no observers does no event work.
