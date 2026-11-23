---
icon: lucide/server
---

# Read replicas

A read replica is a copy of your database that only answers reads, and Dox can send reads to replicas and writes to the main database.

Postgres and MySQL support replicas. SQLite does not.

## Setup

Add `read` to the `ConnectionConfig`. The host of the config is the write host:

```dart title="lib/config/database.dart"
'postgres': ConnectionConfig(
  driver: Driver.postgres,
  host: env.dbHost, // the write host
  user: env.dbUsername,
  password: env.dbPassword,
  database: env.dbName,
  debug: _debug,
  read: <Map<String, dynamic>>[
    <String, dynamic>{'host': 'replica-1.db'},
    <String, dynamic>{'host': 'replica-2.db', 'user': 'reader'},
  ],
  sticky: true,
),
```

Each read map can change `host`, `port`, `user`, `password`, `database` and `extra`. The other settings come from the config.

### Another write host

`write` sets the write host, with the same keys as one read map:

```dart
write: <String, dynamic>{'host': 'primary.db', 'port': 6432},
```

When [`DATABASE_URL`](index.md#database_url) is set, the url is the write host and `write` is not used.

## Where queries go

A plain SELECT goes to a read host. The read hosts take turns. These go to the write host:

- INSERT, UPDATE and DELETE
- a raw query that is not a SELECT
- schema changes and migrations
- a SELECT with a lock or with INTO
- every query in a transaction

`ReplicaDriver.isReadQuery(sql)` tells you if a query can go to a replica.

### Reading from the write host

`onWriteConnection()` sends the queries of a query to the write host, also its `preload()` queries:

```dart
User? user = await User().onWriteConnection().find(id);
```

`insert()`, `create()` and `updateOrCreate()` always read the new row from the write host.

## Sticky reads

A replica can be a little behind. With `sticky: true`, the reads that follow a write in the same request go to the write host. So a request always reads what it wrote.

In a Dox app this works by itself, because `dox_orm` adds the `stickyReads` [global middleware](../the-basic/middleware.md). Outside a request, like in a job, wrap the work in `stickyScope()`:

```dart
await ReplicaDriver.stickyScope(() async {
  await Post().create(<String, dynamic>{'title': 'Hello'});
  List<Post> posts = await Post().get(); // read from the write host
});
```

When a replica read follows a write outside a scope, Dox prints one warning.

## Next steps

- [Database](index.md): connections and settings.
- [Transactions](transactions.md): all queries of a transaction go to the write host.
