---
icon: lucide/search-code
---

# Query Builder

The query builder makes SQL from chained methods and runs it with bound values on Postgres, MySQL, MariaDB and SQLite.

Every value goes to the database as a bound parameter, so you do not escape values yourself. Set up the database first, see [Database](index.md).

## Starting a query

Start a query from a model to get models, or from a table name to get one map per row:

```dart
List<Actor> actors = await Actor().where('age', '>=', 23).get();

List<Map<String, dynamic>> rows = await QueryBuilder.table('actor')
    .where('age', '>=', 23)
    .get();
```

A query object keeps its parts, so start each new query with a new object. The examples use an `Actor` model on the table actor. The SQL in the comments is for Postgres.

### Another primary key

A table query uses id as the primary key. Set another one with `setPrimaryKey`:

```dart
await QueryBuilder.table('device').setPrimaryKey('uid').find('a1');
```

### Another connection

Run the query on another connection from the config:

```dart
await QueryBuilder.table('blog').withConnection('mysql').get();
```

See [Using other connections](index.md#using-other-connections). To read from the write database of a connection with replicas, use `onWriteConnection()`, see [Read replicas](replicas.md).

## Retrieving rows

### All rows

`get` runs the query and returns the rows that match:

```dart
List<Actor> actors = await Actor().where('name', 'John Wick').get();
// SELECT * FROM "actor" WHERE "name" = @name_p0
```

`all` returns the rows that match the where part, but it ignores joins, order and limit:

```dart
List<Actor> actors = await Actor().all();
```

### One row

`find` gets one row by its primary key, or by a column and a value. It returns null when no row matches:

```dart
Actor? actor = await Actor().find(1);
Actor? byName = await Actor().find('name', 'John Wick');
```

`first` returns the first row, or null. `getFirst` does the same:

```dart
Actor? actor = await Actor().where('age', '>', 60).orderBy('age').first();
// SELECT * FROM "actor" WHERE "age" > @age_p0 ORDER BY "age" LIMIT 1
```

### Throwing when no row is found

`firstOrFail` and `findOrFail` throw a `ModelNotFoundException` when no row matches. A route that does not catch it answers 404:

```dart
Actor actor = await Actor().where('name', 'John Wick').firstOrFail();
Actor byId = await Actor().findOrFail(1);
Actor byName = await Actor().findOrFail('name', 'John Wick');
```

`sole` expects exactly one row. It throws a `ModelNotFoundException` for no row, and a `MultipleRecordsFoundException` for more than one:

```dart
Actor actor = await Actor().where('email', 'john@example.com').sole();
```

### One value

`valueOf` returns one column of the first row, or null:

```dart
dynamic age = await Actor().where('name', 'John Wick').valueOf('age');
```

### A list of column values

`pluck` returns the values of one column:

```dart
List<dynamic> names = await Actor().orderBy('name').pluck('name');
// ['John Doe', 'John Wick']
```

`pluckMap` returns a map. The second column gives the keys:

```dart
Map<dynamic, dynamic> names = await Actor().pluckMap('name', 'id');
// {1: 'John Wick', 2: 'John Doe'}
```

### Checking if rows exist

`hasRows` returns true when a row matches. `hasNoRows` and `doesntExist` return the opposite. They read one row at most:

```dart
bool taken = await User().where('email', email).hasRows();
bool free = await User().where('email', email).hasNoRows();
```

## Aggregates

`count` returns the number of rows:

```dart
int adults = await Actor().where('age', '>=', 18).count();
// SELECT count(*) as total FROM "actor" WHERE "age" >= @age_p0
```

`sum`, `avg`, `min` and `max` return one value, or null when no row matches:

```dart
num? total = await Actor().sum('age');
double? average = await Actor().avg('age');
dynamic youngest = await Actor().min('age');
dynamic newest = await Actor().max('created_at');
```

They ignore limit, offset and order. With `groupBy`, use `selectRaw` and `get` in place of them. To make `sum` give 0 for no rows, see [ORM flags](index.md#orm-flags).

## Where clauses

### Basic where clauses

`where` adds a condition. With two arguments it checks for equal. With three, the middle one is the operator:

```dart
await Actor().where('name', 'John Wick').get();
// WHERE "name" = @name_p0

await Actor().where('age', '>=', 23).get();
await Actor().where('name', 'like', 'John%').get();
```

Many calls join with AND. The operator is one of `=`, `!=`, `<>`, `<`, `>`, `<=`, `>=`, `like`, `not like` or `ilike`. Another operator throws an `ArgumentError`.

### Or where clauses

`orWhere` joins a condition with OR:

```dart
await Actor().where('age', '<', 18).orWhere('age', '>', 60).get();
// WHERE "age" < @age_p0 OR "age" > @age_p1
```

### Checking for null

`whereNull` and `whereNotNull` check for NULL. A null value in `where` does the same:

```dart
await Actor().whereNull('deleted_at').get();
await Actor().whereNotNull('deleted_at').get();
await Actor().where('deleted_at', null).get(); // IS NULL
await Actor().where('deleted_at', '!=', null).get(); // IS NOT NULL
```

Each one has an or form: `orWhereNull` and `orWhereNotNull`.

### Grouping conditions

`whereGroup` puts conditions in brackets. `orWhereGroup` joins the brackets with OR:

```dart
await Actor()
    .where('status', 'active')
    .whereGroup((QueryBuilder<Actor> q) {
      q.where('age', '<', 18).orWhere('age', '>', 60);
    })
    .get();
// WHERE "status" = @status_p0 AND ("age" < @age_p1 OR "age" > @age_p2)
```

Give the function its type, like `QueryBuilder<Actor> q`, or `q` is dynamic.

### Where not clauses

`whereNot` keeps the rows where the conditions are not true. `orWhereNot` joins it with OR:

```dart
await Actor()
    .whereNot((QueryBuilder<Actor> q) {
      q.where('status', 'draft').orWhere('age', '<', 18);
    })
    .get();
// WHERE NOT ("status" = @status_p0 OR "age" < @age_p1)

await Actor().whereNot('age', '<', 18).get();
```

### Matching any or all columns

`whereAny` matches when one of the columns matches. `whereAll` matches when all of them match:

```dart
await Actor().whereAny(<String>['name', 'email'], 'like', '%john%').get();
// WHERE ("name" like @name_p0 OR "email" like @email_p1)

await Actor()
    .whereAll(<String>['first_name', 'last_name'], 'like', 'J%')
    .get();
```

Each one has an or form: `orWhereAny` and `orWhereAll`.

### Matching a list of values

`whereIn` keeps the rows where the column is in the list. `whereNotIn` keeps the others:

```dart
await Actor().whereIn('id', <int>[1, 2]).get();
// WHERE "id" IN (@id_p0,@id_p1)

await Actor().whereNotIn('id', <int>[1, 2]).get();
```

An empty list matches no rows for `whereIn` and all rows for `whereNotIn`. The value can also be a query that selects one column:

```dart
await Actor()
    .whereIn('id',
        QueryBuilder.table('award').select('actor_id').where('year', 2024))
    .get();
```

Each one has an or form: `orWhereIn` and `orWhereNotIn`. MySQL and MariaDB do not allow a limit in the inner query.

### Matching a range

`whereBetween` keeps the rows where the column is between two values, both included:

```dart
await Actor().whereBetween('age', <int>[18, 60]).get();
// WHERE "age" BETWEEN @age_p0 AND @age_p1

await Actor().whereNotBetween('age', <int>[18, 60]).get();
```

Each one has an or form: `orWhereBetween` and `orWhereNotBetween`.

### Comparing two columns

`whereColumn` compares two columns:

```dart
await Actor().whereColumn('updated_at', '>', 'created_at').get();
// WHERE "updated_at" > "created_at"
```

The or form is `orWhereColumn`.

### Matching a pattern

`whereLike` matches a pattern. `%` is any text and `_` is one character. The match ignores case by default:

```dart
await Actor().whereLike('name', '%wick%').get();
await Actor().whereNotLike('name', '%doe%').get();
await Actor().whereLike('name', 'John%', caseSensitive: true).get();
```

Each one has an or form: `orWhereLike` and `orWhereNotLike`. On MySQL and MariaDB, the column collation decides the case match.

### Where exists clauses

`whereExists` keeps the rows where a subquery on another table finds a row:

```dart
List<User> users = await User()
    .whereExists('post', (QueryBuilder<Map<String, dynamic>> q) {
      q.whereColumn('post.user_id', 'user.id');
    })
    .get();
// WHERE EXISTS (SELECT 1 FROM "post" WHERE "post"."user_id" = "user"."id")
```

The other forms are `whereNotExists`, `orWhereExists` and `orWhereNotExists`. The subquery skips global scopes and soft deletes. For a model relation, [`whereHas`](model/relation-queries.md) is shorter.

### Comparing dates

These methods compare one part of a date column. They take an operator, like `where`:

```dart
await Actor().whereDate('created_at', '2024-05-01').get();
await Actor().whereDate('created_at', '>=', DateTime(2024, 5, 1)).get();
await Actor().whereTime('created_at', '>', '18:00:00').get();
await Actor().whereYear('created_at', 2024).get();
await Actor().whereMonth('created_at', 5).get();
await Actor().whereDay('created_at', 15).get();
```

Each one has an or form, like `orWhereDate`. On SQLite, a date or time string must have zero padding, like 2024-05-01.

### JSON columns

Use `->` in a column name to read a key inside a JSON column:

```dart
await Actor().where('options->lang', 'en').get();
await Actor().where('options->address->city', 'Paris').get();
await Actor().whereIn('options->lang', <String>['en', 'de']).get();
```

It works in the where methods, `select`, `orderBy`, `groupBy` and joins. In a select, give the value a name with as, like `'options->lang as lang'`.

### Checking JSON arrays

`whereJsonContains` keeps the rows where a JSON array has the value. A list value needs all its items:

```dart
await Actor().whereJsonContains('tags', 'action').get();
await Actor().whereJsonContains('tags', <String>['action', 'drama']).get();
await Actor().whereJsonDoesntContain('tags', 'horror').get();
```

Each one has an or form, like `orWhereJsonContains`.

### Raw where clauses

`whereRaw` adds your own SQL. Put the values in a map and use `@key` in the SQL:

```dart
await Actor()
    .whereRaw('lower(name) = @name', <String, dynamic>{'name': 'john wick'})
    .get();
```

The or form is `orWhereRaw`.

!!! warning
    Never put user input into the SQL text. Always send it in the map.

### Filtering by a relation

`whereHas`, `whereDoesntHave` and `has` filter by related rows. See [Query by relations](model/relation-queries.md):

```dart
List<User> users = await User().whereHas('posts').get();
```

## Conditional clauses

`when` runs the function only when the condition is true. A third function runs when it is false:

```dart
await Actor()
    .when(status != null, (QueryBuilder<Actor> q) {
      q.where('status', status);
    })
    .get();
```

`unless` runs the function when the condition is false:

```dart
await Actor()
    .unless(showDrafts, (QueryBuilder<Actor> q) {
      q.where('status', 'published');
    })
    .get();
```

`whenValue` runs the function when the value is not null, and gives it the value:

```dart
await Actor()
    .whenValue(req.query['status'], (QueryBuilder<Actor> q, status) {
      q.where('status', status);
    })
    .get();
```

## Selecting columns

`select` sets the columns, as a list or a comma separated string:

```dart
await Actor().select(<String>['id', 'name']).get();
// SELECT "id","name" FROM "actor"

await Actor().select('id, name as actor_name').get();
```

Each part is a plain name, like `name`, `table.*` or `name as alias`. Each call replaces the columns of the call before.

### Raw select expressions

`selectRaw` takes an expression. Values go in the map:

```dart
await QueryBuilder.table('actor')
    .selectRaw('age * @rate as score', <String, dynamic>{'rate': 2})
    .get();
```

`selectRaw` replaces the select list. To make it add to the list, see [ORM flags](index.md#orm-flags).

### Distinct rows

`distinct` returns each row only once:

```dart
await QueryBuilder.table('actor').select('age').distinct().get();
// SELECT DISTINCT "age" FROM "actor"
```

### Counting relations

`withCount`, `withSum`, `withAvg`, `withMin`, `withMax` and `withExists` add a value from a relation to each model. See [Counting relations](model/counting-relations.md):

```dart
List<User> users = await User().withCount('posts').get();
```

## Ordering, grouping and limiting

### Ordering rows

`orderBy` sorts the rows, asc by default. `orderByDesc` sorts in desc order:

```dart
await Actor().orderBy('name', 'asc').orderBy('id', 'desc').get();
// ORDER BY "name" asc,"id" desc

await Actor().orderByDesc('age').get();
```

For an expression, use `orderByRaw('count(*) desc')`. Never put user input in it.

### Latest and oldest rows

`latest` and `oldest` sort by a date column, created_at by default:

```dart
Actor? newest = await Actor().latest().first();
await Actor().oldest('updated_at').get();
```

### Random order

`inRandomOrder` sorts at random. It is slow on a big table:

```dart
Actor? random = await Actor().inRandomOrder().first();
```

### Removing the order

`reorder` removes the order. It can also set a new one:

```dart
await Actor().latest().reorder().get();
await Actor().latest().reorder('name', 'desc').get();
```

### Limit and offset

`limit` sets the most rows, and `offset` skips rows. `take` and `skip` are the same:

```dart
await Actor().limit(10).offset(20).get();
await Actor().skip(20).take(10).get();
```

`forPage` gets one page. The first page is 1, and the page size is 15 by default:

```dart
await Actor().forPage(2, 50).get(); // rows 51 to 100
```

### Grouping rows

`groupBy` takes a column or a list of columns. For an expression, use `groupByRaw`:

```dart
await QueryBuilder.table('actor')
    .selectRaw('count(*) as total, age')
    .groupBy('age')
    .get();
```

Use a table query for groups, because a group row is a map. On a model, `get` with `groupBy` throws a `StateError`.

### Filtering groups

`having` filters the groups, with the same arguments as `where`. The or form is `orHaving`:

```dart
await QueryBuilder.table('actor')
    .selectRaw('status, count(*) as total')
    .groupBy('status')
    .having('status', '!=', 'draft')
    .get();
```

For an aggregate, use `havingRaw` or `orHavingRaw`. Postgres does not allow a select alias there:

```dart
await QueryBuilder.table('actor')
    .selectRaw('status, count(*) as total')
    .groupBy('status')
    .havingRaw('count(*) > @min', <String, dynamic>{'min': 5})
    .get();
```

## Joins

### Basic joins

`join` adds the matching rows of another table. `leftJoin` and `rightJoin` work the same:

```dart
await Actor().join('actor_info', 'actor_info.actor_id', 'actor.id').get();
// JOIN "actor_info" on "actor_info"."actor_id" = "actor"."id"

await Actor()
    .leftJoin('actor_info', 'actor_info.actor_id', '=', 'actor.id')
    .get();
```

### Joins with more conditions

Pass a function in place of the columns. `on` and `orOn` compare columns, and `where` and `orWhere` compare with a value:

```dart
await Actor()
    .join('contact', (JoinClause j) {
      j
          .on('contact.actor_id', 'actor.id')
          .orOn('contact.agent_id', 'actor.id')
          .where('contact.active', true);
    })
    .get();
```

### Cross joins

`crossJoin` joins each row with each row of the other table:

```dart
await QueryBuilder.table('size').crossJoin('color').get();
```

### Raw joins

`joinRaw`, `leftJoinRaw` and `rightJoinRaw` take your own SQL. Values go in the map:

```dart
await Actor().rightJoinRaw(
  'actor_info on actor_info.actor_id = actor.id '
      'and actor_info.type = @type',
  <String, dynamic>{'type': 'main'},
).get();
```

### Subquery joins

`joinSub` and `leftJoinSub` join the rows of another query. The second argument names those rows:

```dart
QueryBuilder<Map<String, dynamic>> latest = QueryBuilder.table('post')
    .selectRaw('actor_id, MAX(created_at) as last_post')
    .groupBy('actor_id');

await Actor()
    .joinSub(latest, 'latest', 'latest.actor_id', 'actor.id')
    .get();
```

### Selecting from a subquery

`fromSub` reads from the rows of another query in place of a table:

```dart
QueryBuilder<Map<String, dynamic>> totals = QueryBuilder.table('order')
    .selectRaw('actor_id, SUM(amount) as total')
    .groupBy('actor_id');

await QueryBuilder.table('totals')
    .fromSub(totals, 'totals')
    .where('total', '>', 100)
    .get();
```

## Unions

`union` adds the rows of another query and drops the same rows. `unionAll` keeps them:

```dart
List<Actor> actors = await Actor()
    .where('age', '<', 18)
    .union(Actor().where('age', '>', 60))
    .orderBy('name')
    .get();
```

Both queries select the same number of columns. The order and limit of the first query apply to the whole result. A union is for reads only: the write methods throw a `StateError`.

## Raw queries

`rawQuery` sets the full SQL of a table query. Values go in the map:

```dart
List<Map<String, dynamic>> rows = await QueryBuilder.table('blog')
    .rawQuery('select * from blog where id = @id',
        <String, dynamic>{'id': 1})
    .get();
```

To run SQL with no query builder, use `QueryBuilder.query()`, see [Running raw queries](index.md#running-raw-queries).

## Paginating results

### Page numbers

`paginate` returns one page and the page info. It runs a count query and a select query:

```dart
Pagination<Actor> page = await Actor()
    .where('age', '>=', 18)
    .paginate(currentPage: 2, perPage: 10);

print(page.total);    // rows that match
print(page.lastPage); // number of pages
```

`toJson()` gives total, per_page, last_page, current_page and data, so a controller can return the page.

### Simple pagination

`simplePaginate` skips the count, so it runs one query:

```dart
SimplePagination<Actor> page = await Actor()
    .orderBy('id')
    .simplePaginate(currentPage: 2, perPage: 10);

print(page.hasMorePages);
```

`toJson()` gives per_page, current_page, from, to, has_more_pages and data.

### Cursor pagination

`cursorPaginate` reads the rows after a cursor, so it stays fast on a big table:

```dart
CursorPagination<Actor> page = await Actor()
    .orderBy('age', 'desc')
    .cursorPaginate(perPage: 10, cursor: req.input('cursor'));

print(page.nextCursor); // send it back as cursor for the next page
```

`toJson()` gives per_page, next_cursor, prev_cursor and data. The order columns must be in the select and must have no null values. With no `orderBy`, it orders by the primary key. A cursor that is not valid gives the first page.

## Chunking results

`chunk` reads a few rows at a time. Return false from the function to stop:

```dart
await Actor().where('age', '>=', 18).chunk(100, (List<Actor> actors) {
  for (Actor actor in actors) {
    print(actor.name);
  }
  return true;
});
```

`chunk` pages with an offset. If the function changes or deletes rows, use `chunkById`. It reads the rows after the last id:

```dart
await Actor().chunkById(100, (List<Actor> actors) async {
  for (Actor actor in actors) {
    await actor.delete();
  }
  return true;
});
```

`chunkById` throws a `StateError` with an `orderBy`. For another unique column, add `column: 'uuid'`.

## Streaming results

`lazy`, `lazyById` and `cursor` give the rows as a stream, for `await for`:

```dart
await for (Actor actor in Actor().where('age', '>=', 18).lazy()) {
  print(actor.name);
}
```

| Method | Queries | How it reads |
|---|---|---|
| `lazy({chunkSize})` | many | By id, like `chunkById`. With an offset when the query has an order, a limit or an offset. |
| `lazyById({chunkSize, column})` | many | By id, or by the unique column. |
| `cursor({chunkSize})` | one | The database sends the rows when you are ready for more. |

The default chunk size is 1000. Stop the loop with `break` to stop the queries.

!!! warning
    In a transaction on Postgres or MySQL, do not run another query of the transaction inside a `cursor()` loop. It waits forever. Use `lazy()` there.

## Inserting rows

### Inserting one row

`create` inserts one row and returns it as it is in the table. `insert` does the same:

```dart
Actor actor = await Actor().create(<String, dynamic>{
  'name': 'John Wick',
  'age': 60,
});

Map<String, dynamic> row = await QueryBuilder.table('actor')
    .insert(<String, dynamic>{'name': 'John Doe'});
```

On a model with [events](model/events.md), `create` calls `save()`. Without events, it does not set created_at and updated_at.

### Getting the new id

`insertGetId` inserts one row and returns its id:

```dart
dynamic id = await QueryBuilder.table('actor')
    .insertGetId(<String, dynamic>{'name': 'John Wick'});
```

### Inserting many rows

`insertMultiple` inserts many rows in one query and returns the new ids:

```dart
await Actor().insertMultiple(<Map<String, dynamic>>[
  <String, dynamic>{'name': 'John Wick', 'age': 60},
  <String, dynamic>{'name': 'John Doe', 'age': 25},
]);
```

On MySQL and MariaDB, the result has only the first id.

`insertMany` reads nothing back and returns true, so it works on a table with no id column:

```dart
await QueryBuilder.table('actor_movie').insertMany(<Map<String, dynamic>>[
  <String, dynamic>{'actor_id': 1, 'movie_id': 2},
  <String, dynamic>{'actor_id': 1, 'movie_id': 3},
]);
```

These methods fire no model events and set no timestamps.

### Upserts

`upsert` inserts rows, or updates the row that is there. It returns the number of changed rows:

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

The unique columns must be the primary key or a unique index. Leave out the third list to update every other column. Every row must have the same keys.

### Ignoring duplicate rows

`insertOrIgnore` skips the rows that clash with a unique key. It returns the number of new rows:

```dart
int added = await QueryBuilder.table('tag')
    .insertOrIgnore(<Map<String, dynamic>>[
  <String, dynamic>{'name': 'action'},
  <String, dynamic>{'name': 'drama'},
]);
```

### Finding or creating a row

The first map finds the row, and the second map has the other values:

```dart
User user = await User().firstOrCreate(
  <String, dynamic>{'email': 'ann@example.com'},
  <String, dynamic>{'name': 'Ann'},
);

User other = await User()
    .firstOrNew(<String, dynamic>{'email': 'bob@example.com'});

User updated = await User().updateOrCreate(
  <String, dynamic>{'email': 'ann@example.com'},
  <String, dynamic>{'name': 'Ann Lee'},
);
```

| Method | Row found | No row found |
| --- | --- | --- |
| `firstOrCreate` | returns it | creates a row from both maps |
| `firstOrNew` | returns it | returns a new model, not saved |
| `updateOrCreate` | updates it with the second map | creates a row from both maps |

!!! warning
    Two requests at the same time can both create a row.
    Add a unique index, and use `upsert` when this matters.

### Updating or inserting rows

`updateOrInsert` updates every row that matches the first map. When none matches, it inserts one row. It does not read the row back:

```dart
await QueryBuilder.table('setting').updateOrInsert(
  <String, dynamic>{'key': 'theme'},
  <String, dynamic>{'value': 'dark'},
);
```

## Updating rows

### Updating many rows

`update` changes the rows that match and returns their number:

```dart
int count = await Actor()
    .where('id', 3)
    .update(<String, dynamic>{'name': 'Updated AJ', 'age': 120});
```

On a model, the keys that `fillable` does not allow are dropped. To set every key, use `forceUpdate`, see [skip the fillable check](model/index.md#skip-the-fillable-check). A query update fires no [model events](model/events.md) and does not set updated_at.

!!! warning
    On a model, `update` with no `where` throws a `StateError`.
    To change every row on purpose, see [Writing every row](#writing-every-row).

### Incrementing and decrementing

`increment` and `decrement` change a number column in one query. The amount is 1 by default, and a map sets other columns too:

```dart
await Actor().where('id', 1).increment('views');
await Actor().where('id', 1).decrement('views', 2);
await Actor().where('id', 1)
    .increment('views', 1, <String, dynamic>{'status': 'hot'});
```

On a model from the table, they change only its row and its field.

### Touching timestamps

`touch` sets updated_at to now, or another column:

```dart
await Actor().where('name', 'John Wick').touch();
await Actor().where('id', 1).touch('seen_at');
```

## Deleting rows

`delete` removes the rows that match and returns their number. On a model with `softDelete: true`, it sets deleted_at:

```dart
int count = await Actor().where('name', 'John Wick').delete();
// DELETE FROM "actor" WHERE "name" = @name_p0
```

!!! warning
    On a model, `delete` with no `where` throws a `StateError`.
    To delete every row on purpose, see [Writing every row](#writing-every-row).

### Deleting soft deleted rows for good

`forceDelete` really deletes the rows, also the soft deleted ones:

```dart
await Actor().where('name', 'John Wick').forceDelete();
```

### Including soft deleted rows

`withTrash` also gives the soft deleted rows. `onlyTrashed` gives only them:

```dart
await Actor().withTrash().where('name', 'John Wick').get();
await Actor().onlyTrashed().get();
```

### Restoring soft deleted rows

`restore` sets deleted_at back to NULL. It returns true when it changed a row:

```dart
bool restored = await Blog().where('status', 'old').restore();
```

### Writing every row

To update or delete every row of a model on purpose, add `whereRaw('1 = 1')`:

```dart
await Actor().whereRaw('1 = 1').update(<String, dynamic>{'status': 'old'});
await Actor().whereRaw('1 = 1').delete();
```

!!! warning
    `QueryBuilder.table('actor').delete()` and `truncate` skip soft deletes, so they really delete the rows.

### Truncating a table

`truncate` deletes all rows and resets the id counter:

```dart
await Actor().truncate();
await Actor().truncate(resetId: false);
```

On Postgres, `truncate` also empties every table with a foreign key to this table.

## Locking rows

`lockForUpdate` and `sharedLock` lock the rows that a select reads. Use them in a transaction, see [Row locks](transactions.md#row-locks):

```dart
await QueryBuilder.transaction(() async {
  Actor actor = await Actor().lockForUpdate().findOrFail(1);
  actor.age = actor.age! + 1;
  await actor.save();
});
```

## Cancelling a query

`cancelWith` gives the query a `QueryCancelToken`. Then `token.cancel()` stops it on Postgres and MySQL:

```dart
QueryCancelToken token = QueryCancelToken();
Future<List<Actor>> actors =
    Actor().where('age', '>', 18).cancelWith(token).get();

token.cancel();
try {
  await actors;
} on PgQueryCancelledException {
  // Postgres
} on MysqlQueryCancelledException {
  // MySQL
}
```

On SQLite the query runs to its end.

## Global scopes

`withoutGlobalScope` and `withoutGlobalScopes` leave out the global scopes of a model. See [Scopes](model/scopes.md):

```dart
await User().withoutGlobalScope('active').get();
```

## Transactions

`QueryBuilder.transaction`, `beginTransaction` and `afterCommit` are on the [Transactions](transactions.md) page.

## Debugging

### Showing the SQL

`toSql` returns the SQL with the values put in, not quoted. `toRawSql` quotes each value:

```dart
Actor().where('name', "it's").toSql();    // ... WHERE "name" = it's
Actor().where('name', "it's").toRawSql(); // ... WHERE "name" = 'it''s'
```

Use them to read a query. Do not run this text.

### Printing queries

`debug` prints the SQL of the query when it runs:

```dart
await Actor().debug(true).where('age', 60).get();
// ▌ [db:default] SELECT * FROM "actor" WHERE "age" = 60;
```

To print all queries, set `debug: true` in the `ConnectionConfig`. See [Configuration](index.md#configuration).

## Next steps

- [Transactions](transactions.md): run many queries as one unit.
- [Model](model/index.md): work with rows as objects.
- [Pagination](../guides/pagination.md): a list route with pages.
