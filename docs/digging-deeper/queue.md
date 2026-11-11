---
icon: lucide/list-ordered
---

# Queue

A queue runs slow work in the background, so the request can answer at once.

A worker process does the work later.

Use it to send emails, call slow APIs, make reports or resize images.
The `dox_queue` package gives you jobs, three drivers (Redis, database and sync), retries, delays and a worker.

## Install

```bash
dart pub add dox_queue
```

`dox_queue` has a builder. Your app already runs `build_runner` for `dox_builder`, so nothing else is needed.

## How it works

1. You write a job class with `@Job()`.
2. `dart run build_runner build` writes `lib/generated/jobs.g.dart`. It knows how to save and load each job.
3. Your code calls `dispatch()`. The job is saved in Redis or in the database.
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
| `driver` | `sync` | `sync`, `database` or `redis` |
| `jobs` | empty | `jobRegistry` from `lib/generated/jobs.g.dart` |
| `redis` | 127.0.0.1:6379 | `RedisOptions(host: ..., port: ..., password: ...)` for the `redis` driver. `QueueConfig.redisFromEnv()` reads it from the env. |
| `prefix` | `dox_queue:` | the start of every Redis key |
| `connection` | default | the dox_orm connection name, for the `database` driver |
| `retryAfter` | 90 seconds | when a worker does not finish a job in this time, another worker can take it |
| `workInProcess` | `false` | run a worker inside the web server, see [Small apps](#small-apps-a-worker-in-the-web-server) |
| `workerQueues` | `['default']` | the queues of the in-process worker |
| `workerConcurrency` | `1` | jobs at once in the in-process worker |
| `workerTimeoutGrace` | none | the `--timeout-grace` wait of the in-process worker, see [Retries and failed jobs](#retries-and-failed-jobs) |
| `serializeSync` | `false` | opt-in: the `sync` driver saves the job and reads it back before it runs, see [Sync](#sync) |
| `connections` | none | opt-in: more queue connections by name, see [Queue connections](#queue-connections) |

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

### 4. Tables (database driver only)

Run `dox queue:table`. It writes a migration in `db/migration` that makes the `jobs` and `failed_jobs` tables. Then run `dox migrate`.

```bash
dox queue:table
dox migrate
```

`queue:table` is a [package command](package-commands.md) of `dox_queue`. It does not overwrite: when a `create_queue_tables` migration is already there, it prints so and stops.

The migration it writes looks like this. You can also write it by hand. `QueueTables` makes the two tables.

```dart title="db/migration/2026_10_25_000000_create_queue_tables.dart"
// ignore_for_file: file_names
import 'package:dox_migration/dox_migration.dart';
import 'package:dox_queue/dox_queue.dart';

/// The jobs and failed_jobs tables of dox_queue.
class CreateQueueTables extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await QueueTables.up(schema);
  }

  @override
  Future<void> down(Schema schema) async {
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

It does not go on the queue. So it has no job id and no retry. Outside a request, the job runs soon. When the job throws, its `failed()` runs and the error goes to the exception handler, never to the client. `QueueProvider` turns on `AfterResponse` for it. When the server stops, a job that did not run yet is lost.

### Queue an email

You do not need a job class to send an email later. With [dox_mailer](mail.md#queue-an-email), call `Mail.queue()`:

```dart
await Mail.queue(message);
await Mail.later(Duration(minutes: 10), message, queue: 'emails');
```

dox_queue has a built-in job for it. It is not in `lib/generated/jobs.g.dart`, and you do not need to add it.

Deploy the worker together with the web app. An old worker does not know this job, so it fails the queued emails.

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
| `clear [queue]` | delete the jobs of a queue. Default: `default` |
| `restart` | stop the running workers after their current jobs |
| `prune-failed` | delete failed jobs older than `--hours=N` (default 24) |

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

Inside `handle()`, a job can decide what happens next:

| Call | What it does |
| --- | --- |
| `attempts()` | how many times a worker took the job. The first run gives 1 |
| `release(delay)` | put the job back on its queue. It runs again after `delay` |
| `fail(error)` | fail the job now, with no retry. `failed()` runs |
| `delete()` | delete the job, with no retry and no `failed()` |

```dart
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
```

The worker does the call when `handle()` ends. When you call more than one, the last one wins.
A call also wins over an error that `handle()` throws after it.

`release()` counts as a try. Set `tries` (or `retryUntil`) high enough, or the next run fails.

With `dispatchSync()`, `dispatchAfterResponse()` and the `sync` driver there is no queue.
There `attempts()` is 1, `release()` and `delete()` do nothing, and `fail()` only runs `failed()`.

## Drivers

| Driver | Where jobs are | Needs |
| --- | --- | --- |
| `sync` | nowhere: `dispatch()` runs the job at once | nothing |
| `database` | the `jobs` and `failed_jobs` tables | Postgres, MySQL 8+, MariaDB 10.6+ or SQLite |
| `redis` | Redis lists and sorted sets | Redis |

### Database

Jobs are rows in the `jobs` table. Failed jobs are rows in `failed_jobs`.

`failed_jobs.connection` has the name of the queue connection (see [Queue connections](#queue-connections)). It is NULL for the main connection.
A `failed_jobs` table without this column works too. Then the name is not saved.
To add the column, write a migration:

```dart
await schema.table('failed_jobs', (Table table) {
  table.string('connection').nullable();
});
```

- On Postgres, MySQL and MariaDB a worker takes a job with `SELECT ... FOR UPDATE SKIP LOCKED`. Many workers do not wait on each other.
- On SQLite a worker takes a job with one `UPDATE ... RETURNING`. SQLite runs one write at a time, so this is safe. It is good for small apps.

Use another connection of `config/database.dart` with `QueueConfig(connection: 'postgres')`.

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
- The in-process worker (`workInProcess`) runs the jobs of the main connection only.
- Two `database` connections on the same dox_orm connection share the `jobs` table. Give each one its own dox_orm connection.
- `Queue.fake()` keeps the name in `PushedJob.connection`.

## Small apps: a worker in the web server

You can skip the worker process. Set `workInProcess: true`:

```dart
QueueConfig queueConfig = QueueConfig(
  driver: 'database',
  jobs: jobRegistry,
  workInProcess: true,
);
```

The first isolate of the web server then runs jobs too. When the server stops, it waits for the running jobs.

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

To read the jobs, use `queue.pushed`. Each item has the `job`, the `queue` name and the `delay`. `queue.jobsOf<T>()` gives the `T` jobs. `queue.clear()` forgets them. `Queue.restore()` stops the fake.

- `dispatchSync()` runs the job now. `dispatchAfterResponse()` runs it after the answer, or soon outside a request. The fake does not stop them. It keeps their jobs in `queue.dispatchedSync` and `queue.dispatchedAfterResponse` (not in `queue.pushed`). `queue.clear()` empties these lists too.
- The fake does not encode the job. A job that is missing from `QueueConfig.jobs`, or has data that is not JSON, passes a faked test but fails for real.
- The fake also catches `Mail.queue()`, but only when `Mail.fake()` is off. When both are on, `Mail.fake()` catches the email first. See [Mail](mail.md#testing).

To test a job alone, call `handle()`:

```dart
await SendWelcomeEmail(userId: 1).handle();
```

To test the queue itself, use the `database` driver with SQLite `:memory:`, and run a worker that stops when the queue is empty:

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
- The `database` driver uses the default `dox_orm` connection. Set it up first with `SqlQueryBuilder.initializeWithDatabaseConfig(...)`.
- No services are in the Dox container. Make the services of a job in `handle()`.
