---
date:
  created: 2026-11-20
authors:
  - dox
categories:
  - Releases
tags:
  - release
slug: dox-3-2-patches
---

# Dox 3.2 patches: faster, less memory, fewer leaks

This release is patch versions only. It makes Dox faster, uses less memory, and fixes memory leaks in long-running apps. There are no API changes. A few defaults changed, so read [Read before you update](#read-before-you-update).

<!-- more -->

> **Key takeaways**
>
> - **Faster ORM.** A list of 100 rows as JSON is 47% faster on Postgres and 66% faster on MySQL. The query builder is 12–15% faster.
> - **Faster queue.** A Postgres worker runs 61% more jobs per second, and about 9 times more right after a burst of jobs.
> - **Less memory.** On Postgres, the ORM app uses half the peak memory (253 MB to 117 MB). A plain Dox server uses about a third less.
> - **Leaks fixed.** The idle queue worker, connections of clients that left, and several Socket.IO and Postgres cases no longer grow memory over time.
> - **Easy to update.** Patch versions only, no API changes. Run `dart pub upgrade` and `dox build_runner:build`, then check [Read before you update](#read-before-you-update).

## Why this release

Some Dox apps used a bit more memory every day in production. We looked at every package for leaks and slow paths. This release fixes what we found:

- An idle queue worker used about 8 MB more memory per day for each loop. This is fixed.
- A request whose client went away could keep its connection open forever. This is fixed.
- Rows from the ORM carried all the query builder state. They are much smaller now.
- The hot path of every request does less work.

## Versions

Every package with a change gets a new patch version. Packages with no change keep their version.

| Package | New version |
| --- | --- |
| `dox_core`, `dox_builder` | 3.2.2 |
| `dox_cache` | 3.2.1 |
| `dox_orm`, `dox_migration`, `dox_cache_database` | 3.2.2 |
| `dox_queue`, `dox_queue_database` | 3.2.2 |
| `dox_scheduler`, `dox_storage`, `dox_inertia` | 3.2.2 |
| `dox_socketio`, `dox_auth`, `dox_mailer` | 3.2.1 |
| `dox_http_native`, `dox_postgres_native`, `dox_mysql_native` | 3.2.1 |
| `ioredis` | 3.2.1 |

No change: `dox_annotation`, `dox_validation`, `dox_openapi`, `dox_view`, `dox_mcp` and the `dox` CLI.

## How to update

1. Get the new versions:

    ```bash
    dart pub upgrade
    ```

    Upgrade `dox_core` and `dox_http_native` together. The new `dox_core` uses `NativeResponse.end()` and `headSent` from the new `dox_http_native`.

2. Make the generated code again. The new `dox_builder` writes faster model code:

    ```bash
    dox build_runner:build
    ```

3. Read [Read before you update](#read-before-you-update). Most apps need nothing more.

## Benchmark

We ran the same apps on the released 3.2 packages and on this release. Same machine, same rig, one server at a time, old and new taking turns, 2 or 3 runs each. The numbers are the average of the runs.

<div class="dox-bench" markdown>

<p class="dox-bench__title">ORM: 47% more requests, half the memory</p>
<p class="dox-bench__sub"><code>GET /orm-list</code>: 100 rows with a model query, as JSON. Postgres, 256 connections.</p>

<div class="dox-bench__grid">
  <span></span><span></span>
  <span class="dox-bench__head">req/s</span>
  <span class="dox-bench__head">p99</span>
  <span class="dox-bench__head dox-bench__head--ram">RAM</span>

  <div class="dox-bench__row dox-bench__row--win">
    <span class="dox-bench__name"><strong>Dox</strong><span>this release</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 100%"></span></span>
    <span class="dox-bench__num">31,183<span class="dox-bench__vs">47% faster</span></span>
    <span class="dox-bench__p99">15.0 ms</span>
    <span class="dox-bench__ram">117 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Dox</strong><span>released 3.2</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 68.2%"></span></span>
    <span class="dox-bench__num">21,274<span class="dox-bench__vs">before</span></span>
    <span class="dox-bench__p99">27.8 ms</span>
    <span class="dox-bench__ram">253 MB</span>
  </div>
</div>

<p class="dox-bench__foot"><span>Dart 3.13 · 2 cores · Postgres 18 · 256 connections · wrk</span></p>

</div>

<div class="dox-bench" markdown>

<p class="dox-bench__title">Query builder: one row</p>
<p class="dox-bench__sub"><code>GET /qb</code>: <code>table('world').where('id', id).first()</code>. Postgres, 256 connections.</p>

<div class="dox-bench__grid">
  <span></span><span></span>
  <span class="dox-bench__head">req/s</span>
  <span class="dox-bench__head">p99</span>
  <span class="dox-bench__head dox-bench__head--ram">RAM</span>

  <div class="dox-bench__row dox-bench__row--win">
    <span class="dox-bench__name"><strong>Dox</strong><span>this release</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 100%"></span></span>
    <span class="dox-bench__num">249,862<span class="dox-bench__vs">15% faster</span></span>
    <span class="dox-bench__p99">3.0 ms</span>
    <span class="dox-bench__ram">117 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Dox</strong><span>released 3.2</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 87.0%"></span></span>
    <span class="dox-bench__num">217,259<span class="dox-bench__vs">before</span></span>
    <span class="dox-bench__p99">3.3 ms</span>
    <span class="dox-bench__ram">253 MB</span>
  </div>
</div>

<p class="dox-bench__foot"><span>Dart 3.13 · 2 cores · Postgres 18 · 256 connections · wrk</span></p>

</div>

<div class="dox-bench" markdown>

<p class="dox-bench__title">HTTP: a bit faster, a third less memory</p>
<p class="dox-bench__sub"><code>GET /</code> on a full Dox app, 512 connections.</p>

<div class="dox-bench__grid">
  <span></span><span></span>
  <span class="dox-bench__head">req/s</span>
  <span class="dox-bench__head">p99</span>
  <span class="dox-bench__head dox-bench__head--ram">RAM</span>

  <div class="dox-bench__row dox-bench__row--win">
    <span class="dox-bench__name"><strong>Dox</strong><span>this release</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 100%"></span></span>
    <span class="dox-bench__num">649,990<span class="dox-bench__vs">5% faster</span></span>
    <span class="dox-bench__p99">1.8 ms</span>
    <span class="dox-bench__ram">21 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Dox</strong><span>released 3.2</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 95.0%"></span></span>
    <span class="dox-bench__num">617,618<span class="dox-bench__vs">before</span></span>
    <span class="dox-bench__p99">1.9 ms</span>
    <span class="dox-bench__ram">31 MB</span>
  </div>
</div>

<p class="dox-bench__foot"><span>Dart 3.13 · 2 cores · 512 connections · wrk</span></p>

</div>

RAM is the peak memory of the whole server, the median of the runs. For the database cards it is the peak over all routes of that app.

### HTTP

A full Dox app with three routes, the rules of [the-benchmarker](https://github.com/the-benchmarker/web-frameworks). Requests per second, the average of 3 runs.

| Route | Connections | 3.2 | This release | Change |
| --- | ---: | ---: | ---: | ---: |
| `GET /` | 64 | 495,089 | 521,583 | +5% |
| `GET /` | 256 | 617,487 | 626,655 | +1% |
| `GET /` | 512 | 617,618 | 649,990 | +5% |
| `GET /user/:id` | 64 | 456,879 | 482,241 | +6% |
| `GET /user/:id` | 256 | 560,239 | 552,170 | about the same |
| `GET /user/:id` | 512 | 550,589 | 557,409 | +1% |
| `POST /user` | 64 | 435,214 | 461,935 | +6% |
| `POST /user` | 256 | 530,144 | 555,397 | +5% |
| `POST /user` | 512 | 517,625 | 564,322 | +9% |
| Peak memory (median) | | 31 MB | 21 MB | −32% |

The native server alone, with no framework (`dox_http_native`, average of 2 runs), has the same speed as before. It serves about 690,000 requests per second at 512 connections. That is close to the most wrk can send, so wrk is the limit here. Its peak memory went from about 30 MB to 19 MB, because connections now share one read buffer per core. See [Native server](/latest/digging-deeper/native-server/).

### Database, query builder and ORM

A small app with one table of 10,000 rows. 256 connections, requests per second, higher is better.

#### Postgres 18

Average of 3 runs.

| Test | 3.2 | Now | Change |
| --- | ---: | ---: | ---: |
| 100 rows to JSON (ORM) | 21,274 | 31,183 | **+47%** |
| Preload a relation, 20 rows | 20,596 | 25,978 | +26% |
| 2 relations in a transaction | 8,325 | 9,936 | +19% |
| JSON response | 472,715 | 555,149 | +17% |
| Query builder, one row | 217,259 | 249,862 | +15% |
| `where('id', id).first()` | 207,500 | 237,464 | +14% |
| `find()`, then `save()` | 95,714 | 105,912 | +11% |
| One row with `find(id)` | 224,865 | 243,143 | +8% |
| 20 rows, one query after another | 14,700 | 14,722 | same |
| Peak memory (median) | 253 MB | 117 MB | **−54%** |

#### MySQL 8.4

Average of 2 runs.

| Test | 3.2 | Now | Change |
| --- | ---: | ---: | ---: |
| 100 rows to JSON (ORM) | 18,481 | 30,671 | **+66%** |
| JSON response | 518,197 | 598,645 | +16% |
| Query builder, one row | 214,335 | 240,542 | +12% |
| 2 relations in a transaction | 5,573 | 6,235 | +12% |
| `where('id', id).first()` | 212,650 | 228,801 | +8% |
| One row with `find(id)` | 222,045 | 238,263 | +7% |
| `find()`, then `save()` | 94,271 | 98,262 | +4% |
| Preload a relation, 20 rows | 16,933 | 17,460 | +3% |
| 20 rows, one query after another | 11,980 | 12,265 | +2% |
| Peak memory (range) | 253–261 MB | 125–222 MB | lower |

We also ran the same routes with the driver alone, with no ORM (`dox_postgres_native`, average of 2 runs). One row went from 266,664 to 297,000 requests per second (+11%). The JSON response went from 550,049 to 592,900 (+8%).

Why the numbers moved:

- ORM rows no longer carry the query builder state. So a list of rows is much cheaper to make, to keep in memory and to turn into JSON.
- In a [transaction](/latest/database/transactions/), the [relations](/latest/database/model/relationship/has-many/) of a model now load together, not one by one.
- "20 rows, one query after another" waits for the database 20 times in a row. The database is the limit there, so it barely moves.

### Queue

20,000 jobs that do nothing, on Postgres 18, with 4 worker loops on 2 cores. Jobs per second, the average of 3 runs.

| Test | 3.2 | Now | Change |
| --- | ---: | ---: | ---: |
| Run the jobs | 6,800 | 10,924 | **+61%** |
| Run the jobs right after a burst | 816 | 7,452 | **about 9×** |
| Push 20,000 jobs with `Queue.batch()` | 2.0 s | 0.33 s | **6× faster** |

- A worker now takes a job with one statement, not a transaction of 4 round trips.
- `Queue.batch()` inserts the jobs with multi-row inserts, not one insert per job.
- "Right after a burst" is a table that was nearly empty and just got many jobs. Postgres still thinks the table is small for up to about a minute. Before, each pop then sorted every waiting job, so the worker was 10 times slower until Postgres updated its statistics. A new index fixes this. See [Read before you update](#read-before-you-update) to add it to an old table.


How it was run: Docker on an Apple M2, `linux/arm64`. The server gets 2 CPUs, wrk gets the others. For the database routes, the database gets 2 CPUs of its own. wrk with keep-alive, 5 seconds warm-up, then 15 seconds per route. AOT build (`dart build cli`). See [Performance](/latest/digging-deeper/performance/) for the full rig.

## New

### Run heavy work off the server isolate

`Dox().compute(task)` runs heavy CPU work, like a PDF, an image or a big JSON file, on a worker isolate. The server answers other requests in the meantime. One small pool of workers is shared by every server isolate. `AppConfig.computeWorkers` sets its size (default 4).

`Hash.makeAsync` and `Hash.verifyAsync` now run on this pool. Before, each call started a new isolate, so 500 logins at once started 500 isolates.

Docs: [Performance mistakes](/latest/digging-deeper/performance-mistakes/)

### Strict mode for development

Strict mode warns about code that makes an app slow. It is off by default.

- `AppConfig(strict: StrictConfig(enabled: true))` warns when a route blocks the isolate longer than 50 ms, and when `Hash.make` or `Hash.verify` runs in the web server.
- `DatabaseConfig(strict: OrmStrict(enabled: true))` warns about N+1 queries (the same relation loaded row by row) and about a `get()` with no `limit()` that reads more than 1,000 rows.

Each warning says what to use instead. Turn both on in development with `appConfig.isDevelopment`.

Docs: [Performance mistakes](/latest/digging-deeper/performance-mistakes/), [App config](/latest/reference/app-config/)

### Log tags

Every pretty log line now starts with a dim tag that says where it comes from: `[request]`, `[server]`, `[error]`, `[app]`, `[db:main]`, `[queue]`, `[socketio]`, `[auth]`, `[mail]` and more. The scheduler uses `[scheduler]` when `SchedulerFlags.loggerLines` is on. Pass your own tag as the third argument:

```dart
Logger.info('invoice sent', {'id': 42}, 'billing');
```

In JSON logs, the tag is the `source` field.

### Other new options

- `CoreFlags.rateLimitIpv6Prefix` (opt-in): `RateLimit` counts an IPv6 client by its /64 prefix. See [Rate limiting](/latest/security/rate-limiting/).
- `fsync: false` on a `file` cache store skips the sync to disk on each write. See [Cache](/latest/digging-deeper/cache/).
- `prune_interval` on a `database` cache store prunes expired rows now and then.
- `--max-sleep` for the queue worker: an idle worker sleeps longer, up to this time. See [Queue](/latest/digging-deeper/queue/).
- `SchedulerFlags.loggerLines` (opt-in): scheduler lines go through the app `Logger`. See [Scheduler](/latest/digging-deeper/scheduler/).
- `unsigned_payload: true` on an S3 disk skips the body hash (HTTPS only). See [File storage](/latest/digging-deeper/file-storage/).
- Socket.IO opt-in limits: `maxAttachmentBytes`, `maxAuthSize`, `maxWriteBufferSize` and `ackTimeout`. See [Socket.IO](/latest/packages/socketio/).
- ioredis: `maxQueuedCommands` (opt-in) caps the commands that wait for a connect.
- The queue worker warns once when a job may run longer than `retryAfter`. Then a second worker could take the same job while the first one still runs it.
- `NativeWebSocket.pingInterval` now works.

## Faster

### Requests

- A request with no body makes no body map until you read `req.body`.
- A response makes no Future, map, set or list unless you use them.
- CORS does not read the `Origin` header when it has nothing to check.
- A route with params skips its regex when the url does not start with the route's text.
- A JSON response starts with a 1 KB buffer, not 8 KB. Small JSON bodies encode about 2 times faster.
- An ASCII text body is written straight to bytes.
- The `cookie` session driver decrypts the cookie only when you use `req.session`.
- `RateLimit` on Redis is one round trip per request, not two or three.

### ORM

- Rows no longer carry the query builder state. Each row from `get()` uses much less memory.
- `toJson()`, `preload()` and relation loading do less work per row.
- A relation load reads only the key column of each row (needs `dox build_runner:build`).
- `where(column, value).first()` reuses the SQL of `find()`. The [query builder](/latest/database/query-builder/) does less work per query too.
- `create()` and `save()` copy less.
- Inside a transaction, the relations of a model load together, not one by one.

### Database drivers

- Postgres: each isolate gets a fair share of the connection pool. Before, under load, isolates passed connections back and forth, and the slowest requests got slower.
- The native HTTP server uses one shared read buffer per core, not 16 KB per connection.

### Queue, cache, storage and Socket.IO

- Postgres queue: a worker takes a job with one statement, not a transaction of 4 round trips. Several queues are polled in one statement. An idle worker makes one round trip per poll.
- Postgres and SQLite queue: right after a burst of jobs, a pop no longer sorts every waiting job (a new index).
- `Queue.batch()` inserts its jobs with multi-row inserts.
- Database cache store: `add`, `increment`, `pull`, `touch` and locks run one statement on Postgres and SQLite.
- Memory cache store: removing the least recently used item is O(1), not O(n).
- S3 `putStream` keeps one part in memory, not two or three (about 8 MiB in place of 24 MiB per upload). `stream()` and `download()` send one GET, not a HEAD and a GET.
- Local disk `append` adds to the file, without reading and writing the whole file.
- Socket.IO: a room broadcast with `except` makes no copy of the room. With the Redis adapter, a server does not decode broadcasts for rooms it does not have.
- ioredis: text like Burmese or emoji is encoded in one pass.

## Fixes

### Memory leaks

- Queue: an idle worker leaked a listener on each sleep, about 8 MB a day per loop. This also hit the in-process worker in the web server.
- Native HTTP: sometimes a client leaves while its request still waits, and the handler never answers (for example, a database call with no timeout). The server then kept that connection forever. The same happened to a server-sent events stream that wrote nothing after the client left. Now the connection closes after `AppConfig.idleTimeout`.
- Native HTTP: `response.done` never completed when the client left first. A handler writing events from a timer kept its timer forever.
- Native HTTP: accepted sockets now get TCP keep-alive, so a client that vanished with no close is found in about 2 minutes.
- Postgres: a query that failed after its Parse left a prepared statement on the server. The Postgres backend grew with each one.
- Postgres: each cached statement kept the whole batch of its request in memory, not only its SQL. It now keeps its own copy of the SQL.
- Postgres, MySQL and the ORM: SQL longer than 4 KB is no longer kept in the SQL caches. Big generated inserts could fill them with hundreds of MB.
- Socket.IO: `socket.join()` after a disconnect kept the socket in the room forever.
- Socket.IO: unfinished binary packets, and broadcast acks when Redis was down, stayed in memory.
- Scheduler: a `Scheduler` made without `out` kept every log line forever. It now keeps the last 64 KB.
- Rate limit: the counter in the main isolate had no cap on clients. It now keeps at most 100,000.
- ioredis: while Redis was down, every command waited forever and kept its data. Commands now time out after 10 seconds.

### Security

- Socket.IO: a client could send the start of a binary packet and never the rest. The parts stayed in memory, also before the client joined a namespace. Now such a client is closed.
- Socket.IO: a 1 MB polling body made of separators was split into about 500,000 strings at once. Now packets are read one at a time.
- Socket.IO: with `maxSessions` not set, every GET request makes a session that lives about 45 seconds. The server now prints a warning at start. Set `maxSessions` in production.

### Disk

- The `file` cache store never cleaned up by default. Now a write starts a light prune at most once an hour. Temp files left by a crash are removed too.
- Upload temp files are deleted when the request is handled, also on an error or a raw `Route.mount` handler.

### Bugs

- [Sessions](/latest/the-basic/session/) with the `cache` driver on a `memory` store lived in each isolate on its own, so users were logged out at random. They now live in the main isolate.
- Scheduler: a slow tick that ended in the next minute skipped that minute, so a `dailyAt('02:00')` task could miss a day.
- Scheduler: with `inProcess: true`, the schedule also ran in every `bin/queue.dart` process.
- Native HTTP: a streamed answer with status 1xx, 204 or 304 broke the next answer on the same keep-alive connection.
- Native HTTP: `response.flush()` did nothing. It now sends the head and the bytes so far, like `dart:io`.
- Core: an error after a flush (for example in server-sent events) wrote `Internal Server Error` into the middle of the stream. Now the response just ends.
- Core: a multipart body with no closing boundary kept the request open forever.
- ORM: `find('meta->n', 10)` on a JSON path failed the second time on Postgres and MySQL.
- ORM: `$getRelation<User>('user')` with a type threw a `TypeError`.
- Database cache store: an `increment` past the 64-bit limit wrapped to a negative number. It is now an error.
- S3: `directoryExists` was false for a folder made in the S3 console, and `deleteDirectory` left the folder marker.
- ioredis: a bad reply byte from the server could crash the app.

## Read before you update

These changes can be seen by an app. Most apps need nothing.

- **Log text.** Pretty log lines start with a tag, and plain warnings use tags like `[server]`, `[db]` and `[queue]` in place of `dox: warning:`, `[dox]` or `Queue: `. JSON lines get a `source` field at the end. Check tools that match on log text.
- **ioredis commands time out after 10 seconds.** Blocking commands and subscribers never time out. To turn it off: `RedisOptions(commandTimeout: null)`.
- **Half-closed clients.** A client that closed only its sending side now waits at most `idleTimeout` (30 seconds by default) for its answer. If such clients call slow handlers, raise it in `lib/config/app.dart`:

    ```dart
    AppConfig appConfig = AppConfig(
      // ...
      idleTimeout: const Duration(seconds: 120),
    );
    ```

    See [App config](/latest/reference/app-config/).
- **A test that starts the scheduler by hand.** This only matters if you use `ScheduleConfig(inProcess: true)`, so the schedule runs inside the web server.

    The problem it fixes: `bin/queue.dart` also calls `setup()` on every provider. So the schedule ran in the web server and again in every queue worker process, and each task ran more than once.

    Now `SchedulerProvider.setup()` starts the schedule only in the web server. `Dox().startServer()` marks the web server: it sets `Dox().isWebServer = true`. Your app and your HTTP tests start the server. So they need no change.

    A test that calls `setup()` itself, with no server, now gets no schedule. Set the flag first:

    ```dart
    test('the schedule runs in the server', () async {
      Dox().isWebServer = true; // new: without it, setup() does nothing
      SchedulerProvider provider = SchedulerProvider(
        schedule: appSchedule,
        config: const ScheduleConfig(inProcess: true),
        store: CacheStore(MemoryDriver()),
      );
      await provider.setup();
      expect(provider.scheduler, isNotNull);
      await provider.shutdown();
    });
    ```
- **Queue indexes.** A new `jobs` table on Postgres or SQLite gets better indexes. They keep a worker fast when many jobs come at once, and when many jobs are delayed. For an old table, add a migration that calls `QueueTables.popIndex(schema)`. It adds only the indexes that are missing, and it does nothing on MySQL and MariaDB. This is optional, but we recommend it for Postgres apps that push jobs in bursts.
- **Rate limit cap.** The `RateLimit` counter in the main isolate (no Redis) now keeps at most 100,000 clients. When it is full, it drops expired counts first, then the oldest ones. A dropped client starts again at 0. Most apps never reach this.
- **Cache index.** A new `cache` table gets an index on `expires_at`. For an old table, add it with `schema.table('cache', (Table t) => t.index('expires_at'))`. This is optional.
