# Background work

Answer the request now and do the slow work after. Use another thread for CPU work. Run a job on a timer.

## What you need

- A Dox app.

## What Dox gives you

Dox has no job queue. It has three building blocks from Dart itself:

| You want | Use | Runs where |
| --- | --- | --- |
| I/O work after the response (send an email, call an API, write rows) | a `Future` you do not await | the same isolate, between requests |
| CPU work (resize an image, parse a big file, compute) | `Isolate.run()` | a new thread |
| work every N minutes (cleanup, sync) | `Timer.periodic` in a service | one isolate of your choice |

None of them survive a restart. See [When you need a real queue](#when-you-need-a-real-queue).

## 1. Work after the response

Start the future and return. `unawaited` tells the linter you did this on purpose.
An error in the future goes to the `report` method of the `ExceptionHandler` in `AppConfig`.

```dart title="lib/app/http/controllers/report.controller.dart"
import 'dart:async';
import 'dart:isolate';

import 'package:dox_core/dox_core.dart';

class ReportController {
  /// POST /api/reports
  /// Answers at once. The work runs after the response, in this isolate.
  Map<String, String> store(DoxRequest req) {
    String id = DateTime.now().microsecondsSinceEpoch.toString();
    unawaited(_build(id));
    return <String, String>{'id': id, 'status': 'queued'};
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
/// The new isolate has no Dox, no database and no services.
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

ReportController reportController = ReportController();
```

!!! warning "Do not block the event loop"
    `_build` shares the thread with the requests of this isolate. A long loop makes them all wait.
    Put a long loop in `Isolate.run`.

## 2. CPU work on another thread

`Isolate.run` runs the function on a new isolate and sends the result back.
Pass plain data in (an `int`, a `String`, bytes) and get plain data out. Save the result in the request isolate.

`primes` above waits for the result. To not wait, combine both patterns:

```dart
unawaited(Isolate.run(() => countPrimes(limit)).then(saveResult));
```

## 3. Work on a timer

`setup()` of a service runs in **every** isolate, and Dox starts one per CPU core. So start the timer on isolate 1 only.

```dart title="lib/services/cleanup_service.dart"
import 'dart:async';

import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/models/user/user.model.dart';

/// Work on a timer. `setup()` runs in every isolate, so the timer is
/// started on isolate 1 only. Otherwise 8 isolates do the same job.
class CleanupService implements DoxService {
  @override
  void setup() {
    if (Dox().isolateId != 1) return;
    Timer.periodic(const Duration(hours: 1), _run);
  }

  Future<void> _run(Timer timer) async {
    DateTime limit = DateTime.now().subtract(const Duration(days: 30));
    List<User> old = await User()
        .withTrash()
        .where('deleted_at', '<', limit)
        .get();
    for (User user in old) {
      await user.forceDelete();
    }
    print('cleanup: removed ${old.length} users');
  }
}
```

```dart title="lib/config/services.dart"
List<DoxService> services = <DoxService>[
  ORMService(),
  CleanupService(), // after ORMService, so the database is ready
];
```

When you run more than one process (two machines), each process has an isolate 1. Then the job runs twice. Use a database lock, or run the job from one place only.

## 4. Add the routes

```dart title="lib/routes/api.dart"
Route.post('/reports', reportController.store);
Route.get('/primes/{limit}', reportController.primes);
```

## Check it

```bash
curl -X POST http://localhost:3000/api/reports
```

The answer comes at once:

```json
{"id":"1792677668393002","status":"queued"}
```

Two seconds later, the server prints `report 1792677668393002 is ready`.

```bash
curl http://localhost:3000/api/primes/100000
```

```json
{"limit":100000,"primes":9592}
```

## When you need a real queue

The work above is lost when the process stops, and it does not retry.
When that is not OK (payments, emails that must arrive), save the job as a row in a table first.
Then a `Timer.periodic` service, or a second small Dart program, reads the table, does the work, and marks the row as done.
A failed row stays in the table, so you can retry it.

## See also

- [Isolate](../digging-deeper/isolate.md) for what each isolate shares, and what it does not
- [Services](../digging-deeper/services.md)
- [Custom errors](custom-errors.md) for the `ExceptionHandler` that gets the errors of a future nobody awaits
