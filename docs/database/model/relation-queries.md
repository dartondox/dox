---
icon: lucide/filter
---

# Query by relations

`whereHas()`, `whereDoesntHave()` and `has()` keep the rows of a query by their related rows.

They add a subquery to the `where` part and do not load the related rows. To load them, use [`preload()`](index.md#preloading-relations). Use the relation name (the field name), and start the query with a model, like `User()`.

## Rows that have a relation

`whereHas()` keeps the rows that have a related row. A function adds conditions to the related rows:

```dart
List<User> users = await User().whereHas('posts').get();

List<User> writers = await User().whereHas('posts',
    (QueryBuilder<dynamic> q) {
  q.where('published', true);
}).get();
```

Soft deleted related rows do not count. The global scopes and the `onQuery` function of the relation apply.

## Rows that do not have a relation

`whereDoesntHave()` keeps the rows that have no related row. It also takes a function:

```dart
List<User> users = await User().whereDoesntHave('posts').get();
```

## Joining with or

`orWhereHas()` and `orWhereDoesntHave()` join the condition with OR:

```dart
List<User> users = await User()
    .where('name', 'Ann')
    .orWhereHas('posts')
    .get();

await User().where('name', 'Ann').orWhereDoesntHave('posts').get();
```

## Counting related rows

`has()` takes an operator and a number. The default is at least one related row:

```dart
await User().has('posts', '>=', 3).get();
await User().has('posts', '=', 0).get();

await User().has('posts', '>', 1, (QueryBuilder<dynamic> q) {
  q.where('published', true);
}).get();
```

The operator is one of `=`, `!=`, `<>`, `<`, `>`, `<=` or `>=`.

## Relations of relations

Use a dot path. The function is for the last relation:

```dart
await User().whereHas('posts.comments', (QueryBuilder<dynamic> q) {
  q.where('user_id', 1);
}).get();
```

With `has()`, the count is for the last relation of one row. So `has('posts.comments', '>=', 2)` keeps the users that have a post with two comments or more.

## A relation to the same table

It works for a relation to the same table, like a category and its parent:

```dart
List<Category> books = await Category()
    .whereHas('parent', (QueryBuilder<dynamic> q) {
      q.where('name', 'Books');
    })
    .get();
```

In the function, write the column without the table name: `name`, not `categories.name`.

## Next steps

- [Counting relations](counting-relations.md): count the related rows.
- [HasMany](relationship/has-many.md): define a relation.
