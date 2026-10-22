# HasMany

Use `HasMany` when one row of this table has many rows in another table.
For example, a user has many posts.
The other table keeps the foreign key (`post.user_id`).

## Define it

Add a field with `@HasMany(...)` to the model.
The field type is a list of the related model. Start it as an empty list.

```dart title="lib/app/models/user/user.model.dart"
import 'package:dox_orm/dox_orm.dart';

import '../post/post.model.dart';

part 'user.model.g.dart';

@DoxModel()
class User extends UserGenerator {
  @Column()
  String? name;

  @HasMany(Post)
  List<Post> posts = <Post>[];
}
```

```dart title="lib/app/models/post/post.model.dart"
import 'package:dox_orm/dox_orm.dart';

part 'post.model.g.dart';

@DoxModel()
class Post extends PostGenerator {
  @Column()
  int? userId; // column user_id

  @Column()
  String? title;

  @Column()
  String? status;
}
```

Run `dart run build_runner build` after you add a relationship.

## Load it

The relation is not loaded by default. Load it in one of these ways.
Use the field name (`'posts'`) as the relation name.

### `preload`

Use it when you load the models with a query.

```dart
User? user = await User().preload('posts').find(1);
print(user?.posts.length);

List<User> users = await User().preload('posts').get();
```

`preload` works with `find`, `get`, `all` and `getFirst`.
For a list of users, it runs one query for all of them.
A user without posts gets an empty list.

### `$getRelation`

Use it when you already have the model.

```dart
User? user = await User().find(1);
await user?.$getRelation('posts');
print(user?.posts.length);
```

### `related`

Use it when you need more conditions on the related rows.

```dart
User? user = await User().find(1);
List<Post> activePosts = await user
        ?.related<Post>('posts')
        ?.where('status', 'active')
        .orderBy('id', 'desc')
        .get() ??
    <Post>[];
```

`related` gives a query. You can add more conditions before you run it.
It does not set `user.posts`.

### `eager`

Use it when every query of `User` should load the relation.

```dart
@HasMany(Post, eager: true)
List<Post> posts = <Post>[];
```

With `eager: true`, every query of `User` loads the relation.
You do not call `preload`.

The load runs this SQL:

```sql
SELECT *, "user_id" as "_owner_id" FROM "post" WHERE "user_id" IN (@user_id_p0, ...)
```

## Options

| Option | Default | What it is |
|---|---|---|
| `foreignKey` | `{this table}_id`, like `user_id` | The column in the related table that points to this model. |
| `localKey` | the primary key of this model | The column in this table that `foreignKey` points to. |
| `onQuery` | none | A static function that changes the query. |
| `eager` | `false` | Load the relation on every query. |

!!! warning "Custom table names"
    The default `foreignKey` uses the table name, not the class name.
    With `@DoxModel(table: 'users')`, the default is `users_id`.
    Then set `foreignKey: 'user_id'` yourself.

### `foreignKey` and `localKey`

```dart
@HasMany(Book, foreignKey: 'author_code', localKey: 'code')
List<Book> books = <Book>[];
```

### `onQuery`

`onQuery` is a static function in the same model class.
It gets the query of the related model and returns it.
You can have two fields on the same model with different queries.

```dart
@DoxModel()
class User extends UserGenerator {
  @HasMany(Post)
  List<Post> posts = <Post>[];

  @HasMany(Post, onQuery: onlyActive)
  List<Post> activePosts = <Post>[];

  static QueryBuilder<Post> onlyActive(Post q) {
    return q.where('status', 'active').orderBy('id', 'desc');
  }
}
```

## In JSON

- A relation with `eager: true` is always in `toJson()`.
- A relation loaded with `preload` is in `toJson()` of that query.
- The JSON key is the field name in snake_case.

!!! warning "Known issue: names with more than one word"
    For a relation without `eager: true`, `toJson()` looks for the snake_case name in the preload list.
    But `preload` needs the field name (`'activePosts'`).
    So a preloaded `activePosts` is on the model, but it is not in `toJson()`.
    Use a one word field name, or `eager: true`, when you need it in JSON.
