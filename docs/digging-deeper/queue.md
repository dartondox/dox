---
icon: lucide/list-ordered
---

# Queue

A queue runs slow work in the background, so the request can answer at once.

A worker process does the work later.

Use it to send emails, call slow APIs, make reports or resize images.
The `dox_queue` package gives you jobs, two drivers (Redis and sync), retries, delays and a worker. The database driver is in the `dox_queue_database` package, see [Database driver](#database-driver).

## Install

```bash
dart pub add dox_queue
```

`dox_queue` has a builder. Your app already runs `build_runner` for `dox_builder`, so nothing else is needed.

## How it works

1. You write a job class with `@Job()`.
2. `dart run build_runner build` writes `lib/generated/jobs.g.dart`. It knows how to save and load each job.
3. Your code calls `dispatch()`. The job is saved in Redis, or in the database with `dox_queue_database`.
4. A worker (`dart run bin/queue.dart`) takes the job and runs its `handle()` method.

## Set up

A new app from `dox create` already has the files of steps 1 to 4. Check them, and change the driver if you want.

### 1. Config

```dart title="lib/config/queue.dart"
import 'package:dox_queue/dox_queue.dart';

import '../generated/jobs.g.dart';

QueueConfig queueConfig = QueueConfig(
  /// sync, database or redis
  driver: 'database',

  /// every @Job class, from lib/generated/jobs.g.dart
  jobs: jobRegistry,
);
```

| Option | Default | What it does |
| --- | --- | --- |
| `driver` | `sync` | `sync`, `database` (needs `dox_queue_database`) or `redis` |
| `jobs` | empty | `jobRegistry` from `lib/generated/jobs.g.dart` |
| `redis` | 127.0.0.1:6379 | `RedisOptions(host: ..., port: ..., password: ...)` for the `redis` driver. `QueueConfig.redisFromEnv()` reads it from the env. |
| `prefix` | `dox_queue:` | the start of every Redis key |
| `connection` | default | the dox_orm connection name, for `dox_queue_database` |
| `retryAfter` | 90 seconds | when a worker does not finish a job in this time, another worker can take it |
| `inProcess` | `false` | run a worker inside the web server, see [Small apps](#small-apps-a-worker-in-the-web-server) |
| `workerQueues` | `['default']` | the queues of the in-process worker |
| `workerConcurrency` | `1` | jobs at once in the in-process worker |
| `workerTimeoutGrace` | none | the `--timeout-grace` wait of the in-process worker, see [Retries and failed jobs](#retries-and-failed-jobs) |
| `serializeSync` | `false` | opt-in: the `sync` driver saves the job and reads it back before it runs, see [Sync](#sync) |
| `connections` | none | opt-in: more queue connections by name, see [Queue connections](#queue-connections) |
| `afterCommit` | `false` | opt-in: push jobs that are dispatched inside a transaction only after it commits (needs `dox_queue_database`), see [Dispatch after the commit](#dispatch-after-the-commit) |

!!! warning "Keep `retryAfter` bigger than your longest job"
    `retryAfter` is how Dox finds the job of a crashed worker.
    A job that runs longer than `retryAfter` looks crashed, so a second worker runs it again.

### 2. Provider

The provider sets up the queue in every isolate. Put it in `lib/providers/`, so the generated container finds it.

```dart title="lib/providers/queue_provider.dart"
import 'package:dox_queue/dox_queue.dart';

import '../config/queue.dart';

/// Sets up the queue. Dox finds every DoxProvider class,
/// see lib/generated/container.g.dart.
class AppQueueProvider extends QueueProvider {
  AppQueueProvider() : super(queueConfig);
}
```

### 3. Worker file

```dart title="bin/queue.dart"
import 'dart:io';

import 'package:dox_queue/dox_queue.dart';
import 'package:my_app/config/app.dart';

/// run queued jobs: `dart run bin/queue.dart [work] [flags]`.
/// the `dox` CLI runs this file for its queue commands.
Future<void> main(List<String> args) async {
  exitCode = await QueueWorker(app: appConfig).run(args);
}
```

The worker starts the providers of your app (database, cache, queue). It does not start the HTTP server.

### 4. Database driver and tables

The database driver, [job batches](#job-batches) and `afterCommit` are in the `dox_queue_database` package. Skip this step when you use only Redis or sync and none of these.

```bash
dart pub add dox_queue_database
```

Register it in your queue provider, before `super.setup()`:

```dart title="lib/providers/queue_provider.dart"
import 'package:dox_queue/dox_queue.dart';
import 'package:dox_queue_database/dox_queue_database.dart';

import '../config/queue.dart';

class AppQueueProvider extends QueueProvider {
  AppQueueProvider() : super(queueConfig);

  @override
  Future<void> setup() async {
    QueueDatabase.register();
    await super.setup();
  }
}
```

The `jobs` and `failed_jobs` tables are for the database driver.
The `job_batches` table is for [job batches](#job-batches). If you use batches, you need it with every driver.

Run `dox queue:table`. It writes a migration in `db/migration` that makes all three tables. Then run `dox migrate`.

```bash
dox queue:table
dox migrate
```

`queue:table` is a [package command](package-commands.md) of `dox_queue_database`. It does not overwrite: when a `create_queue_tables` migration is already there, it prints so and stops.

The migration it writes looks like this. You can also write it by hand. `QueueTables.up` makes the `jobs` and `failed_jobs` tables. `QueueTables.upBatches` makes the `job_batches` table.

```dart title="db/migration/2026_10_25_000000_create_queue_tables.dart"
// ignore_for_file: file_names
import 'package:dox_migration/dox_migration.dart';
import 'package:dox_queue_database/dox_queue_database.dart';

/// The jobs, failed_jobs and job_batches tables of dox_queue_database.
class CreateQueueTables extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await QueueTables.up(schema);
    await QueueTables.upBatches(schema);
  }

  @override
  Future<void> down(Schema schema) async {
    await QueueTables.downBatches(schema);
    await QueueTables.down(schema);
  }
}
```

## Write a job

```dart title="lib/app/jobs/send_welcome_email.job.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_queue/dox_queue.dart';

@Job()
class SendWelcomeEmail extends DoxJob {
  SendWelcomeEmail({required this.userId});

  final int userId;

  /// run up to 3 times
  @override
  int get tries => 3;

  /// wait 10 seconds before the 2nd try, 60 seconds before the 3rd
  @override
  List<Duration> get backoff => const <Duration>[
    Duration(seconds: 10),
    Duration(seconds: 60),
  ];

  /// stop a try after 30 seconds
  @override
  Duration? get timeout => const Duration(seconds: 30);

  /// the queue of this job
  @override
  String get queue => 'emails';

  @override
  Future<void> handle() async {
    MailService mail = Dox().ioc.get<MailService>();
    await mail.sendWelcome(userId);
  }

  /// runs once, after the last try failed
  @override
  Future<void> failed(Object error, StackTrace stack) async {
    // tell someone, or clean up
  }
}
```

Run `dart run build_runner build` after you add or change a job.

`dox make:job SendWelcomeEmail` makes a new job file in `lib/app/jobs/`.

All the settings are optional:

| Setting | Default | What it does |
| --- | --- | --- |
| `tries` | the worker `--tries` (1) | how many times to run the job before it fails |
| `backoff` | none (retry at once) | the wait before each retry. The last entry is used for the rest |
| `timeout` | the worker `--timeout` (60 seconds) | the max run time of one try |
| `retryUntil` | none | retry until this time, not `tries` times. Read once, when the job is dispatched |
| `maxExceptions` | none | fail after this many tries that threw an error. A timeout does not count |
| `failOnTimeout` | `false` | fail at once when a try times out, with no retry |
| `queue` | `default` | the queue to put the job on |
| `failed()` | does nothing | runs once, after the last try failed |

### What is saved

The parameters of the unnamed constructor are saved with the job.
Each parameter needs a field or getter with the same name.

These types work:

- `int`, `double`, `num`, `String`, `bool`
- `DateTime`
- enums (saved by name)
- `List` and `Map<String, ...>` of these, also nested
- `dynamic` and `Object` (the value must be JSON)
- nullable versions of all of them

Any other type stops the build with a clear message.

!!! tip "Save an id, not an object"
    Do not save a `User`. Save the `userId`, and load the user in `handle()`.
    The user may change between dispatch and run. The id gives you fresh data.

### Encrypt the saved data

Add the `ShouldBeEncrypted` mixin to save the job data encrypted.
A person who can read Redis or the `jobs` table then can not read it.

```dart
@Job()
class ChargeCard extends DoxJob with ShouldBeEncrypted {
  // ...
}
```

The data is encrypted with the app key (`AppConfig.appKey`). The worker needs `Dox().initialize()` with the same key, or one of `AppConfig.previousKeys`.
The job name, the queue and the id stay plain text.

### Services in a job

A job is made again from its saved data, so it can not get services in its constructor.
Get them in `handle()` from the Dox container:

```dart
UserService users = Dox().ioc.get<UserService>();
```

The worker runs `registerContainer`, so every `@Inject()` class of your app is there.

### Job names

The class name is saved with each job. When you rename a class, queued jobs of the old name can not be found.
Keep the old name with `@Job(name: 'SendWelcomeEmail')`.

## Dispatch a job

```dart
await SendWelcomeEmail(userId: user.id).dispatch();
```

Both ways do the same:

```dart
await Queue.dispatch(SendWelcomeEmail(userId: user.id));
```

A delay, another queue:

```dart
await SendWelcomeEmail(userId: 1).dispatch(
  delay: Duration(minutes: 10),
  queue: 'emails',
);
```

Wait until a time:

```dart
await SendWelcomeEmail(userId: 1).dispatch(
  delayUntil: DateTime.utc(2030, 1, 1, 9),
);
```

Give `delay` or `delayUntil`, not both.

`dispatch()` returns the job id.

Dispatch only when a condition is true, or false:

```dart
await SendWelcomeEmail(userId: 1).dispatchIf(user.wantsEmail);
await SendWelcomeEmail(userId: 1).dispatchUnless(user.isBlocked);
```

They return null when the job was not dispatched.

Run a job now, in this process, with no queue:

```dart
await SendWelcomeEmail(userId: 1).dispatchSync();
```

Run a job in this process after the answer is sent. The client does not wait for it:

```dart
SendWelcomeEmail(userId: 1).dispatchAfterResponse();
```

Do not `await` it. It returns nothing.
It does not go on the queue. So it has no job id and no retry. Outside a request, the job runs soon. When the job throws, its `failed()` runs and the error goes to the exception handler, never to the client. `QueueProvider` turns on `AfterResponse` for it. When the server stops, a job that did not run yet is lost.

### Dispatch after the commit

A job that you dispatch inside a database transaction is pushed at once.
This option needs `dox_queue_database` (see [step 4](#4-database-driver-and-tables)). Without it, a dispatch with `afterCommit` on throws a `StateError`.
A worker can run it before the transaction commits, or after it rolls back.
Then the job reads data that is not saved yet, or data that is never saved.

`afterCommit: true` waits for the commit:

```dart
await QueryBuilder.transaction(() async {
  User user = await User().create(<String, dynamic>{'email': email});
  await SendWelcomeEmail(userId: user.id).dispatch(afterCommit: true);
});
```

- Inside a transaction, the job is pushed after the outermost transaction commits.
- When the transaction rolls back, the job is not pushed.
- Outside a transaction, the job is pushed at once.
- `dispatch()` returns the job id at once. The id is made before the push.
- A job that is not in the registry, or data that is not JSON, throws at `dispatch()`, not at the commit.
- When the push fails after the commit, the `QueryBuilder.transaction()` call throws that error. The data stays saved.
- The `sync` driver runs the job after the commit.
- It waits only for a transaction on the default dox_orm connection, opened with no `connection:` name. A transaction opened by name pushes the job at once, also when the name is the one of the default connection.
- `dispatchIf()`, `dispatchUnless()` and `Queue.dispatch()` take `afterCommit` too.
- Chains and batches take it too: `Queue.chain(jobs).dispatch(afterCommit: true)` and `Queue.batch(jobs).dispatch(afterCommit: true)`. A batch saves its `job_batches` row and pushes its jobs after the commit. A rollback drops it all.
- Before the commit, the returned `Batch` is not saved yet. It has the id and the counts of a new batch.
- A `sync` chain runs as a whole after the commit. It gives a new id before the commit, because its ids are made when it runs.
- `dispatchSync()` and `dispatchAfterResponse()` run the job as before. They do not wait for a commit.

Turn it on for every dispatch with `QueueConfig(afterCommit: true)`. Batches and chains follow it too.
Then `afterCommit: false` on one dispatch pushes that job at once.

`Queue.fake()` keeps the job when you call `dispatch()`, also when the transaction later rolls back.

It works through [`QueryBuilder.afterCommit()`](../database/transactions.md#run-code-after-the-commit) of dox_orm, set up by `dox_queue_database`.

### Queue an email

You do not need a job class to send an email later. With [dox_mailer](mail.md#queue-an-email), call `Mail.queue()`:

```dart
await Mail.queue(message);
await Mail.later(Duration(minutes: 10), message, queue: 'emails');
```

The mail jobs are part of dox_mailer. The queue provider and a worker run them.

## Run the worker

```bash
dart run bin/queue.dart
```

Commands:

| Command | What it does |
| --- | --- |
| `work` | run jobs. This is the default |
| `failed` | list the failed jobs |
| `retry <id>` | put one failed job back on its queue |
| `retry all` | put all failed jobs back |
| `forget <id>` | delete one failed job |
| `flush` | delete all failed jobs |
| `clear [queue]` | delete the jobs of a queue, also the running ones. It frees the locks of [unique jobs](#unique-jobs). Default: `default` |
| `restart` | stop the running workers after their current jobs |
| `prune-failed` | delete failed jobs older than `--hours=N` (default 24) |
| `prune-batches` | delete finished [batches](#prune-old-batches) older than `--hours=N` (default 24). `--unfinished=N` also deletes old batches that never finished |

Flags of `work`:

| Flag | Default | What it does |
| --- | --- | --- |
| `--queue=high,default` | `default` | the queues to work. The first one goes first |
| `--concurrency=4` | `1` | jobs at once in this process |
| `--once` | off | run one job, then stop |
| `--tries=3` | `1` | tries of a job that does not set `tries` |
| `--timeout=60` | `60` | max run time in seconds of a job that does not set `timeout` |
| `--sleep=3` | `3` | seconds to wait when the queues are empty |
| `--stop-when-empty` | off | stop when the queues are empty |
| `--timeout-grace=10` | none | after a timeout, wait up to this many seconds for the old run to end before the next try |
| `--backoff=1,5,10` | none | seconds to wait before each retry of a job that does not set `backoff` |
| `--max-jobs=1000` | off | stop after this many jobs |
| `--max-time=3600` | off | stop after this many seconds |
| `--memory=256` | off | stop when the process uses more than this many MB |

With `--max-jobs`, `--max-time` and `--memory`, the worker stops after its running jobs. Let your process manager start it again.

```bash
dart run bin/queue.dart work --queue=emails,default --concurrency=4
```

The `dox` CLI runs the same file: `dox queue:work`, `dox queue:failed`, `dox queue:retry <id|all>`, `dox queue:forget <id>`, `dox queue:flush`, `dox queue:clear [queue]`, `dox queue:restart` and `dox queue:prune-failed`. They take the same flags.

`--concurrency` runs jobs as async tasks on one thread. It helps for jobs that wait (email, HTTP, database).
For CPU heavy jobs, run more worker processes.

### Stop the worker

Press Ctrl+C, or send SIGTERM (`docker stop` does it).
The worker takes no new job. It waits for the running jobs, then it stops.
A second signal stops it at once.

!!! warning "Restart the worker after a deploy"
    The worker keeps your code in memory. Restart it after each deploy, or it runs the old code.

`dart run bin/queue.dart restart` tells every running worker to stop after its current jobs.
Your process manager then starts it with the new code.
It writes a time to the app cache. Each worker reads it every 3 seconds.
So the workers and the command must use the same cache store, like `file` on one machine, or `redis`.
The `memory` store does not work for it.

### Keep it running

In production, run the binary, not `dart run`. `dox build` makes `build/bundle/bin/queue`, next to the server:

```bash
cd build/bundle
./bin/queue work --concurrency=4
```

It takes the same commands and flags as `dart run bin/queue.dart`.

Run the worker as its own process, next to the web server. For example with Docker Compose and the image of the project `Dockerfile`:

```yaml
services:
  web:
    build: .
    command: /app/bin/server
  worker:
    build: .
    command: /app/bin/queue work --concurrency=4
```

Or with systemd, Supervisor or a second Fly.io process. Set it to restart when it stops.

## Retries and failed jobs

When `handle()` throws:

1. The worker waits the `backoff` time and tries again, up to `tries` times.
2. After the last try, the job goes to the failed jobs, and `failed()` runs.

A timeout counts as a failed try.

!!! info "A timeout does not stop the code"
    Dart can not stop a running `Future`.
    After a timeout the try counts as failed, but `handle()` keeps running in the background until it ends.
    Write jobs that are safe to run twice.

To wait for the old run, start the worker with `--timeout-grace=SECONDS`. Or set `workerTimeoutGrace` in `QueueConfig` for the in-process worker.
The worker waits up to that time for the old run to end before it retries or fails the job. It takes no other job while it waits.
Keep `timeout` plus the grace time below `retryAfter`. If not, another worker can take the job while this one waits.

When a worker crashes, its job stays reserved. After `retryAfter` another worker takes it.
This counts as a try. When there are no tries left, the job fails with a message that the worker did not finish.

Failed jobs are kept until you retry or delete them:

```bash
dart run bin/queue.dart failed
dart run bin/queue.dart retry 6f1c0e...
dart run bin/queue.dart retry all
dart run bin/queue.dart forget 6f1c0e...
dart run bin/queue.dart flush
```

### Control the job in handle()

Add the opt-in `InteractsWithQueue` mixin. Then, inside `handle()`, the job can decide what happens next:

| Call | What it does |
| --- | --- |
| `attempts()` | how many times a worker took the job. The first run gives 1 |
| `release(delay)` | put the job back on its queue. It runs again after `delay` |
| `fail(error)` | fail the job now, with no retry. `failed()` runs |
| `delete()` | delete the job, with no retry and no `failed()` |

```dart
@Job()
class SendReport extends DoxJob with InteractsWithQueue {
  SendReport({required this.reportId});

  final int reportId;

  @override
  int get tries => 5;

  @override
  Future<void> handle() async {
    ReportApi api = Dox().ioc.get<ReportApi>();
    if (await api.isBusy()) {
      release(Duration(seconds: 30));
      return;
    }
    if (!await api.hasReport(reportId)) {
      delete();
      return;
    }
    await api.send(reportId);
  }
}
```

The worker does the call when `handle()` ends. When you call more than one, the last one wins.
A call also wins over an error that `handle()` throws after it.
When `handle()` times out, the call is dropped, and the timeout rules count.

`release()` counts as a try. The default `tries` is 1, so the job then fails on its next pickup.
Set `tries` above 1 (or `retryUntil`) when a job calls `release()`.

With `dispatchSync()`, `dispatchAfterResponse()` and the `sync` driver there is no queue.
There `attempts()` is 1, `release()` and `delete()` do nothing, and `fail()` only runs `failed()`.

In a test file, `package:test` has its own `fail()`. Inside a job class with the mixin, a bare `fail(...)` calls the job method. Write `this.fail(...)` to make it clear.

## Job middleware

Middleware wraps `handle()` of a job. Use it for rules that many jobs share, like a rate limit.
Add the opt-in `HasMiddleware` mixin and list the middleware. The first one runs first.

```dart
@Job()
class SendReport extends DoxJob with HasMiddleware {
  SendReport({required this.reportId});

  final int reportId;

  @override
  int get tries => 5;

  @override
  List<JobMiddleware> get middleware => <JobMiddleware>[
    RateLimited('report-api', 10, Duration(minutes: 1)),
    WithoutOverlapping(
      'report-$reportId',
      releaseAfter: Duration(seconds: 30),
      expireAfter: Duration(minutes: 10), // longer than the longest report run
    ),
  ];

  // ...
}
```

Write your own with `JobMiddleware`.
Call `next()` to go on.
Do not call it to skip the job. The job is then done.
Call `release(job, delay)` to put the job back on the queue.

```dart
class SkipAtNight extends JobMiddleware {
  @override
  Future<void> handle(DoxJob job, JobNext next) async {
    if (DateTime.now().hour < 6) {
      release(job, Duration(hours: 1));
      return;
    }
    await next();
  }
}
```

The middleware runs in the worker, with the `sync` driver, with `dispatchSync()` and with `dispatchAfterResponse()`.
A release counts as a try, like `release()` in [Control the job in handle()](#control-the-job-in-handle).
Outside a worker there is no queue. A release then logs a warning, and `handle()` does not run.

### Rate limits and locks

| Middleware | What it does |
| --- | --- |
| `RateLimited(key, max, per)` | runs at most `max` jobs of `key` in each `per` window. The others go back on the queue until the window ends |
| `WithoutOverlapping(key, releaseAfter:, expireAfter:)` | runs one job of `key` at a time. The others go back after `releaseAfter` (default: zero, so at once). With `releaseAfter: null`, they are dropped. `expireAfter` frees the lock after this time, also while a job still runs. Default: no expiry. Set `expireAfter` longer than the longest run of the job, so a crash can not hold the lock forever and two runs do not overlap |
| `ThrottlesExceptions(key, maxAttempts:, decay:, retryAfter:)` | after `maxAttempts` errors, jobs of `key` wait until `decay` is over. A job that threw goes back after `retryAfter`. Defaults: `maxAttempts` 10, `decay` 10 minutes, `retryAfter` zero |

Things to know:

- They keep their counts and locks in the default cache store. All workers must use the same store: `file` on one machine, or `redis` for several servers. A `memory` store is per process, so the limit would not work.
- A release counts as a try. A job that is released and has `tries` of 1 fails on its next pickup. Set `tries` above 1, or a `retryUntil`.
- The lock of `WithoutOverlapping` has no class name in it. Job classes with the same key share one lock. Put the class name in the key if they should not.

## Unique jobs

Some jobs should wait in the queue only once, like "rebuild the search index of product 5".
Add the opt-in `ShouldBeUnique` mixin.
While a job with the same class and `uniqueId` waits or runs, `dispatch()` pushes nothing and returns `''`.

```dart
@Job()
class UpdateSearchIndex extends DoxJob with ShouldBeUnique {
  UpdateSearchIndex({required this.productId});

  final int productId;

  @override
  String get uniqueId => '$productId';

  @override
  Duration? get uniqueFor => Duration(hours: 1);

  // ...
}
```

- `uniqueId` is the key next to the class. The default is empty: only one job of the class at a time.
- `uniqueFor` ends the lock after a time, also when the job never ran. `null` means no end.
- The worker frees the lock when the job is done, deleted or failed for good. A release or a retry keeps it.
- `ShouldBeUniqueUntilProcessing` frees the lock when a worker starts the job. A new job can then be queued while this one runs.
- The lock is in the default cache store. The web app and the workers must use the same store, like `redis`.
- `queue:clear` frees the locks of the jobs it deletes.
- `queue:retry` of a failed job does not take the lock.
- `dispatchSync()` ignores uniqueness.
- With `afterCommit` inside a transaction, the lock is taken at the commit. `dispatch()` returns the id at once, also when the job is then skipped.
- When a worker crashes, its lock stays. With no `uniqueFor`, the lock never ends, and `dispatch()` keeps returning `''`. So set `uniqueFor` on unique jobs.
- `Queue.fake()` keeps its own locks and needs no cache.

## Job chains

A chain runs jobs one after the other. The next job is pushed only when the job before it is done.

```dart
await Queue.chain(<DoxJob>[
  ResizeImage(imageId: 1),
  UploadImage(imageId: 1),
  TellUser(imageId: 1),
]).catchError(TellAdmin(imageId: 1)).dispatch(queue: 'images');
```

- The rest of the chain is saved in the job that runs now. So the chain works across worker processes and restarts.
- A job that is released or retried keeps the chain. The chain goes on only after the job is done.
- A job that ends with `delete()`, or that a middleware skips, counts as done. The chain goes on.
- When a job fails for good, the rest of the chain is dropped and the catch job runs.
- `queue:retry` of the failed job brings the chain back. When the job is then done, the chain goes on.
- `dispatch()` returns the id of the first job. `queue` and `connection` count for every job. `delay` counts for the first job only.
- The `sync` driver runs the jobs now, one after the other. When one throws, the catch job runs and `dispatch()` throws the error.

### The catch job

A function can not be saved in the queue. So the catch handler is a job too, of a class in `jobRegistry`. Run `dart run build_runner build` after you add it.
It runs once, in the worker where the job failed. It has no queue and no retry, like `dispatchSync()`.
Add the `CatchesError` mixin to read the error:

```dart
@Job()
class TellAdmin extends DoxJob with CatchesError {
  TellAdmin({required this.imageId});

  final int imageId;

  @override
  Future<void> handle() async {
    await alertAdmin('image $imageId failed: $caughtError');
  }
}
```

An error in the catch job is logged. For slow work, dispatch a new job from it.

### Chain traps

- Each job carries the data of the jobs after it. Keep chains short. Save ids in the jobs, not big data.
- A `ShouldBeEncrypted` job stays encrypted inside the job before it.
- A [unique job](#unique-jobs) in the chain that is skipped stops the chain. The catch job runs with a `StateError`. When the first job is skipped, `dispatch()` returns `''` and nothing runs.
- A next job that can not be read, for example when its class was removed, stops the chain. The catch job runs with the error.
- The worker pushes the next job before it deletes the job that is done. A crash between the two can run the next job twice. Make chain jobs safe to run twice.
- When the push of the next job fails, the try of the current job counts as failed, even though its `handle()` worked. The job is tried again. When no try is left, it fails and the catch job runs. With the default `tries` of 1 the first failed push does this. So give chain jobs more than one try.
- The unique lock of a job is freed before the next job is pushed. So a next job with the same unique id is not skipped.

## Job batches

A batch runs many jobs and acts when they are all done:

```dart
Batch batch = await Queue.batch(<DoxJob>[
  ImportRows(from: 0),
  ImportRows(from: 1000),
  ImportRows(from: 2000),
])
    .name('import')
    .then(ImportDone())
    .catchError(ImportFailed())
    .whenComplete(CleanUpImport())
    .dispatch(queue: 'imports');

print(batch.id);
```

### The table

A batch is saved in the `job_batches` table. It uses the database connection of `QueueConfig.connection`, also with the Redis driver and the `sync` driver.
Batches need `dox_queue_database`: install it, call `QueueDatabase.register()` in your queue provider, and run `dox queue:table`. See [step 4](#4-database-driver-and-tables).
Without the package, `Queue.batch()` throws a `StateError` that says to add `dox_queue_database`.

An app that does not use batches does not need the table. If you use batches, you need it with every driver.

### Callbacks

| Callback | Runs |
| --- | --- |
| `before(job)` | once, at `dispatch()`, before the jobs are pushed |
| `progress(job)` | each time a job is done. With `allowFailures()`, also when one fails |
| `then(job)` | once, when every job is done |
| `catchError(job)` | once, when the first job fails for good |
| `whenComplete(job)` | once, when every job ran, done or failed |

A function can not be saved in the queue. So each callback is a job of a class in `jobRegistry`. Run `dart run build_runner build` after you add one.
It runs once, in the process where the step happened. It has no queue and no retry, like `dispatchSync()`.
An error in a callback is logged. For slow work, dispatch a new job from it.
Add `Batchable` to read the batch, and `CatchesError` to read the error:

```dart
@Job()
class ImportFailed extends DoxJob with Batchable, CatchesError {
  @override
  Future<void> handle() async {
    Batch? batch = await this.batch();
    await alertAdmin('import ${batch?.name} failed: $caughtError');
  }
}
```

### Jobs of a batch

Add the opt-in `Batchable` mixin to a job to read its batch.
`batchId` is the id. `batch()` reads the batch as it is now.
A job can skip its work when the batch was cancelled:

```dart
@Job()
class ImportRows extends DoxJob with Batchable {
  ImportRows({required this.from});

  final int from;

  @override
  Future<void> handle() async {
    Batch? batch = await this.batch();
    if (batch?.cancelled ?? false) return;
    await importRows(from);
  }
}
```

A `Batch` has these fields:

| Field | What it holds |
| --- | --- |
| `id`, `name` | the id and the name |
| `totalJobs` | how many jobs the batch has |
| `pendingJobs` | how many jobs are not done. It also counts failed jobs, because they can be retried |
| `failedJobs` | how many jobs failed |
| `processedJobs` | how many jobs are done. Failed jobs are not counted |
| `progress` | the percent of done jobs, from 0 to 100 |
| `finished` | `true` when every job ran, or the batch was cancelled |
| `cancelled` | `true` after `cancel()`, or after a first failure |

A `Batch` is the state at the time it was read. Read it again with `Queue.findBatch(id)`. It gives `null` when there is no such batch.

- The first job that fails for good cancels the batch. Add `allowFailures()` to keep it going.
- `cancel()` does not stop the jobs. They still run and count. A `Batchable` job reads `cancelled` to skip its work.
- `add(jobs)` adds jobs to the batch, for example from a job of the batch. They go on the queue and connection of the batch. It throws a `StateError` when the batch is finished, cancelled or deleted. Then it pushes nothing.
- A failed job that you retry with `queue:retry` is not counted again when it fails again. When it is done, `pendingJobs` and `failedJobs` both go down by one. So `catchError` can run again when a later job fails.
- An empty batch throws an `ArgumentError`, because it would never finish.
- `then` and `whenComplete` run once, also with many workers. Each count changes in one atomic step.

### A chain inside a batch

Add `chain(jobs)` to put a chain in the batch. Its jobs run one after the other:

```dart
await Queue.batch(<DoxJob>[ImportUsers()])
    .chain(<DoxJob>[ImportOrders(), SumOrders()])
    .dispatch();
```

- The batch counts the chain as one job. It is done when its last job is done.
- When a job of the chain fails for good, the rest of the chain is dropped. The batch counts one failed job.
- The usual failure rules apply. The first failure cancels the batch, unless you call `allowFailures()`.
- When the first job of the chain is a skipped [unique job](#unique-jobs), the chain is taken out of the counts. A skipped later job fails the chain.
- `add(jobs)` takes jobs only, not chains.

### Batch traps

- A skipped [unique job](#unique-jobs) is taken out of `totalJobs` and `pendingJobs`. `progress` does not run for it. When it was the last open job, `then` and `whenComplete` run.
- When a push fails in `dispatch()` or `add()`, the jobs that were not pushed are taken out of the counts. The batch is cancelled and the error is thrown. The jobs that were pushed before still run, and the callbacks still fire for them.
- The counts follow the at-least-once rule of the queue. A job that runs twice, for example when it runs longer than `retryAfter`, can be counted twice. `failedJobs` never goes below 0.
- The batch is marked finished before `then` and `whenComplete` run. So `add()` from a callback throws a `StateError`.
- When a worker crashes after a job is done and before it counted the job, the batch keeps that job as pending. Then `then` and `whenComplete` never run. Prune such batches with `--unfinished`, see below.
- Inside a transaction, use `dispatch(afterCommit: true)`. Then the batch is saved and pushed only after the commit. See [Dispatch after the commit](#dispatch-after-the-commit).
- The `sync` driver runs the jobs at `dispatch()` and counts them. A job that throws counts as failed, and `dispatch()` does not throw.
- The queue events fire for the jobs of a batch like for any job. The batch has its own events too, see [Batch events](#batch-events).

### Prune old batches

```bash
dart run bin/queue.dart prune-batches --hours=48
dart run bin/queue.dart prune-batches --hours=48 --unfinished=168
```

The first line deletes batches that finished, or were cancelled, more than 48 hours ago. The default is 24.
`--unfinished=168` also deletes batches that never finished and were made more than 168 hours ago.
In code, use `Queue.pruneBatches(before, unfinishedBefore:)`.

## Queue events

Listen to the steps of a job:

```dart
Queue.before((QueueEvent event) => print('start ${event.name} ${event.id}'));
Queue.after((QueueEvent event) => print('done ${event.name}'));
Queue.failing((QueueEvent event) => alert(event.name, event.error));
```

| Hook | When |
| --- | --- |
| `Queue.queued` | `dispatch()` pushed a job |
| `Queue.before` | a worker starts a job |
| `Queue.after` | a worker finished a job and deleted it |
| `Queue.released` | a worker put a job back (`release()` or a retry) |
| `Queue.exceptionOccurred` | `handle()` threw and the job will be tried again |
| `Queue.failing` | a job failed for good |
| `Queue.looping` | a worker is about to take the next job |
| `Queue.stopping` | a worker stops |

A listener gets a `QueueEvent`:

| Field | What it holds |
| --- | --- |
| `type` | the kind of event |
| `job` | the job. `null` for `looping` and `stopping`, and when the worker can not read the job |
| `name` | the job name of the registry |
| `id` | the job id |
| `queue` | the queue name |
| `attempts` | the try number. `0` for `queued`, `looping` and `stopping` |
| `error`, `stack` | the error and its stack trace, for `exceptionOccurred` and `failing`. `batchFailed` has `error` only |
| `delay` | the wait, for `queued` and `released` |
| `batch` | the `Batch`, for the [batch events](#batch-events). `null` for other events |

- Listeners are per isolate. Register them where the app starts, like in a provider. Then the web app and each worker have them.
- A listener can be async. The queue waits for it.
- A listener that throws is logged. It never stops the worker or the dispatch.
- The `sync` driver, `dispatchSync()` and `dispatchAfterResponse()` fire no job events. The `sync` driver does fire the [batch events](#batch-events).
- `Queue.fake()` fires no events.
- `Queue.forgetListeners()` removes all listeners, for example between tests.

### Batch events

A batch has its own events. In these events, `event.batch` is the batch after the step. It holds the `id`, the `name` and the counts:

```dart
Queue.batchProgress((QueueEvent event) {
  Batch batch = event.batch!;
  print('${batch.name}: ${batch.progress}%');
});
Queue.batchFailed((QueueEvent event) => alert(event.batch!.id, event.error));
```

| Hook | When | Where it fires |
| --- | --- | --- |
| `Queue.batchDispatched` | the batch was saved, before its jobs are pushed | the process that called `dispatch()` |
| `Queue.batchProgress` | a job (or a chain) of the batch is done. With `allowFailures()`, also when one failed | the worker that counted it |
| `Queue.batchFailed` | the first job failed for good. `event.error` is its error | the worker that counted it |
| `Queue.batchCancelled` | the batch was cancelled: `cancel()`, the first failure without `allowFailures()`, or a push that threw | the process that cancelled it |
| `Queue.batchFinished` | every job ran, done or failed | the worker that counted the last job |

- Each event fires once per step, also with many workers.
- When one failure cancels the batch, `batchFailed` fires first. Then `batchCancelled` fires.
- With the `sync` driver, every event fires in the process that called `dispatch()`.
- `Queue.fake()` fires no batch events.

## Drivers

| Driver | Where jobs are | Needs |
| --- | --- | --- |
| `sync` | nowhere: `dispatch()` runs the job at once | nothing |
| `database` | the `jobs` and `failed_jobs` tables | `dox_queue_database`, and Postgres, MySQL 8+, MariaDB 10.6+ or SQLite |
| `redis` | Redis lists and sorted sets | Redis |

### Database driver

The database driver is in the `dox_queue_database` package. Install it and register it in your queue provider (see [step 4](#4-database-driver-and-tables)). Without the registration, `QueueConfig(driver: 'database')` throws an `ArgumentError` that names the package.

Jobs are rows in the `jobs` table. Failed jobs are rows in `failed_jobs`.

`failed_jobs.connection` has the name of the queue connection (see [Queue connections](#queue-connections)). It is NULL for the main connection.
A `failed_jobs` table without this column works too. Then the name is not saved. A worker checks for the column once, so restart the workers after you add it.
To add the column, write a migration:

```dart
await schema.table('failed_jobs', (Table table) {
  table.string('connection').nullable();
});
```

- On Postgres, MySQL and MariaDB a worker takes a job with `SELECT ... FOR UPDATE SKIP LOCKED`. Many workers do not wait on each other.
- On SQLite a worker takes a job with one `UPDATE ... RETURNING`. SQLite runs one write at a time, so this is safe. It is good for small apps.

Use another connection of `config/database.dart` with `QueueConfig(connection: 'postgres')`.

#### The failed_at column

`failed_jobs.failed_at` is the time the job failed. It has one of two types:

- A big integer: unix time in milliseconds. This is the default.
- A timestamp in UTC. Turn it on with `failedAtTimestamp: true`.

`FailedJob.failedAt` is the same `DateTime` with both types.

To make a new table with the timestamp column, pass the setting to `QueueTables.up` in the migration, and set it in the queue config too:

```dart
await QueueTables.up(schema, failedAtTimestamp: true);
```

```dart
QueueConfig queueConfig = QueueConfig(
  driver: 'database',
  jobs: jobRegistry,
  failedAtTimestamp: true,
);
```

The setting counts per connection. Each entry of `connections` has its own `failedAtTimestamp`, so two `database` connections can use tables of different types.

The setting and the column must match. A worker reads the column type once, when it first uses `failed_jobs`.

!!! warning "What happens when the setting and the column do not match"
    `fail`, `failed`, `retry`, `forget` and `prune-failed` throw a `StateError`. Nothing is written.

    A job that fails all its tries is NOT moved to `failed_jobs`, and its `failed()` hook does not run. The job stays in `jobs`. It comes back after `retryAfter` and runs again, with an error in the log each time. This goes on until the setting matches the table.

When the type can not be read (for example, the connection dropped), the worker reads it again on the next call. With the setting off, it logs a warning and goes on. With the setting on, the call throws that error, and nothing is written.

The column type on each database:

| Database | Column | How the time is kept |
| --- | --- | --- |
| SQLite | `TIMESTAMP` | ISO text in UTC, with milliseconds |
| Postgres | `TIMESTAMP` (without time zone) | the UTC time, with milliseconds |
| MySQL, MariaDB | `TIMESTAMP` | whole seconds, in UTC. The queue writes it with `FROM_UNIXTIME()` and reads it with `UNIX_TIMESTAMP()`, so the session time zone does not change the time. |

A MySQL and MariaDB `TIMESTAMP` can not hold a time after 2038-01-19.

#### Use the timestamp column on a table with the integer column

!!! warning "Stop all workers first, also on other servers"
    A worker reads the column type when it first uses `failed_jobs`, and keeps it. A worker that is still running writes numbers into the timestamp column. On SQLite this works without an error, and then pruning and the order by time are wrong.

1. Stop all workers, on every server. Stop the app too when it has `inProcess: true`.
2. Run the SQL for your database below, in a new migration (`await schema.driver.execute('...');` for each line) or in a database client.
3. Set `failedAtTimestamp: true` in the queue config.
4. Start the workers again.

SQLite (3.35 or newer):

```sql
ALTER TABLE failed_jobs ADD COLUMN failed_at_utc TIMESTAMP;
UPDATE failed_jobs SET failed_at_utc = strftime('%Y-%m-%dT%H:%M:%fZ', failed_at / 1000.0, 'unixepoch');
ALTER TABLE failed_jobs DROP COLUMN failed_at;
ALTER TABLE failed_jobs RENAME COLUMN failed_at_utc TO failed_at;
```

Postgres:

```sql
ALTER TABLE failed_jobs ALTER COLUMN failed_at TYPE TIMESTAMP USING to_timestamp(failed_at / 1000.0) AT TIME ZONE 'UTC';
```

MySQL and MariaDB:

```sql
ALTER TABLE failed_jobs ADD COLUMN failed_at_utc TIMESTAMP NULL;
UPDATE failed_jobs SET failed_at_utc = FROM_UNIXTIME(failed_at DIV 1000);
ALTER TABLE failed_jobs DROP COLUMN failed_at;
ALTER TABLE failed_jobs CHANGE failed_at_utc failed_at TIMESTAMP NOT NULL;
```

On SQLite the new column allows NULL, because SQLite can not add a NOT NULL column without a default. The queue never writes NULL there.

### Redis

```dart
QueueConfig queueConfig = QueueConfig(
  driver: 'redis',
  jobs: jobRegistry,
  redis: RedisOptions(host: env.redisHost, port: 6379),
);
```

To read the Redis server from the env, use `QueueConfig.redisFromEnv()`.
It reads `REDIS_URL` (for example `rediss://user:password@host:6380/0`, where `rediss` turns on TLS).
When `REDIS_URL` is not set, it reads `REDIS_HOST`, `REDIS_PORT`, `REDIS_USERNAME`, `REDIS_PASSWORD` and `REDIS_TLS`.
A key that is not set keeps the default of `RedisOptions`.

```dart
QueueConfig queueConfig = QueueConfig(
  driver: 'redis',
  jobs: jobRegistry,
  redis: QueueConfig.redisFromEnv(),
);
```

Each queue has a list of ready jobs, a sorted set of delayed jobs and a sorted set of reserved jobs.
A Lua script takes a job, so two workers never get the same one. Failed jobs are in the hash `dox_queue:failed`.

### Sync

`dispatch()` runs the job at once and waits for it. There is no worker, no retry and no delay.
When the job throws, `failed()` runs and `dispatch()` throws the error.
Use it for tests and for local work.

By default the sync driver runs the job object as it is.
So a job that is not in `jobRegistry`, or a field that is not JSON, works here and fails later in the worker.
Set `serializeSync: true` to save the job and read it back before it runs, the way a worker gets it:

```dart
Queue.configure(
  QueueConfig(driver: 'sync', jobs: jobRegistry, serializeSync: true),
);
```

Then `dispatch()` throws for such a job.

## Queue connections

One app can use more than one queue store.
The config is the main connection. Add more in `connections`, by name:

```dart
QueueConfig queueConfig = QueueConfig(
  driver: 'redis',
  jobs: jobRegistry,
  connections: <String, QueueConfig>{
    'database': QueueConfig(driver: 'database'),
  },
);
```

Pick a connection when you dispatch:

```dart
await SendReport(reportId: 1).dispatch(connection: 'database');
```

With no `connection`, the job goes to the main connection.
An unknown name throws an `ArgumentError`.

Run a worker for each connection. Every command of `bin/queue.dart` takes `--connection`:

```bash
dart run bin/queue.dart work
dart run bin/queue.dart work --connection=database
dart run bin/queue.dart failed --connection=database
```

- An entry uses only `driver`, `redis`, `prefix`, `connection` (the dox_orm one), `retryAfter` and `serializeSync`. The `jobs` of the main config count for all connections.
- The in-process worker (`inProcess`) runs the jobs of the main connection only.
- Two `database` connections on the same dox_orm connection share the `jobs` and `failed_jobs` tables. Give each one its own dox_orm connection. If they share, `failed --connection=X` lists all failed jobs of the table, not only those of X.
- `Queue.fake()` keeps the name in `PushedJob.connection`.

## Small apps: a worker in the web server

You can skip the worker process. Set `inProcess: true`:

```dart
QueueConfig queueConfig = QueueConfig(
  driver: 'database',
  jobs: jobRegistry,
  inProcess: true,
);
```

The first isolate of the web server then runs jobs too. When the server stops, it waits for the running jobs.

Only the web server runs this worker. The scheduler process (`bin/schedule.dart`) does not.

!!! warning "Heavy jobs slow down your API"
    The jobs share the isolate with web requests.
    A long or CPU heavy job makes requests on that isolate slow.
    Use a worker process when your jobs are heavy or many.

## Testing

Use the `sync` driver. `dispatch()` then runs the job at once, so you can check the result right after.

```dart
import 'package:dox_queue/dox_queue.dart';
import 'package:my_app/app/jobs/send_welcome_email.job.dart';
import 'package:my_app/generated/jobs.g.dart';
import 'package:test/test.dart';

void main() {
  setUp(() {
    Queue.configure(QueueConfig(driver: 'sync', jobs: jobRegistry));
  });

  test('sends the welcome email', () async {
    await SendWelcomeEmail(userId: 1).dispatch();
    // check the email was sent
  });
}
```

A job that uses `Dox()` (for example `Dox().ioc` or `Logger`) needs the app config. Call `Dox().initialize(appConfig)` in `setUpAll`.

To check that your code dispatched a job, without running it, use `Queue.fake()`. It records every `dispatch()` in a list. It does not run or save the jobs. It needs no `Queue.configure()`.

```dart
late QueueFake queue;

setUp(() {
  queue = Queue.fake();
});

tearDown(Queue.restore);

test('signing up queues the welcome email', () async {
  await signUp(userId: 1);

  queue.assertPushed<SendWelcomeEmail>();
  queue.assertPushed<SendWelcomeEmail>(
    (SendWelcomeEmail job) => job.userId == 1,
  );
  queue.assertPushedTimes<SendWelcomeEmail>(1);
  queue.assertNotPushed<SendInvoice>();
});
```

| Method | Checks |
|---|---|
| `assertPushed<T>([test])` | a `T` job was pushed. With `test`, one of them passes it |
| `assertPushedTimes<T>(n)` | exactly `n` `T` jobs were pushed |
| `assertNotPushed<T>()` | no `T` job was pushed |
| `assertNothingPushed()` | no job was pushed at all |
| `assertChained(<Type>[A, B])` | a chain of exactly these job classes, in this order, was dispatched |
| `assertBatched([test])` | a batch was dispatched. With `test`, one of them passes it. `test` gets a `PendingBatch` |
| `assertBatchedChain(<Type>[A, B])` | a batch has a chain of exactly these job classes, in this order |
| `assertBatchCount(n)` | exactly `n` batches were dispatched |

To read the jobs, use `queue.pushed`. Each item has the `job`, the `queue` name and the `delay`. `queue.jobsOf<T>()` gives the `T` jobs. `queue.clear()` forgets them. `Queue.restore()` stops the fake.

- `Queue.chain()` and `Queue.batch()` are kept too. Read chains in `queue.chains` and batches in `queue.batches`. The chains of a batch are in `PendingBatch.chains`. Their jobs are not in `queue.pushed`. Nothing is saved or run, and the batch tables are not needed. In a faked batch, `add()` adds to the batch, `cancel()` does nothing and `Queue.findBatch()` gives `null`.
- `dispatchSync()` runs the job now. `dispatchAfterResponse()` runs it after the answer, or soon outside a request. The fake does not stop them. It keeps their jobs in `queue.dispatchedSync` and `queue.dispatchedAfterResponse` (not in `queue.pushed`). `queue.clear()` empties these lists too.
- The fake does not encode the job. A job that is missing from `QueueConfig.jobs`, or has data that is not JSON, passes a faked test but fails for real.
- The fake also catches `Mail.queue()` on the default queue, but only when `Mail.fake()` is off. It does not catch a custom queue set with `Mail.useQueue()`. When both are on, `Mail.fake()` catches the email first. See [Mail](mail.md#testing).

To test a job alone, call `handle()`:

```dart
await SendWelcomeEmail(userId: 1).handle();
```

To test the queue itself, use the `database` driver of `dox_queue_database` with SQLite `:memory:`, and run a worker that stops when the queue is empty:

```dart
await Worker(
  driver: Queue.driver,
  jobs: jobRegistry,
  options: WorkerOptions(stopWhenEmpty: true),
).run();
```

## Without Dox

`dox_queue` also works in a plain Dart app. Add `build_runner`, so it writes `lib/generated/jobs.g.dart`:

```bash
dart pub add dox_queue dox_core
dart pub add dev:build_runner
```

Write your jobs like in [Write a job](#write-a-job), and run `dart run build_runner build`.
Then set up the queue and run a worker yourself:

```dart
import 'dart:async';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_queue/dox_queue.dart';
import 'package:my_app/generated/jobs.g.dart';
import 'package:my_app/jobs/resize_image.dart';

Future<void> main() async {
  // the worker logs with the Dox logger, so it needs an AppConfig
  Dox().initialize(AppConfig(appKey: 'not-used'));

  Queue.configure(QueueConfig(
    driver: 'redis',
    jobs: jobRegistry,
    redis: RedisOptions(host: '127.0.0.1', port: 6379),
  ));

  await ResizeImage(path: 'photo.png').dispatch();

  Worker worker = Worker(
    driver: Queue.driver,
    jobs: jobRegistry,
    options: WorkerOptions(queues: <String>['default'], concurrency: 4),
  );

  // Ctrl+C: finish the running jobs, then stop
  StreamSubscription<ProcessSignal> signal =
      ProcessSignal.sigint.watch().listen((_) => worker.stop());
  await worker.run();
  await signal.cancel();
  await Queue.close();
}
```

- `WorkerOptions` takes the same settings as the flags of `work`: `queues`, `concurrency`, `once`, `tries`, `timeout`, `sleep` and `stopWhenEmpty`.
- The `database` driver needs `dox_queue_database`. Call `QueueDatabase.register()` before `Queue.configure()`. It uses the default `dox_orm` connection. Set it up first with `SqlQueryBuilder.initializeWithDatabaseConfig(...)`.
- No services are in the Dox container. Make the services of a job in `handle()`.
