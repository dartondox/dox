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

## Row locks

A row lock stops two requests from changing the same row at the same time.

Think of a stock count. Two requests read `stock = 5` at the same time.
Each one takes 1 and saves `4`. The right value is `3`.
A lock makes the second request wait until the first one is done.

```dart
Future<void> buy(int productId, int quantity) async {
  await QueryBuilder.transaction(() async {
    // read the row and lock it
    Product product = await Product().lockForUpdate().findOrFail(productId);

    if (product.stock! < quantity) {
      throw BadRequestException(message: 'Not enough stock');
    }

    // change it and save it while the lock is held
    product.stock = product.stock! - quantity;
    await product.save();
  });
  // the lock ends here, when the transaction commits
}
```

- `lockForUpdate()` adds `FOR UPDATE` to the select.
  Other transactions that lock or change these rows wait.
- `sharedLock()` adds a shared lock.
  Other transactions can still read the rows, but they wait to change them.
- Use them with `find()`, `findOrFail()`, `getFirst()`, `firstOrFail()`, `get()`, `all()` and `pluck()`.
- `count()`, `sum()` and the other aggregates do not lock.

| Database | `lockForUpdate()` | `sharedLock()` |
| --- | --- | --- |
| Postgres | `FOR UPDATE` | `FOR SHARE` |
| MySQL, MariaDB | `FOR UPDATE` | `LOCK IN SHARE MODE` |
| SQLite | nothing | nothing |

!!! warning "Use a lock only inside a transaction"
    A lock lasts until the transaction ends.
    Outside a transaction, each query commits right away, so the lock ends at once.

SQLite has no row locks, so the lock does nothing there.
But a Dox transaction on SQLite starts with `BEGIN IMMEDIATE`.
It takes the write lock of the whole database.
So the same code is safe on SQLite too.

!!! note
    Postgres does not allow a lock with `groupBy()`, `distinct()`,
    or on the nullable side of a left join. The database throws an error then.

For one number column, [`increment()`](query-builder.md#increment-and-decrement) is simpler.
It changes the value in one query, so it needs no lock.

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
