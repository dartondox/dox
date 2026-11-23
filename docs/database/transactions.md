---
icon: lucide/arrow-left-right
---

# Transactions

A transaction runs many queries as one unit, so either all of them are saved or none of them.

## Running a transaction

`QueryBuilder.transaction()` commits when the function ends. When the function throws, it rolls back and throws the error again:

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

All queries and models inside the function use the transaction. The function can return a value:

```dart
int? id = await QueryBuilder.transaction(() async {
  Actor actor = Actor();
  actor.name = 'John Wick';
  await actor.save();
  return actor.id;
});
```

### Another connection

Pass `connection` to use a named connection:

```dart
await QueryBuilder.transaction(() async {
  // ...
}, connection: 'mysql');
```

On MySQL and MariaDB, a rollback can not undo CREATE, ALTER and DROP TABLE.

## Nested transactions

A transaction inside another one uses a savepoint. If the inner function throws, only its work is undone:

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
```

If you do not catch the error, the outer transaction rolls back too. Run nested transactions one after another, not in `Future.wait`, because they share one connection.

## Handling deadlocks

`attempts` runs the whole function again after a deadlock or a lock failure, up to that many runs in all:

```dart
await QueryBuilder.transaction(() async {
  // ...
}, attempts: 3);
```

Other errors throw at once. The function runs again from the start, so put a mail or a call to another service in [`afterCommit()`](#run-code-after-the-commit).

`DatabaseTransaction.isConcurrencyError(error)` tells you if an error counts:

| Database | Errors |
| --- | --- |
| Postgres | SQLSTATE 40001 (serialization failure), 40P01 (deadlock) |
| MySQL, MariaDB | error 1213 (deadlock), 1205 (lock wait timeout), 1020 (record changed), SQLSTATE 40001 |
| SQLite | SQLITE_BUSY and SQLITE_LOCKED |

## Begin and commit by hand

If the work can not fit in one function, use `QueryBuilder.beginTransaction()`. Only code inside `run()` uses the transaction:

```dart
DatabaseTransaction tx = await QueryBuilder.beginTransaction();
try {
  await tx.run(() async {
    User user = await User().create(<String, dynamic>{'email': email});
    await QueryBuilder.afterCommit(() => sendWelcomeMail(user));
  });
  await tx.run(() => QueryBuilder.table('audit')
      .insert(<String, dynamic>{'event': 'signup'}));
  await tx.commit();
} finally {
  await tx.rollBack(); // does nothing after commit
}
```

- Await each `run()` before `commit()`.
- `commit()` saves the work, then runs the `afterCommit()` functions.
- `rollBack()` undoes the work. It does nothing on a closed transaction.
- `tx.isOpen` is true until `commit()`, `rollBack()` or the timeout.

### Timeout

A transaction that is still open after the timeout (1 minute by default) is rolled back, and its work is lost. Set your own timeout:

```dart
QueryBuilder.beginTransaction(timeout: const Duration(seconds: 10))
```

On Postgres, after a database error inside `run()`, call `rollBack()`. A `commit()` then saves nothing and gives no error.

## Run code after the commit

`QueryBuilder.afterCommit()` runs a function after the outermost transaction commits. A rollback drops it:

```dart
await QueryBuilder.transaction(() async {
  User user = await User().create(<String, dynamic>{'email': email});
  await QueryBuilder.afterCommit(() => sendWelcomeMail(user));
});
```

Outside a transaction, the function runs at once. If a function throws, the data stays saved and the `transaction()` call throws the error. For a named connection, pass the same `connection`:

```dart
await QueryBuilder.afterCommit(() => notify(order), connection: 'mysql');
```

[Queue jobs](../digging-deeper/queue.md#dispatching-after-the-commit) use this with `dispatch(afterCommit: true)`.

## Row locks

A row lock stops two requests from changing the same row at the same time. Lock the row in a transaction, then change it:

```dart
Future<void> buy(int productId, int quantity) async {
  await QueryBuilder.transaction(() async {
    Product product = await Product().lockForUpdate().findOrFail(productId);

    if (product.stock! < quantity) {
      throw BadRequestException(message: 'Not enough stock');
    }

    product.stock = product.stock! - quantity;
    await product.save();
  });
}
```

The lock lasts until the transaction ends. Outside a transaction, it ends at once. Aggregates like `count()` do not lock.

| Database | `lockForUpdate()` | `sharedLock()` |
| --- | --- | --- |
| Postgres | FOR UPDATE | FOR SHARE |
| MySQL, MariaDB | FOR UPDATE | LOCK IN SHARE MODE |
| SQLite | nothing | nothing |

With `sharedLock()`, other transactions can read the rows, but they wait to change them. SQLite has no row locks, but a Dox transaction there takes the write lock of the whole database. So the same code is safe.

For one number column, [`increment()`](query-builder.md#incrementing-and-decrementing) needs no lock.

## Next steps

- [Query Builder](query-builder.md): the queries you run in a transaction.
- [Read replicas](replicas.md): where a query goes when you have replicas.
