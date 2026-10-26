---
icon: lucide/calendar-clock
---

# Scheduler

`dox_scheduler` runs your tasks on a schedule, like cron.

You write the schedule in Dart, in one file.
Each task is a plain function.
A task runs once per tick, even when many isolates or servers run the schedule.

## Install

```bash
dart pub add dox_scheduler
```

## Set up in a Dox app

A new app from `dox create` already has these files. In another app, add them:

- `lib/config/schedule.dart`: the tasks and the `ScheduleConfig`. See [Define tasks](#define-tasks).
- `bin/schedule.dart`: the program that runs the schedule. See [Run the schedule](#run-the-schedule).
- `lib/providers/schedule_provider.dart` (optional): runs the schedule inside the server. See [Run inside the server](#run-inside-the-server).

Then start it next to your server:

```bash
dart run bin/schedule.dart work
```

## Without Dox

`dox_scheduler` also works in a plain Dart app. Leave out `app`:

```dart
import 'dart:io';

import 'package:dox_scheduler/dox_scheduler.dart';

void schedule(Schedule s) {
  s.call('cleanup', cleanup).dailyAt('02:00');
}

Future<void> cleanup() async {
  // delete old files, ...
}

Future<void> main(List<String> args) async {
  exitCode = await SchedulerRunner(schedule: schedule).run(args);
}
```

- With no `app`, no providers start, and the locks use a memory store.
- For many servers, pass a shared lock store: `SchedulerRunner(schedule: schedule, store: myRedisStore)`.
  It is a `CacheStore` from `dox_cache`.
- The commands are the same. See [Run the schedule](#run-the-schedule).

## Define tasks

Put the tasks in `lib/config/schedule.dart`.

```dart
import 'package:dox_scheduler/dox_scheduler.dart';

ScheduleConfig scheduleConfig = const ScheduleConfig();

void schedule(Schedule s) {
  s.call('cleanup', cleanup).dailyAt('02:00');
  s.call('report', sendReport).hourly();
  s.call('ping', ping).cron('*/5 * * * *').timezone('Asia/Yangon');
}

Future<void> cleanup() async {
  // delete old rows, files, ...
}
```

`s.call(name, function)` adds a task.
The name must be unique. It shows in the logs and in the lock keys.
A task with no frequency runs every minute.

### Queue jobs

The scheduler does not know about queues. Wrap the job in a function:

```dart
s.call('report', () => SendReport().dispatch()).hourly();
```

The task only puts the job on the queue. A queue worker runs it.

## Frequencies

| Method | Runs |
| --- | --- |
| `everyMinute()` | every minute (the default) |
| `everyTwoMinutes()` | every 2 minutes |
| `everyFiveMinutes()` | every 5 minutes |
| `everyTenMinutes()` | every 10 minutes |
| `everyFifteenMinutes()` | every 15 minutes |
| `everyThirtyMinutes()` | at minute 0 and 30 |
| `hourly()` | at minute 0 of every hour |
| `hourlyAt(17)` | at minute 17 of every hour |
| `daily()` | every day at 00:00 |
| `dailyAt('13:00')` | every day at 13:00 |
| `twiceDaily(1, 13)` | every day at 01:00 and 13:00 |
| `weekly()` | every Sunday at 00:00 |
| `weeklyOn(DateTime.monday, '08:00')` | every Monday at 08:00 |
| `monthly()` | the 1st of every month at 00:00 |
| `monthlyOn(15, '12:00')` | the 15th of every month at 12:00 |
| `yearly()` | January 1st at 00:00 |
| `cron('*/5 9-17 * * 1-5')` | any 5 field cron expression |

You can limit the days. The order of the calls does not matter.

| Method | Runs |
| --- | --- |
| `weekdays()` | Monday to Friday |
| `weekends()` | Saturday and Sunday |
| `days(<int>[DateTime.monday, DateTime.friday])` | only on these days |

```dart
s.call('standup', remind).weekdays().dailyAt('09:00');
```

### Cron expressions

`cron()` takes the standard 5 fields: `minute hour day-of-month month day-of-week`.

| Field | Values |
| --- | --- |
| minute | 0-59 |
| hour | 0-23 |
| day of month | 1-31 |
| month | 1-12 or `JAN`-`DEC` |
| day of week | 0-7 or `SUN`-`SAT` (0 and 7 are Sunday) |

Each field takes `*`, a number `5`, a range `1-5`, a list `1,15`, and a step `*/15` or `0-30/10`.

When both day fields are set, a day matches when **either** field matches.
This is the standard cron rule. `0 0 1 * MON` runs on the 1st of the month and on every Monday.
When one day field starts with `*`, both must match.

## Time zones

The schedule uses UTC by default.
Use `timezone()` to read the time in another zone:

```dart
s.call('report', sendReport).dailyAt('08:00').timezone('Asia/Yangon');
```

The name is an IANA name, like `Europe/London` or `America/New_York`.
The zone data comes from the `timezone` package.

With summer time (DST):

- A time that does not exist that day (it is skipped when the clock goes forward) does not run that day.
- A time that happens twice (when the clock goes back) runs once.
- `hourly()` and other "every" frequencies keep running every real hour.

## Filters

```dart
s.call('sync', sync).everyFiveMinutes().between('09:00', '17:00');
s.call('night', night).hourly().between('22:00', '06:00'); // crosses midnight
s.call('promo', promo).daily().when(isPromoOn);
s.call('backup', backup).daily().skip(isHoliday);
```

| Method | What it does |
| --- | --- |
| `between('09:00', '17:00')` | runs only in this time of day, both ends included, in the task zone |
| `when(function)` | runs only when the function gives `true` |
| `skip(function)` | does not run when the function gives `true` |

`when` and `skip` take a function that gives a `bool` or a `Future<bool>`.

## Options

| Method | What it does |
| --- | --- |
| `withoutOverlapping()` | does not start while the last run still runs |
| `onOneServer()` | runs once per tick across isolates and servers. **On by default** |
| `onEveryServer()` | runs on every process that runs the schedule |
| `runInBackground()` | the next task of the same minute does not wait for this one |
| `timeout(Duration(minutes: 5))` | counts the run as failed when it takes longer |

### withoutOverlapping

A lock is held while the task runs.
When the next minute comes and the lock is still held, the task is skipped.
The lock expires after 24 hours, in case the process dies.
Pass another expiry like this: `withoutOverlapping(Duration(hours: 1))`.

### Once per tick

Before a task runs, the scheduler takes a lock named after the task and the minute.
The first process to take it runs the task. The others skip it.
The lock is not released, so a late server can not run the same minute again. It expires after 10 minutes.

The locks use a [cache](cache.md) store.

!!! warning "Many servers need Redis"
    A `memory` store lives inside one process.
    It works for one `work` process, or for many isolates of one server.
    When many servers run the schedule, set a Redis store:
    `ScheduleConfig(store: 'redis')`.

When the store has no locks (`file`, `null`), the scheduler uses a memory store.

### Timeout

Dart can not stop a running function.
After the timeout, the run counts as failed and the hooks run, but the work may go on.

## Hooks

```dart
s
    .call('report', sendReport)
    .daily()
    .before(logStart)
    .onSuccess(logDone)
    .onFailure(alertTeam)
    .after(cleanUp);

Future<void> alertTeam(Object error, StackTrace stack) async {
  await notifyTeam('report failed: $error');
}
```

| Hook | Runs |
| --- | --- |
| `before` | before the task. When it throws, the task does not run and counts as failed |
| `onSuccess` | after the task worked |
| `onFailure` | after the task threw or timed out. It gets the error and the stack trace |
| `after` | after the task, always |

An error in a task is logged and the next task still runs.

## Run the schedule

`bin/schedule.dart` runs the schedule:

```dart
import 'dart:io';

import 'package:my_app/config/app.dart';
import 'package:my_app/config/schedule.dart';
import 'package:dox_scheduler/dox_scheduler.dart';

Future<void> main(List<String> args) async {
  exitCode = await SchedulerRunner(
    schedule: schedule,
    app: appConfig,
    config: scheduleConfig,
  ).run(args);
}
```

With `app`, the runner starts your app providers first (like the database).
It stops them at the end.

| Command | What it does |
| --- | --- |
| `dart run bin/schedule.dart work` | runs due tasks at every minute until you stop it. The default |
| `dart run bin/schedule.dart run` | runs the tasks due this minute once, then exits |
| `dart run bin/schedule.dart list` | shows each task, its schedule and its next run time |
| `dart run bin/schedule.dart test cleanup` | runs one task now |

The `dox` CLI runs the same file: `dox schedule:work`, `dox schedule:run`, `dox schedule:list` and `dox schedule:test <name>`.

### work

`work` is a long running process. Run it next to your server, with the same deploy tool (systemd, Docker, Kubernetes).

It wakes at each full minute and runs the due tasks.
On Ctrl+C or SIGTERM it starts no new task and waits for the running ones.
A second signal stops it at once.

### run

`run` is for a system cron. Add one line to the crontab:

```bash
* * * * * cd /path/to/app/build/bundle && ./bin/schedule run
```

It runs the tasks of this minute, waits for them, and exits.
The exit code is 1 when a task failed.

`./bin/schedule` is the binary that `dox build` makes in `build/bundle`. It starts fast and needs no Dart SDK.
Do not use `dart compile exe`. It can not build apps with native libraries, like SQLite.

### list

```
Task     Schedule                   Next run
cleanup  0 2 * * *                  2026-10-26 02:00 UTC
report   0 * * * *                  2026-10-25 14:00 UTC
ping     */5 * * * * Asia/Yangon    2026-10-25 20:35 Asia/Yangon
```

The next run time checks the frequency and `between()`. It does not check `when()` and `skip()`.

### test

`test <name>` runs one task now, with its hooks.
It does not check the schedule, the filters or the locks.

## Run inside the server

You can run the schedule inside your Dox server instead of a `work` process.
Add a provider that extends `SchedulerProvider`:

```dart
// lib/providers/schedule_provider.dart
import 'package:dox_scheduler/dox_scheduler.dart';
import 'package:my_app/config/schedule.dart';

class ScheduleProvider extends SchedulerProvider {
  ScheduleProvider() : super(schedule: schedule, config: scheduleConfig);
}
```

Then turn it on in `lib/config/schedule.dart`:

```dart
ScheduleConfig scheduleConfig = const ScheduleConfig(inProcess: true);
```

Run `dart run build_runner build`. The generated container finds the provider.

How it works:

- Only the first isolate runs the tasks. The other isolates only serve requests.
- With many servers, each server runs the loop. The once-per-tick lock makes each task run once. Use a Redis store for this.
- When the server stops, it waits for the running tasks.

Trade-offs:

- Tasks use the CPU of the server, so they can slow down requests on the first isolate.
- A long task makes the server stop slower.
- With a separate `work` process, you can deploy, scale and restart the scheduler on its own.

Use `work` for heavy tasks. Use the in-process provider for small apps.

## Testing

`Scheduler` runs the tasks. Give it a fake clock to test a schedule with no waiting:

```dart
import 'package:dox_cache/dox_cache.dart';
import 'package:dox_scheduler/dox_scheduler.dart';
import 'package:my_app/config/schedule.dart';
import 'package:test/test.dart';

class FakeClock extends ScheduleClock {
  FakeClock(this.time);

  DateTime time;

  @override
  DateTime now() {
    return time;
  }
}

test('cleanup runs at 02:00', () async {
  Schedule s = Schedule();
  schedule(s);
  Scheduler scheduler = Scheduler(
    tasks: s.tasks,
    store: CacheStore(MemoryDriver()),
    clock: FakeClock(DateTime.utc(2026, 10, 25, 2)),
  );
  Map<String, TaskOutcome> outcomes = await scheduler.runDue();
  expect(outcomes['cleanup'], TaskOutcome.ran);
});
```

`ScheduledTask.isDue(time)` and `ScheduledTask.nextRun(time)` check a schedule with no run at all.
