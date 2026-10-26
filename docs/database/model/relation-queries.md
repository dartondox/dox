---
icon: lucide/filter
---

# Query by relations

`whereHas()`, `whereDoesntHave()` and `has()` keep the rows of a query by their related rows.

For example: get the users that have a post.
These methods do not load the related rows.
They add a subquery to the `where` part, so it is still one query.
To load the related rows, use `preload()`. See [HasMany](relationship/has-many.md).

The examples on this page use these models:

```dart
@DoxModel()
class User extends UserGenerator {
  @HasMany(Post)
  List<Post> posts = <Post>[];
}

@DoxModel()
class Post extends PostGenerator {
  @Column()
  bool? published;

  @BelongsTo(User)
  User? user;

  @HasMany(Comment)
  List<Comment> comments = <Comment>[];
}
```

## `whereHas`

Keeps the rows that have at least one related row.
Use the relation name (the field name).

```dart
List<User> users = await User().whereHas('posts').get();
// WHERE EXISTS (SELECT 1 FROM "post" WHERE ...)
```

Give a function to add conditions to the related rows.

```dart
List<User> users = await User().whereHas('posts', (QueryBuilder<dynamic> q) {
  q.where('published', true);
}).get();
```

This keeps the users that have at least one published post.

## `whereDoesntHave`

Keeps the rows that have no related row.

```dart
List<User> users = await User().whereDoesntHave('posts').get();
// WHERE NOT EXISTS (SELECT 1 FROM "post" WHERE ...)

List<User> noDrafts = await User().whereDoesntHave('posts', (QueryBuilder<dynamic> q) {
  q.where('published', false);
}).get();
```

## `orWhereHas` and `orWhereDoesntHave`

They are the same, but they join the condition with `OR`.

```dart
List<User> users = await User()
    .where('name', 'Ann')
    .orWhereHas('posts')
    .get();
// WHERE "name" = @name_p0 OR EXISTS (...)

await User().where('name', 'Ann').orWhereDoesntHave('posts').get();
```

## `has`

`has()` counts the related rows.
Give an operator and a number.

```dart
// at least one post
await User().has('posts').get();

// three posts or more
await User().has('posts', '>=', 3).get();

// no post
await User().has('posts', '=', 0).get();

// more than one published post
await User().has('posts', '>', 1, (QueryBuilder<dynamic> q) {
  q.where('published', true);
}).get();
```

- The default is `'>='` and `1`: at least one related row.
- The operator must be one of `=`, `!=`, `<>`, `<`, `>`, `<=` or `>=`.
  Any other operator throws an `ArgumentError`.

## Relations of relations

Use a dot to check a relation of a relation.

```dart
// users that have a post with a comment
await User().whereHas('posts.comments').get();

// users that have a post with a comment by user 1
await User().whereHas('posts.comments', (QueryBuilder<dynamic> q) {
  q.where('user_id', 1);
}).get();

// users that have no post with a comment
await User().whereDoesntHave('posts.comments').get();
```

The function is for the last relation (`comments`).

With `has()`, the count is for the last relation of one row.
`has('posts.comments', '>=', 2)` keeps the users that have a post with two comments or more.

## Rules

- It works with `hasOne`, `hasMany`, `belongsTo` and `manyToMany` relations.
- Soft deleted related rows do not count.
  To count them, set `q.withTrashed = true` in the function.
- The global scopes and the `onQuery` function of the relation are used.
- It works with `where()`, `count()`, `paginate()`, `withCount()` and the other query methods.
- Start the query with a model, like `User()`.
  On `QueryBuilder.table()` it throws a `StateError`.
- A name that is not a relation of the model throws an `ArgumentError`.

!!! warning "Known limit"
    A relation from a table to the same table does not work yet.
    For example, a `Category` with a parent `Category`.
    Use [`whereExists`](../query-builder.md#whereexists-and-wherenotexists) for it.
