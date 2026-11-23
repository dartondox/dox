---
icon: lucide/hash
---

# Counting relations

`withCount()` adds the number of related rows to each model, without loading the rows.

It adds a subquery to the select, so you get the counts with the same query. Use the relation name, which is the field name.

## Counting related rows

Read the count with `countOf()`. In JSON, the key is the relation name in snake_case with `_count`:

```dart
List<User> users = await User().withCount('posts').get();

users.first.countOf('posts'); // 3
users.first.toJson();         // {..., "posts_count": 3}
```

It works with every relation but `@BelongsTo` and `@MorphTo`, which throw an `UnsupportedError`. The global scopes and soft deletes of the related model apply.

### Counting only some rows

Give a function with conditions, and use `as` to give the count its own key. Read a custom key with `aggregate()`:

```dart
List<User> users = await User()
    .withCount('posts as published_count', (QueryBuilder<dynamic> q) {
      q.where('published', true);
    })
    .get();

users.first.aggregate('published_count');
```

### Counting and loading together

`withCount()` works with the other query methods and with `preload()`:

```dart
User? user = await User().preload('posts').withCount('posts').find(1);
```

## Sum, average, min and max

`withSum()`, `withAvg()`, `withMin()` and `withMax()` work like `withCount()` on one column. The value is null when there is no related row:

```dart
User? user = await User()
    .withSum('posts', 'views')
    .withAvg('posts', 'views')
    .withMin('posts', 'views')
    .withMax('posts', 'views')
    .find(1);

user?.aggregate('posts_sum_views');
```

The keys are `posts_sum_views`, `posts_avg_views`, `posts_min_views` and `posts_max_views`.

## Checking if related rows exist

`withExists()` adds `<relation>_exists`, which is true when there is a related row. It takes a function and `as`, like `withCount()`:

```dart
User? user = await User().withExists('posts').find(1);
user?.aggregate('posts_exists'); // true or false
```

## Next steps

- [Query by relations](relation-queries.md): keep only the rows that have related rows.
- [HasMany](relationship/has-many.md): define a relation.
