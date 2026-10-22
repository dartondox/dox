# Query Builder

The query builder makes SQL for you.
You chain methods, and Dox runs the query with bound values.
It works on Postgres, MySQL/MariaDB and SQLite.

- Set up the database first. See [Database](index.md).
- For transactions, see [Transactions](transactions.md).

## Start a query

There are two ways to start a query.

=== "With a model"

    ```dart
    List<Actor> actors = await Actor().where('age', '>=', 23).get();
    ```

    The result is a list of `Actor` models. See [Models](model/index.md).

=== "With a table name"

    ```dart
    List<Map<String, dynamic>> rows = await QueryBuilder.table('actor')
        .where('age', '>=', 23)
        .get();
    ```

    The result is a list of maps, one map per row.

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

=== "By primary key"

    ```dart
    Actor? actor = await Actor().find(1);
    // SELECT * FROM "actor" WHERE "id" = @id_p0 LIMIT 1
    ```

=== "By another column"

    ```dart
    Actor? actor = await Actor().find('name', 'John Wick');
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
Pagination page = await Actor()
    .where('age', '>=', 18)
    .paginate(currentPage: 2, perPage: 10);

List<Actor> actors = page.getData<Actor>();
print(page.total);    // rows that match
print(page.lastPage); // number of pages
```

`page.toJson()` gives `total`, `per_page`, `last_page`, `current_page` and `data`.
So you can return a `Pagination` from a controller.

## Where

### `where`

=== "Equal"

    ```dart
    await Actor().where('name', 'John Wick').get();
    // WHERE "name" = @name_p0
    ```

=== "Other operator"

    ```dart
    await Actor().where('age', '>=', 23).get();
    await Actor().where('name', '!=', 'John Wick').get();
    await Actor().where('name', 'like', 'John%').get();
    ```

=== "Null"

    ```dart
    await Actor().where('deleted_at', null).get();
    // WHERE "deleted_at" IS NULL
    ```

Many `where` calls are joined with `AND`.

!!! warning
    The operator is written into the SQL as it is.
    Do not pass user input as the operator or as the column name.

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

- Each value is sent as a bound parameter.
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

=== "List"

    ```dart
    await Actor().select(<String>['id', 'name']).get();
    // SELECT "id","name" FROM "actor"
    ```

=== "Comma separated"

    ```dart
    await Actor().select('id, name, age').get();
    ```

=== "With a function"

    ```dart
    await Actor().select('count(*) as total, name').groupBy('name').get();
    // SELECT count(*) as total,"name" FROM "actor" GROUP BY "name"
    ```

=== "Raw"

    ```dart
    // nothing is quoted
    await Actor().selectRaw('DISTINCT name').get();
    ```

A part with `(` is kept as it is. Other parts are quoted.

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
- The column name is quoted, but a name with `(` is kept as it is.
  Do not pass user input as the column name.

### `limit`, `take` and `offset`

`limit` and `take` do the same thing.

```dart
await Actor().limit(10).get();
await Actor().take(10).get();
await Actor().limit(10).offset(20).get();
// LIMIT 10 OFFSET 20
```

### `groupBy`

Takes one column, or a list of columns.

```dart
List<Map<String, dynamic>> rows = await Actor()
    .select('count(*) as total, age')
    .groupBy('age')
    .get();
```

!!! info
    A query with `groupBy` returns maps, not models.
    This is because a group row does not match a model row.

## Join

```dart
await Actor().join('actor_info', 'actor_info.actor_id', 'actor.id').get();
// JOIN "actor_info" on "actor_info"."actor_id" = "actor"."id"

await Actor().leftJoin('actor_info', 'actor_info.actor_id', 'actor.id').get();
await Actor().rightJoin('actor_info', 'actor_info.actor_id', 'actor.id').get();

// with an operator
await Actor().join('actor_info', 'actor_info.actor_id', '=', 'actor.id').get();
```

For a join condition that these methods can not build, use the raw methods.
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
