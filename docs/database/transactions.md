# Transactions

A transaction runs many queries as one unit. Either all of them are saved, or none of them.

`QueryBuilder.transaction()` takes a function:

- It commits when the function ends.
- It rolls back when the function throws. Then the error is thrown again.

## Use

=== "Transaction"

    ```dart
    await QueryBuilder.transaction(() async {
      Actor actor = Actor();
      actor.name = 'John Wick';
      await actor.save();
      await QueryBuilder.table('actor_info').insert(<String, dynamic>{
        'actor_id': actor.id,
      });
    });
    ```

=== "Return a value"

    ```dart
    int? id = await QueryBuilder.transaction(() async {
      Actor actor = Actor();
      actor.name = 'John Wick';
      await actor.save();
      return actor.id;
    });
    ```

=== "Other connection"

    ```dart
    await QueryBuilder.transaction(() async {
      // ...
    }, connection: 'mysql');
    ```

- All queries and models inside the function use the transaction.
  You do not pass a transaction object around.
- A transaction inside another transaction joins the outer one.
  There are no savepoints. If the inner one throws, the whole outer transaction rolls back.

!!! warning "MySQL"
    On MySQL and MariaDB, `CREATE`, `ALTER` and `DROP TABLE` are saved right away.
    A rollback can not undo them.

## Connections

- Postgres and MySQL use a connection pool.
  Set the size with `maxConnectionCount` in the `extra` map of the connection.
- A transaction uses one connection of the pool. Other queries use the other connections.
- SQLite has one connection per isolate.
  While a transaction is open, the other queries of that isolate wait.
- Values are always sent as bound parameters. They are never written into the SQL text.

!!! note "Changed in 3.x"
    Before 3.x, Postgres ran every query in its own transaction.
    Now a query only runs in a transaction when you use `QueryBuilder.transaction()`.
