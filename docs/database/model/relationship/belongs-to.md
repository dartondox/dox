---
icon: lucide/corner-left-up
---

# BelongsTo

Use `BelongsTo` when this table keeps the foreign key to another table.

For example, a comment belongs to a user, so the comment table has the column `user_id`. It is the other side of [HasOne](has-one.md) and [HasMany](has-many.md).

## Setup

Add a nullable field with `@BelongsTo()` to the model that has the foreign key column:

```dart title="lib/app/models/comment/comment.model.dart"
@DoxModel()
class Comment extends CommentGenerator {
  @Column()
  int? userId; // column user_id

  @Column()
  String? content;

  @BelongsTo(User)
  User? user;
}
```

Run `dart run build_runner build` after you add a relation.

### Options

The default foreign key comes from the class name of the related model, not from the field name. So a field `author` still uses `user_id`. Set the key for another name:

```dart
@BelongsTo(User, foreignKey: 'author_id', localKey: 'id')
User? author;
```

| Option | Default | What it is |
|---|---|---|
| `foreignKey` | `{related model}_id`, like `user_id` | The column in this table that points to the related model. |
| `localKey` | the primary key of the related model | The column in the related table that `foreignKey` points to. |
| `onQuery` | none | A static function that changes the query. |
| `eager` | `false` | Load the relation on every query. |

With the [`belongsToKeyFromRelation` flag](../../index.md#orm-flags), the default comes from the field name: `author` gives `author_id`.

## Loading the relation

The relation is not loaded by default. Use the field name, `'user'`, as the relation name.

### Preloading

`preload()` loads the relation for all models of a query, with one more query. Comments of the same user get the same `User` object:

```dart
List<Comment> comments = await Comment().preload('user').all();
print(comments.first.user?.name);
```

The relation is then in `toJson()`, with the field name in snake_case as the key.

### Loading on a model you have

`$getRelation()` loads the relation into the field. It runs one query each time, so use `preload()` for a list:

```dart
await comment.$getRelation('user');
```

### Querying the relation

`related()` gives a query for the related row. It does not set the field:

```dart
User? activeUser = await comment
    .related<User>('user')
    ?.where('status', 'active')
    .getFirst();
```

### Always loading the relation

Set `eager: true` to load the relation on every query of the model:

```dart
@BelongsTo(User, eager: true)
User? user;
```

## Saving related models

`associate()` sets the foreign key to the key of a saved model. `dissociate()` sets it to null. Call `save()` after them:

```dart
await comment.associate('user', user).save();
await comment.dissociate('user').save();
```

The relation field does not change.

## Filtering by the relation

`whereHas()` keeps the comments of a user that matches:

```dart
List<Comment> comments = await Comment().whereHas('user',
    (QueryBuilder<dynamic> q) {
  q.where('name', 'Ann');
}).get();
```

See [Query by relations](../relation-queries.md).

## Changing the relation query

Give `onQuery` a static function of the model. It gets the query of the related model and returns it:

```dart
@BelongsTo(User, onQuery: onlyActive)
User? activeUser;

static QueryBuilder<User> onlyActive(User q) {
  return q.where('status', 'active');
}
```

## Next steps

- [HasMany](has-many.md): the other side of the relation.
- [Serializer](../../../the-basic/serializer.md): set the JSON shape of a model.
- [Query by relations](../relation-queries.md): filter by the related rows.
