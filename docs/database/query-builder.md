# Query Builder

Query Builder provides a user-friendly interface where users can define the criteria and parameters for database queries without needing to write the SQL code manually. Query builders are commonly used in database management systems and data analysis tools to streamline the query creation process, making it more accessible to users who may not be proficient in writing SQL queries.

### `create`

=== "Create"

    ```dart
    await Actor().create(
        {'name': 'John Wick', 'age': 60}
    );
    ```

### `insert`

=== "Insert"

    ```dart
    await Actor().insert(
        {'name': 'John Wick', 'age': 60}
    );
    ```

=== "Multiple insert"

    ```dart
    await Actor().insertMultiple([
        {'name': 'John Wick', 'age': 60},
        {'name': 'John Doe', 'age': 25},
    ]);
    ```

### `update`

=== "Update rows"

    ```dart
    await Actor()
        .where('id', 3)
        .where('status', 'active')
        .update({
            "name": "Updated AJ",
            "age": 120,
        });
    ```

### `count`

=== "Count all"

    ```dart
    await Actor().count();
    ```

=== "Count with condition"

    ```dart
    await Actor().where('age', '>=' , 23).count();
    ```

### `find`

=== "Find by id"

    ```dart
    await Actor().find(id);
    ```

=== "Find by custom column"

    ```dart
    await Actor().find('name', 'John Wick');
    ```

### `getFirst`

=== "Get first row"

    ```dart
    Actor actor = await Actor().getFirst(); // limit = 1
    ```

### `all`

=== "Ge all rows"

    ```dart
    List<Actor> actors = await Actor().all();
    for(Actor actor in actors) {
        print(actor.id)
    }
    ```

### `get`

=== "Get"

    ```dart
    List<Actor> actors = await Actor().where('name', 'John Wick').get();
        for(Actor actor in actors) {
        print(actor.id)
    }
    ```

### `toSql`

=== "To SQL query"

    ```dart
    String query = Actor().where('name', 'John Wick').toSql();
    print(query)
    ```

### `delete`

=== "Delete a row"

    ```dart
    await Actor().where('name', 'John Wick').delete();
    ```

### `forceDelete`

=== "Force delete"

    ```dart
    await Actor().where('name', 'John Wick').forceDelete();
    ```

!!! info
    This work only with softDeletes.

### `withTrash`

=== "Get from trash"

    ```dart
    List actors = await Actor().where('name', 'John Wick').withTrash().get();
    for(Actor actor in actors) {
        print(actor.id)
    }
    ```

!!! info
    This work only with softDeletes.


### `select`

=== "Multiple select"

    ```dart
    await Actor()
        .select('id')
        .select('name')
        .where('name', 'John Wick').get();
    ```

=== "Select with array of columns"

    ```dart
    await Actor()
        .select(['id', 'name', 'age']).where('name', 'John Wick').get();
    ```

=== "Select with comma separated columns"

    ```dart
    await Actor()
        .select('id, name, age').where('name', 'John Wick').get();
    ```

### `whereIn`

=== "Where in condition"

    ```dart
    await Actor().whereIn('id', ['1', '2']).get();
    ```

### `where`

=== "where"

    ```dart
    await Actor().where('name', 'John Wick').get();
    ```

=== "Where with custom condition"

    ```dart
    await Actor().where('name', '=', 'John Wick').get();
    await Actor().where('age', '>=', 23).get();
    ```

### `orWhere`

=== "orWhere"

    ```dart
    await Actor().orWhere('name', 'John Wick').get();
    ```

=== "orWhere with custom condition"

    ```dart
    await Actor().orWhere('name', '=', 'John Wick').get();
    await Actor().orWhere('age', '>=', 23).get();
    ```

=== "where and orWhere"

    ```dart
    await Actor()
    .where('name', 'John Doe').orWhere('name', 'John Wick').get();
    ```

### `whereRaw`

=== "whereRaw"

    ```dart
    await Actor().whereRaw('name = @name', {'name', 'John Wick'}).get();
    ```

### `orWhereRaw`

=== "Or where raw"

    ```dart
    await Actor().orWhereRaw('name = @name', {'name', 'John Wick'}).get();
    ```

### `limit`, `take`, `offset`

=== "Limit"

    ```dart
    await Actor().limit(10).get();
    ```

=== "Take"

    ```dart
    await Actor().take(10).get();
    ```

=== "offset"

    ```dart
    await Actor().limit(10).offset(10).get();
    ```

!!! info
    Limit and take are the same function.

### `groupBy`

=== "Group by"

    ```dart
    await Actor()
        .select('count(*) as total, name').groupBy('name').get();
    ```

### `orderBy`

=== "default"

    ```dart
    await Actor().orderBy('name').get();
    ```

=== "desc"

    ```dart
    await Actor().orderBy('name', 'desc').get();
    ```

=== "asc"

    ```dart
    await Actor().orderBy('name', 'desc').get();
    ```

=== "multiple columns"

    ```dart
    await Actor()
        .orderBy('name', 'asc')
        .orderBy('id', 'desc')
        .get();
    ```


### `join`

=== "Join"

    ```dart
    await Actor()
        .join('actor_info', 'actor_info.admin_id', 'admin.id')
        .get();
    ```

### `leftJoin`

=== "Left join"

    ```dart
    await Actor()
        .leftJoin('actor_info', 'actor_info.admin_id', 'admin.id')
        .get();
    ```

### `rightJoin`

=== "Right join"

    ```dart
    await Actor()
        .rightJoin('actor_info', 'actor_info.admin_id', 'admin.id')
        .get();
    ```

### `joinRaw`

=== "Join raw"

    ```dart
    await Actor()
        .joinRaw('actor_info on actor_info.admin_id = admin.id')
        .get();
    ```

### `leftJoinRaw`

=== "Left join raw"

    ```dart
    await Actor()
        .leftJoinRaw('actor_info on actor_info.admin_id = admin.id')
        .get();
    ```

### `rightJoinRaw`

=== "Right Join Raw"

    ```dart
    await Actor()
        .rightJoinRaw('actor_info on actor_info.admin_id = admin.id')
        .get();
    ```

### `debug`

=== "Debug"

    ```dart
    await Actor().debug(true).all();
    ```