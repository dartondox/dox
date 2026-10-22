# BelongsTo

Use `BelongsTo` when this table keeps the foreign key to another table.
For example, a comment belongs to a user.
The comment table has the column `user_id`.

`BelongsTo` is the other side of [HasOne](has-one.md) and [HasMany](has-many.md).

## Define it

Add a field with `@BelongsTo(...)` to the model. The field type is the related model, nullable.

=== "Comment"

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

=== "User"

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

## Load it

The relation is not loaded by default. Load it in one of these ways.
Use the field name (`'user'`) as the relation name.

=== "preload"

    ```dart
    List<Comment> comments = await Comment().preload('user').all();
    for (Comment comment in comments) {
      print(comment.user?.name);
    }
    ```

    `preload` works with `find`, `get`, `all` and `getFirst`.
    It runs one query for all comments, not one query per comment.

=== "$getRelation"

    ```dart
    Comment? comment = await Comment().find(1);
    await comment?.$getRelation('user');
    print(comment?.user?.name);
    ```

    Use it when you already have the model.
    Do not call it in a loop over many models. Use `preload` for a list.

=== "related"

    ```dart
    Comment? comment = await Comment().find(1);
    User? activeUser = await comment
        ?.related<User>('user')
        ?.where('status', 'active')
        .getFirst();
    ```

    `related` gives a query. You can add more conditions before you run it.
    It does not set `comment.user`.

=== "eager"

    ```dart
    @BelongsTo(User, eager: true)
    User? user;
    ```

    With `eager: true`, every query of `Comment` loads the relation.
    You do not call `preload`.

The load runs this SQL:

```sql
SELECT "user".*, "comment"."id" as "_foreign_id" FROM "user"
  LEFT JOIN "comment" on "comment"."user_id" = "user"."id"
  WHERE "comment"."user_id" IN (@commentuser_id_p0, ...)
```

## Options

| Option | Default | What it is |
|---|---|---|
| `foreignKey` | `{related table}_id`, like `user_id` | The column in this table that points to the related model. |
| `localKey` | the primary key of the related model | The column in the related table that `foreignKey` points to. |
| `onQuery` | none | A static function that changes the query. |
| `eager` | `false` | Load the relation on every query. |

!!! warning "Custom table names"
    The default `foreignKey` uses the table name of the related model, not its class name.
    When `User` has `@DoxModel(table: 'users')`, the default is `users_id`.
    Then set `foreignKey: 'user_id'` yourself.

### `foreignKey` and `localKey`

```dart
@BelongsTo(User, foreignKey: 'author_id', localKey: 'id')
User? author;
```

### `onQuery`

`onQuery` is a static function in the same model class.
It gets the query of the related model and returns it.

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

## In JSON

- A relation with `eager: true` is always in `toJson()`.
- A relation loaded with `preload` is in `toJson()` of that query.
- The JSON key is the field name in snake_case: `user`.

!!! warning "Known issue: names with more than one word"
    For a relation without `eager: true`, `toJson()` looks for the snake_case name in the preload list.
    But `preload` needs the field name (`'activeUser'`).
    So a preloaded `activeUser` is on the model, but it is not in `toJson()`.
    Use a one word field name, or `eager: true`, when you need it in JSON.
