---
icon: lucide/route
---

# HasManyThrough

Use `HasManyThrough` to read rows that are two steps away.
A model in the middle links the two ends.
`HasOneThrough` is the same, but it gives one row.

For example, a country has many users, and a user has many posts.
A country has many posts through its users.

## Tables

| Table | Columns |
|---|---|
| `country` | `id`, `name` |
| `user` | `id`, `country_id` |
| `post` | `id`, `user_id`, `title` |

## Define it

Add the field to the first model.
The `through` option is the model in the middle.

```dart title="lib/app/models/country/country.model.dart"
import 'package:dox_orm/dox_orm.dart';

import '../post/post.model.dart';
import '../user/user.model.dart';

part 'country.model.g.dart';

@DoxModel()
class Country extends CountryGenerator {
  @Column()
  String? name;

  @HasManyThrough(Post, through: User)
  List<Post> posts = <Post>[];

  @HasOneThrough(Post, through: User, onQuery: newest)
  Post? latestPost;

  static Model<Post> newest(Post q) {
    q.orderBy('post.id');
    return q;
  }
}
```

With `HasOneThrough`, when several rows match, the last row of the query wins.
So `newest` orders by `post.id` from low to high, and the highest id is the last row.

Run `dart run build_runner build` after you add a relationship.

## Load it

It loads like the other relations.

```dart
Country? country = await Country().preload('posts').find(1);
print(country?.posts.length);

List<Country> countries = await Country().withCount('posts').get();
List<Country> active = await Country().whereHas('posts').get();
```

`preload` runs one query for all countries.
`withCount`, `whereHas`, `whereDoesntHave` and `has` work too.
See [Counting relations](../counting-relations.md) and [Query by relations](../relation-queries.md).

Rows that are soft deleted are left out, in the middle table and in the far table.

## Options

| Option | Default | What it is |
|---|---|---|
| `foreignKey` | `{this model}_id`, like `country_id` | The column in the middle table that points to this model. |
| `localKey` | the primary key of this model | The column in this table that `foreignKey` points to. |
| `throughForeignKey` | `{middle model}_id`, like `user_id` | The column in the far table that points to the middle model. |
| `throughLocalKey` | the primary key of the middle model | The column in the middle table that `throughForeignKey` points to. |
| `onQuery` | none | A static function that changes the query. |
| `eager` | `false` | Load the relation on every query. |

```dart
@HasManyThrough(
  Post,
  through: User,
  foreignKey: 'home_country_id', // on user, points to the country
  localKey: 'id', // on country
  throughForeignKey: 'author_id', // on post, points to the user
  throughLocalKey: 'id', // on user
)
List<Post> posts = <Post>[];
```

## Write the table in a column name

The query joins the two tables.
So in `onQuery` and in a `whereHas` callback, write the table in front of the column.

```dart
List<Country> countries = await Country().whereHas('posts', (QueryBuilder<dynamic> q) {
  q.where('post.title', 'Hello');
}).get();
```

A column without the table, like `title`, can be in both tables.
