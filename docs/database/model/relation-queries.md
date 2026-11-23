---
icon: lucide/filter
---

# Query by relations

`whereHas()`, `whereDoesntHave()` and `has()` keep the rows of a query by their related rows.

For example, you may want only the users that have a post. These methods do not load the related rows. They add a subquery to the `where` part, so it is still one query. If you also want to load the related rows, use `preload()`. See [HasMany](relationship/has-many.md).

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

Use the relation name (the field name), like `'posts'`. Start the query with a model, like `User()`. A query from `QueryBuilder.table()` throws a `StateError`.

## Rows that have a relation

`whereHas` keeps the rows that have at least one related row:

```dart
List<User> users = await User().whereHas('posts').get();
// WHERE EXISTS (SELECT 1 FROM "post" WHERE ...)
```

If only some related rows should count, give a function with conditions. This keeps the users that have at least one published post:

```dart
List<User> users = await User().whereHas('posts', (QueryBuilder<dynamic> q) {
  q.where('published', true);
}).get();
```

## Rows that do not have a relation

`whereDoesntHave` keeps the rows that have no related row. It also takes a function:

```dart
List<User> users = await User().whereDoesntHave('posts').get();
// WHERE NOT EXISTS (SELECT 1 FROM "post" WHERE ...)

List<User> noDrafts = await User().whereDoesntHave('posts', (QueryBuilder<dynamic> q) {
  q.where('published', false);
}).get();
```

## Joining with or

`orWhereHas` and `orWhereDoesntHave` do the same, but they join the condition with `OR`:

```dart
List<User> users = await User()
    .where('name', 'Ann')
    .orWhereHas('posts')
    .get();
// WHERE "name" = @name_p0 OR EXISTS (...)

await User().where('name', 'Ann').orWhereDoesntHave('posts').get();
```

## Counting related rows

Sometimes you need a number of related rows, like "three posts or more". `has` takes an operator and a number. The default is `'>='` and `1`, so at least one related row:

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

The operator must be one of `=`, `!=`, `<>`, `<`, `>`, `<=` or `>=`. Any other operator throws an `ArgumentError`.

## Relations of relations

If you want to check a relation of a relation, use a dot. The function is for the last relation (`comments`):

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

With `has()`, the count is for the last relation of one row. So `has('posts.comments', '>=', 2)` keeps the users that have a post with two comments or more.

## A relation to the same table

It also works for a relation to the same table, like a `Category` with a parent `Category`:

```dart
// categories that have at least one child category
List<Category> parents = await Category().whereHas('children').get();

// categories whose parent is named 'Books'
List<Category> books = await Category()
    .whereHas('parent', (QueryBuilder<dynamic> q) {
      q.where('name', 'Books');
    })
    .get();
```

In the function, write the column without the table name: `name`, not `categories.name`. With the table name, the column points to the parent row, not to the related row.

## Details

- It works with `hasOne`, `hasMany`, `hasOneThrough`, `hasManyThrough`, `belongsTo`, `manyToMany`, `morphOne` and `morphMany` relations. A `morphTo` relation throws an `UnsupportedError`.
- Soft deleted related rows do not count. To count them, set `q.withTrashed = true` in the function.
- The global scopes and the `onQuery` function of the relation are used.
- It works with `where()`, `count()`, `paginate()`, `withCount()` and the other query methods.
- A name that is not a relation of the model throws an `ArgumentError`.
- For a relation to the same table, the subquery gives the table its own name, so each row is not compared with itself.

## See also

- [Counting relations](counting-relations.md): count the related rows.
- [HasMany](relationship/has-many.md): define the relation.
