---
icon: lucide/arrow-left-right
---

# Transactions

A transaction runs many queries as one unit, so either all of them are saved or none of them.

You need a transaction when some changes only make sense together. For example, you create an order and take the items out of stock. If one step fails, you do not want the other one saved.

## Running a transaction

Pass a function to `QueryBuilder.transaction()`. When the function ends, the transaction commits. When the function throws, the transaction rolls back, and the error is thrown again:

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

All queries and models inside the function use the transaction. You do not pass a transaction object around.

The function can return a value:

```dart
int? id = await QueryBuilder.transaction(() async {
  Actor actor = Actor();
  actor.name = 'John Wick';
  await actor.save();
  return actor.id;
});
```

To use a named connection, pass `connection`:

```dart
await QueryBuilder.transaction(() async {
  // ...
}, connection: 'mysql');
```

On MySQL and MariaDB, `CREATE`, `ALTER` and `DROP TABLE` are saved right away, so a rollback can not undo them.

## Nested transactions

Sometimes one part of the work may fail, and you still want to keep the rest. A transaction inside another transaction uses a savepoint, so if the inner function throws, only its work is undone:

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

If you catch the error, the outer transaction goes on and can still commit. If you do not catch it, the outer transaction rolls back too. The inner work is saved only when the outer transaction commits.

This works on Postgres, MySQL, MariaDB and SQLite, and you can nest many levels. Run nested transactions one after another, not at the same time (for example in `Future.wait`), because they share one connection.

## Handling deadlocks

Two transactions can wait for each other's rows. The database then stops one of them with a deadlock error. Often one more run works, so `attempts` runs the whole function again, up to that many runs in all:

```dart
await QueryBuilder.transaction(() async {
  // ...
}, attempts: 3);
```

It runs again only on a deadlock or a lock / serialization failure. Other errors are thrown at once. When the last run fails too, its error is thrown. The default is `1`, so one run and no retry.

The function runs again from the start. So keep work that is not in the database, like a mail or a call to another service, out of it. Or put that work in [`afterCommit()`](#run-code-after-the-commit).

## Begin and commit by hand

`QueryBuilder.transaction()` is the simple way, so use it when you can. If the work can not fit in one function, begin the transaction by hand:

```dart
DatabaseTransaction tx = await QueryBuilder.beginTransaction();
try {
  await tx.run(() async {
    User user = await User().create(<String, dynamic>{'email': email});
    await QueryBuilder.afterCommit(() => sendWelcomeMail(user));
  });
  await tx.run(() => QueryBuilder.table('audit').insert(<String, dynamic>{'event': 'signup'}));
  await tx.commit();
} finally {
  await tx.rollBack(); // does nothing after commit
}
```

- Only code inside `tx.run()` uses the transaction. Other queries, and queries of other requests, never join it.
- Await each `run()` before `commit()`.
- `commit()` saves the work, then runs the `afterCommit()` functions. It throws a `StateError` if the transaction is already closed.
- `rollBack()` undoes the work. It does nothing if the transaction is already closed, so it is safe in a `finally`.
- `tx.isOpen` is `true` until `commit()`, `rollBack()` or the timeout.
- `connection:` picks a named connection, like in `transaction()`.

The transaction holds one connection until you close it. If it is still open after `timeout` (default 1 minute), it is rolled back so the connection is free again. After that, `run()` and `commit()` throw a `StateError` and the work is lost. You can set your own timeout:

```dart
QueryBuilder.beginTransaction(timeout: const Duration(seconds: 10))
```

On Postgres, a database error inside `run()` breaks the whole transaction, so call `rollBack()` then. A `commit()` saves nothing and gives no error, because the server answers COMMIT with ROLLBACK. A plain `QueryBuilder.transaction()` works the same way if you catch a database error inside it.

## Run code after the commit

Some work must only happen when the data is saved, like sending a mail or a queue job. `QueryBuilder.afterCommit()` runs a function after the transaction commits:

```dart
await QueryBuilder.transaction(() async {
  User user = await User().create(<String, dynamic>{'email': email});
  await QueryBuilder.afterCommit(() => sendWelcomeMail(user));
});
```

- The function runs after the outermost transaction commits, so the data is saved and other connections can see it.
- If the transaction rolls back, the function does not run.
- Outside a transaction, the function runs at once.
- The functions run one by one, in the order you added them. They can be async, and the `QueryBuilder.transaction()` call waits for them.

If a function throws, the data stays saved and the other functions still run. Then the `QueryBuilder.transaction()` call throws the first error.

To wait for a transaction of a named connection, pass the same `connection:`:

```dart
await QueryBuilder.afterCommit(() => notify(order), connection: 'mysql');
```

[Queue jobs](../digging-deeper/queue.md#dispatching-after-the-commit) use this with `dispatch(afterCommit: true)`.

## Row locks

A row lock stops two requests from changing the same row at the same time.

Think of a stock count. Two requests read `stock = 5` at the same time. Each one takes 1 and saves `4`, but the right value is `3`. A lock makes the second request wait until the first one is done. This example has an `int? stock` column field on a `Product` model:

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

`lockForUpdate()` adds `FOR UPDATE` to the select, so other transactions that lock or change these rows wait. `sharedLock()` adds a shared lock: other transactions can still read the rows, but they wait to change them.

Use a lock only inside a transaction. A lock lasts until the transaction ends, and outside a transaction each query commits right away, so the lock ends at once.

Locks work with `find()`, `findOrFail()`, `getFirst()`, `firstOrFail()`, `get()`, `all()` and `pluck()`. `count()`, `sum()` and the other aggregates do not lock.

| Database | `lockForUpdate()` | `sharedLock()` |
| --- | --- | --- |
| Postgres | `FOR UPDATE` | `FOR SHARE` |
| MySQL, MariaDB | `FOR UPDATE` | `LOCK IN SHARE MODE` |
| SQLite | nothing | nothing |

SQLite has no row locks. But a Dox transaction on SQLite starts with `BEGIN IMMEDIATE`, which takes the write lock of the whole database. So the same code is safe on SQLite too.

For one number column, [`increment()`](query-builder.md#incrementing-and-decrementing) is simpler. It changes the value in one query, so it needs no lock.

## Details

This section is for special cases. Most apps do not need it.

### Deadlock retries

- There is no wait between the runs. `0` and below also run once.
- Only the outermost transaction runs again. A nested transaction gives the error to the outer one.
- `afterCommit()` functions of a failed run are dropped. An error after the commit (for example in an `afterCommit()` function) never runs it again.
- `DatabaseTransaction.isConcurrencyError(error)` tells you if an error counts, for your own checks. These errors count:

| Database | Errors |
| --- | --- |
| Postgres | SQLSTATE `40001` (serialization failure), `40P01` (deadlock) |
| MySQL, MariaDB | error `1213` (deadlock), `1205` (lock wait timeout), `1020` (record changed), SQLSTATE `40001` |
| SQLite | `SQLITE_BUSY` and `SQLITE_LOCKED` ("database is locked") |

### Transactions by hand

- Nested `QueryBuilder.transaction()` calls (savepoints) and `afterCommit()` work inside `run()`.
- `rollBack()` also drops the `afterCommit()` functions.
- `beginTransaction()` throws a `StateError` inside a transaction of the same connection. Use `QueryBuilder.transaction()` for nested work.
- Use the transaction only in the code that began it: the same request, job or test.
- On SQLite, other queries of the isolate wait until the transaction ends or times out. This includes a `QueryBuilder.transaction()` outside `run()`. So do not await them while it is open.

### After commit

- A function added in a nested transaction waits for the outermost commit. If that nested transaction rolls back, its functions are dropped, even if the outer one commits.
- A function can open a new transaction, or call `afterCommit()` again.
- With `connection:`, the function waits only for a transaction of that connection. With no `connection`, it uses the default connection.
- A transaction opened with the default connection's own name (like `connection: 'main'`) uses another driver than no name. So `afterCommit()` with no name runs at once there. Pass the same `connection:` to both, or no name to both.
- Code can outlive its transaction, like a `Timer` or a future that you did not await. If it calls `afterCommit()` after the transaction ended, the function runs at once if the transaction committed, and is dropped if it rolled back. If such a late function throws, the error goes to the `Future` that `afterCommit()` returns, so await it or catch it.
- A driver has it too: `driver.afterCommit(() => ...)`. A custom `DBDriver` that does not use the `afterCommitZone()` and `runAfterCommit()` helpers runs the functions at once.

### Other cases

- On MySQL and MariaDB, a `CREATE`, `ALTER` or `DROP TABLE` inside a nested transaction saves the outer work and ends the savepoint. Do not change the schema there.
- Postgres does not allow a lock with `groupBy()`, `distinct()`, or on the nullable side of a left join. The database throws an error then.
- Postgres and MySQL use a connection pool (size: `maxConnectionCount` in `extra`). A transaction uses one connection of the pool, and other queries use the other connections. SQLite has one connection per isolate.
- When a model has more than one relation to load (`preload` or `eager`), the relation queries run at the same time outside a transaction. Inside a transaction they run one after another on its connection.

## See also

- [Query Builder](query-builder.md): the queries you run in a transaction.
- [Read replicas](replicas.md): where a query goes when you have replicas.
