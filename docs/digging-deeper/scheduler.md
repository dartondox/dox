---
icon: lucide/calendar-clock
---

# Scheduler

`dox_scheduler` runs your tasks on a schedule, so you do not need a cron line for each task.

You write the full schedule in Dart, in one file, and each task is a plain function. A task runs one time for each tick, also when many isolates or servers run the schedule.

## Setup

A new app already has the scheduler. In an older app, run this command:

```bash
dox add scheduler
```

It adds the package and writes these files. It never overwrites a file:

- `lib/config/schedule.dart`: your tasks and the `ScheduleConfig`. See [Defining tasks](#defining-tasks).
- `bin/schedule.dart`: the program that runs the schedule. See [Running the scheduler](#running-the-scheduler).
- `lib/providers/schedule_provider.dart`: runs the schedule inside the server. See [Run inside the server](#run-inside-the-server).

## Defining tasks

Add a task with `s.call(name, function)` in `lib/config/schedule.dart`, then add a frequency:

```dart title="lib/config/schedule.dart"
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

The name must be unique, because the logs and the locks use it. A task with no frequency runs every minute. `s.find(name)` gives the task with that name, or null.

### Scheduling queued jobs

For a slow task, put a [queue](queue.md) job on the queue. A queue worker then runs it:

```dart
s.call('report', () => SendReport().dispatch()).hourly();
s.call('prune', () => PruneFiles().dispatch(connection: 'redis')).hourly();
```

### Scheduling shell commands

Use `exec` to run a program. An exit code that is not 0 fails the task:

```dart
s.exec('pg_dump', args: <String>['-f', 'backup.sql', 'mydb']).daily();
```

No shell is used, so `|`, `>` and `*` are plain text. To use a shell, run it yourself:

```dart
s.exec('sh', args: <String>['-c', 'pg_dump mydb | gzip > backup.sql.gz'])
    .daily();
```

### Scheduling dox commands

Use `command` to run `dox <command> <args>`:

```dart
s.command('queue:prune', args: <String>['--hours=48']).hourly();
```

The task name is the command line, and the logs show it. If `args` has a secret, give your own name:

```dart
s.command('sync', args: <String>['--token=$token'], name: 'sync');
```

If `dox` is not on the PATH, set `Schedule.doxExecutable = '/usr/local/bin/dox';`.

## Frequency options

Add one of these methods to set how often a task runs:

| Method | Runs |
| --- | --- |
| `everySecond()` | every second. Also `everyTwoSeconds`, `everyFiveSeconds`, `everyTenSeconds`, `everyFifteenSeconds`, `everyTwentySeconds`, `everyThirtySeconds` |
| `everyMinute()` | every minute (the default) |
| `everyTwoMinutes()` | every 2 minutes. Also `everyThreeMinutes`, `everyFourMinutes`, `everyFiveMinutes`, `everyTenMinutes`, `everyFifteenMinutes` |
| `everyThirtyMinutes()` | at minute 0 and 30 |
| `hourly()` | at minute 0 of every hour |
| `hourlyAt(17)` | at minute 17 of every hour |
| `everyTwoHours()` | every 2 hours at minute 0. Also `everyThreeHours`, `everyFourHours`, `everySixHours`. Give a minute: `everyTwoHours(15)` |
| `everyOddHour()` | at 01:00, 03:00 ... 23:00. Give a minute: `everyOddHour(30)` |
| `daily()` | every day at 00:00 |
| `dailyAt('13:00')` | every day at 13:00. `at('13:00')` is the same |
| `twiceDaily(1, 13)` | every day at 01:00 and 13:00 |
| `twiceDailyAt(1, 13, 15)` | every day at 01:15 and 13:15 |
| `weekly()` | every Sunday at 00:00 |
| `weeklyOn(DateTime.monday, '08:00')` | every Monday at 08:00 |
| `monthly()` | the 1st of every month at 00:00 |
| `monthlyOn(15, '12:00')` | the 15th of every month at 12:00 |
| `twiceMonthly(1, 16, '13:00')` | the 1st and 16th of every month at 13:00 |
| `lastDayOfMonth('15:00')` | the last day of every month at 15:00 |
| `quarterly()` | January, April, July and October 1st at 00:00 |
| `quarterlyOn(4, '14:00')` | January, April, July and October 4th at 14:00 |
| `yearly()` | January 1st at 00:00 |
| `yearlyOn(6, 1, '17:00')` | June 1st at 17:00 |
| `cron('*/5 9-17 * * 1-5')` | any 5 field cron expression |

The last method that sets a field wins. So `.dailyAt('09:00').weekly()` runs at 00:00, but `.weekly().dailyAt('09:00')` runs at 09:00.

### Day constraints

Add a day method to run a task only on some days:

| Method | Runs |
| --- | --- |
| `weekdays()` | Monday to Friday |
| `weekends()` | Saturday and Sunday |
| `mondays()` ... `sundays()` | only on that day of the week |
| `days(<int>[DateTime.monday, DateTime.friday])` | only on these days |

```dart
s.call('standup', remind).weekdays().dailyAt('09:00');
```

A day of the month and a day of the week join with OR, like in cron. So `monthlyOn(15).fridays()` runs on the 15th and on every Friday.

### Sub-minute tasks

A seconds method, like `everyFiveSeconds()`, repeats the task in each due minute. Call it first, because it also sets the task to every minute:

```dart
s.call('poll', poll).everyFiveSeconds().between('09:00', '17:00');
```

### Cron expressions

`cron()` takes the 5 standard fields: `minute hour day-of-month month day-of-week`.

| Field | Values |
| --- | --- |
| minute | 0-59 |
| hour | 0-23 |
| day of month | 1-31 |
| month | 1-12 or `JAN`-`DEC` |
| day of week | 0-7 or `SUN`-`SAT` (0 and 7 are Sunday) |

Each field takes `*`, a number `5`, a range `1-5`, a list `1,15`, and a step `*/15` or `0-30/10`.

## Time zones

The schedule uses UTC by default. Use `timezone()` to read the time of a task in another zone:

```dart
s.call('report', sendReport).dailyAt('08:00').timezone('Asia/Yangon');
```

The name is an IANA name, like `Europe/London`. To use one zone for all tasks, set it in the config:

```dart
ScheduleConfig scheduleConfig =
    const ScheduleConfig(timezone: 'Asia/Yangon');
```

On a summer time change, a time that does not exist that day does not run. A time that occurs two times runs one time.

## Limiting when a task runs

### Between times

Use `between` to run a task only in a time of day, and `unlessBetween` to skip a time of day. A range can cross midnight:

```dart
s.call('sync', sync).everyFiveMinutes().between('09:00', '17:00');
s.call('night', night).hourly().between('22:00', '06:00');
s.call('quiet', quiet).hourly().unlessBetween('23:00', '04:00');
```

### Truth tests

`when` runs the task when the function gives true. `skip` skips the task when the function gives true:

```dart
s.call('promo', promo).daily().when(isPromoOn);
s.call('backup', backup).daily().skip(isHoliday);
```

### Environments

Run a task only when `APP_ENV` is one of the names:

```dart
s.call('emails', sendEmails).daily()
    .environments(<String>['production']);
```

When `APP_ENV` is not set, the task does not run.

## Preventing task overlaps

Skip a run while the last run of the task still runs:

```dart
s.call('report', sendReport).everyFiveMinutes().withoutOverlapping();
```

The lock expires after 24 hours. Give another time with `withoutOverlapping(Duration(hours: 1))`. After a crash, remove the lock with [`clear-cache`](#clearing-overlap-locks).

## Running tasks on one server

A task runs one time for each tick on all isolates and servers. This is `onOneServer()`, the default. The locks are in a [cache](cache.md) store, so use a shared store like Redis for many servers:

```dart
ScheduleConfig scheduleConfig = const ScheduleConfig(store: 'redis');
```

To run a task on every process, use `onEveryServer()`:

```dart
s.call('clear-tmp', clearTmp).hourly().onEveryServer();
```

## Background tasks

Tasks of the same minute run one after the other. Use `runInBackground` so a long task does not stop the next one:

```dart
s.call('export', export).daily().runInBackground();
```

## Timeouts

Count a run as failed when it takes too long. The failure hooks then run:

```dart
s.exec('pg_dump', args: <String>['mydb']).daily()
    .timeout(Duration(minutes: 5));
```

An `exec()` or `command()` process gets SIGTERM, then SIGKILL after `Schedule.processGrace` (5 seconds). A Dart function cannot be stopped, so its work can continue.

## Running the scheduler

`bin/schedule.dart` runs your schedule. With `app`, it starts your app providers first, like the database:

```dart title="bin/schedule.dart"
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

The `dox` CLI runs the same file: `dox schedule:work` is `dart run bin/schedule.dart work`.

### Running the worker

Start a process that runs the due tasks at each full minute. Run it next to your server:

```bash
dox schedule:work
```

On Ctrl+C or SIGTERM, it waits for the running tasks. A second signal stops it at once.

### Running from cron

`run` runs the tasks of this minute one time, then exits. Add one line to the crontab:

```bash
* * * * * cd /path/to/app/build/bundle && ./bin/schedule run
```

`./bin/schedule` is the binary that `dox build` makes. The exit code is 1 when a task failed.

### Listing tasks

Show each task, its schedule and its next run:

```bash
dox schedule:list
```

```
Task     Schedule                   Next run
cleanup  0 2 * * *                  2026-10-26 02:00 UTC
report   0 * * * *                  2026-10-25 14:00 UTC
ping     */5 * * * * Asia/Yangon    2026-10-25 20:35 Asia/Yangon
```

The next run does not check `when()`, `skip()` and `environments()`.

### Running one task now

Run one task now, with its hooks. The schedule, the filters and the locks are not checked:

```bash
dox schedule:test cleanup
```

### Clearing overlap locks

Remove the `withoutOverlapping()` locks that a crash left in the store:

```bash
dox schedule:clear-cache
```

Run it only when the task does not run on another process. If it does, the task can start a second time.

## Run inside the server

For a small app, run the schedule inside the Dox server. Add a provider that extends `SchedulerProvider`:

```dart title="lib/providers/schedule_provider.dart"
import 'package:dox_scheduler/dox_scheduler.dart';
import 'package:my_app/config/schedule.dart';

class ScheduleProvider extends SchedulerProvider {
  ScheduleProvider() : super(schedule: schedule, config: scheduleConfig);
}
```

Then turn it on, and run `dart run build_runner build`:

```dart title="lib/config/schedule.dart"
ScheduleConfig scheduleConfig = const ScheduleConfig(inProcess: true);
```

Only the first isolate of the web server runs the tasks, so heavy tasks can slow its requests. Use `work` for heavy tasks. In a test of the in-process schedule, set `Dox().isWebServer = true;` first.

## Logging the schedule

Send the `[schedule]` lines through the app `Logger`:

```dart title="lib/config/schedule.dart"
ScheduleConfig scheduleConfig = const ScheduleConfig(
  flags: SchedulerFlags(loggerLines: true),
);
```

The lines then get the tag `[scheduler]`, like `[scheduler] ran cleanup in 12ms`. `SchedulerFlags.all()` turns on every flag.

## Task output

These hooks keep the output of an `exec()` or `command()` task. Without them, the output is lost.

Write the output to a file. Each run replaces the file:

```dart
s.exec('pg_dump', args: <String>['mydb']).daily()
    .sendOutputTo('storage/logs/backup.log');
```

Add the output to the end of the file:

```dart
s.exec('pg_dump', args: <String>['mydb']).daily()
    .appendOutputTo('storage/logs/backup.log');
```

Get the output in code after the process ends:

```dart
s.exec('pg_dump', args: <String>['mydb']).daily()
    .onOutput((String output) {...});
```

`onOutput` keeps the full output in memory, so do not use it for very large output.

## Task hooks

Run code around a task, for example to tell your team when it fails:

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
| `before` | before the task. If it throws, the task does not run and fails |
| `onSuccess` | after the task worked |
| `onFailure` | after the task threw or timed out. It gets the error and the stack trace |
| `after` | after the task, always |

An error in a task is logged, and the next task still runs.

### Pinging URLs

Send a GET request to a URL around a task, for example to a health check service:

```dart
s
    .call('backup', backup)
    .daily()
    .pingBefore('https://health.example.com/backup/start')
    .pingOnSuccess('https://health.example.com/backup')
    .pingOnFailure('https://health.example.com/backup/fail');
```

`thenPing(url)` pings after the task, always. Each ping method has an `If` form, like `pingOnFailureIf(isProduction, url)`. A failed ping is logged, and the task does not fail. A ping stops after `ScheduledTask.pingTimeout` (10 seconds).

## Testing

Give `Scheduler` a fake clock to test a schedule with no wait:

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
  Schedule s = Schedule(timezone: scheduleConfig.timezone);
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

To run one task, use `scheduler.runTask(task, time)`. To check a schedule with no run, use `task.isDue(time)` and `task.nextRun(time)`. To replace the ping request, set `ScheduledTask.sendPing = (Uri url) async {...};`.

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

With no `app`, the locks use a memory store. For many servers, give a shared `CacheStore` from `dox_cache`: `SchedulerRunner(schedule: schedule, store: myRedisStore)`.

## Next steps

- [Queue](queue.md): jobs that must not get lost.
- [Background work](../guides/background-work.md): pick the right tool for work after the response.
- [CLI](../reference/cli.md): the `schedule:*` commands.
