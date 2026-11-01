---
icon: lucide/hash
---

# Counting relations

`withCount()` adds the number of related rows to each model.

It does not load the rows. It adds a subquery to the select,
so you get the counts with the same query.

It works with `hasOne`, `hasMany`, `manyToMany`, `morphOne` and `morphMany` relations.

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

The key is the relation name in snake_case and `_count`, like `posts_count`.
Use the relation name (the field name) in `withCount()` and `countOf()`.

## Count only some rows

Give a function to add conditions to the related rows.
Use `as` to give the count its own key.

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

## With other query methods

`withCount()` works with `where()`, `orderBy()`, `find()`, `getFirst()`,
`paginate()` and with `preload()` or eager relations:

```dart
User? user = await User().preload('posts').withCount('posts').find(1);
user?.posts;              // the posts
user?.countOf('posts');   // the number of posts
```

## Sum, average, min and max

`withSum()`, `withAvg()`, `withMin()` and `withMax()` work the same way, on one column of the related rows.
The value is null when there is no related row.

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

## Exists

`withExists()` adds `<relation>_exists`. It is `true` when there is at least one related row.
It takes a function and `as`, like `withCount()`.

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

!!! info
    `withCount()` is not for `belongsTo` relations. It throws an `UnsupportedError`.
    It works for a relation to the same table, like the children of a category.

To keep only the rows that have related rows, use `whereHas()` or `has()`.
See [Query by relations](relation-queries.md).
