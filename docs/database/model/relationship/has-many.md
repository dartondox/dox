---
icon: lucide/network
---

# HasMany

Use `HasMany` when one row of this table has many rows in another table.

For example, a user has many posts. The other table keeps the foreign key: `post.user_id`.

## Setup

Add a list field with `@HasMany()` to the model, and start it as an empty list. The related model has the foreign key column:

```dart title="lib/app/models/user/user.model.dart"
@DoxModel()
class User extends UserGenerator {
  @HasMany(Post)
  List<Post> posts = <Post>[];
}

@DoxModel()
class Post extends PostGenerator {
  @Column()
  int? userId; // column user_id

  @Column()
  String? title;
}
```

Run `dart run build_runner build` after you add a relation.

### Options

Set the keys when your columns have other names:

```dart
@HasMany(Book, foreignKey: 'author_code', localKey: 'code')
List<Book> books = <Book>[];
```

| Option | Default | What it is |
|---|---|---|
| `foreignKey` | `{this model}_id`, like `user_id` | The column in the related table that points to this model. |
| `localKey` | the primary key of this model | The column in this table that `foreignKey` points to. |
| `onQuery` | none | A static function that changes the query. |
| `eager` | `false` | Load the relation on every query. |

The default foreign key comes from the class name, also when the table is `users`.

## Loading the relation

The relation is not loaded by default. Use the field name, `'posts'`, as the relation name.

### Preloading

`preload()` loads the relation for all models of a query, with one more query. A user with no posts gets an empty list:

```dart
List<User> users = await User().preload('posts').get();
print(users.first.posts.length);
```

The relation is then in `toJson()`, with the field name in snake_case as the key.

### Loading on a model you have

`$getRelation()` loads the relation into the field:

```dart
await user.$getRelation('posts');
```

### Querying the relation

`related()` gives a query for the related rows. It does not set the field:

```dart
List<Post> drafts = await user
        .related<Post>('posts')
        ?.where('status', 'draft')
        .get() ??
    <Post>[];
```

### Always loading the relation

Set `eager: true` to load the relation on every query of the model:

```dart
@HasMany(Post, eager: true)
List<Post> posts = <Post>[];
```

## Saving related models

`createRelated()`, `saveRelated()` and `saveManyRelated()` save related models and set their foreign key:

```dart
Post post = await user.createRelated<Post>('posts',
    <String, dynamic>{'title': 'Hello'});
await user.saveRelated('posts', Post()..title = 'Hello');
await user.saveManyRelated('posts', <Post>[first, second]);
```

Save the user first, because a model with no key throws a `StateError`.

## Filtering by the relation

`whereHas()` keeps the users that have a post. `whereDoesntHave()` keeps the users with no post, and `has()` counts the posts:

```dart
List<User> writers = await User().whereHas('posts').get();
List<User> noPosts = await User().whereDoesntHave('posts').get();
List<User> busy = await User().has('posts', '>=', 10).get();
```

See [Query by relations](../relation-queries.md).

## Changing the relation query

Give `onQuery` a static function of the model. It gets the query of the related model and returns it. Two fields can use the same model with other queries:

```dart
@HasMany(Post)
List<Post> posts = <Post>[];

@HasMany(Post, onQuery: onlyActive)
List<Post> activePosts = <Post>[];

static QueryBuilder<Post> onlyActive(Post q) {
  return q.where('status', 'active').orderBy('id', 'desc');
}
```

## Next steps

- [BelongsTo](belongs-to.md): the other side of the relation.
- [Counting relations](../counting-relations.md): count the related rows.
- [Query by relations](../relation-queries.md): filter by the related rows.
