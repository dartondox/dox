---
icon: lucide/search-code
---

# Query Builder

The query builder makes SQL from chained methods and runs it with bound values on Postgres, MySQL, MariaDB and SQLite.

You build a query step by step, like `where`, then `orderBy`, then `get`. Every value is sent as a bound parameter, so you do not need to escape values yourself.

Set up the database first. See [Database](index.md).

## Starting a query

You can start a query from a model or from a table name. A model query gives you models. A table query gives you maps, one map per row:

```dart
// with a model: the result is a list of Actor models
List<Actor> actors = await Actor().where('age', '>=', 23).get();

// with a table name: the result is a list of maps, one map per row
List<Map<String, dynamic>> rows = await QueryBuilder.table('actor')
    .where('age', '>=', 23)
    .get();
```

Start each new query with a new object, like `Actor()` or `QueryBuilder.table(...)`. This is because a query object keeps its `where`, `orderBy` and other parts.

The examples on this page use an `Actor` model on the table `actor`. The SQL in the comments is for Postgres. MySQL quotes names with `` ` `` instead of `"`.

## Retrieving rows

### Retrieving all rows

The `get` method runs the query and returns all rows that match:

```dart
List<Actor> actors = await Actor().where('name', 'John Wick').get();
// SELECT * FROM "actor" WHERE "name" = @name_p0
```

The `all` method also returns the rows that match the `where` part. But it ignores `join`, `orderBy` and `limit`, so use `get` when you need those:

```dart
List<Actor> actors = await Actor().all();
// SELECT * FROM "actor"
```

### Retrieving a single row

Use `find` to get one row by its primary key. You can also give a column and a value. It returns `null` when there is no match:

```dart
// by primary key
Actor? actor = await Actor().find(1);
// SELECT * FROM "actor" WHERE "id" = @id_p0 LIMIT 1

// by another column
Actor? byName = await Actor().find('name', 'John Wick');
// SELECT * FROM "actor" WHERE "name" = @name_p0 LIMIT 1
```

The `first` method returns the first row of the query, or `null`. `getFirst` does the same:

```dart
Actor? actor = await Actor().where('age', '>', 60).orderBy('age').getFirst();
// SELECT * FROM "actor" WHERE "age" > @age_p0 ORDER BY "age" LIMIT 1

Actor? same = await Actor().where('age', '>', 60).orderBy('age').first();
```

### Throwing when no row is found

Sometimes a missing row is an error, for example in a route like `/actors/{id}`. In this case, use `firstOrFail` or `findOrFail`. They work like `first` and `find`, but they throw a `ModelNotFoundException` when no row matches. So the result is never `null`:

```dart
Actor actor = await Actor().where('name', 'John Wick').firstOrFail();

Actor byId = await Actor().findOrFail(1);
Actor byName = await Actor().findOrFail('name', 'John Wick');
```

If the route does not catch the exception, the client gets a `404` answer with `{"code": "not_found", "message": "Not Found"}`.

If you expect exactly one row, use `sole`. It throws a `ModelNotFoundException` when no row matches, and a `MultipleRecordsFoundException` when more than one row matches:

```dart
Actor actor = await Actor().where('email', 'john@example.com').sole();
```

### Retrieving a single value

If you need only one column of the first row, use `valueOf`. It returns `null` when no row matches:

```dart
dynamic age = await Actor().where('name', 'John Wick').valueOf('age');
```

### Retrieving a list of column values

The `pluck` method returns the values of one column as a list:

```dart
List<dynamic> names = await Actor().orderBy('name').pluck('name');
// ['John Doe', 'John Wick']
```

If you want a map, use `pluckMap`. The second column gives the keys. If two rows have the same key, the last row wins:

```dart
Map<dynamic, dynamic> names = await Actor().pluckMap('name', 'id');
// {1: 'John Wick', 2: 'John Doe'}
```

### Checking if rows exist

`hasRows` returns `true` when at least one row matches. `hasNoRows` returns the opposite, and `doesntExist` is the same as `hasNoRows`. They read one row at most, so they are faster than `count() > 0`:

```dart
bool taken = await User().where('email', email).hasRows();

if (await User().where('email', email).hasNoRows()) {
  await User().create(<String, dynamic>{'email': email});
}
```

## Aggregates

Sometimes you need a number about the rows, not the rows. The `count` method returns the number of rows as an `int`:

```dart
int total = await Actor().count();
int adults = await Actor().where('age', '>=', 18).count();
// SELECT count(*) as total FROM "actor" WHERE "age" >= @age_p0
```

`sum`, `avg`, `min` and `max` return one value for all rows that match. They return `null` when no row matches:

```dart
num? total = await Actor().where('age', '>=', 18).sum('age');
double? average = await Actor().avg('age');
dynamic youngest = await Actor().min('age');
dynamic newest = await Actor().max('created_at');
```

`sum` returns a `num`. It can be an `int` or a `double`, so use `toInt()` or `toDouble()` when you need one type.

All aggregates use `where`, `join` and soft deletes, but they ignore `limit`, `offset` and `orderBy`.

## Where clauses

### Basic where clauses

The `where` method adds a condition. With two arguments, it checks that the column equals the value. With three arguments, the middle one is the operator:

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

The operator must be one of `=`, `!=`, `<>`, `<`, `>`, `<=`, `>=`, `like`, `not like` or `ilike` (any case). Any other value throws an `ArgumentError`. The column must be a plain name. For an expression, use [`whereRaw`](#raw-where-clauses).

### Or where clauses

The `orWhere` method joins a condition with `OR`. It takes the same arguments as `where`:

```dart
await Actor().where('name', 'John Doe').orWhere('name', 'John Wick').get();
// WHERE "name" = @name_p0 OR "name" = @name_p1

await Actor().where('age', '<', 18).orWhere('age', '>', 60).get();
```

### Checking for null

A `null` value makes an `IS NULL` or `IS NOT NULL` check:

```dart
await Actor().where('deleted_at', null).get();
// WHERE "deleted_at" IS NULL

await Actor().where('deleted_at', '=', null).get();
// WHERE "deleted_at" IS NULL

await Actor().where('deleted_at', '!=', null).get();
// WHERE "deleted_at" IS NOT NULL
```

`whereNull` and `whereNotNull` do the same, and they are easier to read:

```dart
await Actor().whereNull('deleted_at').get();
await Actor().whereNotNull('deleted_at').get();
await Actor().where('age', 60).orWhereNull('deleted_at').get();
await Actor().where('age', 60).orWhereNotNull('deleted_at').get();
```

### Grouping conditions

Sometimes you need brackets, for example "active AND (young OR old)". Use `whereGroup` for this. The function gets the query, and you add the conditions to it:

```dart
await Actor()
    .where('status', 'active')
    .whereGroup((QueryBuilder<Actor> q) {
      q.where('age', '<', 18).orWhere('age', '>', 60);
    })
    .get();
// WHERE "status" = @status_p0 AND ("age" < @age_p1 OR "age" > @age_p2)
```

Use `orWhereGroup` to join the brackets with `OR`:

```dart
await Actor()
    .where('id', 1)
    .orWhereGroup((QueryBuilder<Actor> q) {
      q.where('status', 'active').where('age', '>', 60);
    })
    .get();
// WHERE "id" = @id_p0 OR ("status" = @status_p1 AND "age" > @age_p2)
```

Give the function its type, like `(QueryBuilder<Actor> q) {...}`. Without it, `q` is `dynamic`. A group can also have another group in it.

### Where not clauses

`whereNot` keeps the rows where the conditions in the brackets are not true. `orWhereNot` joins it with `OR`:

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

### Matching any or all columns

Sometimes you want to search the same value in many columns. `whereAny` keeps the rows where at least one of the columns matches. `whereAll` keeps the rows where all of the columns match. After the list of columns, they take the same values as `where`:

```dart
await Actor().whereAny(<String>['name', 'email'], 'like', '%john%').get();
// WHERE ("name" like @name_p0 OR "email" like @email_p1)

await Actor().whereAll(<String>['first_name', 'last_name'], 'like', 'J%').get();
// WHERE ("first_name" like @first_name_p0 AND "last_name" like @last_name_p1)
```

Each one has an `or` form: `orWhereAny` and `orWhereAll`.

### Matching a list of values

`whereIn` keeps the rows where the column is in the list. `whereNotIn` keeps the others:

```dart
await Actor().whereIn('id', <int>[1, 2]).get();
// WHERE "id" IN (@id_p0,@id_p1)

await Actor().whereNotIn('id', <int>[1, 2]).get();
await Actor().where('age', 60).orWhereIn('id', <int>[1, 2]).get();
await Actor().where('age', 60).orWhereNotIn('id', <int>[1, 2]).get();
```

The list can also be another `Iterable`, like a `Set`. An empty list matches no rows for `whereIn`, and all rows for `whereNotIn`.

The value can also be a query that selects one column. Its values are bound too:

```dart
await Actor()
    .whereIn('id', QueryBuilder.table('award').select('actor_id').where('year', 2024))
    .get();
// WHERE "id" IN (SELECT "actor_id" FROM "award" WHERE "year" = @dox_sub0_year_p0)
```

### Matching a range

`whereBetween` keeps the rows where the column is between two values. Both values are in the range:

```dart
await Actor().whereBetween('age', <int>[18, 60]).get();
// WHERE "age" BETWEEN @age_p0 AND @age_p1

await Actor().whereNotBetween('age', <int>[18, 60]).get();
await Actor().where('id', 1).orWhereBetween('age', <int>[18, 60]).get();
await Actor().where('id', 1).orWhereNotBetween('age', <int>[18, 60]).get();
```

The list must have two values that are not `null`. Otherwise it throws an `ArgumentError`.

### Comparing two columns

`whereColumn` compares two columns. Both names are columns, not values:

```dart
await Actor().whereColumn('created_at', 'updated_at').get();
// WHERE "created_at" = "updated_at"

await Actor().whereColumn('updated_at', '>', 'created_at').get();
// WHERE "updated_at" > "created_at"

await Actor().where('id', 1).orWhereColumn('updated_at', '>', 'created_at').get();
```

### Matching a pattern

`whereLike` matches a column with a pattern. In the pattern, `%` is any text and `_` is one character:

```dart
await Actor().whereLike('name', '%wick%').get();
await Actor().whereNotLike('name', '%doe%').get();
await Actor().where('id', 1).orWhereLike('name', 'John%').get();
await Actor().where('id', 1).orWhereNotLike('name', 'John%').get();
```

By default, the match does not care about upper or lower case. If you want it to care, add `caseSensitive: true`:

```dart
await Actor().whereLike('name', 'John%', caseSensitive: true).get();
```

### Where exists clauses

`whereExists` keeps the rows where a subquery finds a row. The function gets a new query on the other table:

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

The subquery does not use global scopes or soft deletes, so add those conditions yourself, for example `q.whereNull('deleted_at')`. For a relation of a model, [`whereHas`](model/relation-queries.md) is shorter.

### Comparing dates

These methods compare one part of a date or datetime column. Like `where`, they take an optional operator:

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
- `whereYear`, `whereMonth` and `whereDay` take an `int`, a number string or a `DateTime`.

Each one has an `or` form, like `orWhereDate`. Time zones work the same as in `where`, see [Details](#dates-and-time-zones).

### JSON columns

Use `->` in a column name to read a key inside a JSON column. Use `->` again for a nested key:

```dart
await Actor().where('options->lang', 'en').get();
await Actor().where('options->address->city', 'Paris').get();
await Actor().where('options->rating', '>', 4).get();
await Actor().where('options->active', true).get();

await Actor().whereIn('options->lang', <String>['en', 'de']).get();
await Actor().whereNull('options->lang').get();
```

It works in `where`, the other `where*` methods, `select`, `orderBy`, `groupBy` and joins. In `select`, give the value a name with `as`:

```dart
List<Map<String, dynamic>> rows = await QueryBuilder.table('actor')
    .select(<String>['name', 'options->lang as lang'])
    .orderBy('options->lang')
    .get();
```

Keys can have letters, digits and `_`. Any other key throws an `ArgumentError`.

### Checking JSON arrays

`whereJsonContains` keeps the rows where a JSON column has the value. For a JSON array, the value is one item. A list value needs all its items:

```dart
await Actor().whereJsonContains('tags', 'action').get();
await Actor().whereJsonContains('tags', <String>['action', 'drama']).get();

// a key inside the JSON
await Actor().whereJsonContains('options->languages', 'en').get();

await Actor().whereJsonDoesntContain('tags', 'horror').get();
```

Each one has an `or` form, like `orWhereJsonContains`.

### Raw where clauses

Sometimes you need SQL that the other methods can not build. Then write the condition yourself with `whereRaw`. Put the values in a map, and use `@key` in the SQL. The column names are not quoted:

```dart
await Actor().whereRaw('name = @name', <String, dynamic>{'name': 'John Wick'}).get();

await Actor()
    .where('age', 60)
    .orWhereRaw('lower(name) = @name', <String, dynamic>{'name': 'john wick'})
    .get();
```

!!! warning
    Never put user input into the SQL text. Always send it in the map.

### Filtering by a relation

`whereHas`, `whereDoesntHave` and `has` keep the rows that have (or do not have) related rows. See [Query by relations](model/relation-queries.md).

```dart
List<User> users = await User().whereHas('posts').get();
```

## Conditional clauses

Sometimes a condition depends on the request, like a filter that the user may or may not send. `when` runs the function only when the condition is `true`, so you can keep the query in one chain:

```dart
List<Actor> actors = await Actor()
    .when(status != null, (QueryBuilder<Actor> q) {
      q.where('status', status);
    })
    .get();
```

A third function runs when the condition is `false`:

```dart
await Actor()
    .when(
      sort == 'name',
      (QueryBuilder<Actor> q) => q.orderBy('name'),
      (QueryBuilder<Actor> q) => q.latest(),
    )
    .get();
```

`unless` is the opposite of `when`. It runs the function only when the condition is `false`:

```dart
await Actor()
    .unless(showDrafts, (QueryBuilder<Actor> q) {
      q.where('status', 'published');
    })
    .get();
```

`whenValue` runs the function when the value is not `null`. The function gets the value, and it is not `null` there:

```dart
await Actor()
    .whenValue(req.query['status'], (QueryBuilder<Actor> q, status) {
      q.where('status', status);
    })
    .get();
```

`unless` and `whenValue` also take a third function, which runs in the other case.

## Selecting columns

You do not always need every column. `select` sets the columns you want. You can give a list or a comma separated string:

```dart
// a list
await Actor().select(<String>['id', 'name']).get();
// SELECT "id","name" FROM "actor"

// comma separated
await Actor().select('id, name, age').get();
```

Use `as` to give a column another name:

```dart
// with an alias
await Actor().select('name as actor_name').get();
```

Each part must be a plain name: `name`, `table.name`, `table.*`, `*` or `name as alias`. Anything else, like `count(*)`, throws an `ArgumentError`. Each `select` call replaces the columns of the call before.

A model loaded with `select` only has the selected fields. So `save()` on it only updates the fields it has.

### Raw select expressions

For an expression like `count(*)`, use `selectRaw`. Nothing is quoted there:

```dart
// raw: nothing is quoted
await QueryBuilder.table('actor').selectRaw('count(*) as total, name').groupBy('name').get();
```

`selectRaw` takes values, like `whereRaw`. Write `@name` in the SQL and put the value in the map:

```dart
await QueryBuilder.table('actor')
    .selectRaw('age * @rate as score', <String, dynamic>{'rate': 2})
    .get();
```

### Distinct rows

`distinct` returns each row only once (`SELECT DISTINCT`):

```dart
List<Map<String, dynamic>> rows = await QueryBuilder.table('actor')
    .select('age')
    .distinct()
    .get();
// SELECT DISTINCT "age" FROM "actor"

int ages = await QueryBuilder.table('actor').select('age').distinct().count();
```

## Ordering, grouping and limiting

### Ordering rows

`orderBy` sorts the rows. The direction is `asc` (the default) or `desc`:

```dart
await Actor().orderBy('name').get();
await Actor().orderBy('name', 'desc').get();
await Actor().orderBy('name', 'asc').orderBy('id', 'desc').get();
// ORDER BY "name" asc,"id" desc
```

`orderByDesc` is a short way to sort in `desc` order:

```dart
await Actor().orderByDesc('age').get();
// ORDER BY "age" desc
```

For an expression, use `orderByRaw('count(*) desc')`. Nothing is quoted there, so never put user input in it.

### Latest and oldest rows

`latest` and `oldest` sort by a date column. They use `created_at` when you give no column:

```dart
Actor? newest = await Actor().latest().getFirst();
// ORDER BY "created_at" desc

await Actor().latest('updated_at').get();
await Actor().oldest().get();
// ORDER BY "created_at" asc
```

### Random order

`inRandomOrder` sorts the rows at random. It sorts the whole table, so it is slow on a big table:

```dart
Actor? random = await Actor().inRandomOrder().getFirst();
```

### Removing the order

`reorder` removes the order of the query. You can give a new order in the same call:

```dart
// remove the order
await Actor().latest().reorder().get();

// remove the order, then order by name
await Actor().latest().reorder('name').get();
await Actor().latest().reorder('name', 'desc').get();
```

### Limit and offset

`limit` sets the most rows to read, and `offset` skips rows. `take` is the same as `limit`, and `skip` is the same as `offset`:

```dart
await Actor().limit(10).get();
await Actor().take(10).get();
await Actor().limit(10).offset(20).get();
// LIMIT @dox_limit OFFSET @dox_offset

await Actor().skip(20).take(10).get();
```

`forPage` gets one page of rows. The first page is `1`, and the page size is `15` when you give none:

```dart
// rows 31 to 45
await Actor().forPage(3).get();

// rows 51 to 100
await Actor().forPage(2, 50).get();
```

### Grouping rows

`groupBy` takes one column or a list of columns. For an expression, use `groupByRaw('date(created_at)')`. Nothing is quoted there:

```dart
List<Map<String, dynamic>> rows = await QueryBuilder.table('actor')
    .selectRaw('count(*) as total, age')
    .groupBy('age')
    .get();
```

Use `QueryBuilder.table()` for `groupBy`, because a group row is a map, not a model. On a model, `get()` with `groupBy` throws a `StateError`. `count()` with `groupBy` works on a model too, and it returns the number of groups.

### Filtering groups

`having` filters the groups. It takes the same arguments as `where`:

```dart
await QueryBuilder.table('actor')
    .selectRaw('status, count(*) as total')
    .groupBy('status')
    .having('status', '!=', 'draft')
    .orHaving('status', 'retired')
    .get();
// GROUP BY "status" HAVING "status" != @status_p0 OR "status" = @status_p1
```

For an aggregate like `count(*)`, use `havingRaw` or `orHavingRaw`. Put the values in the map, like in `whereRaw`:

```dart
await QueryBuilder.table('actor')
    .selectRaw('status, count(*) as total')
    .groupBy('status')
    .havingRaw('count(*) > @min', <String, dynamic>{'min': 5})
    .get();
```

Postgres does not allow a select alias (like `total`) in `HAVING`. So write the aggregate again, as in the example.

## Joins

### Basic joins

`join` adds the rows of another table that match. `leftJoin` and `rightJoin` work the same way:

```dart
await Actor().join('actor_info', 'actor_info.actor_id', 'actor.id').get();
// JOIN "actor_info" on "actor_info"."actor_id" = "actor"."id"

await Actor().leftJoin('actor_info', 'actor_info.actor_id', 'actor.id').get();
await Actor().rightJoin('actor_info', 'actor_info.actor_id', 'actor.id').get();
```

You can also give an operator:

```dart
// with an operator
await Actor().join('actor_info', 'actor_info.actor_id', '=', 'actor.id').get();
```

### Joins with more conditions

If a join needs more than one condition, pass a function in place of the columns. It works with `join`, `leftJoin` and `rightJoin`:

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
- The function must add at least one condition, or it throws an `ArgumentError`.

SQL reads `a OR b AND c` as `a OR (b AND c)`.

### Cross joins

`crossJoin` joins each row with each row of the other table:

```dart
await QueryBuilder.table('size').crossJoin('color').get();
// SELECT * FROM "size" CROSS JOIN "color"
```

### Raw joins

For other join conditions, use `joinRaw`, `leftJoinRaw` or `rightJoinRaw`. Nothing is quoted, and values go in the map, like in `whereRaw`:

```dart
await Actor().joinRaw('actor_info on actor_info.actor_id = actor.id').get();
await Actor().leftJoinRaw('actor_info on actor_info.actor_id = actor.id').get();
await Actor().rightJoinRaw(
  'actor_info on actor_info.actor_id = actor.id and actor_info.type = @type',
  <String, dynamic>{'type': 'main'},
).get();
```

### Subquery joins

`joinSub` and `leftJoinSub` join the rows of another query. The second argument is the name of those rows:

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

### Selecting from a subquery

`fromSub` reads from the rows of another query, not from a table. The name is also the table name of the query, so `totals.total` works in `where` and `orderBy`:

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

## Unions

`union` adds the rows of another query to the result. It drops rows that are the same. If you want to keep them, use `unionAll`, which is also faster:

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
- `orderBy`, `limit` and `offset` of the first query sort and cut the whole result. Use a plain column name in `orderBy`, not `table.column`.
- `count()`, `paginate()` and the other aggregates use the whole result.
- A union is for reading only. `update`, `delete` and the other write methods throw a `StateError` on it.

## Paginating results

### Page numbers

`paginate` returns one page of rows and the page info. It runs a `count()` query and a `get()` query:

```dart
Pagination<Actor> page = await Actor()
    .where('age', '>=', 18)
    .paginate(currentPage: 2, perPage: 10);

List<Actor> actors = page.data;
print(page.total);    // rows that match
print(page.lastPage); // number of pages
```

`page.toJson()` gives `total`, `per_page`, `last_page`, `current_page` and `data`. So you can return a `Pagination` from a controller.

### Simple pagination

If you do not need the total count, use `simplePaginate`. It runs one query, not two:

```dart
SimplePagination<Actor> page = await Actor()
    .orderBy('id')
    .simplePaginate(currentPage: 2, perPage: 10);

List<Actor> actors = page.data;
print(page.hasMorePages); // true when there is a next page
```

`page.toJson()` gives `per_page`, `current_page`, `from`, `to`, `has_more_pages` and `data`. `from` and `to` are the numbers of the first and last row of the page. They are `null` on an empty page.

### Cursor pagination

On a big table, `OFFSET` gets slow. `cursorPaginate` returns the rows after a cursor, so it stays fast. Use it for an endless list or an API:

```dart
CursorPagination<Actor> page = await Actor()
    .where('age', '>=', 18)
    .orderBy('age', 'desc')
    .cursorPaginate(perPage: 10, cursor: req.input('cursor'));

List<Actor> actors = page.data;
print(page.nextCursor); // send it back as `cursor` to read the next page
print(page.prevCursor); // send it back as `cursor` to read the page before
```

`page.toJson()` gives `per_page`, `next_cursor`, `prev_cursor` and `data`. `next_cursor` is `null` on the last page, and `prev_cursor` is `null` on the first page.

- The rows are ordered by all the `orderBy()` columns. You can mix `asc` and `desc`. With no `orderBy()`, they are ordered by the primary key.
- The order columns must be in the select, and they must have no `null` values.
- The cursor is safe to take from a user, because its values are only sent as bound values. A cursor that is not valid gives the first page.

## Chunking results

If you work on many rows, do not load them all at once. `chunk` reads a few rows at a time, so the rows do not fill the memory. The function gets one page of rows. Return `true` to go on, or `false` to stop:

```dart
await Actor().where('age', '>=', 18).chunk(100, (List<Actor> actors) {
  for (Actor actor in actors) {
    print(actor.name);
  }
  return true; // go on to the next page
});
```

`chunk` pages with `OFFSET`. So if the function changes or deletes rows, some rows can be skipped or read twice. In this case, use `chunkById`. It reads the rows after the last id:

```dart
await Actor().where('age', '>', 100).chunkById(100, (List<Actor> actors) async {
  for (Actor actor in actors) {
    await actor.delete();
  }
  return true;
});
```

`chunkById` orders by the id itself, so a query with `orderBy()` throws a `StateError`. To use another unique column, add `column: 'uuid'`.

## Streaming results

`lazy`, `lazyById` and `cursor` give the rows as a `Stream`, one row at a time. So you do not write a function, you use `await for`:

```dart
await for (Actor actor in Actor().where('age', '>=', 18).lazy()) {
  print(actor.name);
}

await for (Actor actor in Actor().orderBy('id').cursor(chunkSize: 500)) {
  print(actor.name);
}
```

| Method | Queries | How it reads |
|---|---|---|
| `lazy({chunkSize})` | many | In chunks, by id like `chunkById`. With `OFFSET` when there is an `orderBy()`, a `limit()` or an `offset()`. |
| `lazyById({chunkSize, column})` | many | In chunks, by id (or the unique `column`) like `chunkById`. |
| `cursor({chunkSize})` | one | The database sends the rows when you are ready for more. |

The default `chunkSize` is `1000`. To stop the queries, stop reading with `break` or `.take(10)`.

!!! warning
    In a transaction on Postgres or MySQL, do not run another query of the same transaction inside a `cursor()` loop. It waits forever, because the stream holds the one connection. Use `lazy()` there.

## Inserting rows

### Inserting one row

`create` inserts one row and returns it as it is in the table, with the column defaults too. `insert` does the same. On a model, the result is the model. On `QueryBuilder.table(...)`, it is a map:

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

- It works with any primary key type, for example a uuid string.
- On a model with [events](model/events.md), `create` calls `save()`, so the hooks run.
- On a model without events, `create` does not set `created_at` and `updated_at`. Put them in the map, or use `save()`.

### Getting the new id

If you only need the new id, use `insertGetId`. It returns the auto increment id, or the id in the map when the table has no auto increment:

```dart
dynamic id = await QueryBuilder.table('actor').insertGetId(<String, dynamic>{
  'name': 'John Wick',
});
```

### Inserting many rows

`insertMultiple` inserts many rows in one query. It does not return models, it returns the new ids:

```dart
await Actor().insertMultiple(<Map<String, dynamic>>[
  <String, dynamic>{'name': 'John Wick', 'age': 60},
  <String, dynamic>{'name': 'John Doe', 'age': 25},
]);
```

- On Postgres and SQLite, you get one map per row, like `[{id: 4}, {id: 5}]`.
- On MySQL and MariaDB, you get one map with the first id, like `[{id: 4}]`. It is an empty list when the table has no auto increment id.

The columns are the keys from all rows. When a row does not have a key, that column gets its default value.

`insertMany` inserts many rows, reads nothing back and returns `true`. Because it reads nothing back, it works on a table with no `id` column, like a pivot table:

```dart
await QueryBuilder.table('actor_movie').insertMany(<Map<String, dynamic>>[
  <String, dynamic>{'actor_id': 1, 'movie_id': 2},
  <String, dynamic>{'actor_id': 1, 'movie_id': 3},
]);
```

`insertGetId`, `insertMultiple` and `insertMany` fire no model events and set no timestamps. On a model, the keys that `fillable` and `guarded` do not allow are dropped.

### Upserts

`upsert` inserts rows, or updates the row that is already there. It runs one query and returns the number of changed rows:

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

- The second list is the columns that find the old row. They must be the primary key or a unique index.
- The third list is the columns to update. Leave it out to update every other column. An empty list keeps the old row as it is.
- Every row must have the same keys. Otherwise it throws an `ArgumentError`.
- On a model, keys that `fillable` and `guarded` do not allow are dropped. A model with no `fillable` throws, see [mass assignment](model/index.md#mass-assignment). `created_at` and `updated_at` are set, and an update does not change `created_at`.
- It fires no [model events](model/events.md).

### Ignoring duplicate rows

`insertOrIgnore` inserts rows and skips the rows that clash with a unique key. It returns the number of inserted rows:

```dart
int added = await QueryBuilder.table('tag').insertOrIgnore(<Map<String, dynamic>>[
  <String, dynamic>{'name': 'action'},
  <String, dynamic>{'name': 'drama'},
]);
```

It has the same rules as `upsert`: every row has the same keys, `fillable` applies on a model, and no model events fire.

### Finding or creating a row

Often you want to find a row, and create it when it is not there. These methods do this. The first map finds the row, and the second map has the other values:

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

### Updating or inserting rows

`updateOrInsert` updates the rows that match the first map with the second map. When no row matches, it inserts one row from both maps. Unlike `updateOrCreate`, it does not read the row back:

```dart
await QueryBuilder.table('setting').updateOrInsert(
  <String, dynamic>{'key': 'theme'},
  <String, dynamic>{'value': 'dark'},
);
```

- It updates every row that matches the first map, not only one.
- It returns `true` when it inserted a row, or when the update changed a row.
- An empty first map throws an `ArgumentError`, so it can never update every row by mistake.

Two calls at the same time can both insert a row, so add a unique index when this matters.

## Updating rows

### Updating many rows

`update` changes all rows that match the `where` part. It returns the number of changed rows:

```dart
int count = await Actor()
    .where('id', 3)
    .where('status', 'active')
    .update(<String, dynamic>{'name': 'Updated AJ', 'age': 120});
// UPDATE "actor" SET "name" = @name_p2,"age" = @age_p3
//   WHERE "id" = @id_p0 AND "status" = @status_p1
```

On a model, keys that `fillable` and `guarded` do not allow are dropped. A model with no `fillable` throws, see [mass assignment](model/index.md#mass-assignment). To set every key of the map, use `forceUpdate()`, see [skip the fillable check](model/index.md#skip-the-fillable-check).

!!! warning
    On a model, `update` needs a `where` (or a global scope).
    `Actor().update({...})` with no `where` throws a `StateError` and runs no query.
    To change every row on purpose, see [Writing every row](#writing-every-row).

A query `update` does not set `updated_at` and fires no [model events](model/events.md). If you need them, load the model, change it and call `save()`.

### Incrementing and decrementing

`increment` and `decrement` add to (or take from) a number column in one query. The amount is 1 when you give none. They return the number of changed rows:

```dart
await Actor().where('id', 1).increment('views');
// UPDATE "actor" SET "views" = "views" + @views_p1 WHERE "id" = @id_p0

await Actor().where('id', 1).increment('views', 5);
await Actor().where('id', 1).decrement('views', 2);
```

You can set other columns in the same query:

```dart
// set other columns in the same query
await Actor().where('id', 1).increment('views', 1, <String, dynamic>{'status': 'hot'});
```

Like `update`, they need a `where` on a model, they do not set `updated_at`, and they fire no model events.

On a model from the table, they change only the row of that model, and the field of the model gets the new value too. This example has an `int? views` column field on `Actor`:

```dart
Actor? actor = await Actor().find(1);
await actor!.increment('views');
print(actor.views); // the new value
```

`update` on a model from the table also changes only that row: `await actor!.update({'name': 'AJ'})`. It runs one query and fires no model events. Use `save()` for the events.

### Touching timestamps

`touch` sets `updated_at` of the rows to now. Give a column name to set another column. It returns the number of changed rows:

```dart
await Actor().where('name', 'John Wick').touch();
await Actor().where('id', 1).touch('seen_at');
```

On a query, `touch` fires no model events. On a model from the table, it changes only the row of that model, see [Models](model/index.md#touch-and-replicate).

## Deleting rows

`delete` removes all rows that match the `where` part. It returns the number of deleted rows:

```dart
int count = await Actor().where('name', 'John Wick').delete();
// DELETE FROM "actor" WHERE "name" = @name_p0
```

On a model with `softDelete: true`, `delete` sets `deleted_at` and keeps the row.

!!! warning
    On a model, `delete` needs a `where`, a global scope, or a model from the table with its primary key.
    `Actor().delete()` with no `where` throws a `StateError` and runs no query, so it can not delete every row by mistake.
    To delete every row on purpose, see [Writing every row](#writing-every-row).

### Deleting soft deleted rows for good

On a model with `softDelete: true`, `forceDelete` really deletes the rows. It also deletes rows that are already soft deleted, so you do not need `withTrash()`. It returns the number of deleted rows:

```dart
int count = await Actor().where('name', 'John Wick').forceDelete();
```

### Including soft deleted rows

A model with `softDelete: true` hides soft deleted rows. If you want to see them too, use `withTrash`:

```dart
List<Actor> actors = await Actor().withTrash().where('name', 'John Wick').get();
```

`onlyTrashed` gives only the soft deleted rows. On a model without soft deletes, it throws a `StateError`:

```dart
List<Actor> trashed = await Actor().onlyTrashed().get();

// delete the soft deleted rows for good
await Actor().onlyTrashed().forceDelete();
```

### Restoring soft deleted rows

`restore` sets `deleted_at` back to `NULL` for every soft deleted row of the query. It returns `true` when it changed a row:

```dart
bool restored = await Blog().withTrash().where('status', 'old').restore();
```

It also sets `updated_at` when the model has timestamps. It fires no model events. With no `where`, it throws a `StateError`, so it can not restore every row by mistake.

### Writing every row

On a model, `delete`, `forceDelete`, `update`, `increment`, `decrement` and `touch` with no `where` throw a `StateError`. If you really want to write every row, use `whereRaw('1 = 1')`. It keeps soft deletes and global scopes:

```dart
await Actor().whereRaw('1 = 1').update(<String, dynamic>{'status': 'old'});
await Actor().whereRaw('1 = 1').delete();
```

!!! warning
    `QueryBuilder.table('actor').delete()` and `truncate` are not the same as a model delete.
    They skip soft deletes, so they really delete the rows. They also skip global scopes and `fillable`.

### Truncating a table

`truncate` deletes all rows of the table and resets the id counter:

```dart
await Actor().truncate();
await Actor().truncate(resetId: false); // keep the id counter on Postgres and SQLite
```

On Postgres, `truncate` runs `CASCADE`. So it also empties every table with a foreign key to this table.

## Locking rows

Sometimes two requests change the same row at the same time. `lockForUpdate` and `sharedLock` lock the rows that a select reads, so the other request waits. Use them inside a transaction. See [Row locks](transactions.md#row-locks).

```dart
await QueryBuilder.transaction(() async {
  Actor actor = await Actor().lockForUpdate().findOrFail(1);
  actor.age = actor.age! + 1;
  await actor.save();
});
```

## Cancelling a query

Sometimes a slow query is no longer needed, for example when the user closed the page. Give a `QueryCancelToken` to the query with `cancelWith`. Then `token.cancel()` stops the query on Postgres and MySQL:

```dart
QueryCancelToken token = QueryCancelToken();
Future<List<Actor>> actors = Actor().where('age', '>', 18).cancelWith(token).get();

token.cancel();
try {
  await actors;
} on PgQueryCancelledException {
  // Postgres: the query was stopped
} on MysqlQueryCancelledException {
  // MySQL: the query was stopped
}
```

The relation queries of `preload()` and `cursor()` use the token too. SQLite does not support cancel, so there the query runs to its end.

## Debugging

### Showing the SQL

`toSql` returns the SQL of the query with the values filled in. The values are not quoted or escaped, so use it only to read the query:

```dart
String sql = Actor().where('name', 'John Wick').toSql();
print(sql); // SELECT * FROM "actor" WHERE "name" = John Wick
```

`toRawSql` returns the SQL with each value quoted for the database. Use it for logs and debugging, but run queries with bound values, not with this text:

```dart
String sql = Actor().where('name', "it's").toRawSql();
print(sql); // SELECT * FROM "actor" WHERE "name" = 'it''s'
```

### Printing queries

`debug` prints the SQL and the values of the query when it runs:

```dart
await Actor().debug(true).where('age', 60).get();
```

With the default `PrettyQueryPrinter`, it prints one line:

```
▌ [db:default] SELECT * FROM "actor" WHERE "age" = 60;
```

To print all queries, set `debug: true` in the `ConnectionConfig`. See [Database](index.md#configuration).

## Details

This section is for special cases. Most apps do not need it.

### Retrieving

- `ModelNotFoundException` has the `table`. From `findOrFail`, it also has the `column` and the `id` it looked for.
- `sole` reads 2 rows at most.
- There is no `exists()` on a query, because a model has the `exists` getter (it tells if that one model is saved). Use `hasRows()`.
- There is no `value()`, because `value` is a common column name. Use `valueOf`.
- `pluck` and `pluckMap` use `where`, `join`, `orderBy`, `limit` and `distinct`. A date comes back as an ISO string.

### Aggregate details

- With `distinct()`, `count()` returns the number of distinct rows, and `sum()` and `avg()` use only the distinct values.
- When no row matches, `sum()` is `null`. The [`sumReturnsZero` flag](index.md#orm-flags) makes it `0`.
- `avg()` returns a `double`. `min()` and `max()` return the value as the driver gives it: a date is an ISO string, a Postgres `numeric` is a `String`, and a MySQL `DECIMAL` is a `double`.
- `sum`, `avg`, `min` and `max` throw a `StateError` with `groupBy()`. Use `selectRaw()` and `get()` for groups.

### Where clauses

- Any operator other than `=`, `!=` or `<>` with a `null` value throws an `ArgumentError`. `where('name')` with no value throws too.
- In `whereGroup`, add only `where` conditions. The function gets the same query, so an `orderBy()` there is for the whole query. An empty group adds nothing.
- A row with `NULL` in a column of a `whereNot` bracket matches neither the bracket nor `NOT` of it. This is how SQL works with `NULL`.
- An empty list in `whereAny` or `whereAll` adds nothing.
- On Postgres, a `whereIn` list of only `int` or only `String` values is sent as one array parameter: `"id" = ANY(@id_p0)` (`<> ALL` for `whereNotIn`).
- A sub query is built when it is added. A change to it later is not used. This is the same for `joinSub`, `fromSub` and `union`.
- MySQL and MariaDB do not allow `LIMIT` in an `IN (sub query)`.
- `whereLike` is `ILIKE` on Postgres. On MySQL and MariaDB, the column collation decides, and the default collations do not care about case. On SQLite it ignores case for ASCII letters only. With `caseSensitive: true`, it is `LIKE` on Postgres, `LIKE BINARY` on MySQL and `GLOB` on SQLite (Dox changes the pattern for you).

### Dates and time zones

- On SQLite, a `whereDate` or `whereTime` string must be zero padded, like `2024-05-01` or `09:00:00`. A value like `2024-5-1` matches no row.
- The column is read as it is stored. On SQLite and Postgres, Dox stores a `DateTime` in UTC.
- A `DateTime` value is compared the same way `where` binds it: in UTC on SQLite and Postgres, and as the wall clock on MySQL and MariaDB.
- On Postgres, a `timestamptz` is read in the session time zone (UTC by default). If the connection sets another `timeZone`, a `DateTime` value does not match.
- On Postgres, a column with fractions of a second does not equal a time without them. For example, `10:00:00.5` is not `10:00:00`.

### JSON

- In `where`, a number or a bool value works the same on every database. On Postgres, the other methods compare the value as text. So `whereBetween` and `whereIn` on a JSON key compare text there, and `sum` and `avg` fail. Use `selectRaw` with a cast for them.
- `where('options->lang', null)` and `whereNull('options->lang')` match a missing key. On SQLite and Postgres they also match a JSON `null`. On MySQL and MariaDB they do not.
- On SQLite, and in `where` on Postgres, the number `5` does not match the string `"5"`. MySQL and MariaDB compare them as numbers, so `5` matches `"5"` there.
- On SQLite, `whereJsonContains` also matches a value inside a JSON object, one level down. The value must be a string, a number, a bool or a list of them. A map throws an `ArgumentError`. SQLite stores `true` as `1`, so `true`, `1` and `1.0` match each other there.
- `whereJsonDoesntContain` on a row that does not have the key: SQLite and MariaDB keep the row, Postgres and MySQL drop it.

### Select, order and group

- `selectRaw()` replaces the select list. The [`selectRawAdds` flag](index.md#orm-flags) makes it add to the list.
- `selectRaw` value names must be unique in the query, and may not start with `dox_`. Otherwise it throws an `ArgumentError`.
- A direction other than `asc` or `desc`, or a column that is not a plain name, throws an `ArgumentError` in `orderBy`.
- `inRandomOrder()` is `RANDOM()` on Postgres and SQLite, and `RAND()` on MySQL.
- `limit` and `offset` numbers are sent as bound parameters.
- A second `groupBy()` replaces the first. The [`groupByAdds` flag](index.md#orm-flags) makes it add to the first.
- SQLite before 3.39 has no `RIGHT JOIN`.

### Union details

- The added query can have its own `orderBy` and `limit`.
- `sum()`, `avg()`, `min()` and `max()` on a union keep `orderBy`, `limit` and `offset`. `count()` does not.
- `cursorPaginate()` and `chunkById()` do not work on a union or a `fromSub` query. They throw a `StateError`. Use `paginate()`, `simplePaginate()` or `chunk()`.
- `update`, `delete`, `forceDelete`, `increment`, `decrement`, `touch` and `all()` throw a `StateError` on a union, because they would use only the first query.

### Pagination

- `perPage` must be 1 or more. A smaller value throws an `ArgumentError`. A `currentPage` below 1 is read as page 1.
- With no rows, `lastPage` is `0`. The [`lastPageAtLeastOne` flag](index.md#orm-flags) makes it `1`.
- `simplePaginate` reads one row more to know if there is a next page.
- `cursorPaginate` can also take `column` and `direction` in place of `orderBy()`: `cursorPaginate(perPage: 10, column: 'created_at', direction: 'desc')`. Using both throws a `StateError`, and so do `orderByRaw()` and `inRandomOrder()`.
- `cursorPaginate` adds the primary key as the last order column, so rows with the same value are never skipped.
- A changed cursor with a value of the wrong kind, like a text for a number column, also gives the first page.

### Chunking and streaming

- After a stop, `chunk()` returns `false`. Otherwise it returns `true`. Without `orderBy()`, it orders by the primary key.
- `lazyById` throws a `StateError` with an `orderBy()`, like `chunkById`.
- `lazy()` starts at the `offset()` of the query and stops after its `limit()`. It works on every database, and also on a `union` or a `fromSub` query.
- `cursor()` does not fill the memory with a big result. Postgres uses a server-side portal, MySQL sends the rows as they come, and SQLite uses a statement cursor.
- Relations of `preload()` load for each chunk. In a transaction on Postgres or MySQL, `cursor()` with `preload()` throws a `StateError`. Use `lazy()` there.
- Query listeners and the [slow query log](index.md#slow-query-log) see a `cursor()` query once, when its first chunk comes. The time is the time to the first chunk.

### Writing

- On MySQL, `create` reads the new row again by its id. When the table has no auto increment id and the map has no id (for example a pivot table), the result is made from the map you gave.
- `insertMany` with an empty list runs no query.
- `upsert` counts 1 for each new or updated row on Postgres and SQLite (`ON CONFLICT ... DO UPDATE`). On MySQL and MariaDB (`ON DUPLICATE KEY UPDATE`), it counts 1 for each new row, 2 for each updated row and 0 for a row that did not change.
- MySQL and MariaDB do not use the unique columns you give to `upsert`. Any unique index of the table can find the old row. Postgres throws when two rows of one call have the same unique values.
- `insertOrIgnore` is `ON CONFLICT DO NOTHING` on Postgres. On SQLite it is `INSERT OR IGNORE`, which also skips rows that break a `NOT NULL` or `CHECK` rule. On MySQL and MariaDB it is `INSERT IGNORE`, which turns some bad values into a warning, for example text that is too long is cut.
- On a model, `updateOrInsert` uses the model's `insert()` and `update()`. The insert is a `create()`, so the create events run and the timestamps are set. The update fires no events and does not set `updated_at`. Soft deleted rows do not match, so a soft deleted match gives a new row.
- `update` with an empty map, or with no key left after `fillable`, runs no query and returns 0.
- Postgres and SQLite count every row that the `where` part matched. MySQL and MariaDB count only the rows that really changed, so a row that already has the new values counts 0. This also applies to `updateOrInsert` and `touch` (within the same second).
- A `NULL` column stays `NULL` after `increment`, like in SQL.
- A model read without its primary key (like after `select('name')`) throws on `delete`. `delete` does not count rows that are already soft deleted.
- `truncate` runs `TRUNCATE TABLE ... RESTART IDENTITY CASCADE` on Postgres and `TRUNCATE TABLE` on MySQL (which always resets the id counter). On SQLite it runs `DELETE FROM`.

### Other cases

- A token that is cancelled already fails a new query at once.
- A custom `DBDriver` must override `affectingStatement()`. It runs an `UPDATE`, `DELETE` or `INSERT` and returns the number of changed rows. `update()`, `delete()`, `increment()` and `upsert()` use it. The default throws an `UnsupportedError`.

## See also

- [Transactions](transactions.md): run many queries as one unit.
- [Model](model/index.md): work with rows as objects.
- [Pagination](../guides/pagination.md): a list route with pages.
