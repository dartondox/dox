---
icon: lucide/list-ordered
---

# Queue

A queue runs slow work in the background, so the request can answer at once.

You put a slow task, like an email or a report, on a queue as a **job**. A **worker** process then takes each job and runs it. The `dox_queue` package has a `redis` driver and a `sync` driver. The `database` driver is in the `dox_queue_database` package.

## Setup

A new app already has the queue. In an older app, run this command:

```bash
dox add queue
```

The default driver is `database`. Add `--driver=redis` or `--driver=sync` to pick another one. The command writes the config, the provider, `bin/queue.dart` and a sample job. It never overwrites a file.

With `database`, it also adds `dox_queue_database` and the migration of the jobs tables, so run `dox add orm` first. With `redis`, it adds the `REDIS_*` keys.

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

`dart run build_runner build` writes `jobRegistry`. `Queue.config` gives this config in your code.

- `sync`: `dispatch()` runs the job at once. There is no worker, no retry and no delay. Use it for tests and local work.
- `database`: jobs are rows in the `jobs` table. It needs `dox_queue_database`, and Postgres, MySQL 8+, MariaDB 10.6+ or SQLite.
- `redis`: jobs are in Redis.

!!! warning "Keep `retryAfter` bigger than your longest job"
    A job that runs longer than `retryAfter` (default 90 seconds) looks crashed, so a second worker runs it again.

### All options

| Option | Default | What it does |
| --- | --- | --- |
| `driver` | `sync` | `sync`, `database` (needs `dox_queue_database`) or `redis` |
| `jobs` | empty | `jobRegistry` from `lib/generated/jobs.g.dart` |
| `redis` | 127.0.0.1:6379 | `RedisOptions` for the `redis` driver. See [Redis driver](#redis) |
| `prefix` | `dox_queue:` | the start of every Redis key |
| `connection` | default | the dox_orm connection name, for `dox_queue_database` |
| `retryAfter` | 90 seconds | when a worker does not finish a job in this time, another worker can take it |
| `inProcess` | false | run a worker in the web server. See [Running jobs in the web server](#running-jobs-in-the-web-server) |
| `workerQueues` | `['default']` | the queues of the in-process worker |
| `workerConcurrency` | 1 | jobs at once in the in-process worker |
| `workerTimeoutGrace` | none | the `--timeout-grace` wait of the in-process worker |
| `serializeSync` | false | the `sync` driver saves the job and reads it back before it runs |
| `connections` | none | more queue connections by name. See [Queue connections](#queue-connections) |
| `afterCommit` | false | push jobs from a transaction only after the commit. See [Dispatching after the commit](#dispatching-after-the-commit) |
| `failedAtTimestamp` | false | the `failed_at` column is a timestamp. See [The failed_at column](#the-failed_at-column) |

### The provider

The provider sets up the queue in every isolate. Put it in `lib/providers/`:

```dart title="lib/providers/queue_provider.dart"
import 'package:dox_queue/dox_queue.dart';

import '../config/queue.dart';

class AppQueueProvider extends QueueProvider {
  AppQueueProvider() : super(queueConfig);
}
```

### The worker file

The worker runs from `bin/queue.dart`. It starts the providers of your app, but not the HTTP server:

```dart title="bin/queue.dart"
import 'dart:io';

import 'package:dox_queue/dox_queue.dart';
import 'package:my_app/config/app.dart';

/// run queued jobs: `dart run bin/queue.dart [work] [flags]`.
Future<void> main(List<String> args) async {
  exitCode = await QueueWorker(app: appConfig).run(args);
}
```

### Database driver

The `database` driver, [job batches](#job-batching) and [dispatching after the commit](#dispatching-after-the-commit) need the `dox_queue_database` package:

```bash
dart pub add dox_queue_database
```

Then make your queue provider extend `DatabaseQueueProvider`:

```dart title="lib/providers/queue_provider.dart"
import 'package:dox_queue_database/dox_queue_database.dart';

import '../config/queue.dart';

class AppQueueProvider extends DatabaseQueueProvider {
  AppQueueProvider() : super(queueConfig);
}
```

Make the `jobs`, `failed_jobs` and `job_batches` tables. Batches need the `job_batches` table with every driver:

```bash
dox queue:table
dox migrate
```

The migration looks like this:

```dart title="db/migration/2026_10_25_000000_create_queue_tables.dart"
// ignore_for_file: file_names
import 'package:dox_migration/dox_migration.dart';
import 'package:dox_queue_database/dox_queue_database.dart';

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

To keep the jobs in another database connection, use `QueueConfig(connection: 'postgres')`.

#### Adding the pop indexes to an old table

A `jobs` table from an earlier migration can be slow to poll. Add the missing indexes with a new migration:

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

#### The connection column

`failed_jobs.connection` keeps the name of the [queue connection](#queue-connections). An older table without it still works, but `failed --connection=X` then lists all failed jobs. Add the column, then restart the workers:

```dart
await schema.table('failed_jobs', (Table table) {
  table.string('connection').nullable();
});
```

#### The failed_at column

`failed_jobs.failed_at` is an integer with unix time in milliseconds. For a UTC timestamp, set `failedAtTimestamp: true` in the migration and in the queue config:

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

!!! warning "The setting and the column must match"
    If they do not match, the failed job commands throw a StateError, and a job that fails all its tries stays in `jobs` and runs again after `retryAfter`.

On MySQL and MariaDB, a `TIMESTAMP` cannot hold a time after 2038-01-19. To change an existing integer column, stop all workers, run the SQL for your database, set `failedAtTimestamp: true`, then start the workers.

SQLite (3.35 or newer):

```sql
ALTER TABLE failed_jobs ADD COLUMN failed_at_utc TIMESTAMP;
UPDATE failed_jobs SET failed_at_utc =
  strftime('%Y-%m-%dT%H:%M:%fZ', failed_at / 1000.0, 'unixepoch');
ALTER TABLE failed_jobs DROP COLUMN failed_at;
ALTER TABLE failed_jobs RENAME COLUMN failed_at_utc TO failed_at;
```

Postgres:

```sql
ALTER TABLE failed_jobs ALTER COLUMN failed_at TYPE TIMESTAMP
  USING to_timestamp(failed_at / 1000.0) AT TIME ZONE 'UTC';
```

MySQL and MariaDB:

```sql
ALTER TABLE failed_jobs ADD COLUMN failed_at_utc TIMESTAMP NULL;
UPDATE failed_jobs SET failed_at_utc = FROM_UNIXTIME(failed_at DIV 1000);
ALTER TABLE failed_jobs DROP COLUMN failed_at;
ALTER TABLE failed_jobs CHANGE failed_at_utc failed_at TIMESTAMP NOT NULL;
```

### Redis driver {#redis}

Set the driver to `redis` and give the Redis server:

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

`commandTimeout` (default 10 seconds) fails a command that gets no reply, and null turns it off. `maxQueuedCommands` limits the commands that wait for a connection. It is off by default.

To read the Redis server from the env, use `QueueConfig.redisFromEnv()`:

```dart
QueueConfig queueConfig = QueueConfig(
  driver: 'redis',
  jobs: jobRegistry,
  redis: QueueConfig.redisFromEnv(),
);
```

It reads `REDIS_URL`, like `rediss://user:password@host:6380/0`, where `rediss` turns on TLS. Without `REDIS_URL`, it reads `REDIS_HOST`, `REDIS_PORT`, `REDIS_USERNAME`, `REDIS_PASSWORD` and `REDIS_TLS`.

## Creating jobs

### Generating job classes

Make a new job file in `lib/app/jobs/`:

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

Run `dart run build_runner build` after you add or change a job.

### Job data

The parameters of the unnamed constructor are saved with the job. Each parameter needs a field or getter with the same name. These types work:

- `int`, `double`, `num`, `String`, `bool`
- `DateTime`
- enums (saved by name)
- `List` and `Map<String, ...>` of these, also nested
- `dynamic` and `Object` (the value must be JSON)
- the nullable types of all of them

Save an id, not an object. Load the user in `handle()`, so you get the newest data.

### Using services in a job

A job is made again from its saved data, so get services in `handle()` from the container:

```dart
UserService users = Dox().ioc.get<UserService>();
```

### Setting the number of tries

A job runs one time by default. Set `tries` to try again when `handle()` throws, and `backoff` to wait between the tries:

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

The last `backoff` entry is used for all later tries. Three more settings change the retries:

- `retryUntil` retries until a time, in place of a number of tries.
- `maxExceptions` fails the job after this many tries that threw an error.
- `failOnTimeout` fails the job at once when a try times out.

### Setting a timeout

`timeout` is the maximum run time of one try. The default is the worker `--timeout`, 60 seconds:

```dart
@override
Duration? get timeout => const Duration(seconds: 30);
```

### Choosing the queue

Jobs go on the `default` queue. Give a job its own queue, so a worker can run it first or apart:

```dart
@override
String get queue => 'emails';
```

### Handling failed jobs

`failed()` runs one time, after the last try failed:

```dart
@override
Future<void> failed(Object error, StackTrace stack) async {
  // tell someone, or clean up
}
```

### Encrypting job data

Add the `ShouldBeEncrypted` mixin to encrypt the data of the job with the app key. The worker needs the same key, or one of `AppConfig.previousKeys`:

```dart
@Job()
class ChargeCard extends DoxJob with ShouldBeEncrypted {
  // ...
}
```

The job name, the queue and the id stay plain text.

### Renaming a job class

The class name is saved with each job. When you rename a class, keep the old name with `name`:

```dart
@Job(name: 'SendWelcomeEmail')
```

## Dispatching jobs

Call `dispatch()` to put a job on the queue. It gives the job id. `Queue.dispatch()` does the same:

```dart
await SendWelcomeEmail(userId: user.id).dispatch();
await Queue.dispatch(SendWelcomeEmail(userId: user.id));
```

### Delayed dispatching

Use `delay` to wait before the job runs. You can also pick another queue:

```dart
await SendWelcomeEmail(userId: 1).dispatch(
  delay: Duration(minutes: 10),
  queue: 'emails',
);
```

To wait until a time, use `delayUntil`. Give `delay` or `delayUntil`, not both:

```dart
await SendWelcomeEmail(userId: 1).dispatch(
  delayUntil: DateTime.utc(2030, 1, 1, 9),
);
```

### Conditional dispatching

`dispatchIf` dispatches only when the condition is true, and `dispatchUnless` only when it is false. They give null when the job was not dispatched:

```dart
await SendWelcomeEmail(userId: 1).dispatchIf(user.wantsEmail);
await SendWelcomeEmail(userId: 1).dispatchUnless(user.isBlocked);
```

### Synchronous dispatching

Run the job now, in this process, with no queue. `Queue.dispatchSync(job)` does the same:

```dart
await SendWelcomeEmail(userId: 1).dispatchSync();
```

### Dispatching after the response

Run the job in this process after the response is sent. `Queue.dispatchAfterResponse(job)` does the same:

```dart
SendWelcomeEmail(userId: 1).dispatchAfterResponse();
```

It gives nothing, so do not `await` it. The job has no retry, and it is lost if the server stops first.

### Dispatching after the commit

A job dispatched in a transaction can run before the commit, or after a rollback. Use `afterCommit: true` to push it after the commit. This needs [`dox_queue_database`](#database-driver):

```dart
await QueryBuilder.transaction(() async {
  User user = await User().create(<String, dynamic>{'email': email});
  await SendWelcomeEmail(userId: user.id).dispatch(afterCommit: true);
});
```

A rollback drops the job, and outside a transaction it is pushed at once. It waits only for a transaction on the default dox_orm connection. To do this for every dispatch, set `QueueConfig(afterCommit: true)`. Chains and batches also take `afterCommit`.

### Queueing an email

To send an email later, you do not need a job class. With [dox_mailer](mail.md#queue-an-email), call `Mail.queue()`:

```dart
await Mail.queue(message);
await Mail.later(Duration(minutes: 10), message, queue: 'emails');
```

## Running the worker

Start a worker to run the jobs:

```bash
dart run bin/queue.dart
```

`--queue` picks the queues, and the first one goes first. `--concurrency` runs more jobs at once on one thread:

```bash
dart run bin/queue.dart work --queue=emails,default --concurrency=4
```

For CPU heavy jobs, run more worker processes. The `dox` CLI runs the same file: `dox queue:work`, `dox queue:failed`, `dox queue:retry <id|all>`, `dox queue:forget <id>`, `dox queue:flush`, `dox queue:clear [queue]`, `dox queue:restart` and `dox queue:prune-failed`.

### Worker flags

| Flag | Default | What it does |
| --- | --- | --- |
| `--queue=high,default` | `default` | the queues to work. The first one goes first |
| `--concurrency=4` | 1 | jobs at once in this process |
| `--once` | off | run one job, then stop |
| `--tries=3` | 1 | tries of a job that does not set `tries` |
| `--timeout=60` | 60 | maximum run time in seconds of a job that does not set `timeout` |
| `--sleep=3` | 3 | seconds to wait when the queues are empty |
| `--max-sleep=30` | off | double the sleep on each empty poll, up to this many seconds |
| `--stop-when-empty` | off | stop when the queues are empty |
| `--timeout-grace=10` | none | after a timeout, wait up to this many seconds for the old run to end |
| `--backoff=1,5,10` | none | seconds to wait before each retry of a job that does not set `backoff` |
| `--max-jobs=1000` | off | stop after this many jobs |
| `--max-time=3600` | off | stop after this many seconds |
| `--memory=256` | off | stop when the process uses more than this many MB |
| `--connection=name` | main | the [queue connection](#queue-connections) to use |

After `--max-jobs`, `--max-time` and `--memory`, let your process manager start the worker again.

### Stopping the worker

Press Ctrl+C, or send SIGTERM. The worker waits for the running jobs, then stops. A second signal stops it at once.

### Restarting after a deploy

The worker keeps your code in memory, so restart it after each deploy:

```bash
dart run bin/queue.dart restart
```

Each worker stops after its current jobs, and your process manager starts it again. The workers and the command must share a cache store, like `file` on one machine, or `redis`.

### Running the worker in production

Run the binary that `dox build` makes in `build/bundle/bin/queue`. It takes the same commands and flags:

```bash
cd build/bundle
./bin/queue work --concurrency=4
```

Run it as its own process, next to the web server. For example, with Docker Compose:

```yaml
services:
  web:
    build: .
    command: /app/bin/server
  worker:
    build: .
    command: /app/bin/queue work --concurrency=4
```

Set your process manager to restart it when it stops.

### Running jobs in the web server

A small app can skip the worker process. With `inProcess: true`, the first isolate of the web server also runs jobs:

```dart
QueueConfig queueConfig = QueueConfig(
  driver: 'database',
  jobs: jobRegistry,
  inProcess: true,
);
```

The jobs share the isolate with web requests, so heavy jobs make those requests slow.

## Dealing with failed jobs

When `handle()` throws or times out, the worker waits the `backoff` time and tries again, up to `tries` times. After the last try, the job goes to the failed jobs, and `failed()` runs.

!!! info "A timeout does not stop the code"
    Dart cannot stop a running `Future`, so `handle()` continues after a timeout. Write jobs that are safe to run two times.

To wait for the old run, start the worker with `--timeout-grace=SECONDS`. Keep `timeout` plus the grace time below `retryAfter`.

### Retrying failed jobs

List the failed jobs, and put one or all of them back on their queue:

```bash
dart run bin/queue.dart failed
dart run bin/queue.dart retry 6f1c0e...
dart run bin/queue.dart retry all
```

### Deleting failed jobs

`forget` deletes one failed job, and `flush` deletes all of them. `prune-failed` deletes failed jobs older than `--hours=N` (default 24):

```bash
dart run bin/queue.dart forget 6f1c0e...
dart run bin/queue.dart flush
dart run bin/queue.dart prune-failed --hours=48
```

### Controlling the job from handle()

Add the `InteractsWithQueue` mixin, then call one of these in `handle()`:

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

`release()` counts as a try, so set `tries` above 1. In a test file, write `this.fail(...)`, because `package:test` also has a `fail()`.

### Clearing jobs from a queue

Delete all jobs of a queue, also the running ones. The default queue is `default`:

```bash
dart run bin/queue.dart clear emails
```

## Job middleware

Job middleware wraps `handle()` of a job, for rules that many jobs share. Add the `HasMiddleware` mixin and list the middleware. The first one runs first:

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

The built-in middleware keeps its counts and locks in the default cache store. All workers must share it, so do not use the `memory` store. A middleware that puts the job back counts as a try.

### Rate limiting

`RateLimited(key, max, per)` runs `max` jobs of `key` in each `per` window at most. The other jobs go back on the queue:

```dart
RateLimited('report-api', 10, Duration(minutes: 1)),
```

### Preventing job overlaps

`WithoutOverlapping(key)` runs one job of `key` at a time:

```dart
WithoutOverlapping(
  'report-$reportId',
  releaseAfter: Duration(seconds: 30),
  expireAfter: Duration(minutes: 10), // longer than the longest run
),
```

`releaseAfter` (default zero) puts the other jobs back after this time. With null, they are dropped. `expireAfter` frees the lock after this time, so a crash cannot keep it forever.

### Throttling exceptions

`ThrottlesExceptions(key, maxAttempts:, decay:, retryAfter:)` is for jobs that call a service that is down. After `maxAttempts` errors (default 10), jobs of `key` wait until `decay` is over (default 10 minutes):

```dart
ThrottlesExceptions('report-api',
    maxAttempts: 5, decay: Duration(minutes: 5)),
```

### Writing your own middleware

Extend `JobMiddleware`. Call `next()` to continue, or `release(job, delay)` to put the job back:

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

If you do not call `next()`, the job is skipped and counts as done.

## Unique jobs

Add the `ShouldBeUnique` mixin to keep one job of a class and `uniqueId` on the queue. While one waits or runs, `dispatch()` pushes nothing and gives `''`:

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

Set `uniqueFor`, or the lock of a crashed worker never ends. The lock is in the default cache store, so the web app and the workers must share it.

To free the lock when a worker starts the job, use `ShouldBeUniqueUntilProcessing`.

## Job chaining

A chain runs jobs one after the other. When a job fails for good, the rest of the chain is dropped and the catch job runs:

```dart
await Queue.chain(<DoxJob>[
  ResizeImage(imageId: 1),
  UploadImage(imageId: 1),
  TellUser(imageId: 1),
]).catchError(TellAdmin(imageId: 1)).dispatch(queue: 'images');
```

`dispatch()` gives the id of the first job. `delay` counts for the first job only. Each job carries the data of the jobs after it, so keep chains short.

### Handling chain failures

The catch handler is a job too. Add the `CatchesError` mixin to read the error:

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

The catch job runs one time, in the worker, with no retry. `queue:retry` of the failed job continues the chain.

## Job batching

A batch runs many jobs and does something when they are all done. Batches need [`dox_queue_database`](#database-driver) and the `job_batches` table, with every driver:

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

### Batch callbacks

| Callback | Runs |
| --- | --- |
| `before(job)` | one time, at `dispatch()`, before the jobs are pushed |
| `progress(job)` | each time a job is done. With `allowFailures()`, also when one fails |
| `then(job)` | one time, when every job is done |
| `catchError(job)` | one time, when the first job fails for good |
| `whenComplete(job)` | one time, when every job ran, done or failed |

Each callback is a job. It runs one time, with no retry. Add `Batchable` to read the batch, and `CatchesError` to read the error:

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

Add the `Batchable` mixin to read the batch of a job. `batchId` is the id, and `batch()` reads the batch:

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

`Queue.findBatch(id)` reads a batch, or gives null. A `Batch` has these fields:

| Field | What it holds |
| --- | --- |
| `id`, `name` | the id and the name |
| `totalJobs` | how many jobs the batch has |
| `pendingJobs` | how many jobs are not done. Failed jobs are counted, because you can retry them |
| `failedJobs` | how many jobs failed |
| `processedJobs` | how many jobs are done |
| `progress` | the percent of done jobs, from 0 to 100 |
| `finished` | true when every job ran, or the batch was cancelled |
| `cancelled` | true after `cancel()`, or after a first failure |
| `createdAt`, `cancelledAt`, `finishedAt` | the times of these steps |

```dart
Batch? batch = await Queue.findBatch(id);
```

### Cancelling batches

The first job that fails for good cancels the batch. Add `allowFailures()` to continue. You can also call `cancel()`. The jobs still run, so a `Batchable` job reads `cancelled` to skip its work:

```dart
await batch.cancel();
```

### Adding jobs to a batch

`add(jobs)` adds jobs to a batch, for example from a job of the batch. It throws a StateError when the batch is finished or cancelled:

```dart
await batch.add(<DoxJob>[ImportRows(from: 3000)]);
```

### Chains in a batch

Use `chain(jobs)` to put a chain in a batch. The batch counts the chain as one job:

```dart
await Queue.batch(<DoxJob>[ImportUsers()])
    .chain(<DoxJob>[ImportOrders(), SumOrders()])
    .dispatch();
```

### Pruning batches

Delete batches that finished or were cancelled more than `--hours` ago (default 24). `--unfinished` also deletes old batches that never finished:

```bash
dart run bin/queue.dart prune-batches --hours=48
dart run bin/queue.dart prune-batches --hours=48 --unfinished=168
```

In code, use `Queue.pruneBatches(before, unfinishedBefore:)`.

## Queue events

Listen to the steps of a job, for example to log or count jobs:

```dart
Queue.before(
    (QueueEvent event) => print('start ${event.name} ${event.id}'));
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

Each isolate has its own listeners, so register them in a provider. `Queue.forgetListeners()` removes all listeners. A listener gets a `QueueEvent`:

| Field | What it holds |
| --- | --- |
| `type` | the kind of event |
| `job` | the job. Null for `looping` and `stopping` |
| `name` | the job name of the registry |
| `id` | the job id |
| `queue` | the queue name |
| `attempts` | the try number. 0 for `queued`, `looping` and `stopping` |
| `error`, `stack` | the error and its stack trace, for `exceptionOccurred` and `failing` |
| `delay` | the wait, for `queued` and `released` |
| `batch` | the `Batch`, for the [batch events](#batch-events) |

The `sync` driver, `dispatchSync()` and `dispatchAfterResponse()` fire no job events.

### Batch events

In a batch event, `event.batch` is the batch after the step:

```dart
Queue.batchProgress((QueueEvent event) {
  Batch batch = event.batch!;
  print('${batch.name}: ${batch.progress}%');
});
Queue.batchFailed(
    (QueueEvent event) => alert(event.batch!.id, event.error));
```

| Hook | When |
| --- | --- |
| `Queue.batchDispatched` | the batch was saved, before its jobs are pushed |
| `Queue.batchProgress` | a job (or a chain) of the batch is done. With `allowFailures()`, also when one failed |
| `Queue.batchFailed` | the first job failed for good |
| `Queue.batchCancelled` | the batch was cancelled |
| `Queue.batchFinished` | every job ran, done or failed |

Each event fires one time for each step, also with many workers.

## Queue connections

The config is the main connection. Add more queue stores in `connections`:

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

Run a worker for each connection. Every command of `bin/queue.dart` takes `--connection`:

```bash
dart run bin/queue.dart work
dart run bin/queue.dart work --connection=database
dart run bin/queue.dart failed --connection=database
```

An entry uses only `driver`, `redis`, `prefix`, `connection`, `retryAfter`, `serializeSync` and `failedAtTimestamp`. The in-process worker runs only the main connection. `Queue.driverOf(name)` gives the job store of a connection.

## Custom drivers

Write a `QueueDriverFactory` that makes your `QueueDriver`, and add it with `Queue.extend` before the first use of the queue:

```dart
class MyDriverFactory implements QueueDriverFactory {
  @override
  QueueDriver create(QueueConfig config, {String? name}) {
    return MyQueueDriver(config);
  }
}

Queue.extend('mine', MyDriverFactory()); // QueueConfig(driver: 'mine')
```

Call it in `setup()` of your queue provider, before `super.setup()`.

## Testing

### Running jobs in tests

Use the `sync` driver. `dispatch()` then runs the job at once:

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

A job that uses `Dox()` needs `Dox().initialize(appConfig)` in `setUpAll`. Set `serializeSync: true` to save the job and read it back before it runs, like a worker. Then a job that is not in `jobRegistry` throws:

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

`Queue.fake()` keeps every `dispatch()` in a list and runs nothing:

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
| `assertPushedTimes<T>(n)` | `n` `T` jobs were pushed |
| `assertNotPushed<T>()` | no `T` job was pushed |
| `assertNothingPushed()` | no job was pushed |
| `assertChained(<Type>[A, B])` | a chain of these job classes, in this order, was dispatched |
| `assertBatched([test])` | a batch was dispatched. `test` gets a `PendingBatch` |
| `assertBatchedChain(<Type>[A, B])` | a batch has a chain of these job classes, in this order |
| `assertBatchCount(n)` | `n` batches were dispatched |

`queue.pushed` gives the jobs, with the `job`, the `queue`, the `delay` and the `connection`. `queue.jobsOf<T>()` gives the `T` jobs, and `queue.clear()` removes them. `dispatchSync()` and `dispatchAfterResponse()` still run, and their jobs are in `queue.dispatchedSync` and `queue.dispatchedAfterResponse`.

The fake does not encode the job. So a job that is not in `QueueConfig.jobs` passes a faked test, but fails in a worker.

### Testing the queue itself

Use the `database` driver with SQLite `:memory:`, and run a worker that stops when the queue is empty:

```dart
await Worker(
  driver: Queue.driver,
  jobs: jobRegistry,
  options: WorkerOptions(stopWhenEmpty: true),
).run();
```

## Without Dox

`dox_queue` also works in a plain Dart app. Add `build_runner` and `dox_builder`, so it writes `lib/generated/jobs.g.dart`:

```bash
dart pub add dox_queue dox_core
dart pub add dev:build_runner dev:dox_builder
```

Write your jobs as in [Creating jobs](#creating-jobs), and run `dart run build_runner build`. Then set up the queue and run a worker:

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

`WorkerOptions` takes the settings of the `work` flags, like `queues`, `concurrency`, `once`, `tries`, `timeout`, `sleep` and `stopWhenEmpty`. For the `database` driver, call `QueueDatabase.register()` before `Queue.configure()`, after you set up the default dox_orm connection.

## Next steps

- [Background work](../guides/background-work.md): pick the right tool for work after the response.
- [Scheduler](scheduler.md): run work on a timer.
- [Mail](mail.md): queue an email.
