---
icon: lucide/arrow-left-right
---

# Transactions

A transaction runs many queries as one unit, so either all of them are saved or none of them.

`QueryBuilder.transaction()` takes a function:

- It commits when the function ends.
- It rolls back when the function throws. Then the error is thrown again.

## Use

```dart
// a transaction
await QueryBuilder.transaction(() async {
  Actor actor = Actor();
  actor.name = 'John Wick';
  await actor.save();
  await QueryBuilder.table('actor_info').insert(<String, dynamic>{
    'actor_id': actor.id,
  });
});

// return a value
int? id = await QueryBuilder.transaction(() async {
  Actor actor = Actor();
  actor.name = 'John Wick';
  await actor.save();
  return actor.id;
});

// on another connection
await QueryBuilder.transaction(() async {
  // ...
}, connection: 'mysql');
```

- All queries and models inside the function use the transaction.
  You do not pass a transaction object around.
- A transaction inside another transaction uses a savepoint.
  See [Nested transactions](#nested-transactions).

!!! warning "MySQL"
    On MySQL and MariaDB, `CREATE`, `ALTER` and `DROP TABLE` are saved right away.
    A rollback can not undo them.

## Nested transactions

A transaction inside another transaction uses a savepoint.
It runs on the same connection as the outer one.

- When the inner function ends, its work stays in the outer transaction.
  It is saved when the outer one commits.
- When the inner function throws, only its work is undone. Then the error is thrown again.
- If you catch that error, the outer transaction goes on and can still commit.
- If you do not catch it, the outer transaction rolls back too.
- When the outer transaction rolls back, the inner work is undone too.

```dart
await QueryBuilder.transaction(() async {
  await Actor().create(<String, dynamic>{'name': 'John Wick'});
  try {
    await QueryBuilder.transaction(() async {
      await Actor().create(<String, dynamic>{'name': 'Bad row'});
      throw StateError('stop');
    });
  } on StateError {
    // only 'Bad row' is undone
  }
});
// 'John Wick' is saved
```

This works on Postgres, MySQL, MariaDB and SQLite. You can nest many levels.

- Run nested transactions one after another, not at the same time (for example in `Future.wait`).
  They share one connection.
- On MySQL and MariaDB, a `CREATE`, `ALTER` or `DROP TABLE` inside a nested transaction
  saves the outer work and ends the savepoint. Do not change the schema there.

## Connections

- Postgres and MySQL use a connection pool.
  Set the size with `maxConnectionCount` in the `extra` map of the connection.
- A transaction uses one connection of the pool. Other queries use the other connections.
- SQLite has one connection per isolate.
  While a transaction is open, the other queries of that isolate wait.
- When a model has more than one relation to load (`preload` or `eager`),
  the relation queries run at the same time outside a transaction.
  Inside a transaction, they run one after another on its connection.
- A query runs in a transaction only when you use `QueryBuilder.transaction()`.
