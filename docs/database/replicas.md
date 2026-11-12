---
icon: lucide/server
---

# Read replicas

A read replica is a copy of your database that only answers reads.
Dox can send reads to replicas and writes to the main database.
This spreads the load over more servers.

Postgres and MySQL support it. SQLite does not.

## Set it up

Add `read` to the `ConnectionConfig`.
The `host` of the config is the write host.

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

Each map in `read` can change `host`, `port`, `user`, `password`, `database` and `extra`.
The other settings are shared with the config.

To change the write host, add `write`. It has the same keys as one `read` map.
Without `write`, the config itself is the write host.

```dart
write: <String, dynamic>{'host': 'primary.db', 'port': 6432},
```

Without `read`, nothing changes.

## What goes where

The read hosts take turns, in the order of the list (round robin).

| Goes to a read host | Goes to the write host |
|---|---|
| A plain `SELECT` | `INSERT`, `UPDATE` and `DELETE` |
| | A raw query that is not a `SELECT` |
| | Schema changes and migrations |
| | A `SELECT` with a lock (`lockForUpdate()`, `sharedLock()`) or with `INTO` |
| | Every query in a transaction |

Use `onWriteConnection()` to read from the write host.
Use it when a replica may be behind, or when a `SELECT` changes data.

```dart
User? user = await User().onWriteConnection().find(id);
```

It also sends the queries of `preload()` to the write host.
`insert()`, `create()` and `updateOrCreate()` read the new row back from the write host, so you always get it.

## Sticky reads

A replica can be a little behind the main database.
A user saves a post, then the page loads, and the post is not there yet.

`sticky: true` fixes this.
After a write, the reads of the same request go to the write host.
So a request reads what it just wrote.
Other requests still read from the replicas.

In a Dox app this works by itself.
`dox_orm` adds the `stickyReads` middleware as a [global middleware](../the-basic/middleware.md) when a connection uses `sticky`.
You change nothing.

Outside a request, like in a job or a script, wrap the work in `stickyScope()`:

```dart
await ReplicaDriver.stickyScope(() async {
  await Post().create(<String, dynamic>{'title': 'Hello'});
  List<Post> posts = await Post().get(); // read from the write host
});
```

The warning shows once, when a read from a replica follows a write, outside a request.

## With `DATABASE_URL`

When [`DATABASE_URL`](index.md#database_url) is set, the url is the write host.
The `read` hosts and `sticky` stay.
`write` is not used then.
