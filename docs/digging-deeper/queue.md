---
icon: lucide/list-ordered
---

# Queue

A queue runs slow work in the background, so the request can answer at once.

Some tasks take too long to do during a request, like sending an email, calling a slow API, making a report or resizing an image. You put these tasks on a queue as jobs. A worker process then takes each job and runs it.

The `dox_queue` package gives you jobs, retries, delays and a worker. It has a `redis` driver and a `sync` driver. The `database` driver is in the `dox_queue_database` package.

## Setup

A new app from `dox create` already has the queue. In other apps, run:

```bash
dox add queue
```

The default driver is `database`. Add `--driver=redis` or `--driver=sync` to pick another one. The command adds the package and writes the config, the provider, `bin/queue.dart` and a sample job. It never overwrites a file, so it is safe to run twice.

With `database`, it also adds `dox_queue_database` and the migration for the jobs tables, so run `dox add orm` first. With `redis`, it adds the `REDIS_*` keys.

The sections below show the files it writes. Check them, and change the driver if you want. To set it up by hand, run `dart pub add dox_queue` and write the same files.

### Configuration

The queue config picks the driver and lists your jobs:

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

`jobRegistry` holds every job class of your app. `dart run build_runner build` writes it, because the job builder is in `dox_builder`, which your app already runs. See [All options](#all-options) for the other settings.

Dox has three drivers:

- `sync`: `dispatch()` runs the job at once and waits for it. There is no worker, no retry and no delay. Use it for tests and local work.
- `database`: jobs are rows in the `jobs` table. It needs `dox_queue_database`, and Postgres, MySQL 8+, MariaDB 10.6+ or SQLite.
- `redis`: jobs are kept in Redis.

!!! warning "Keep `retryAfter` bigger than your longest job"
    `retryAfter` (default 90 seconds) is how Dox finds the job of a crashed worker.
    A job that runs longer than `retryAfter` looks crashed, so a second worker runs it again.

### The provider

The provider sets up the queue in every isolate. Put it in `lib/providers/`, so the generated container finds it:

```dart title="lib/providers/queue_provider.dart"
import 'package:dox_queue/dox_queue.dart';

import '../config/queue.dart';

/// Sets up the queue. Dox finds every DoxProvider class,
/// see lib/generated/container.g.dart.
class AppQueueProvider extends QueueProvider {
  AppQueueProvider() : super(queueConfig);
}
```

### The worker file

The worker runs from `bin/queue.dart`. It starts the providers of your app (database, cache, queue), but not the HTTP server:

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

### Database driver

The `database` driver, [job batches](#job-batching) and [dispatching after the commit](#dispatching-after-the-commit) are in the `dox_queue_database` package. If you use only Redis or sync and none of these, skip this step.

```bash
dart pub add dox_queue_database
```

Then make your queue provider extend `DatabaseQueueProvider` in place of `QueueProvider`. This turns the package on. Without it, `QueueConfig(driver: 'database')` throws an `ArgumentError` that names the package.

```dart title="lib/providers/queue_provider.dart"
import 'package:dox_queue_database/dox_queue_database.dart';

import '../config/queue.dart';

class AppQueueProvider extends DatabaseQueueProvider {
  AppQueueProvider() : super(queueConfig);
}
```

The database driver needs the `jobs` and `failed_jobs` tables. Batches need the `job_batches` table, with every driver. `dox queue:table` writes a migration in `db/migration` that makes all three:

```bash
dox queue:table
dox migrate
```

The migration looks like this, so you can also write it by hand:

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

To keep the jobs in another database connection of `config/database.dart`, use `QueueConfig(connection: 'postgres')`.

#### Adding the pop indexes to an old table

A new `jobs` table has the indexes a worker needs to find the next job fast. A table you made earlier works too, but a poll can read every waiting job. To add the indexes, write a new migration. It adds only the indexes the table does not have, so you can run it more than once:

```dart title="db/migration/2026_11_20_000000_add_queue_pop_index.dart"
// ignore_for_file: file_names
import 'package:dox_migration/dox_migration.dart';
import 'package:dox_queue_database/dox_queue_database.dart';

class AddQueuePopIndex extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await QueueTables.popIndex(schema);
  }

  @override
  Future<void> down(Schema schema) async {}
}
```

On MySQL and MariaDB it does nothing, because the index on `queue` is enough.

### Redis driver

Set the driver to `redis` and give the Redis server:

```dart
QueueConfig queueConfig = QueueConfig(
  driver: 'redis',
  jobs: jobRegistry,
  redis: RedisOptions(host: env.redisHost, port: 6379),
);
```

A Redis command that gets no reply in 10 seconds fails with `RedisTimeoutError`, and the client reconnects. This stops a Redis outage from hanging every request. Change it with `commandTimeout`. `null` turns it off. Blocking commands and subscriber connections never time out.

To cap the commands that wait for a connection, set `maxQueuedCommands`. One more fails at once with `RedisQueueFullError`. It is off by default:

```dart
QueueConfig queueConfig = QueueConfig(
  driver: 'redis',
  jobs: jobRegistry,
  redis: RedisOptions(
    host: env.redisHost,
    port: 6379,
    commandTimeout: Duration(seconds: 5),
    maxQueuedCommands: 1000,
  ),
);
```

You can also read the Redis server from the env with `QueueConfig.redisFromEnv()`:

```dart
QueueConfig queueConfig = QueueConfig(
  driver: 'redis',
  jobs: jobRegistry,
  redis: QueueConfig.redisFromEnv(),
);
```

It reads `REDIS_URL`, like `rediss://user:password@host:6380/0`, where `rediss` turns on TLS. If `REDIS_URL` is not set, it reads `REDIS_HOST`, `REDIS_PORT`, `REDIS_USERNAME`, `REDIS_PASSWORD` and `REDIS_TLS`. A key that is not set keeps the default of `RedisOptions`.

## Creating jobs

### Generating job classes

`dox make:job` makes a new job file in `lib/app/jobs/`:

```bash
dox make:job SendWelcomeEmail
```

### Class structure

A job is a class with `@Job()` that extends `DoxJob`. The worker calls its `handle()` method:

```dart title="lib/app/jobs/send_welcome_email.job.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_queue/dox_queue.dart';

@Job()
class SendWelcomeEmail extends DoxJob {
  SendWelcomeEmail({required this.userId});

  final int userId;

  @override
  Future<void> handle() async {
    MailService mail = Dox().ioc.get<MailService>();
    await mail.sendWelcome(userId);
  }
}
```

Run `dart run build_runner build` after you add or change a job. It writes `lib/generated/jobs.g.dart`, which knows how to save and load each job.

### Job data

The parameters of the unnamed constructor are saved with the job. Each parameter needs a field or getter with the same name. These types work:

- `int`, `double`, `num`, `String`, `bool`
- `DateTime`
- enums (saved by name)
- `List` and `Map<String, ...>` of these, also nested
- `dynamic` and `Object` (the value must be JSON)
- nullable versions of all of them

Any other type stops the build with a clear message.

!!! tip "Save an id, not an object"
    Do not save a `User`. Save the `userId`, and load the user in `handle()`.
    The user may change between dispatch and run, so the id gives you fresh data.

### Using services in a job

A job is made again from its saved data, so it can not get services in its constructor. Get them in `handle()` from the Dox container:

```dart
UserService users = Dox().ioc.get<UserService>();
```

The worker runs `registerContainer`, so every `@Inject()` class of your app is there.

### Setting the number of tries

By default a job runs once. If you want the worker to try again when `handle()` throws, set `tries`. Use `backoff` to wait between the tries:

```dart
/// run up to 3 times
@override
int get tries => 3;

/// wait 10 seconds before the 2nd try, 60 seconds before the 3rd
@override
List<Duration> get backoff => const <Duration>[
  Duration(seconds: 10),
  Duration(seconds: 60),
];
```

The last `backoff` entry is used for all later tries. With no `backoff`, the retry happens at once.

There are three more settings for retries:

- `retryUntil` retries until a time, in place of a number of tries. It is read once, when the job is dispatched.
- `maxExceptions` fails the job after this many tries that threw an error. A timeout does not count.
- `failOnTimeout` fails the job at once when a try times out, with no retry.

### Setting a timeout

`timeout` is the max run time of one try. The default is the worker `--timeout`, which is 60 seconds:

```dart
/// stop a try after 30 seconds
@override
Duration? get timeout => const Duration(seconds: 30);
```

### Choosing the queue

Jobs go on the `default` queue. You can give a job its own queue, so a worker can run it first or apart:

```dart
/// the queue of this job
@override
String get queue => 'emails';
```

### Handling failed jobs

`failed()` runs once, after the last try failed. Use it to tell someone, or to clean up:

```dart
/// runs once, after the last try failed
@override
Future<void> failed(Object error, StackTrace stack) async {
  // tell someone, or clean up
}
```

### Encrypting job data

If a job holds private data, add the `ShouldBeEncrypted` mixin. Then a person who can read Redis or the `jobs` table can not read the data:

```dart
@Job()
class ChargeCard extends DoxJob with ShouldBeEncrypted {
  // ...
}
```

The data is encrypted with the app key (`AppConfig.appKey`), so the worker needs the same key, or one of `AppConfig.previousKeys`. The job name, the queue and the id stay plain text.

### Renaming a job class

The class name is saved with each job. So when you rename a class, queued jobs with the old name can not be found. Keep the old name with `name`:

```dart
@Job(name: 'SendWelcomeEmail')
```

## Dispatching jobs

Call `dispatch()` to put a job on the queue. It returns the job id:

```dart
await SendWelcomeEmail(userId: user.id).dispatch();
```

`Queue.dispatch()` does the same:

```dart
await Queue.dispatch(SendWelcomeEmail(userId: user.id));
```

### Delayed dispatching

Sometimes a job should wait before it runs. Use `delay`. You can also pick another queue here:

```dart
await SendWelcomeEmail(userId: 1).dispatch(
  delay: Duration(minutes: 10),
  queue: 'emails',
);
```

To wait until a fixed time, use `delayUntil`. Give `delay` or `delayUntil`, not both:

```dart
await SendWelcomeEmail(userId: 1).dispatch(
  delayUntil: DateTime.utc(2030, 1, 1, 9),
);
```

### Conditional dispatching

`dispatchIf` dispatches only when the condition is true, and `dispatchUnless` only when it is false. They return null when the job was not dispatched:

```dart
await SendWelcomeEmail(userId: 1).dispatchIf(user.wantsEmail);
await SendWelcomeEmail(userId: 1).dispatchUnless(user.isBlocked);
```

### Synchronous dispatching

`dispatchSync` runs the job now, in this process, with no queue:

```dart
await SendWelcomeEmail(userId: 1).dispatchSync();
```

### Dispatching after the response

Sometimes a job is short, but the client should not wait for it. `dispatchAfterResponse` runs the job in this process after the answer is sent:

```dart
SendWelcomeEmail(userId: 1).dispatchAfterResponse();
```

Do not `await` it, because it returns nothing. The job does not go on the queue, so it has no job id and no retry. If the job throws, its `failed()` runs and the error goes to the exception handler, never to the client. If the server stops before the job runs, the job is lost.

### Dispatching after the commit

If you dispatch a job inside a database transaction, it is pushed at once. Then a worker can run it before the transaction commits, or after it rolls back. So the job reads data that is not saved yet, or is never saved.

Use `afterCommit: true` to wait for the commit. This needs [`dox_queue_database`](#database-driver):

```dart
await QueryBuilder.transaction(() async {
  User user = await User().create(<String, dynamic>{'email': email});
  await SendWelcomeEmail(userId: user.id).dispatch(afterCommit: true);
});
```

- The job is pushed after the outermost transaction commits.
- If the transaction rolls back, the job is not pushed.
- Outside a transaction, the job is pushed at once.
- `dispatch()` still returns the job id at once.

To do this for every dispatch, set `QueueConfig(afterCommit: true)`. Then `afterCommit: false` on one dispatch pushes that job at once. Chains and batches take `afterCommit` too. See [Dispatch after the commit details](#dispatch-after-the-commit-details) for special cases.

### Queueing an email

You do not need a job class to send an email later. With [dox_mailer](mail.md#queue-an-email), call `Mail.queue()`:

```dart
await Mail.queue(message);
await Mail.later(Duration(minutes: 10), message, queue: 'emails');
```

The mail jobs are part of dox_mailer, so the queue provider and a worker run them.

## Running the worker

Start a worker to run the jobs:

```bash
dart run bin/queue.dart
```

Use `--queue` to pick the queues. The first one goes first. Use `--concurrency` to run more jobs at once:

```bash
dart run bin/queue.dart work --queue=emails,default --concurrency=4
```

`--concurrency` runs jobs as async tasks on one thread. It helps for jobs that wait, like email, HTTP or database calls. For CPU heavy jobs, run more worker processes. See [Worker flags](#worker-flags) for all flags.

The `dox` CLI runs the same file, with the same flags: `dox queue:work`, `dox queue:failed`, `dox queue:retry <id|all>`, `dox queue:forget <id>`, `dox queue:flush`, `dox queue:clear [queue]`, `dox queue:restart` and `dox queue:prune-failed`.

### Stopping the worker

Press Ctrl+C, or send SIGTERM (`docker stop` does it). The worker takes no new job, waits for the running jobs, then stops. A second signal stops it at once.

### Restarting after a deploy

The worker keeps your code in memory. So restart it after each deploy, or it runs the old code:

```bash
dart run bin/queue.dart restart
```

This tells every running worker to stop after its current jobs, and your process manager starts them again with the new code. It works through the app cache, so the workers and the command must use the same cache store, like `file` on one machine, or `redis`. The `memory` store does not work for it.

### Running the worker in production

In production, run the binary, not `dart run`. `dox build` makes `build/bundle/bin/queue`, next to the server. It takes the same commands and flags:

```bash
cd build/bundle
./bin/queue work --concurrency=4
```

Run the worker as its own process, next to the web server. For example, with Docker Compose and the image of the project `Dockerfile`:

```yaml
services:
  web:
    build: .
    command: /app/bin/server
  worker:
    build: .
    command: /app/bin/queue work --concurrency=4
```

You can also use systemd, Supervisor or a second Fly.io process. Set it to restart when it stops.

### Running jobs in the web server

A small app can skip the worker process. Set `inProcess: true`, and the first isolate of the web server runs jobs too:

```dart
QueueConfig queueConfig = QueueConfig(
  driver: 'database',
  jobs: jobRegistry,
  inProcess: true,
);
```

When the server stops, it waits for the running jobs. Only the web server runs this worker, not the scheduler process (`bin/schedule.dart`).

!!! warning "Heavy jobs slow down your API"
    The jobs share the isolate with web requests, so a long or CPU heavy job makes requests on that isolate slow.
    Use a worker process when your jobs are heavy or many.

## Dealing with failed jobs

When `handle()` throws, the worker waits the `backoff` time and tries again, up to `tries` times. After the last try, the job goes to the failed jobs, and `failed()` runs. A timeout counts as a failed try.

!!! info "A timeout does not stop the code"
    Dart can not stop a running `Future`. After a timeout the try counts as failed, but `handle()` keeps running in the background until it ends.
    So write jobs that are safe to run twice.

If you want the worker to wait for the old run, start it with `--timeout-grace=SECONDS` (or set `workerTimeoutGrace` for the in-process worker). Keep `timeout` plus the grace time below `retryAfter`.

When a worker crashes, its job stays reserved. After `retryAfter`, another worker takes it, and this counts as a try.

### Retrying failed jobs

Failed jobs are kept until you retry or delete them. List them with `failed`, and put one or all of them back on their queue with `retry`:

```bash
dart run bin/queue.dart failed
dart run bin/queue.dart retry 6f1c0e...
dart run bin/queue.dart retry all
```

### Deleting failed jobs

`forget` deletes one failed job, and `flush` deletes all of them:

```bash
dart run bin/queue.dart forget 6f1c0e...
dart run bin/queue.dart flush
```

`prune-failed` deletes failed jobs older than `--hours=N` (default 24):

```bash
dart run bin/queue.dart prune-failed --hours=48
```

### Controlling the job from handle()

Sometimes the job itself knows what should happen next. For example, an API is busy, so the job should try again later. Add the `InteractsWithQueue` mixin, then call one of these in `handle()`:

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

`release()` counts as a try. Because the default `tries` is 1, set `tries` above 1 (or `retryUntil`) when a job calls `release()`. If not, the job fails on its next pickup.

### Clearing jobs from a queue

`clear` deletes all jobs of a queue, also the running ones. The default queue is `default`:

```bash
dart run bin/queue.dart clear emails
```

## Job middleware

Job middleware wraps `handle()` of a job. Use it for rules that many jobs share, like a rate limit. Add the `HasMiddleware` mixin and list the middleware. The first one runs first:

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
  ];

  // ...
}
```

The built-in middleware keeps its counts and locks in the default cache store. So all workers must use the same store: `file` on one machine, or `redis` for several servers. The `memory` store is per process, so the limit would not work.

A middleware that puts the job back counts as a try. So give these jobs `tries` above 1, or a `retryUntil`.

### Rate limiting

`RateLimited(key, max, per)` runs at most `max` jobs of `key` in each `per` window. The other jobs go back on the queue until the window ends:

```dart
RateLimited('report-api', 10, Duration(minutes: 1)),
```

### Preventing job overlaps

`WithoutOverlapping(key)` runs only one job of `key` at a time:

```dart
WithoutOverlapping(
  'report-$reportId',
  releaseAfter: Duration(seconds: 30),
  expireAfter: Duration(minutes: 10), // longer than the longest report run
),
```

- `releaseAfter` is when the other jobs go back on the queue. The default is zero, so at once. With `releaseAfter: null`, they are dropped.
- `expireAfter` frees the lock after this time, also while a job still runs. The default is no expiry. Set it longer than the longest run of the job, so a crash can not hold the lock forever.
- The key has no class name in it, so job classes with the same key share one lock. Put the class name in the key if they should not.

### Throttling exceptions

`ThrottlesExceptions(key, maxAttempts:, decay:, retryAfter:)` is for jobs that call a service that is down. After `maxAttempts` errors (default 10), jobs of `key` wait until `decay` is over (default 10 minutes). A job that threw goes back after `retryAfter` (default zero).

### Writing your own middleware

Extend `JobMiddleware`. Call `next()` to go on. If you do not call it, the job is skipped and counts as done. Call `release(job, delay)` to put the job back on the queue:

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

## Unique jobs

Some jobs should wait in the queue only once, like "rebuild the search index of product 5". Add the `ShouldBeUnique` mixin. While a job with the same class and `uniqueId` waits or runs, `dispatch()` pushes nothing and returns `''`:

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

- `uniqueId` is the key next to the class. The default is empty, so only one job of the class at a time.
- `uniqueFor` ends the lock after a time, also when the job never ran. You should set it, because the lock of a crashed worker never ends without it.
- The worker frees the lock when the job is done, deleted or failed for good. A release or a retry keeps it.
- The lock is in the default cache store, so the web app and the workers must use the same store, like `redis`.

If a new job may be queued while the old one runs, use `ShouldBeUniqueUntilProcessing` in place of `ShouldBeUnique`. It frees the lock when a worker starts the job.

## Job chaining

A chain runs jobs one after the other. The next job is pushed only when the job before it is done. If a job fails for good, the rest of the chain is dropped and the catch job runs:

```dart
await Queue.chain(<DoxJob>[
  ResizeImage(imageId: 1),
  UploadImage(imageId: 1),
  TellUser(imageId: 1),
]).catchError(TellAdmin(imageId: 1)).dispatch(queue: 'images');
```

The rest of the chain is saved in the job that runs now, so the chain works across worker processes and restarts. `dispatch()` returns the id of the first job. `queue` and `connection` count for every job, but `delay` counts for the first job only.

Each job carries the data of the jobs after it. So keep chains short, and save ids in the jobs, not big data. Give chain jobs more than one try, and make them safe to run twice.

### Handling chain failures

A function can not be saved in the queue. So the catch handler is a job too, of a class in `jobRegistry`. Add the `CatchesError` mixin to read the error:

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

The catch job runs once, in the worker where the job failed, with no queue and no retry. An error in it is logged. For slow work, dispatch a new job from it.

`queue:retry` of the failed job brings the chain back. When the job is then done, the chain goes on.

## Job batching

A batch runs many jobs and acts when they are all done. Batches need [`dox_queue_database`](#database-driver) and the `job_batches` table, with every driver. Without the package, `Queue.batch()` throws a `StateError`.

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

The batch is saved in the `job_batches` table of the `QueueConfig.connection` database, also with the Redis and `sync` drivers.

### Batch callbacks

These callbacks run at the steps of a batch:

| Callback | Runs |
| --- | --- |
| `before(job)` | once, at `dispatch()`, before the jobs are pushed |
| `progress(job)` | each time a job is done. With `allowFailures()`, also when one fails |
| `then(job)` | once, when every job is done |
| `catchError(job)` | once, when the first job fails for good |
| `whenComplete(job)` | once, when every job ran, done or failed |

A function can not be saved in the queue, so each callback is a job of a class in `jobRegistry`. It runs once, with no queue and no retry. An error in a callback is logged. Add `Batchable` to read the batch, and `CatchesError` to read the error:

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

### Defining batchable jobs

Add the `Batchable` mixin to a job to read its batch. `batchId` is the id, and `batch()` reads the batch as it is now. For example, a job can skip its work when the batch was cancelled:

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

### Inspecting batches

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

A `Batch` shows the state at the time it was read. To read it again, use `Queue.findBatch(id)`. It gives `null` when there is no such batch.

### Cancelling batches

The first job that fails for good cancels the batch. If you want the batch to go on, add `allowFailures()`. You can also cancel a batch yourself with `cancel()`. This does not stop the jobs: they still run and count, so a `Batchable` job should read `cancelled` to skip its work.

### Adding jobs to a batch

`add(jobs)` adds jobs to a batch, for example from a job of the batch. They go on the queue and connection of the batch. It throws a `StateError` when the batch is finished, cancelled or deleted.

### Chains in a batch

Use `chain(jobs)` to put a chain in a batch. Its jobs run one after the other, and the batch counts the chain as one job:

```dart
await Queue.batch(<DoxJob>[ImportUsers()])
    .chain(<DoxJob>[ImportOrders(), SumOrders()])
    .dispatch();
```

When a job of the chain fails for good, the rest of the chain is dropped, and the batch counts one failed job.

### Pruning batches

Old batch rows stay in the table until you delete them. `prune-batches` deletes batches that finished, or were cancelled, more than `--hours` ago (default 24). Add `--unfinished` to also delete batches that never finished and were made more than that many hours ago:

```bash
dart run bin/queue.dart prune-batches --hours=48
dart run bin/queue.dart prune-batches --hours=48 --unfinished=168
```

In code, use `Queue.pruneBatches(before, unfinishedBefore:)`.

## Queue events

Sometimes you want to log or count jobs. Listen to the steps of a job:

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

Listeners are per isolate. So register them where the app starts, like in a provider. Then the web app and each worker have them. A listener can be async, and a listener that throws is only logged. See [Event details](#event-details) for the fields of `QueueEvent`.

### Batch events

A batch has its own events. In them, `event.batch` is the batch after the step:

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

Each event fires once per step, also with many workers. When one failure cancels the batch, `batchFailed` fires first, then `batchCancelled`.

## Queue connections

Sometimes one app needs more than one queue store. The config is the main connection. Add more in `connections`, by name:

```dart
QueueConfig queueConfig = QueueConfig(
  driver: 'redis',
  jobs: jobRegistry,
  connections: <String, QueueConfig>{
    'database': QueueConfig(driver: 'database'),
  },
);
```

Pick a connection when you dispatch. With no `connection`, the job goes to the main connection. An unknown name throws an `ArgumentError`:

```dart
await SendReport(reportId: 1).dispatch(connection: 'database');
```

Run a worker for each connection. Every command of `bin/queue.dart` takes `--connection`:

```bash
dart run bin/queue.dart work
dart run bin/queue.dart work --connection=database
dart run bin/queue.dart failed --connection=database
```

- An entry uses only `driver`, `redis`, `prefix`, `connection` (the dox_orm one), `retryAfter`, `serializeSync` and `failedAtTimestamp`. The `jobs` of the main config count for all connections.
- The in-process worker (`inProcess`) runs the jobs of the main connection only.
- Two `database` connections on the same dox_orm connection share the `jobs` and `failed_jobs` tables. So give each one its own dox_orm connection.

## Using the queue without Dox

`dox_queue` also works in a plain Dart app. Add `build_runner` and `dox_builder`, so it writes `lib/generated/jobs.g.dart`:

```bash
dart pub add dox_queue dox_core
dart pub add dev:build_runner dev:dox_builder
```

Write your jobs as in [Creating jobs](#creating-jobs), and run `dart run build_runner build`. Then set up the queue and run a worker yourself:

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
- The `database` driver needs `dox_queue_database`. There are no providers here, so call `QueueDatabase.register()` before `Queue.configure()`. It uses the default `dox_orm` connection, so set that up first with `SqlQueryBuilder.initializeWithDatabaseConfig(...)`.
- No services are in the Dox container, so make the services of a job in `handle()`.

## Testing

### Running jobs in tests

Use the `sync` driver. `dispatch()` then runs the job at once, so you can check the result right after:

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

The sync driver runs the job object as it is. So a job that is not in `jobRegistry`, or a field that is not JSON, works here and fails later in the worker. Set `serializeSync: true` to save the job and read it back before it runs, the way a worker gets it. Then `dispatch()` throws for such a job:

```dart
Queue.configure(
  QueueConfig(driver: 'sync', jobs: jobRegistry, serializeSync: true),
);
```

To test a job alone, call `handle()`:

```dart
await SendWelcomeEmail(userId: 1).handle();
```

### Faking the queue

If you only want to check that your code dispatched a job, without running it, use `Queue.fake()`. It records every `dispatch()` in a list, and needs no `Queue.configure()`:

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

To read the jobs, use `queue.pushed`. Each item has the `job`, the `queue` name and the `delay`. `queue.jobsOf<T>()` gives the `T` jobs, `queue.clear()` forgets them, and `Queue.restore()` stops the fake.

The fake does not encode the job. So a job that is missing from `QueueConfig.jobs`, or has data that is not JSON, passes a faked test but fails for real.

### Testing the queue itself

To test the real queue, use the `database` driver of `dox_queue_database` with SQLite `:memory:`. Then run a worker that stops when the queue is empty:

```dart
await Worker(
  driver: Queue.driver,
  jobs: jobRegistry,
  options: WorkerOptions(stopWhenEmpty: true),
).run();
```

## Details

This section is for special cases. Most apps do not need it.

### All options

| Option | Default | What it does |
| --- | --- | --- |
| `driver` | `sync` | `sync`, `database` (needs `dox_queue_database`) or `redis` |
| `jobs` | empty | `jobRegistry` from `lib/generated/jobs.g.dart` |
| `redis` | 127.0.0.1:6379 | `RedisOptions(host: ..., port: ..., password: ...)` for the `redis` driver. `QueueConfig.redisFromEnv()` reads it from the env |
| `prefix` | `dox_queue:` | the start of every Redis key |
| `connection` | default | the dox_orm connection name, for `dox_queue_database` |
| `retryAfter` | 90 seconds | when a worker does not finish a job in this time, another worker can take it |
| `inProcess` | `false` | run a worker inside the web server, see [Running jobs in the web server](#running-jobs-in-the-web-server) |
| `workerQueues` | `['default']` | the queues of the in-process worker |
| `workerConcurrency` | `1` | jobs at once in the in-process worker |
| `workerTimeoutGrace` | none | the `--timeout-grace` wait of the in-process worker |
| `serializeSync` | `false` | the `sync` driver saves the job and reads it back before it runs |
| `connections` | none | more queue connections by name, see [Queue connections](#queue-connections) |
| `afterCommit` | `false` | push jobs that are dispatched inside a transaction only after it commits (needs `dox_queue_database`) |
| `failedAtTimestamp` | `false` | the `failed_at` column is a timestamp, not a number, see [The failed_at column](#the-failed_at-column) |

### Worker flags

| Flag | Default | What it does |
| --- | --- | --- |
| `--queue=high,default` | `default` | the queues to work. The first one goes first |
| `--concurrency=4` | `1` | jobs at once in this process |
| `--once` | off | run one job, then stop |
| `--tries=3` | `1` | tries of a job that does not set `tries` |
| `--timeout=60` | `60` | max run time in seconds of a job that does not set `timeout` |
| `--sleep=3` | `3` | seconds to wait when the queues are empty |
| `--max-sleep=30` | off | when the queues stay empty, double the sleep on each empty poll, up to this many seconds. A job sets it back to `--sleep` |
| `--stop-when-empty` | off | stop when the queues are empty |
| `--timeout-grace=10` | none | after a timeout, wait up to this many seconds for the old run to end before the next try |
| `--backoff=1,5,10` | none | seconds to wait before each retry of a job that does not set `backoff` |
| `--max-jobs=1000` | off | stop after this many jobs |
| `--max-time=3600` | off | stop after this many seconds |
| `--memory=256` | off | stop when the process uses more than this many MB |
| `--connection=name` | main | the [queue connection](#queue-connections) to use |

With `--max-jobs`, `--max-time` and `--memory`, the worker stops after its running jobs, so let your process manager start it again.

### Worker details

- The worker logs one warning when a job may run longer than `retryAfter` (the `--timeout`, the `timeout` of a job class, and the grace time all count). Then a second worker can take the job while the first one still runs it. Raise `retryAfter` or lower the timeout.
- While the worker waits for `--timeout-grace`, it takes no other job. If `timeout` plus the grace time is above `retryAfter`, another worker can take the job while this one waits.
- When a crashed worker's job has no tries left, it fails with a message that the worker did not finish.
- `restart` writes a time to the app cache, and each worker reads it every 3 seconds.
- With `InteractsWithQueue`, the worker does the call when `handle()` ends. When you call more than one, the last one wins. A call also wins over an error that `handle()` throws after it. When `handle()` times out, the call is dropped.
- With `dispatchSync()`, `dispatchAfterResponse()` and the `sync` driver there is no queue. There `attempts()` is 1, `release()` and `delete()` do nothing, and `fail()` only runs `failed()`.
- In a test file, `package:test` has its own `fail()`. Inside a job class with `InteractsWithQueue`, write `this.fail(...)` to make it clear which one you call.
- Job middleware also runs with the `sync` driver, `dispatchSync()` and `dispatchAfterResponse()`. There is no queue there, so a release logs a warning and `handle()` does not run.
- `dispatchAfterResponse()` works because `QueueProvider` turns on `AfterResponse`. Outside a request, the job runs soon.

### Dispatch after the commit details

- `afterCommit` needs `dox_queue_database`. Without it, a dispatch with `afterCommit` on throws a `StateError`.
- A job that is not in the registry, or data that is not JSON, throws at `dispatch()`, not at the commit.
- When the push fails after the commit, the `QueryBuilder.transaction()` call throws that error. The data stays saved.
- It waits only for a transaction on the default dox_orm connection, opened with no `connection:` name. A transaction opened by name pushes the job at once.
- The `sync` driver runs the job after the commit. A `sync` chain runs as a whole after the commit, and gets a new id.
- A batch saves its `job_batches` row and pushes its jobs after the commit. A rollback drops it all. Before the commit, the returned `Batch` is not saved yet.
- `dispatchSync()` and `dispatchAfterResponse()` do not wait for a commit.
- `Queue.fake()` keeps the job when you call `dispatch()`, also when the transaction later rolls back.
- It works through [`QueryBuilder.afterCommit()`](../database/transactions.md#run-code-after-the-commit) of dox_orm.

### Unique job details

- `clear` frees the locks of the jobs it deletes. `retry` of a failed job does not take the lock.
- `dispatchSync()` ignores uniqueness.
- With `afterCommit` inside a transaction, the lock is taken at the commit. `dispatch()` returns the id at once, also when the job is then skipped.
- `Queue.fake()` keeps its own locks and needs no cache.

### Chain details

- A job that is released or retried keeps the chain. A job that ends with `delete()`, or that a middleware skips, counts as done, so the chain goes on.
- The `sync` driver runs the jobs now, one after the other. When one throws, the catch job runs and `dispatch()` throws the error.
- A `ShouldBeEncrypted` job stays encrypted inside the job before it.
- A skipped [unique job](#unique-jobs) stops the chain, and the catch job runs with a `StateError`. When the first job is skipped, `dispatch()` returns `''` and nothing runs.
- A next job that can not be read, for example because its class was removed, stops the chain. The catch job runs with the error.
- The worker pushes the next job before it deletes the job that is done. So a crash between the two can run the next job twice.
- When the push of the next job fails, the try of the current job counts as failed, and the job is tried again.
- The unique lock of a job is freed before the next job is pushed. So a next job with the same unique id is not skipped.

### Batch details

- A failed job that you retry with `queue:retry` is not counted again when it fails again. When it is done, `pendingJobs` and `failedJobs` both go down by one, so `catchError` can run again on a later failure.
- An empty batch throws an `ArgumentError`, because it would never finish.
- `then` and `whenComplete` run once, also with many workers, because each count changes in one atomic step.
- A skipped [unique job](#unique-jobs) is taken out of the counts. When it was the last open job, `then` and `whenComplete` run. In a chain of a batch, a skipped first job takes the chain out of the counts, and a skipped later job fails the chain.
- When a push fails in `dispatch()` or `add()`, the jobs that were not pushed are taken out of the counts. The batch is cancelled and the error is thrown. The jobs that were pushed still run.
- A job that runs twice, for example when it runs longer than `retryAfter`, can be counted twice. `failedJobs` never goes below 0.
- The batch is marked finished before `then` and `whenComplete` run, so `add()` from a callback throws a `StateError`. `add()` takes jobs only, not chains.
- When a worker crashes after a job is done and before it counted the job, the batch keeps that job as pending, and `then` never runs. Delete such batches with `prune-batches --unfinished`.
- The `sync` driver runs the jobs at `dispatch()` and counts them. A job that throws counts as failed, and `dispatch()` does not throw.
- In `Queue.fake()`, chains are in `queue.chains` and batches in `queue.batches`, and the chains of a batch in `PendingBatch.chains`. Nothing is saved or run. In a faked batch, `add()` adds to the batch, `cancel()` does nothing and `Queue.findBatch()` gives `null`.

### Event details

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

- The `sync` driver, `dispatchSync()` and `dispatchAfterResponse()` fire no job events. The `sync` driver does fire the batch events, all in the process that called `dispatch()`.
- `Queue.fake()` fires no events.
- `Queue.forgetListeners()` removes all listeners, for example between tests.

### Fake details

- `dispatchSync()` and `dispatchAfterResponse()` still run the job under the fake. Their jobs are in `queue.dispatchedSync` and `queue.dispatchedAfterResponse`, not in `queue.pushed`.
- `Queue.fake()` keeps the connection name in `PushedJob.connection`.
- The fake also catches `Mail.queue()` on the default queue, but only when `Mail.fake()` is off. It does not catch a custom queue set with `Mail.useQueue()`. See [Mail](mail.md#testing).

### How the drivers store jobs

- Database: jobs are rows in `jobs`, failed jobs are rows in `failed_jobs`. On Postgres, MySQL and MariaDB a worker takes a job with `SELECT ... FOR UPDATE SKIP LOCKED`, so many workers do not wait on each other. On SQLite a worker takes a job with one `UPDATE ... RETURNING`. SQLite runs one write at a time, so this is safe for small apps.
- Redis: each queue has a list of ready jobs, a sorted set of delayed jobs and a sorted set of reserved jobs. A Lua script takes a job, so two workers never get the same one. Failed jobs are in the hash `dox_queue:failed`.
- `failed_jobs.connection` has the name of the [queue connection](#queue-connections), or NULL for the main one. A table without this column works too, but then the name is not saved, and `failed --connection=X` lists all failed jobs of the table. A worker checks for the column once, so restart the workers after you add it:

```dart
await schema.table('failed_jobs', (Table table) {
  table.string('connection').nullable();
});
```

### The failed_at column

`failed_jobs.failed_at` is the time the job failed. By default it is a big integer with unix time in milliseconds. If you want a UTC timestamp, pass `failedAtTimestamp: true` to `QueueTables.up` in the migration, and set it in the queue config too:

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

`FailedJob.failedAt` is the same `DateTime` with both types. Each entry of `connections` has its own `failedAtTimestamp`.

!!! warning "The setting and the column must match"
    A worker reads the column type once, when it first uses `failed_jobs`. If the setting does not match the column, `fail`, `failed`, `retry`, `forget` and `prune-failed` throw a `StateError`, and nothing is written. A job that fails all its tries is NOT moved to `failed_jobs`, and its `failed()` does not run. It stays in `jobs` and runs again after `retryAfter`, until the setting matches.

If the type can not be read (for example, the connection dropped), the worker tries again on the next call. With the setting off, it logs a warning and goes on. With the setting on, the call throws.

| Database | Column | How the time is kept |
| --- | --- | --- |
| SQLite | `TIMESTAMP` | ISO text in UTC, with milliseconds |
| Postgres | `TIMESTAMP` (without time zone) | the UTC time, with milliseconds |
| MySQL, MariaDB | `TIMESTAMP` | whole seconds, in UTC. The queue writes it with `FROM_UNIXTIME()` and reads it with `UNIX_TIMESTAMP()`, so the session time zone does not change the time. A MySQL and MariaDB `TIMESTAMP` can not hold a time after 2038-01-19 |

To change an existing integer column to a timestamp:

1. Stop all workers, on every server. Stop the app too when it has `inProcess: true`. A worker that still runs writes numbers into the timestamp column, and on SQLite this gives no error.
2. Run the SQL for your database below, in a new migration (`await schema.driver.execute('...');` for each line) or in a database client.
3. Set `failedAtTimestamp: true` in the queue config.
4. Start the workers again.

SQLite (3.35 or newer). The new column allows NULL, because SQLite can not add a NOT NULL column without a default. The queue never writes NULL there:

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
