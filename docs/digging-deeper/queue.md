# Queue

A queue runs slow work in the background. The request answers at once. A worker process does the work later.

Use it to send emails, call slow APIs, make reports or resize images.
The `dox_queue` package gives you jobs, three drivers (Redis, database and sync), retries, delays and a worker.

## Install

```bash
dart pub add dox_queue
```

`dox_queue` has a builder. Your app already runs `build_runner` for `dox_builder`, so nothing else is needed.

## How it works

1. You write a job class with `@Job()`.
2. `dart run build_runner build` writes `lib/jobs.g.dart`. It knows how to save and load each job.
3. Your code calls `dispatch()`. The job is saved in Redis or in the database.
4. A worker (`dart run bin/queue.dart`) takes the job and runs its `handle()` method.

## Set up

### 1. Config

```dart title="lib/config/queue.dart"
import 'package:dox_queue/dox_queue.dart';

import '../jobs.g.dart';

QueueConfig queueConfig = QueueConfig(
  /// sync, database or redis
  driver: 'database',

  /// every @Job class, from lib/jobs.g.dart
  jobs: jobRegistry,
);
```

| Option | Default | What it does |
| --- | --- | --- |
| `driver` | `sync` | `sync`, `database` or `redis` |
| `jobs` | empty | `jobRegistry` from `lib/jobs.g.dart` |
| `redis` | localhost:6379 | `RedisOptions(host: ..., port: ..., password: ...)` for the `redis` driver |
| `prefix` | `dox_queue:` | the start of every Redis key |
| `connection` | default | the dox_orm connection name, for the `database` driver |
| `retryAfter` | 90 seconds | when a worker does not finish a job in this time, another worker can take it |
| `workInProcess` | `false` | run a worker inside the web server, see [Small apps](#small-apps-a-worker-in-the-web-server) |
| `workerQueues` | `['default']` | the queues of the in-process worker |
| `workerConcurrency` | `1` | jobs at once in the in-process worker |

!!! warning "Keep `retryAfter` bigger than your longest job"
    `retryAfter` is how Dox finds the job of a crashed worker.
    A job that runs longer than `retryAfter` looks crashed, so a second worker runs it again.

### 2. Service

The service sets up the queue in every isolate. Put it in `lib/` so the generated container finds it.

```dart title="lib/services/queue_service.dart"
import 'package:dox_queue/dox_queue.dart';

import '../config/queue.dart';

/// Sets up the queue. Dox finds every DoxService class,
/// see lib/container.g.dart.
class AppQueueService extends QueueService {
  AppQueueService() : super(queueConfig);
}
```

### 3. Worker file

```dart title="bin/queue.dart"
import 'dart:io';

import 'package:dox_queue/dox_queue.dart';
import 'package:dox_sample/config/app.dart';

/// run queued jobs: `dart run bin/queue.dart [work] [flags]`.
/// the `dox` CLI runs this file for its queue commands.
Future<void> main(List<String> args) async {
  exitCode = await QueueWorker(app: appConfig).run(args);
}
```

The worker starts the services of your app (database, cache, queue). It does not start the HTTP server.

### 4. Tables (database driver only)

Add a migration in `db/migration`. `QueueTables` makes the `jobs` and `failed_jobs` tables.

```dart title="db/migration/2026_10_25_000000000_create_queue_tables.dart"
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

Then run `dox migrate`.

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

All the settings are optional:

| Setting | Default | What it does |
| --- | --- | --- |
| `tries` | the worker `--tries` (1) | how many times to run the job before it fails |
| `backoff` | none (retry at once) | the wait before each retry. The last entry is used for the rest |
| `timeout` | the worker `--timeout` (60 seconds) | the max run time of one try |
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

`dispatch()` returns the job id.

Run a job now, in this process, with no queue:

```dart
await SendWelcomeEmail(userId: 1).dispatchSync();
```

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

```bash
dart run bin/queue.dart work --queue=emails,default --concurrency=4
```

`--concurrency` runs jobs as async tasks on one thread. It helps for jobs that wait (email, HTTP, database).
For CPU heavy jobs, run more worker processes.

### Stop the worker

Press Ctrl+C, or send SIGTERM (`docker stop` does it).
The worker takes no new job. It waits for the running jobs, then it stops.
A second signal stops it at once.

!!! warning "Restart the worker after a deploy"
    The worker keeps your code in memory. Restart it after each deploy, or it runs the old code.

### Keep it running

Run the worker as its own process, next to the web server. For example with Docker Compose:

```yaml
services:
  web:
    build: .
    command: dart run bin/server.dart
  worker:
    build: .
    command: dart run bin/queue.dart work --concurrency=4
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

## Drivers

| Driver | Where jobs are | Needs |
| --- | --- | --- |
| `sync` | nowhere: `dispatch()` runs the job at once | nothing |
| `database` | the `jobs` and `failed_jobs` tables | Postgres, MySQL 8+, MariaDB 10.6+ or SQLite |
| `redis` | Redis lists and sorted sets | Redis |

### Database

Jobs are rows in the `jobs` table. Failed jobs are rows in `failed_jobs`.

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

Each queue has a list of ready jobs, a sorted set of delayed jobs and a sorted set of reserved jobs.
A Lua script takes a job, so two workers never get the same one. Failed jobs are in the hash `dox_queue:failed`.

### Sync

`dispatch()` runs the job at once and waits for it. There is no worker, no retry and no delay.
When the job throws, `failed()` runs and `dispatch()` throws the error.
Use it for tests and for local work.

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
import 'package:dox_sample/jobs.g.dart';
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
