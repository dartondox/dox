# Model events

A model fires events when you save, delete or restore it.
You can run your own code on these events.
There are two ways: hooks in the model, and observer classes.

## Hooks in the model

Override an `on...` method in the model. Then run `dart run build_runner build`.

```dart
@DoxModel(softDelete: true)
class User extends UserGenerator {
  @Column()
  String? email;

  @override
  Future<void> onCreating() async {
    email = email?.trim().toLowerCase();
  }

  @override
  Future<void> onDeleted() async {
    await AuditLog().create({'message': 'user $id deleted'});
  }
}
```

!!! info
    The hook names start with `on` (`onCreating`, not `creating`).
    This is because `created` and `deleted` are common column names.
    Declare the hooks in the model class itself. The generator looks there.

## Events and order

| Call | Events, in order |
|------|------------------|
| `save()` on a new model | `saving` → `creating` → *INSERT* → `created` → `saved` |
| `save()` on a loaded model | `saving` → `updating` → *UPDATE* → `updated` → `saved` |
| `create({...})` | the same as `save()` on a new model |
| `delete()` | `deleting` → *DELETE or soft delete* → `deleted` |
| `forceDelete()` | `forceDeleting` → `deleting` → *DELETE* → `deleted` → `forceDeleted` |
| `restore()` | `restoring` → *UPDATE deleted_at = NULL* → `restored` |

The model hook runs first. Then the observers run, in the order you added them.

!!! warning "Query updates and deletes fire no events"
    Events fire only on a model instance.
    `User().where('active', false).update({...})`, `User().where(...).delete()`
    and `insertMultiple()` run one query and fire no events. This is the same as Laravel.

## Cancel an operation

Throw `CancelModelEvent` in a "before" event
(`saving`, `creating`, `updating`, `deleting`, `forceDeleting`, `restoring`).
The query does not run. `save()`, `delete()`, `forceDelete()` and `restore()` return `false`.

```dart
@override
Future<void> onDeleting() async {
  if (isAdmin == true) throw CancelModelEvent('admins can not be deleted');
}
```

```dart
bool deleted = await user.delete(); // false
```

`create({...})` returns the unsaved model (its `id` is `null`) when an event cancels it.
Any other error from a hook is thrown to the caller.

## Observers

An observer is a class that listens to one model.
Override only the methods you need. Each method gets the model.

```dart
class UserObserver extends ModelObserver<User> {
  final Mailer mailer;

  UserObserver(this.mailer);

  @override
  Future<void> onCreated(User user) async {
    await mailer.sendWelcome(user.email!);
  }
}
```

Add it once, for example when the app starts:

```dart
Model.observe<User>(UserObserver(mailer));
```

- You can add more than one observer to a model.
- `Model.forgetObservers<User>()` removes the observers of `User`. `Model.forgetObservers()` removes all.

## Skip events

```dart
await user.saveQuietly(); // save without events

await Model.withoutEvents(() async {
  await user.save();
  await post.delete();
});
```

## Transactions

Hooks run inside the transaction of the caller.
`save()` does **not** start a transaction by itself.

- If an "after" hook (`created`, `saved`, ...) throws, the row is already written.
- To undo the row when a hook fails, wrap the call in [`QueryBuilder.transaction()`](../transactions.md):

```dart
await QueryBuilder.transaction(() async {
  await user.save(); // if onCreated() throws, the INSERT is rolled back
});
```

## Performance

- There is no reflection. The generator sets `hasModelHooks` only for models that declare a hook.
- A model with no hooks and no observers does no event work. It is one `bool` check, plus one map lookup when some other model has observers.
- When a model has events, `create({...})` fills a model with `fromMap()` and calls `save()`.
  Only the `@Column` fields are saved then.
