---
icon: lucide/search-code
---

# Query Builder

The query builder makes SQL from chained methods and runs it with bound values on Postgres, MySQL, MariaDB and SQLite.

Set up the database first. See [Database](index.md).

## Start a query

There are two ways to start a query.

```dart
// with a model: the result is a list of Actor models
List<Actor> actors = await Actor().where('age', '>=', 23).get();

// with a table name: the result is a list of maps, one map per row
List<Map<String, dynamic>> rows = await QueryBuilder.table('actor')
    .where('age', '>=', 23)
    .get();
```

The examples on this page use an `Actor` model on the table `actor`.
The SQL in the examples is for Postgres. MySQL quotes names with `` ` `` instead of `"`.

!!! tip "Start each query with a new object"
    A query object keeps its `where`, `orderBy` and other parts.
    Use `Actor()` (or `QueryBuilder.table(...)`) again for each new query.

## Read rows

### `get`

Runs the query and returns all rows that match.

```dart
List<Actor> actors = await Actor().where('name', 'John Wick').get();
// SELECT * FROM "actor" WHERE "name" = @name_p0
```

### `all`

Returns all rows that match the `where` part.
`all()` ignores `join`, `orderBy` and `limit`. Use `get()` for those.

```dart
List<Actor> actors = await Actor().all();
// SELECT * FROM "actor"
```

### `find`

Returns one row, or `null` when there is no match.

```dart
// by primary key
Actor? actor = await Actor().find(1);
// SELECT * FROM "actor" WHERE "id" = @id_p0 LIMIT 1

// by another column
Actor? byName = await Actor().find('name', 'John Wick');
// SELECT * FROM "actor" WHERE "name" = @name_p0 LIMIT 1
```

### `getFirst`

Returns the first row of the query, or `null`.

```dart
Actor? actor = await Actor().where('age', '>', 60).orderBy('age').getFirst();
// SELECT * FROM "actor" WHERE "age" > @age_p0 ORDER BY "age" LIMIT 1
```

### `firstOrFail` and `findOrFail`

They work like `getFirst()` and `find()`.
When no row matches, they throw a `ModelNotFoundException`.
So the result is never `null`.

```dart
Actor actor = await Actor().where('name', 'John Wick').firstOrFail();

Actor byId = await Actor().findOrFail(1);
Actor byName = await Actor().findOrFail('name', 'John Wick');
```

The exception has the `table`, and for `findOrFail()` also the `column` and the `id` it looked for.

```dart
try {
  Actor actor = await Actor().findOrFail(id);
} on ModelNotFoundException catch (e) {
  print(e.table); // actor
  print(e.id);    // the id
}
```

### `count`

Returns the number of rows as an `int`.

```dart
int total = await Actor().count();
int adults = await Actor().where('age', '>=', 18).count();
// SELECT count(*) as total FROM "actor" WHERE "age" >= @age_p0
```

- `count()` ignores `limit`, `offset` and `orderBy`.
- With `groupBy`, `count()` returns the number of groups.
- With `distinct()`, `count()` returns the number of distinct rows. See [`distinct`](#distinct).

### `hasRows` and `hasNoRows`

`hasRows()` returns `true` when at least one row matches.
`hasNoRows()` returns the opposite.
They read one row at most, so they are faster than `count() > 0`.

```dart
bool taken = await User().where('email', email).hasRows();

if (await User().where('email', email).hasNoRows()) {
  await User().create(<String, dynamic>{'email': email});
}
```

A model also has the `exists` getter.
It tells if that one model is saved in the table.
`hasRows()` checks a query.

### `pluck` and `pluckMap`

`pluck()` returns the values of one column, as a list.

```dart
List<dynamic> names = await Actor().orderBy('name').pluck('name');
// ['John Doe', 'John Wick']
```

`pluckMap()` returns a map. The second column gives the keys.
When two rows have the same key, the last row wins.

```dart
Map<dynamic, dynamic> names = await Actor().pluckMap('name', 'id');
// {1: 'John Wick', 2: 'John Doe'}
```

Both use `where`, `join`, `orderBy`, `limit` and `distinct`.
A date comes back as an ISO string.

### `valueOf`

Returns the value of one column of the first row.
It returns `null` when no row matches.

```dart
dynamic age = await Actor().where('name', 'John Wick').valueOf('age');
```

### `paginate`

Returns one page of rows and the page info.
It runs a `count()` query and a `get()` query.

```dart
Pagination<Actor> page = await Actor()
    .where('age', '>=', 18)
    .paginate(currentPage: 2, perPage: 10);

List<Actor> actors = page.data;
print(page.total);    // rows that match
print(page.lastPage); // number of pages
```

`page.toJson()` gives `total`, `per_page`, `last_page`, `current_page` and `data`.
So you can return a `Pagination` from a controller.

- `perPage` must be 1 or more. A smaller value throws an `ArgumentError`.
- A `currentPage` below 1 is read as page 1.

### `chunk` and `chunkById`

Use them to work on a big table.
They read a few rows at a time, so the rows do not fill the memory.

```dart
await Actor().where('age', '>=', 18).chunk(100, (List<Actor> actors) {
  for (Actor actor in actors) {
    print(actor.name);
  }
  return true; // go on to the next page
});
```

- The function gets one page of rows.
- Return `true` to go on, or `false` to stop. After a stop, `chunk()` returns `false`.
  Otherwise it returns `true`.
- Without `orderBy()`, `chunk()` orders by the primary key.
  So each page has other rows.

`chunk()` pages with `OFFSET`.
When the function changes or deletes rows, some rows can be skipped or read twice.
Use `chunkById()` then.

```dart
await Actor().where('age', '>', 100).chunkById(100, (List<Actor> actors) async {
  for (Actor actor in actors) {
    await actor.delete();
  }
  return true;
});
```

- `chunkById()` reads the rows after the last id: `WHERE "id" > @last`.
- It orders by the id itself. A query with `orderBy()` throws a `StateError`.
- To use another column, add `column: 'uuid'`. The column must be unique.

## Aggregates

`sum`, `avg`, `min` and `max` return one value for all rows that match.
They return `null` when no row matches.

```dart
num? total = await Actor().where('age', '>=', 18).sum('age');
double? average = await Actor().avg('age');
dynamic youngest = await Actor().min('age');
dynamic newest = await Actor().max('created_at');
```

- `sum()` returns a `num`. It is an `int` or a `double`, by driver. Use `toInt()` or `toDouble()`.
- `avg()` returns a `double`.
- `min()` and `max()` return the value as the driver gives it.
  A date is an ISO string. A Postgres `numeric` is a `String`. A MySQL `DECIMAL` is a `double`.
- Like `count()`, they use `where`, `join` and soft deletes.
  They ignore `limit`, `offset` and `orderBy`.
- After `distinct()`, `sum()` and `avg()` use only the distinct values.
- With `groupBy()` they throw a `StateError`. Use `selectRaw()` and `get()` for groups.

## Where

### `where`

```dart
// equal
await Actor().where('name', 'John Wick').get();
// WHERE "name" = @name_p0

// other operator
await Actor().where('age', '>=', 23).get();
await Actor().where('name', '!=', 'John Wick').get();
await Actor().where('name', 'like', 'John%').get();
```

Many `where` calls are joined with `AND`.

!!! info
    The operator must be one of `=`, `!=`, `<>`, `<`, `>`, `<=`, `>=`, `like`,
    `not like` or `ilike` (any case). Any other value throws an `ArgumentError`.
    The column must be a plain name. Use `whereRaw` for expressions.

#### `null` values

A `null` value makes an `IS NULL` or `IS NOT NULL` check.

```dart
await Actor().where('deleted_at', null).get();
// WHERE "deleted_at" IS NULL

await Actor().where('deleted_at', '=', null).get();
// WHERE "deleted_at" IS NULL

await Actor().where('deleted_at', '!=', null).get();
// WHERE "deleted_at" IS NOT NULL
```

- `=` with `null` is `IS NULL`.
- `!=` or `<>` with `null` is `IS NOT NULL`.
- Any other operator with `null` throws an `ArgumentError`.
- `where('name')` with no value throws an `ArgumentError`.

`whereNull` and `whereNotNull` do the same. See [`whereNull`](#wherenull-and-wherenotnull).

### `orWhere`

```dart
await Actor().where('name', 'John Doe').orWhere('name', 'John Wick').get();
// WHERE "name" = @name_p0 OR "name" = @name_p1

await Actor().where('age', '<', 18).orWhere('age', '>', 60).get();
```

`orWhere` takes the same arguments as `where`, also `null`.

### `whereGroup` and `orWhereGroup`

Use them to put conditions in brackets.
The function gets the query. Add the conditions to it.

```dart
await Actor()
    .where('status', 'active')
    .whereGroup((QueryBuilder<Actor> q) {
      q.where('age', '<', 18).orWhere('age', '>', 60);
    })
    .get();
// WHERE "status" = @status_p0 AND ("age" < @age_p1 OR "age" > @age_p2)

await Actor()
    .where('id', 1)
    .orWhereGroup((QueryBuilder<Actor> q) {
      q.where('status', 'active').where('age', '>', 60);
    })
    .get();
// WHERE "id" = @id_p0 OR ("status" = @status_p1 AND "age" > @age_p2)
```

- A group can have another group in it.
- An empty group adds nothing.
- Add only `where` conditions in the function.
  The function gets the same query, so an `orderBy()` there is for the whole query.

### `whereNot` and `orWhereNot`

`whereNot` keeps the rows where the conditions in the brackets are not true.

```dart
await Actor()
    .whereNot((QueryBuilder<Actor> q) {
      q.where('status', 'draft').orWhere('age', '<', 18);
    })
    .get();
// WHERE NOT ("status" = @status_p0 OR "age" < @age_p1)

await Actor()
    .where('id', 1)
    .orWhereNot((QueryBuilder<Actor> q) => q.where('status', 'draft'))
    .get();
```

!!! note
    A row with `NULL` in a column of the brackets matches neither the brackets nor `NOT` of them.
    This is how SQL works with `NULL`.

### `whereIn` and `whereNotIn`

```dart
await Actor().whereIn('id', <int>[1, 2]).get();
// WHERE "id" IN (@id_p0,@id_p1)

await Actor().whereNotIn('id', <int>[1, 2]).get();
await Actor().where('age', 60).orWhereIn('id', <int>[1, 2]).get();
await Actor().where('age', 60).orWhereNotIn('id', <int>[1, 2]).get();
```

- On Postgres, a list of only `int` or only `String` values is sent as one array
  parameter: `"id" = ANY(@id_p0)` (`<> ALL` for `whereNotIn`).
- An empty list matches no rows for `whereIn`, and all rows for `whereNotIn`.

### `whereNull` and `whereNotNull`

```dart
await Actor().whereNull('deleted_at').get();
await Actor().whereNotNull('deleted_at').get();
await Actor().where('age', 60).orWhereNull('deleted_at').get();
await Actor().where('age', 60).orWhereNotNull('deleted_at').get();
```

### `whereBetween` and `whereNotBetween`

The list has two values: from and to. Both are in the range.

```dart
await Actor().whereBetween('age', <int>[18, 60]).get();
// WHERE "age" BETWEEN @age_p0 AND @age_p1

await Actor().whereNotBetween('age', <int>[18, 60]).get();
await Actor().where('id', 1).orWhereBetween('age', <int>[18, 60]).get();
await Actor().where('id', 1).orWhereNotBetween('age', <int>[18, 60]).get();
```

The list must have two values that are not `null`. Otherwise it throws an `ArgumentError`.

### `whereColumn`

Compares two columns. Both names are columns, not values.

```dart
await Actor().whereColumn('created_at', 'updated_at').get();
// WHERE "created_at" = "updated_at"

await Actor().whereColumn('updated_at', '>', 'created_at').get();
// WHERE "updated_at" > "created_at"

await Actor().where('id', 1).orWhereColumn('updated_at', '>', 'created_at').get();
```

### `whereLike` and `whereNotLike`

Matches a column with a pattern.
`%` is any text. `_` is one character.

```dart
await Actor().whereLike('name', '%wick%').get();
await Actor().whereNotLike('name', '%doe%').get();
await Actor().where('id', 1).orWhereLike('name', 'John%').get();
await Actor().where('id', 1).orWhereNotLike('name', 'John%').get();
```

By default, the match does not care about upper or lower case.
Add `caseSensitive: true` to care about case.

```dart
await Actor().whereLike('name', 'John%', caseSensitive: true).get();
```

| Database | Default | `caseSensitive: true` |
| --- | --- | --- |
| Postgres | `ILIKE` | `LIKE` |
| MySQL, MariaDB | `LIKE`. The column collation decides. The default collations do not care about case. | `LIKE BINARY` |
| SQLite | `LIKE`. It does not care about case for ASCII letters only. | `GLOB`. Dox changes the pattern for you. |

### `whereExists` and `whereNotExists`

`whereExists` keeps the rows where a subquery finds a row.
The function gets a new query on the other table.

```dart
List<User> users = await User()
    .whereExists('post', (QueryBuilder<Map<String, dynamic>> q) {
      q.whereColumn('post.user_id', 'user.id');
    })
    .get();
// WHERE EXISTS (SELECT 1 FROM "post" WHERE "post"."user_id" = "user"."id")

await User()
    .whereNotExists('post', (QueryBuilder<Map<String, dynamic>> q) {
      q.whereColumn('post.user_id', 'user.id');
    })
    .get();
```

`orWhereExists` and `orWhereNotExists` join the condition with `OR`.

!!! info
    The subquery does not use global scopes or soft deletes.
    Add those conditions in the function, for example `q.whereNull('deleted_at')`.
    For a relation of a model, [`whereHas`](model/relation-queries.md) is shorter.

### `whereRaw` and `orWhereRaw`

Write the condition yourself. Put values in a map, and use `@key` in the SQL.
The column names are not quoted.

```dart
await Actor().whereRaw('name = @name', <String, dynamic>{'name': 'John Wick'}).get();

await Actor()
    .where('age', 60)
    .orWhereRaw('lower(name) = @name', <String, dynamic>{'name': 'john wick'})
    .get();
```

!!! warning
    Never put user input into the SQL text. Always send it in the map.

### Filter by a relation

`whereHas`, `whereDoesntHave` and `has` keep the rows that have (or do not have) related rows.
See [Query by relations](model/relation-queries.md).

```dart
List<User> users = await User().whereHas('posts').get();
```

### `when`

Runs the function only when the condition is `true`.
So you can keep the query in one chain.

```dart
List<Actor> actors = await Actor()
    .when(status != null, (QueryBuilder<Actor> q) {
      q.where('status', status);
    })
    .get();
```

A third function runs when the condition is `false`.

```dart
await Actor()
    .when(
      sort == 'name',
      (QueryBuilder<Actor> q) => q.orderBy('name'),
      (QueryBuilder<Actor> q) => q.latest(),
    )
    .get();
```

## Select

`select` sets the columns. Each call replaces the columns of the call before.

```dart
// a list
await Actor().select(<String>['id', 'name']).get();
// SELECT "id","name" FROM "actor"

// comma separated
await Actor().select('id, name, age').get();

// with an alias
await Actor().select('name as actor_name').get();

// raw: nothing is quoted
await QueryBuilder.table('actor').selectRaw('count(*) as total, name').groupBy('name').get();
```

Each part must be a plain name: `name`, `table.name`, `table.*`, `*` or `name as alias`.
Anything else, like `count(*)`, throws an `ArgumentError`. Use `selectRaw` for it.

!!! info
    A model loaded with `select()` only has the selected fields.
    `save()` on it only updates the fields it has.

### `distinct`

`distinct()` returns each row only once (`SELECT DISTINCT`).

```dart
List<Map<String, dynamic>> rows = await QueryBuilder.table('actor')
    .select('age')
    .distinct()
    .get();
// SELECT DISTINCT "age" FROM "actor"

int ages = await QueryBuilder.table('actor').select('age').distinct().count();
```

## Order, limit and group

### `orderBy`

```dart
await Actor().orderBy('name').get();
await Actor().orderBy('name', 'desc').get();
await Actor().orderBy('name', 'asc').orderBy('id', 'desc').get();
// ORDER BY "name" asc,"id" desc
```

- The direction must be `asc` or `desc`. Any other value throws an `ArgumentError`.
- The column must be a plain name. Anything else throws an `ArgumentError`.
- For an expression, use `orderByRaw('count(*) desc')`. Nothing is quoted there,
  so never put user input in it.

### `latest`, `oldest` and `inRandomOrder`

```dart
Actor? newest = await Actor().latest().getFirst();
// ORDER BY "created_at" desc

await Actor().latest('updated_at').get();
await Actor().oldest().get();
// ORDER BY "created_at" asc

Actor? random = await Actor().inRandomOrder().getFirst();
```

- `latest()` and `oldest()` use `created_at` when you give no column.
- `inRandomOrder()` is `RANDOM()` on Postgres and SQLite, and `RAND()` on MySQL.
  It sorts the whole table, so it is slow on a big table.

### `limit`, `take` and `offset`

`limit` and `take` do the same thing.

```dart
await Actor().limit(10).get();
await Actor().take(10).get();
await Actor().limit(10).offset(20).get();
// LIMIT @dox_limit OFFSET @dox_offset
```

The numbers are sent as bound parameters.

### `groupBy`

Takes one column, or a list of columns.

```dart
List<Map<String, dynamic>> rows = await QueryBuilder.table('actor')
    .selectRaw('count(*) as total, age')
    .groupBy('age')
    .get();
```

For an expression, use `groupByRaw('date(created_at)')`. Nothing is quoted there.

!!! info
    Use `QueryBuilder.table()` for `groupBy`. A group row is a map, not a model.
    On a model, `get()` gives models (`List<Actor>`), so a `groupBy` there throws a `StateError`.
    `count()` with `groupBy` works on a model too.

### `having`

`having` filters the groups. It goes after `GROUP BY`.
It takes the same arguments as `where`.

```dart
await QueryBuilder.table('actor')
    .selectRaw('status, count(*) as total')
    .groupBy('status')
    .having('status', '!=', 'draft')
    .orHaving('status', 'retired')
    .get();
// GROUP BY "status" HAVING "status" != @status_p0 OR "status" = @status_p1
```

Use `havingRaw` and `orHavingRaw` for an aggregate, like `count(*)`.
Put values in the map, like in `whereRaw`.

```dart
await QueryBuilder.table('actor')
    .selectRaw('status, count(*) as total')
    .groupBy('status')
    .havingRaw('count(*) > @min', <String, dynamic>{'min': 5})
    .get();
```

!!! note
    Postgres does not allow a select alias (like `total`) in `HAVING`.
    Write the aggregate again: `havingRaw('count(*) > @min', ...)`.

## Join

```dart
await Actor().join('actor_info', 'actor_info.actor_id', 'actor.id').get();
// JOIN "actor_info" on "actor_info"."actor_id" = "actor"."id"

await Actor().leftJoin('actor_info', 'actor_info.actor_id', 'actor.id').get();
await Actor().rightJoin('actor_info', 'actor_info.actor_id', 'actor.id').get();

// with an operator
await Actor().join('actor_info', 'actor_info.actor_id', '=', 'actor.id').get();
```

For other join conditions, use the raw methods.
Nothing is quoted. Values go in the map, like in `whereRaw`.

```dart
await Actor().joinRaw('actor_info on actor_info.actor_id = actor.id').get();
await Actor().leftJoinRaw('actor_info on actor_info.actor_id = actor.id').get();
await Actor().rightJoinRaw(
  'actor_info on actor_info.actor_id = actor.id and actor_info.type = @type',
  <String, dynamic>{'type': 'main'},
).get();
```

!!! note
    SQLite before 3.39 has no `RIGHT JOIN`.

## Row locks

`lockForUpdate()` and `sharedLock()` lock the rows that a select reads.
Use them inside a transaction.
See [Row locks](transactions.md#row-locks).

```dart
await QueryBuilder.transaction(() async {
  Actor actor = await Actor().lockForUpdate().findOrFail(1);
  actor.age = actor.age! + 1;
  await actor.save();
});
```

## Insert

### `create` and `insert`

`create` and `insert` do the same thing.
They insert one row, then return it as it is in the table.

```dart
Actor actor = await Actor().create(<String, dynamic>{
  'name': 'John Wick',
  'age': 60,
});
print(actor.id);

Map<String, dynamic> row = await QueryBuilder.table('actor').insert(<String, dynamic>{
  'name': 'John Doe',
});
print(row['id']);
```

- On a model, the result is the model. On `QueryBuilder.table(...)`, the result is a map.
- The result has the column defaults of the table too.
  Postgres and SQLite read the row with `RETURNING *`. MySQL reads it again by its id.
- It works with any primary key type, for example a uuid string.
- On a model with [events](model/events.md), `create` calls `save()`, so the hooks run.
- On a model without events, `create` does not set `created_at` and `updated_at`.
  Put them in the map, or use `save()`.

!!! note "MySQL and a table without an auto increment id"
    MySQL can not read the new row when the table has no auto increment id,
    and the map has no id (for example a pivot table).
    Then the result is made from the map you gave.

### `insertMultiple`

Inserts many rows in one query.
It does not return models. It returns the new ids:

- Postgres and SQLite: one map per row, like `[{id: 4}, {id: 5}]`.
- MySQL and MariaDB: one map with the first id, like `[{id: 4}]`.
  It is an empty list when the table has no auto increment id.

```dart
await Actor().insertMultiple(<Map<String, dynamic>>[
  <String, dynamic>{'name': 'John Wick', 'age': 60},
  <String, dynamic>{'name': 'John Doe', 'age': 25},
]);
```

The columns are the keys from all rows.
When a row does not have a key, that column gets its default value.

### `upsert`

`upsert` inserts rows, or updates the row that is already there.
It runs one query and returns the number of changed rows.

```dart
int count = await Flight().upsert(
  <Map<String, dynamic>>[
    <String, dynamic>{'from': 'Oakland', 'to': 'San Diego', 'price': 99},
    <String, dynamic>{'from': 'Chicago', 'to': 'New York', 'price': 150},
  ],
  <String>['from', 'to'], // the unique columns
  <String>['price'], // the columns to update
);
```

- The second list is the columns that find the old row.
  They must be the primary key or a unique index.
- The third list is the columns to update. Leave it out to update every other column.
  An empty list keeps the old row as it is.
- Every row must have the same keys. Otherwise it throws an `ArgumentError`.
- On a model, keys that `fillable` and `guarded` do not allow are dropped.
  `created_at` and `updated_at` are set. An update does not change `created_at`.
- It fires no [model events](model/events.md).

| Database | SQL | Count |
| --- | --- | --- |
| Postgres, SQLite | `ON CONFLICT (...) DO UPDATE` | 1 for each new or updated row |
| MySQL, MariaDB | `ON DUPLICATE KEY UPDATE` | 1 for each new row, 2 for each updated row, 0 for a row that did not change |

!!! note
    MySQL and MariaDB do not use the unique columns you give.
    Any unique index of the table can find the old row.
    Postgres throws when two rows of one call have the same unique values.

### `firstOrCreate`, `firstOrNew` and `updateOrCreate`

The first map finds the row. The second map has the other values.

```dart
// find the user, or create it
User user = await User().firstOrCreate(
  <String, dynamic>{'email': 'ann@example.com'},
  <String, dynamic>{'name': 'Ann'},
);

// find the user, or make a new model that is not saved yet
User other = await User().firstOrNew(<String, dynamic>{'email': 'bob@example.com'});
if (!other.exists) {
  await other.save();
}

// update the user, or create it
User updated = await User().updateOrCreate(
  <String, dynamic>{'email': 'ann@example.com'},
  <String, dynamic>{'name': 'Ann Lee'},
);
```

| Method | Row found | No row found |
| --- | --- | --- |
| `firstOrCreate` | returns it | creates a row from both maps |
| `firstOrNew` | returns it | returns a new model from both maps, not saved |
| `updateOrCreate` | updates it with the second map | creates a row from both maps |

- They return the row as it is in the table: a model, or a map for `QueryBuilder.table()`.
- On a model, `firstOrCreate` and `updateOrCreate` use `create()` and `save()`, so the [model events](model/events.md) run.
- On a model, keys that `fillable` and `guarded` do not allow are dropped.

!!! warning
    Two requests at the same time can both create a row.
    Add a unique index, and use `upsert` when this matters.

## Update

### `update`

Updates all rows that match the `where` part.
It returns the number of changed rows.

```dart
int count = await Actor()
    .where('id', 3)
    .where('status', 'active')
    .update(<String, dynamic>{'name': 'Updated AJ', 'age': 120});
// UPDATE "actor" SET "name" = @name_p2,"age" = @age_p3
//   WHERE "id" = @id_p0 AND "status" = @status_p1
```

- An empty map runs no query and returns 0.
- On a model, keys that `fillable` and `guarded` do not allow are dropped.
  When no key is left, it runs no query and returns 0.
- Postgres and SQLite count every row that the `where` part matched.
- MySQL and MariaDB count only the rows that really changed.
  A row that already has the new values counts 0.

!!! warning
    `update` without `where` changes every row of the table.
    A query `update` does not set `updated_at` and fires no [model events](model/events.md).
    To do that, load the model, change it and call `save()`.

### `increment` and `decrement`

They add to (or take from) a number column in one query.
They return the number of changed rows.

```dart
await Actor().where('id', 1).increment('views');
// UPDATE "actor" SET "views" = "views" + @views_p1 WHERE "id" = @id_p0

await Actor().where('id', 1).increment('views', 5);
await Actor().where('id', 1).decrement('views', 2);

// set other columns in the same query
await Actor().where('id', 1).increment('views', 1, <String, dynamic>{'status': 'hot'});
```

- The amount is 1 when you give none.
- A `NULL` column stays `NULL`, like in SQL.
- They do not set `updated_at` and fire no model events.

On a model from the table, they change only the row of that model.
The field of the model gets the new value too.
This example has an `int? views` column field on `Actor`.

```dart
Actor? actor = await Actor().find(1);
await actor!.increment('views');
print(actor.views); // the new value
```

## Delete

### `delete`

Deletes all rows that match the `where` part.
It returns the number of deleted rows.

```dart
int count = await Actor().where('name', 'John Wick').delete();
// DELETE FROM "actor" WHERE "name" = @name_p0
```

On a model with `softDelete: true`, `delete` sets `deleted_at` and keeps the row.
Rows that are already soft deleted are not counted.

### `forceDelete`

On a model with `softDelete: true`, `forceDelete` really deletes the rows.
It also deletes rows that are already soft deleted, so you do not need `withTrash()`.
It returns the number of deleted rows.

```dart
int count = await Actor().where('name', 'John Wick').forceDelete();
```

### `withTrash`

A model with `softDelete: true` hides soft deleted rows.
`withTrash()` shows them too.
On a model without soft deletes it does nothing.

```dart
List<Actor> actors = await Actor().withTrash().where('name', 'John Wick').get();
```

### `truncate`

Deletes all rows of the table and resets the id counter.

```dart
await Actor().truncate();
await Actor().truncate(resetId: false); // keep the id counter on Postgres and SQLite
```

On Postgres it runs `TRUNCATE TABLE ... RESTART IDENTITY CASCADE`.
On MySQL it runs `TRUNCATE TABLE`, and MySQL always resets the id counter.
On SQLite it runs `DELETE FROM`.

## Debug

### `toSql`

Returns the SQL of the query with the values filled in.
The values are not quoted or escaped, so use it only to read the query.

```dart
String sql = Actor().where('name', 'John Wick').toSql();
print(sql); // SELECT * FROM "actor" WHERE "name" = John Wick
```

### `debug`

Prints the SQL and the values of the query when it runs.

```dart
await Actor().debug(true).where('age', 60).get();
```

To print all queries, set `debug: true` in the `ConnectionConfig`.
See [Database](index.md#config).

## Custom drivers

A custom `DBDriver` must override `affectingStatement()`.
It runs an `UPDATE`, `DELETE` or `INSERT` and returns the number of changed rows.
`update()`, `delete()`, `increment()` and `upsert()` use it.
The default throws an `UnsupportedError`.
