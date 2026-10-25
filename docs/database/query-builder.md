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

Returns all rows of the table.
`all()` ignores `where`, `join`, `orderBy` and `limit`. Use `get()` for those.

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

### `count`

Returns the number of rows as an `int`.

```dart
int total = await Actor().count();
int adults = await Actor().where('age', '>=', 18).count();
// SELECT count(*) as total FROM "actor" WHERE "age" >= @age_p0
```

- `count()` ignores `limit`, `offset` and `orderBy`.
- With `groupBy`, `count()` returns the number of groups.

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

// null
await Actor().where('deleted_at', null).get();
// WHERE "deleted_at" IS NULL
```

Many `where` calls are joined with `AND`.

!!! info
    The operator must be one of `=`, `!=`, `<>`, `<`, `>`, `<=`, `>=`, `like`,
    `not like` or `ilike` (any case). Any other value throws an `ArgumentError`.
    The column must be a plain name. Use `whereRaw` for expressions.

### `orWhere`

```dart
await Actor().where('name', 'John Doe').orWhere('name', 'John Wick').get();
// WHERE "name" = @name_p0 OR "name" = @name_p1

await Actor().where('age', '<', 18).orWhere('age', '>', 60).get();
```

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
await Actor().selectRaw('DISTINCT name').get();
await QueryBuilder.table('actor').selectRaw('count(*) as total, name').groupBy('name').get();
```

Each part must be a plain name: `name`, `table.name`, `table.*`, `*` or `name as alias`.
Anything else, like `count(*)`, throws an `ArgumentError`. Use `selectRaw` for it.

!!! info
    A model loaded with `select()` only has the selected fields.
    `save()` on it only updates the fields it has.

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

## Insert

### `create` and `insert`

`create` and `insert` do the same thing.
They insert one row, then read it back and return it.

```dart
Actor actor = await Actor().create(<String, dynamic>{
  'name': 'John Wick',
  'age': 60,
});
print(actor.id);
```

- On a model, the result is the model. On `QueryBuilder.table(...)`, the result is a map.
- It works with any primary key type, for example a uuid string.
- On a model with [events](model/events.md), `create` calls `save()`, so the hooks run.

### `insertMultiple`

Inserts many rows in one query.
It does not return models.
On Postgres it returns the new ids, like `[{id: 4}, {id: 5}]`.
On MySQL it returns only one id.

```dart
await Actor().insertMultiple(<Map<String, dynamic>>[
  <String, dynamic>{'name': 'John Wick', 'age': 60},
  <String, dynamic>{'name': 'John Doe', 'age': 25},
]);
```

The columns are the keys from all rows.
When a row does not have a key, that column gets its default value.

## Update

Updates all rows that match the `where` part.

```dart
await Actor()
    .where('id', 3)
    .where('status', 'active')
    .update(<String, dynamic>{'name': 'Updated AJ', 'age': 120});
// UPDATE "actor" SET "name" = @name_p2,"age" = @age_p3
//   WHERE "id" = @id_p0 AND "status" = @status_p1
```

!!! warning
    `update` without `where` changes every row of the table.
    A query `update` does not set `updated_at` and fires no [model events](model/events.md).
    To do that, load the model, change it and call `save()`.

## Delete

### `delete`

Deletes all rows that match the `where` part.

```dart
await Actor().where('name', 'John Wick').delete();
// DELETE FROM "actor" WHERE "name" = @name_p0
```

On a model with `softDelete: true`, `delete` sets `deleted_at` and keeps the row.

### `forceDelete`

On a model with `softDelete: true`, `forceDelete` really deletes the rows.
It also deletes rows that are already soft deleted, so you do not need `withTrash()`.

```dart
await Actor().where('name', 'John Wick').forceDelete();
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
