---
icon: lucide/server
---

# Read replicas

A read replica is a copy of your database that only answers reads, and Dox can send reads to replicas and writes to the main database.

This spreads the load over more servers, which helps when your app reads much more than it writes. Postgres and MySQL support it. SQLite does not.

## Configuring replicas

Add `read` to the `ConnectionConfig`. The `host` of the config is the write host:

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

Each map in `read` can change `host`, `port`, `user`, `password`, `database` and `extra`. The other settings come from the config. Without `read`, nothing changes.

If the write host is not the host of the config, add `write`. It has the same keys as one `read` map:

```dart
write: <String, dynamic>{'host': 'primary.db', 'port': 6432},
```

## Where queries go

A plain `SELECT` goes to a read host. The read hosts take turns, in the order of the list. Everything else goes to the write host:

- `INSERT`, `UPDATE` and `DELETE`
- a raw query that is not a `SELECT`
- schema changes and migrations
- a `SELECT` with a lock (`lockForUpdate()`, `sharedLock()`) or with `INTO`
- every query in a transaction

### Reading from the write host

A replica may be a little behind, or a `SELECT` may change data. In these cases, use `onWriteConnection()` to read from the write host:

```dart
User? user = await User().onWriteConnection().find(id);
```

It also sends the queries of `preload()` to the write host. You do not need it after `insert()`, `create()` and `updateOrCreate()`, because they always read the new row back from the write host.

## Sticky reads

A replica can be a little behind the main database. So a user saves a post, the next page loads, and the post is not there yet.

`sticky: true` fixes this. After a write, the reads of the same request go to the write host, so a request always reads what it just wrote. Other requests still read from the replicas.

In a Dox app this works on its own. When a connection uses `sticky`, `dox_orm` adds the `stickyReads` middleware as a [global middleware](../the-basic/middleware.md).

Outside a request, like in a job or a script, wrap the work in `stickyScope()`:

```dart
await ReplicaDriver.stickyScope(() async {
  await Post().create(<String, dynamic>{'title': 'Hello'});
  List<Post> posts = await Post().get(); // read from the write host
});
```

If you forget it, `dox_orm` prints a warning on stderr, once, when a read from a replica follows a write outside `stickyScope()`.

## Details

- When [`DATABASE_URL`](index.md#database_url) is set, the url is the write host. The `read` hosts and `sticky` stay, and `write` is not used.
