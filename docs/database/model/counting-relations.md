---
icon: lucide/hash
---

# Counting relations

`withCount()` adds the number of related rows to each model, without loading the rows.

This is useful when a page shows "3 posts" next to each user. It adds a subquery to the select, so you get the counts with the same query.

## Counting related rows

Give `withCount` the relation name (the field name). Then read the count with `countOf`:

```dart
@DoxModel()
class User extends UserGenerator {
  @HasMany(Post)
  List<Post> posts = <Post>[];
}

List<User> users = await User().withCount('posts').get();

users.first.countOf('posts'); // 3
users.first.toJson();         // {..., "posts_count": 3}
```

In JSON, the key is the relation name in snake_case and `_count`, like `posts_count`.

It works with `hasOne`, `hasMany`, `hasOneThrough`, `hasManyThrough`, `manyToMany`, `morphOne` and `morphMany` relations. It is not for `belongsTo` relations, and there it throws an `UnsupportedError`.

### Counting only some rows

Sometimes you only want to count some related rows, like the published posts. Give a function with conditions, and use `as` to give the count its own key:

```dart
List<User> users = await User()
    .withCount('posts')
    .withCount('posts as published_count', (QueryBuilder<dynamic> q) {
      q.where('published', true);
    })
    .get();

users.first.countOf('posts');               // all posts
users.first.aggregate('published_count');   // published posts
```

The global scopes and soft deletes of the related model are used in the count.

### Counting and loading together

`withCount()` works with `where()`, `orderBy()`, `find()`, `getFirst()`, `paginate()`, and with `preload()` or eager relations:

```dart
User? user = await User().preload('posts').withCount('posts').find(1);
user?.posts;              // the posts
user?.countOf('posts');   // the number of posts
```

## Sum, average, min and max

If you need a total of one column, like all views of a user's posts, use `withSum()`, `withAvg()`, `withMin()` or `withMax()`. They work like `withCount()`. Read the value with `aggregate`. It is null when there is no related row:

```dart
User? user = await User()
    .withSum('posts', 'views')
    .withAvg('posts', 'views')
    .withMin('posts', 'views')
    .withMax('posts', 'views')
    .find(1);

user?.aggregate('posts_sum_views');
user?.aggregate('posts_avg_views');
user?.aggregate('posts_min_views');
user?.aggregate('posts_max_views');
```

## Checking if related rows exist

If you only need to know whether there is a related row, use `withExists()`. It adds `<relation>_exists`, which is `true` when there is at least one related row. It takes a function and `as`, like `withCount()`:

```dart
User? user = await User()
    .withExists('posts')
    .withExists('posts as has_published', (QueryBuilder<dynamic> q) {
      q.where('published', true);
    })
    .find(1);

user?.aggregate('posts_exists');   // true or false
user?.aggregate('has_published');  // true or false
```

If you want to keep only the rows that have related rows, use `whereHas()` or `has()` instead. See [Query by relations](relation-queries.md).

## Details

- It works for a relation to the same table, like the children of a category.
