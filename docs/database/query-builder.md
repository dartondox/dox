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

### `getFirst` and `first`

Returns the first row of the query, or `null`.
`first()` does the same, with the Laravel name.

```dart
Actor? actor = await Actor().where('age', '>', 60).orderBy('age').getFirst();
// SELECT * FROM "actor" WHERE "age" > @age_p0 ORDER BY "age" LIMIT 1

Actor? same = await Actor().where('age', '>', 60).orderBy('age').first();
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
When a route does not catch it, the client gets `404` with `{"code": "not_found", "message": "Not Found"}`.

```dart
try {
  Actor actor = await Actor().findOrFail(id);
} on ModelNotFoundException catch (e) {
  print(e.table); // actor
  print(e.id);    // the id
}
```

### `sole`

`sole()` returns the only row of the query.
It throws a `ModelNotFoundException` when no row matches.
It throws a `MultipleRecordsFoundException` when more than one row matches.

```dart
Actor actor = await Actor().where('email', 'john@example.com').sole();
```

It reads 2 rows at most.

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
`hasNoRows()` returns the opposite. `doesntExist()` is the same as `hasNoRows()`.
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

There is no `exists()` method on a query, because a model already has the getter `exists`. Use `hasRows()`.
There is no `value()` either, because `value` is a common column name. Use [`valueOf`](#valueof).

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
- With no rows, `lastPage` is `0`. The [`lastPageAtLeastOne` flag](index.md#orm-flags) makes it `1`.
- A `currentPage` below 1 is read as page 1.

### `simplePaginate`

Like `paginate()`, but without the total count. So it runs one query, not two.
It reads one row more to know if there is a next page.

```dart
SimplePagination<Actor> page = await Actor()
    .orderBy('id')
    .simplePaginate(currentPage: 2, perPage: 10);

List<Actor> actors = page.data;
print(page.hasMorePages); // true when there is a next page
```

`page.toJson()` gives `per_page`, `current_page`, `from`, `to`, `has_more_pages` and `data`.
`from` and `to` are the numbers of the first and last row of the page. They are `null` on an empty page.

### `cursorPaginate`

Returns one page of rows after a cursor.
It uses a `WHERE` on the order columns, not `OFFSET`, so it stays fast on a big table.
Use it for an endless list or an API.

```dart
CursorPagination<Actor> page = await Actor()
    .where('age', '>=', 18)
    .orderBy('age', 'desc')
    .cursorPaginate(perPage: 10, cursor: req.input('cursor'));

List<Actor> actors = page.data;
print(page.nextCursor); // send it back as `cursor` to read the next page
print(page.prevCursor); // send it back as `cursor` to read the page before
```

`page.toJson()` gives `per_page`, `next_cursor`, `prev_cursor` and `data`.
`next_cursor` is `null` on the last page. `prev_cursor` is `null` on the first page.

- The rows are ordered by all the `orderBy()` columns. You can mix `asc` and `desc`.
- With no `orderBy()`, they are ordered by the primary key.
  Or use `column` and `direction`: `cursorPaginate(perPage: 10, column: 'created_at', direction: 'desc')`.
- The primary key is added as the last order column, so rows with the same value are never skipped.
- `orderBy()` together with `column`, `orderByRaw()` and `inRandomOrder()` throw a `StateError`.
- It does not work on a [`union`](#union) or a [`fromSub`](#fromsub) query. It throws a `StateError` there.
  Use `paginate()` or `simplePaginate()`.
- The order columns must be in the select, and they must have no `null` values.
- The cursor is safe to take from a user. The columns and the order come from your code.
  The values of the cursor are only sent as query values, never as SQL.
- A cursor that is not valid gives the first page. This is also true for a changed cursor
  with a value of the wrong kind, like a text for a number column.

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
- `chunkById()` does not work on a [`union`](#union) or a [`fromSub`](#fromsub) query. It throws a `StateError` there.
  Use `chunk()`.
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
  When no row matches, it is `null`. The [`sumReturnsZero` flag](index.md#orm-flags) makes it `0`.
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

They also take a column and a value, like `where`:

```dart
await Actor().whereNot('status', 'draft').get();
await Actor().whereNot('age', '<', 18).get();
await Actor().where('id', 1).orWhereNot('status', 'draft').get();
```

Give the function its type, like `(QueryBuilder<Actor> q) {...}`. Without it, `q` is `dynamic`.

!!! note
    A row with `NULL` in a column of the brackets matches neither the brackets nor `NOT` of them.
    This is how SQL works with `NULL`.

### `whereAny` and `whereAll`

`whereAny` keeps the rows where at least one of the columns matches.
`whereAll` keeps the rows where all of the columns match.
They take the same values as `where`, after the list of columns.

```dart
await Actor().whereAny(<String>['name', 'email'], 'like', '%john%').get();
// WHERE ("name" like @name_p0 OR "email" like @email_p1)

await Actor().whereAll(<String>['first_name', 'last_name'], 'like', 'J%').get();
// WHERE ("first_name" like @first_name_p0 AND "last_name" like @last_name_p1)
```

- The conditions go in one bracket.
- Each one has an `or` form: `orWhereAny` and `orWhereAll`.
- An empty list adds nothing.

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

The list can also be another `Iterable`, like a `Set`.
The value can also be a query that selects one column.
Its values are bound too.

```dart
await Actor()
    .whereIn('id', QueryBuilder.table('award').select('actor_id').where('year', 2024))
    .get();
// WHERE "id" IN (SELECT "actor_id" FROM "award" WHERE "year" = @dox_sub0_year_p0)
```

- The sub query is built when it is added. A change to it after `whereIn` is not used.
  This is the same for `joinSub`, `fromSub` and `union`.
- MySQL and MariaDB do not allow `LIMIT` in an `IN (sub query)`.

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

### `whereDate`, `whereTime`, `whereYear`, `whereMonth` and `whereDay`

They compare one part of a date or datetime column.
Like `where`, they take an optional operator.

```dart
await Actor().whereDate('created_at', '2024-05-01').get();
await Actor().whereDate('created_at', '>=', DateTime(2024, 5, 1)).get();
await Actor().whereTime('created_at', '>', '18:00:00').get();
await Actor().whereYear('created_at', 2024).get();
await Actor().whereMonth('created_at', 5).get();
await Actor().whereDay('created_at', 15).get();
```

- `whereDate` takes a `DateTime` or a `yyyy-mm-dd` string.
- `whereTime` takes a `DateTime` or a `hh:mm:ss` string.
- On SQLite, a `whereDate` or `whereTime` string must be zero padded, like `2024-05-01` or `09:00:00`. A value like `2024-5-1` matches no row.
- `whereYear`, `whereMonth` and `whereDay` take an `int`, a number string or a `DateTime`.
- Each one has an `or` form, like `orWhereDate`.
- The column is read as it is stored. On SQLite and Postgres, Dox stores a `DateTime` in UTC.
- A `DateTime` value is compared the same way `where` binds it:
  in UTC on SQLite and Postgres, and as the wall clock on MySQL and MariaDB.
- On Postgres, a `timestamptz` is read in the session time zone (UTC by default).
  If the connection sets another `timeZone`, a `DateTime` value does not match.
- On Postgres, a column with fractions of a second does not equal a time without them.
  For example, `10:00:00.5` is not `10:00:00`. Laravel works the same way.

| Database | `whereDate` | `whereYear` |
| --- | --- | --- |
| Postgres | `CAST(col AS date)` | `EXTRACT(year FROM col)` |
| MySQL, MariaDB | `DATE(col)` | `YEAR(col)` |
| SQLite | `date(col)` | `strftime('%Y', col)` |

### `whereJsonContains` and `whereJsonDoesntContain`

`whereJsonContains` keeps the rows where a JSON column has the value.
For a JSON array, the value is one item. A list value needs all its items.

```dart
await Actor().whereJsonContains('tags', 'action').get();
await Actor().whereJsonContains('tags', <String>['action', 'drama']).get();

// a key inside the JSON
await Actor().whereJsonContains('options->languages', 'en').get();

await Actor().whereJsonDoesntContain('tags', 'horror').get();
```

- `column->key` reads a key inside the JSON. Keys can have letters, digits and `_`.
  Any other key throws an `ArgumentError`.
- Each one has an `or` form, like `orWhereJsonContains`.
- On SQLite, it also matches a value inside a JSON object, one level down. For example, `{"a": "x"}` matches `'x'`.

| Database | SQL |
| --- | --- |
| Postgres | `CAST(col AS jsonb) @> CAST(@value AS jsonb)` |
| MySQL, MariaDB | `JSON_CONTAINS(col, @value)` |
| SQLite | `EXISTS (SELECT 1 FROM json_each(col) WHERE value = @value)` |

!!! note
    On SQLite, the value must be a string, a number, a bool or a list of them.
    A map throws an `ArgumentError`.
    SQLite stores `true` as `1`, so `true`, `1` and `1.0` match each other there.

!!! note
    `whereJsonDoesntContain` on a row that does not have the key is not the same on every database.
    SQLite and MariaDB keep the row. Postgres and MySQL drop it. Laravel works the same way.

### JSON columns

Use `->` in a column name to read a key inside a JSON column.
Use `->` again for a nested key.

```dart
await Actor().where('options->lang', 'en').get();
await Actor().where('options->address->city', 'Paris').get();
await Actor().where('options->rating', '>', 4).get();
await Actor().where('options->active', true).get();

await Actor().whereIn('options->lang', <String>['en', 'de']).get();
await Actor().whereNull('options->lang').get();

List<Map<String, dynamic>> rows = await QueryBuilder.table('actor')
    .select(<String>['name', 'options->lang as lang'])
    .orderBy('options->lang')
    .get();
```

- It works in `where`, the other `where*` methods, `select`, `orderBy`, `groupBy` and joins.
- Keys can have letters, digits and `_`. Any other key throws an `ArgumentError`.
- In `select`, give the value a name with `as`.

| Database | `options->address->city` |
| --- | --- |
| SQLite | `json_extract("options", '$."address"."city"')` |
| MySQL, MariaDB | ``json_unquote(json_extract(`options`, '$."address"."city"'))`` |
| Postgres | `CAST("options" AS jsonb)->'address'->>'city'` |

!!! note
    In `where`, a number or a bool value works the same on every database.
    On Postgres, the other methods compare the value as text.
    For example, `whereBetween('options->rating', [1, 5])` compares text there.

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

### `unless` and `whenValue`

`unless` is the opposite of `when`. It runs the function only when the condition is `false`.

```dart
await Actor()
    .unless(showDrafts, (QueryBuilder<Actor> q) {
      q.where('status', 'published');
    })
    .get();
```

`whenValue` runs the function when the value is not `null`. The function gets the value, and it is not `null` there.
It is like Laravel `when($value, fn)`.

```dart
await Actor()
    .whenValue(req.query['status'], (QueryBuilder<Actor> q, status) {
      q.where('status', status);
    })
    .get();
```

Both take a third function too. It runs in the other case.

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

`selectRaw()` replaces the select list. The [`selectRawAdds` flag](index.md#orm-flags) makes it add to the list.

`selectRaw()` takes values, like `whereRaw`.
Write `@name` in the SQL and put the value in the map.

```dart
await QueryBuilder.table('actor')
    .selectRaw('age * @rate as score', <String, dynamic>{'rate': 2})
    .get();
```

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

### `orderByDesc` and `reorder`

```dart
await Actor().orderByDesc('age').get();
// ORDER BY "age" desc

// remove the order
await Actor().latest().reorder().get();

// remove the order, then order by name
await Actor().latest().reorder('name').get();
await Actor().latest().reorder('name', 'desc').get();
```

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

### `skip` and `forPage`

`skip` is the same as `offset`.
`forPage` gets one page of rows. The first page is `1`.
The page size is `15` when you give none.

```dart
await Actor().skip(20).take(10).get();

// rows 31 to 45
await Actor().forPage(3).get();

// rows 51 to 100
await Actor().forPage(2, 50).get();
```

### `groupBy`

Takes one column, or a list of columns.

```dart
List<Map<String, dynamic>> rows = await QueryBuilder.table('actor')
    .selectRaw('count(*) as total, age')
    .groupBy('age')
    .get();
```

For an expression, use `groupByRaw('date(created_at)')`. Nothing is quoted there.

A second `groupBy()` replaces the first. The [`groupByAdds` flag](index.md#orm-flags) makes it add to the first.

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

For a join with more conditions, pass a function in place of the columns.
It works with `join`, `leftJoin` and `rightJoin`.

```dart
await Actor()
    .join('contact', (JoinClause j) {
      j
          .on('contact.actor_id', 'actor.id')
          .orOn('contact.agent_id', 'actor.id')
          .where('contact.active', true);
    })
    .get();
// JOIN "contact" on "contact"."actor_id" = "actor"."id"
//   OR "contact"."agent_id" = "actor"."id"
//   AND "contact"."active" = @contactactive_p0
```

- `on` and `orOn` compare two columns. They take an operator too, like `on('a.x', '>=', 'b.x')`.
- `where` and `orWhere` compare a column with a value. The value is bound.
- Give the function its type, like `(JoinClause j) {...}`.
- The function must add at least one condition, or it throws an `ArgumentError`.

!!! note
    SQL reads `a OR b AND c` as `a OR (b AND c)`.

`crossJoin` joins each row with each row of the other table.

```dart
await QueryBuilder.table('size').crossJoin('color').get();
// SELECT * FROM "size" CROSS JOIN "color"
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

### `joinSub` and `leftJoinSub`

They join the rows of another query.
The second argument is the name of those rows.

```dart
QueryBuilder<Map<String, dynamic>> latest = QueryBuilder.table('post')
    .selectRaw('actor_id, MAX(created_at) as last_post')
    .groupBy('actor_id');

await Actor()
    .joinSub(latest, 'latest', 'latest.actor_id', 'actor.id')
    .get();
// JOIN (SELECT actor_id, MAX(created_at) as last_post FROM "post"
//   GROUP BY "actor_id") AS "latest" on "latest"."actor_id" = "actor"."id"

await Actor()
    .leftJoinSub(latest, 'latest', 'latest.actor_id', '=', 'actor.id')
    .get();
```

### `fromSub`

`fromSub` reads from the rows of another query, not from a table.

```dart
QueryBuilder<Map<String, dynamic>> totals = QueryBuilder.table('order')
    .selectRaw('actor_id, SUM(amount) as total')
    .groupBy('actor_id');

List<Map<String, dynamic>> rows = await QueryBuilder.table('totals')
    .fromSub(totals, 'totals')
    .where('total', '>', 100)
    .get();
// SELECT * FROM (SELECT ... GROUP BY "actor_id") AS "totals"
// WHERE "total" > @total_p0
```

The name is also the table name of the query, so `totals.total` works in `where` and `orderBy`.

## Union

`union` adds the rows of another query.
It drops rows that are the same. `unionAll` keeps them, and it is faster.

```dart
List<Actor> actors = await Actor()
    .where('age', '<', 18)
    .union(Actor().where('age', '>', 60))
    .orderBy('name')
    .get();
// SELECT * FROM "actor" WHERE "age" < @age_p0
// UNION SELECT * FROM (SELECT * FROM "actor" WHERE "age" > @dox_sub0_age_p0) AS "dox_union0"
// ORDER BY "name"

await QueryBuilder.table('actor')
    .select('name')
    .unionAll(QueryBuilder.table('director').select('name'))
    .get();
```

- Both queries must select the same number of columns.
- `orderBy`, `limit` and `offset` of the first query sort and cut the whole result.
  Use a plain column name in `orderBy`, not `table.column`.
- The added query can have its own `orderBy` and `limit`.
- `count()`, `paginate()`, `sum()`, `avg()`, `min()` and `max()` use the whole result:
  `SELECT SUM("age") as dox_aggregate FROM (...) as dox_union_aggregate`.
- `sum()`, `avg()`, `min()` and `max()` keep `orderBy`, `limit` and `offset`. `count()` does not.
- `cursorPaginate()` and `chunkById()` do not work on a union. They throw a `StateError`. Use `paginate()`, `simplePaginate()` or `chunk()`.
- `update`, `delete`, `forceDelete`, `increment`, `decrement`, `touch` and `all()` throw a `StateError` on a union, because they would use only the first query. Use `get()` to read it.

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

### `insertGetId` and `insertMany`

`insertGetId` inserts one row and returns its new id.
The id is the auto increment id, or the id in the map when the table has no auto increment.

```dart
dynamic id = await QueryBuilder.table('actor').insertGetId(<String, dynamic>{
  'name': 'John Wick',
});
```

`insertMany` inserts many rows, reads nothing back and returns `true`.
It works on a table with no `id` column, like a pivot table. An empty list runs no query.

```dart
await QueryBuilder.table('actor_movie').insertMany(<Map<String, dynamic>>[
  <String, dynamic>{'actor_id': 1, 'movie_id': 2},
  <String, dynamic>{'actor_id': 1, 'movie_id': 3},
]);
```

- Both fire no model events and set no timestamps.
- On a model, the keys that `fillable` and `guarded` do not allow are dropped.

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
- On a model, keys that `fillable` and `guarded` do not allow are dropped. A model with no `fillable` throws, see [mass assignment](model/index.md#mass-assignment).
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

### `insertOrIgnore`

`insertOrIgnore` inserts rows and skips the rows that clash with a unique key.
It returns the number of inserted rows.

```dart
int added = await QueryBuilder.table('tag').insertOrIgnore(<Map<String, dynamic>>[
  <String, dynamic>{'name': 'action'},
  <String, dynamic>{'name': 'drama'},
]);
```

- Every row must have the same keys. Otherwise it throws an `ArgumentError`.
- On a model, keys that `fillable` and `guarded` do not allow are dropped. A model with no `fillable` throws, see [mass assignment](model/index.md#mass-assignment).
- It fires no [model events](model/events.md).

| Database | SQL | Also skips |
| --- | --- | --- |
| Postgres | `ON CONFLICT DO NOTHING` | nothing else |
| SQLite | `INSERT OR IGNORE` | rows that break a `NOT NULL` or `CHECK` rule |
| MySQL, MariaDB | `INSERT IGNORE` | some bad values become a warning, for example text that is too long is cut |

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
- On a model, keys that `fillable` and `guarded` do not allow are dropped. A model with no `fillable` throws, see [mass assignment](model/index.md#mass-assignment).

!!! warning
    Two requests at the same time can both create a row.
    Add a unique index, and use `upsert` when this matters.

### `updateOrInsert`

`updateOrInsert` updates the rows that match the first map with the second map.
When no row matches, it inserts one row from both maps.

```dart
await QueryBuilder.table('setting').updateOrInsert(
  <String, dynamic>{'key': 'theme'},
  <String, dynamic>{'value': 'dark'},
);
```

- It does not read the row back. Use `updateOrCreate` when you need the row.
- It returns `true` when it inserted a row, or when the update changed a row.
  MySQL and MariaDB count only the rows that really changed.
- An empty first map throws an `ArgumentError`, so it can never update every row by mistake.

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
- On a model, keys that `fillable` and `guarded` do not allow are dropped. A model with no `fillable` throws, see [mass assignment](model/index.md#mass-assignment).
  When no key is left, it runs no query and returns 0.
  To set every key of the map, use `forceUpdate()`, see [skip the fillable check](model/index.md#skip-the-fillable-check).
- Postgres and SQLite count every row that the `where` part matched.
- MySQL and MariaDB count only the rows that really changed.
  A row that already has the new values counts 0.

!!! warning
    On a model, `update` needs a `where` (or a global scope).
    `Actor().update({...})` with no `where` throws a `StateError` and runs no query.
    To change every row on purpose, see [write every row](#write-every-row).
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
- On a model, they need a `where`, a global scope or a model from the table.
  `Actor().increment('views')` with no `where` throws a `StateError` and runs no query.

On a model from the table, they change only the row of that model.
`update` on a model from the table does the same, like Laravel: `await actor!.update({'name': 'AJ'})`.
It runs one query and fires no model events. Use `save()` for the events and `updated_at`.
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

!!! warning
    On a model, `delete` needs a `where`, a global scope, or a model from the table with its primary key.
    `Actor().delete()` with no `where` throws a `StateError` and runs no query.
    A model read without its primary key (like after `select('name')`) throws too.
    So it can not delete every row by mistake. `forceDelete` does the same.
    To delete every row on purpose, see [write every row](#write-every-row).

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

### `onlyTrashed`

`onlyTrashed()` gives only the soft deleted rows.
On a model without soft deletes it throws a `StateError`.

```dart
List<Actor> trashed = await Actor().onlyTrashed().get();

// delete the soft deleted rows for good
await Actor().onlyTrashed().forceDelete();
```

### `restore`

`restore()` on a query sets `deleted_at` back to `NULL` for every soft deleted row of the query. It sets `updated_at` too, when the model has timestamps.
It returns `true` when it changed a row, else `false`.
It fires no model events.
With no `where()`, it throws a `StateError`, so it can not restore every row by mistake.

```dart
bool restored = await Blog().withTrash().where('status', 'old').restore();
```

### `touch`

Sets `updated_at` of the rows to now. Give a column name to set another column.
It returns the number of changed rows.

```dart
await Actor().where('name', 'John Wick').touch();
await Actor().where('id', 1).touch('seen_at');
```

On a query, `touch()` fires no model events.
On a model query with no `where()` (and no global scope), `touch()` throws a `StateError`.
On MySQL and MariaDB, it can return 0 when the new time is the same as the stored one (the same second), because they count only changed rows.
On a model from the table, `touch()` changes only the row of that model.
See [Models](model/index.md#touch-and-replicate).

### Write every row

On a model, `delete`, `forceDelete`, `update`, `increment`, `decrement` and `touch` with no `where` throw a `StateError`.
To write every row on purpose, use `whereRaw('1 = 1')`:

```dart
await Actor().whereRaw('1 = 1').update(<String, dynamic>{'status': 'old'});
await Actor().whereRaw('1 = 1').delete();
```

It keeps soft deletes (a soft delete model sets `deleted_at`) and global scopes.

!!! warning
    `QueryBuilder.table('actor').delete()` and `truncate` are not the same.
    They skip soft deletes, so they really delete the rows. They also skip global scopes and `fillable`.
    On Postgres, `truncate` runs `CASCADE`: it also empties every table with a foreign key to this table.

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

### `toRawSql`

Returns the SQL with each value quoted for the database.
Use it for logs and debugging. Run queries with bound values, not with this text.

```dart
String sql = Actor().where('name', "it's").toRawSql();
print(sql); // SELECT * FROM "actor" WHERE "name" = 'it''s'
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
