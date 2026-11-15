---
icon: lucide/network
---

# HasMany

Use `HasMany` when one row of this table has many rows in another table.

For example, a user has many posts. The other table keeps the foreign key (`post.user_id`).

## Defining the relation

Add a field with `@HasMany(...)` to the model. The field type is a list of the related model. Start it as an empty list:

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

The related model has the foreign key column:

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

### Custom keys

By default the foreign key is the class name in snake_case and `_id`, so `User` gives `user_id`. This is also true when the table is `users`. If your columns have other names, set `foreignKey` and `localKey`:

```dart
@HasMany(Book, foreignKey: 'author_code', localKey: 'code')
List<Book> books = <Book>[];
```

## Loading the relation

The relation is not loaded by default. Use the field name (`'posts'`) as the relation name.

### Preloading

Use `preload` when you load the models with a query. For a list of users, it runs one query for all of them. A user without posts gets an empty list:

```dart
User? user = await User().preload('posts').find(1);
print(user?.posts.length);

List<User> users = await User().preload('posts').get();
```

`preload` works with `find`, `get`, `all` and `getFirst`.

### Loading on a model you have

If you already have the model, use `$getRelation`:

```dart
User? user = await User().find(1);
await user?.$getRelation('posts');
print(user?.posts.length);
```

### Querying the relation

Sometimes you need more conditions on the related rows. `related` gives you a query for them. It does not set `user.posts`:

```dart
User? user = await User().find(1);
List<Post> activePosts = await user
        ?.related<Post>('posts')
        ?.where('status', 'active')
        .orderBy('id', 'desc')
        .get() ??
    <Post>[];
```

### Always loading the relation

If every query of `User` should load the relation, set `eager: true`. Then you do not call `preload`:

```dart
@HasMany(Post, eager: true)
List<Post> posts = <Post>[];
```

## Filtering by the relation

`whereHas()` keeps the users that have a post. `whereDoesntHave()` keeps the users with no post. `has()` counts the posts. They do not load the posts:

```dart
List<User> writers = await User().whereHas('posts', (QueryBuilder<dynamic> q) {
  q.where('status', 'active');
}).get();

List<User> noPosts = await User().whereDoesntHave('posts').get();
List<User> busy = await User().has('posts', '>=', 10).get();
```

See [Query by relations](../relation-queries.md).

## Changing the relation query

Sometimes the relation should only load some rows, or load them in an order. Give `onQuery` a static function in the same model class. It gets the query of the related model and returns it.

You can have two fields for the same model with different queries:

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

## Details

### All options

| Option | Default | What it is |
|---|---|---|
| `foreignKey` | `{this model}_id`, like `user_id` | The column in the related table that points to this model. |
| `localKey` | the primary key of this model | The column in this table that `foreignKey` points to. |
| `onQuery` | none | A static function that changes the query. |
| `eager` | `false` | Load the relation on every query. |

### Other cases

- A relation with `eager: true` is always in `toJson()`. A relation loaded with `preload` is in `toJson()` of that query. The JSON key is the field name in snake_case.
- `reload()` and a preload set the relation fields again, also when there is no related row. See [Relationships](../index.md#relationships).
- The load runs one query like this:

```sql
SELECT *, "user_id" as "_owner_id" FROM "post" WHERE "user_id" IN (@user_id_p0, ...)
```
