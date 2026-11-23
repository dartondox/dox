---
icon: lucide/route
---

# HasManyThrough

Use `HasManyThrough` to read rows that are two steps away, through a model in the middle. `HasOneThrough` is the same, but it gives one row.

For example, a country has many users, and a user has many posts. So a country has many posts through its users.

## Setup

### Tables

| Table | Columns |
|---|---|
| `country` | `id`, `name` |
| `user` | `id`, `country_id` |
| `post` | `id`, `user_id`, `title` |

### Defining the relation

Add the field to the first model. The `through` option is the model in the middle:

```dart title="lib/app/models/country/country.model.dart"
@DoxModel()
class Country extends CountryGenerator {
  @HasManyThrough(Post, through: User)
  List<Post> posts = <Post>[];

  @HasOneThrough(Post, through: User)
  Post? post;
}
```

Run `dart run build_runner build` after you add a relation.

### Options

Set the four keys when your columns have other names:

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

| Option | Default | What it is |
|---|---|---|
| `through` | required | The model in the middle. |
| `foreignKey` | `{this model}_id`, like `country_id` | The column in the middle table that points to this model. |
| `localKey` | the primary key of this model | The column in this table that `foreignKey` points to. |
| `throughForeignKey` | `{middle model}_id`, like `user_id` | The column in the far table that points to the middle model. |
| `throughLocalKey` | the primary key of the middle model | The column in the middle table that `throughForeignKey` points to. |
| `onQuery` | none | A static function that changes the query. |
| `eager` | `false` | Load the relation on every query. |

## Loading the relation

The relation is not loaded by default. Use the field name, `'posts'`, as the relation name. Soft deleted rows of the middle and the far table are left out.

### Preloading

`preload()` loads the relation for all models of a query, with one more query:

```dart
Country? country = await Country().preload('posts').find(1);
print(country?.posts.length);
```

The relation is then in `toJson()`, with the field name in snake_case as the key.

### Loading on a model you have

`$getRelation()` loads the relation into the field:

```dart
await country.$getRelation('posts');
```

### Querying the relation

`related()` gives a query for the far rows. It does not set the field:

```dart
List<Post> posts = await country
        .related<Post>('posts')
        ?.where('post.title', 'Hello')
        .get() ??
    <Post>[];
```

### Always loading the relation

Set `eager: true` to load the relation on every query of the model:

```dart
@HasManyThrough(Post, through: User, eager: true)
List<Post> posts = <Post>[];
```

## Saving related models

A through relation only reads. Save the middle and the far models with their own relations, like [HasMany](has-many.md#saving-related-models).

## Filtering by the relation

`whereHas()`, `whereDoesntHave()`, `has()` and `withCount()` work too. The query joins two tables, so write the table in front of the column:

```dart
List<Country> countries = await Country().whereHas('posts',
    (QueryBuilder<dynamic> q) {
  q.where('post.title', 'Hello');
}).get();
```

See [Query by relations](../relation-queries.md) and [Counting relations](../counting-relations.md).

## Changing the relation query

Give `onQuery` a static function of the model. Write the table in front of the column:

```dart
@HasOneThrough(Post, through: User, onQuery: newest)
Post? latestPost;

static Model<Post> newest(Post q) {
  q.orderBy('post.id');
  return q;
}
```

With `HasOneThrough`, the last row of the query wins. So this example keeps the post with the highest id.

## Next steps

- [HasMany](has-many.md): the direct relation.
- [ManyToMany](many-to-many.md): a relation with a pivot table.
