---
icon: lucide/loader
---

# Background work

Answer the request now and do the slow work later: after the response, on another thread, in a queue, or on a timer.

## What you need

- A Dox app (`dox create my_app`). A new app has the queue (`dox_queue`) and the scheduler (`dox_scheduler`).

## Pick the right tool

Pick a tool by the type of work, and by whether the work may get lost:

| You want | Use | Runs where | Lost when the process stops |
| --- | --- | --- | --- |
| small I/O work after the response (a log line, a cache update) | a `Future` you do not await | the same isolate, between requests | yes |
| CPU work (resize an image, parse a big file, compute) | `Isolate.run()` | a new thread | yes |
| work that must not get lost (an email, a payment call), with retries | a queue job | the queue worker process | no |
| work every N minutes (cleanup, sync) | a scheduled task | the schedule process | it runs again at the next tick |

## 1. Work after the response

For small I/O work, start the future with `unawaited` and return. An error of the future goes to `report` of the exception handler. This file has the code of steps 1, 2 and 3:

```dart title="lib/app/http/controllers/report.controller.dart"
import 'dart:async';
import 'dart:isolate';

import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/jobs/build_report.job.dart';

@Inject()
class ReportController {
  /// POST /api/reports
  /// Answers at once. The work runs after the response, in this isolate.
  Map<String, String> store(DoxRequest req) {
    String id = DateTime.now().microsecondsSinceEpoch.toString();
    unawaited(_build(id));
    return <String, String>{'id': id, 'status': 'queued'};
  }

  /// POST /api/reports/queued
  /// Saves a job in the jobs table and answers at once.
  /// The queue worker (`dox queue:work`) runs it, and tries again when
  /// it fails. The job is not lost when the server stops.
  Future<Map<String, String>> queue(DoxRequest req) async {
    String id = DateTime.now().microsecondsSinceEpoch.toString();
    String jobId = await BuildReport(reportId: id).dispatch();
    return <String, String>{'id': id, 'job': jobId, 'status': 'queued'};
  }

  /// I/O work (database, HTTP calls, email) is fine here. It shares the
  /// event loop with the requests, so it must not block the CPU.
  Future<void> _build(String id) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    print('report $id is ready');
  }

  /// GET /api/primes/{limit}
  /// CPU work runs on another thread with `Isolate.run`.
  /// The request waits for the result, but other requests are not blocked.
  Future<Map<String, int>> primes(int limit) async {
    int count = await Isolate.run(() => countPrimes(limit));
    return <String, int>{'limit': limit, 'primes': count};
  }
}

/// Must be a top level or static function with plain arguments.
/// The new isolate has no Dox, no database and no providers.
int countPrimes(int limit) {
  List<bool> sieve = List<bool>.filled(limit + 1, true);
  int count = 0;
  for (int i = 2; i <= limit; i++) {
    if (!sieve[i]) continue;
    count++;
    for (int j = i * i; j <= limit; j += i) {
      sieve[j] = false;
    }
  }
  return count;
}
```

!!! warning "Do not block the event loop"
    `_build` shares the thread with the requests of this isolate, so a long loop makes them all wait. Put a long loop in `Isolate.run`.

## 2. CPU work on another thread

`Isolate.run` runs a function on a new isolate and sends the result back. Pass plain data in, like an integer, a string or bytes, and get plain data out.

If many requests do CPU work, use `Dox().compute`. It uses a pool of workers. See [Heavy CPU work](../digging-deeper/isolate.md#heavy-cpu-work).

`primes` above waits for the result. To not wait, combine both patterns:

```dart
unawaited(Isolate.run(() => countPrimes(limit)).then(saveResult));
```

## 3. A job that must not get lost

For work that must happen, use a queue job. `dispatch()` saves the job in the database. A worker runs `handle()`, and tries again if it fails.

Make the job:

```bash
dox make:job BuildReport
```

Write the work in `handle()`:

```dart title="lib/app/jobs/build_report.job.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_queue/dox_queue.dart';

/// Builds a report in the queue worker.
/// Dispatch it: `await BuildReport(reportId: id).dispatch();`
@Job()
class BuildReport extends DoxJob {
  BuildReport({required this.reportId});

  final String reportId;

  /// try 3 times, wait 10 seconds between tries
  @override
  int get tries => 3;

  @override
  List<Duration> get backoff => const <Duration>[Duration(seconds: 10)];

  @override
  Future<void> handle() async {
    Logger.info('report $reportId is ready');
  }
}
```

Dox saves the fields of the job with it, so use plain values, like strings, numbers, dates, lists and maps. Save an id, not a model, and load the model in `handle()`.

Run `dart run build_runner build` after you add or change a job. The `queue` method of the controller dispatches the job.

Start the worker in a second terminal:

```bash
dox queue:work
```

`dox queue:failed` lists the jobs that failed every try. `dox queue:retry all` puts them back on the queue.

## 4. Work on a timer

Put a task that runs again and again in `lib/config/schedule.dart`:

```dart title="lib/config/schedule.dart"
import 'package:dox_scheduler/dox_scheduler.dart';
import 'package:my_app/app/models/user/user.model.dart';

/// `inProcess: false`: run `dox schedule:work` next to the server.
ScheduleConfig scheduleConfig = const ScheduleConfig();

/// The tasks. `dox schedule:list` shows them.
void schedule(Schedule s) {
  s.call('cleanup', cleanupUsers).hourly();
}

/// Removes the users that were soft deleted more than 30 days ago.
Future<void> cleanupUsers() async {
  DateTime limit = DateTime.now().subtract(const Duration(days: 30));
  List<User> old = await User()
      .withTrash()
      .where('deleted_at', '<', limit)
      .get();
  int removed = 0;
  for (User user in old) {
    removed += await user.forceDelete();
  }
  print('cleanup: removed $removed users');
}
```

Start the scheduler in a third terminal:

```bash
dox schedule:work
```

`dox schedule:list` shows each task and its next run. `dox schedule:test cleanup` runs the task now.

With many servers, set `ScheduleConfig(store: 'redis')`, so each task runs one time per tick. For a small app, you can [run the schedule inside the server](../digging-deeper/scheduler.md#run-inside-the-server).

## 5. Add the routes

Add the three routes to the API router:

```dart title="lib/routes/api.dart"
Route.post('/reports', (ReportController c) => c.store);
Route.post('/reports/queued', (ReportController c) => c.queue);
Route.get('/primes/{limit}', (ReportController c) => c.primes);
```

Run `dart run build_runner build --delete-conflicting-outputs` and `dox serve`.

## Check it

Start a report:

```bash
curl -X POST http://localhost:3000/api/reports
```

The response comes at once:

```json
{"id":"1792677668393002","status":"queued"}
```

Two seconds later, the server prints `report 1792677668393002 is ready`.

Start a queued report:

```bash
curl -X POST http://localhost:3000/api/reports/queued
```

```json
{
  "id": "1792677670112345",
  "job": "9f2c4e1a7b3d5f60a1c2e3f4a5b6c7d8",
  "status": "queued"
}
```

The worker terminal shows `report 1792677670112345 is ready`. When the worker is stopped, the job waits in the `jobs` table.

Count the primes:

```bash
curl http://localhost:3000/api/primes/100000
```

```json
{"limit":100000,"primes":9592}
```

## Next steps

- [Queue](../digging-deeper/queue.md): drivers, retries, delays and failed jobs.
- [Scheduler](../digging-deeper/scheduler.md): frequencies, time zones and hooks.
- [Isolate](../digging-deeper/isolate.md): what each isolate shares.
- [Custom errors](custom-errors.md): log the errors of a future.
