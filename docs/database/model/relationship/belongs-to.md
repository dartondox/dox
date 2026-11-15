---
icon: lucide/corner-left-up
---

# BelongsTo

Use `BelongsTo` when this table keeps the foreign key to another table.

For example, a comment belongs to a user, so the comment table has the column `user_id`. `BelongsTo` is the other side of [HasOne](has-one.md) and [HasMany](has-many.md).

## Defining the relation

Add a field with `@BelongsTo(...)` to the model. The field type is the related model, and it is nullable:

```dart title="lib/app/models/comment/comment.model.dart"
import 'package:dox_orm/dox_orm.dart';

import '../user/user.model.dart';

part 'comment.model.g.dart';

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

The related model needs nothing special:

```dart title="lib/app/models/user/user.model.dart"
import 'package:dox_orm/dox_orm.dart';

part 'user.model.g.dart';

@DoxModel()
class User extends UserGenerator {
  @Column()
  String? name;

  @Column()
  String? status;
}
```

Run `dart run build_runner build` after you add a relationship.

### Custom keys

By default the foreign key is the class name of the related model in snake_case and `_id`, so `User` gives `user_id`. This is also true when the table is `users`. It is not taken from the field name, so a field named `author` still uses `user_id`. In that case, set `foreignKey`:

```dart
@BelongsTo(User, foreignKey: 'author_id', localKey: 'id')
User? author;
```

## Loading the relation

The relation is not loaded by default. Use the field name (`'user'`) as the relation name.

### Preloading

Use `preload` when you load the models with a query. It runs one query for all comments, not one query per comment:

```dart
List<Comment> comments = await Comment().preload('user').all();
for (Comment comment in comments) {
  print(comment.user?.name);
}
```

`preload` works with `find`, `get`, `all` and `getFirst`. Each user is read once, also when it has many comments. Comments of the same user get the same `User` object.

### Loading on a model you have

If you already have the model, use `$getRelation`. Do not call it in a loop over many models, because it runs one query each time. Use `preload` for a list:

```dart
Comment? comment = await Comment().find(1);
await comment?.$getRelation('user');
print(comment?.user?.name);
```

### Querying the relation

Sometimes you need more conditions on the related row. `related` gives you a query for it. It does not set `comment.user`:

```dart
Comment? comment = await Comment().find(1);
User? activeUser = await comment
    ?.related<User>('user')
    ?.where('status', 'active')
    .getFirst();
```

### Always loading the relation

If every query of `Comment` should load the relation, set `eager: true`. Then you do not call `preload`:

```dart
@BelongsTo(User, eager: true)
User? user;
```

## Filtering by the relation

`whereHas()` keeps the comments by a user that matches. It does not load the users:

```dart
List<Comment> comments = await Comment().whereHas('user', (QueryBuilder<dynamic> q) {
  q.where('name', 'Ann');
}).get();
```

See [Query by relations](../relation-queries.md).

## Changing the relation query

Sometimes the relation should only load some rows. Give `onQuery` a static function in the same model class. It gets the query of the related model and returns it:

```dart
@DoxModel()
class Comment extends CommentGenerator {
  @Column()
  int? userId;

  @BelongsTo(User, onQuery: onlyActive)
  User? activeUser;

  static QueryBuilder<User> onlyActive(User q) {
    return q.where('status', 'active');
  }
}
```

## Details

### All options

| Option | Default | What it is |
|---|---|---|
| `foreignKey` | `{related model}_id`, like `user_id` | The column in this table that points to the related model. |
| `localKey` | the primary key of the related model | The column in the related table that `foreignKey` points to. |
| `onQuery` | none | A static function that changes the query. |
| `eager` | `false` | Load the relation on every query. |

### Other cases

- The [`belongsToKeyFromRelation` flag](../../index.md#orm-flags) takes the default foreign key from the relation name (`author_id`). The model generator does not pass the relation name yet, so set `foreignKey` when it is not the class name.
- A relation with `eager: true` is always in `toJson()`. A relation loaded with `preload` is in `toJson()` of that query. The JSON key is the field name in snake_case: `user`.
- `reload()` and a preload set the relation fields again, also when there is no related row. See [Relationships](../index.md#relationships).
- The load runs one query like this:

```sql
SELECT * FROM "user"
  WHERE "user"."id" IN (@userid_p0, ...)
```
