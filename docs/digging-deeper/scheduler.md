---
icon: lucide/calendar-clock
---

# Scheduler

`dox_scheduler` runs your tasks on a schedule, so you do not need a cron line for each task.

You write the whole schedule in Dart, in one file, and each task is a plain function. One small process runs the schedule. A task runs only once per tick, even when many isolates or servers run the schedule.

## Setup

Add the package with the `dox` CLI. A new app from `dox create` already has it:

```bash
dox add scheduler
```

It adds the package and writes three files. It never overwrites a file, so it is safe to run twice.

- `lib/config/schedule.dart`: your tasks and the `ScheduleConfig`. See [Defining tasks](#defining-tasks).
- `bin/schedule.dart`: the program that runs the schedule. See [Running the scheduler](#running-the-scheduler).
- `lib/providers/schedule_provider.dart` (optional): runs the schedule inside the server. See [Run inside the server](#run-inside-the-server).

If you want to set it up by hand, add the package and write these files yourself:

```bash
dart pub add dox_scheduler
```

## Defining tasks

Put your tasks in the `schedule` function in `lib/config/schedule.dart`. Use `s.call(name, function)` to add a task, then chain a frequency:

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

The name must be unique, because it is used in the logs and in the lock keys. A task with no frequency runs every minute.

### Scheduling queued jobs

If a task is slow, you can put a [queue](queue.md) job on the queue instead. Wrap the dispatch in a function, so the task only adds the job and a queue worker runs it:

```dart
s.call('report', () => SendReport().dispatch()).hourly();
```

To use another [queue connection](queue.md#queue-connections), pass `connection:` to `dispatch()`:

```dart
s.call('prune', () => PruneFiles().dispatch(connection: 'redis')).hourly();
```

### Scheduling shell commands

Use `exec` to run a program. A non-zero exit code fails the task:

```dart
s.exec('pg_dump', args: <String>['-f', 'backup.sql', 'mydb']).daily();
```

No shell is used, so `|`, `>` and `*` are plain text. If you need a shell, run it yourself:

```dart
s.exec('sh', args: <String>['-c', 'pg_dump mydb | gzip > backup.sql.gz']).daily();
```

### Scheduling dox commands

Use `command` to run a `dox` command of your app. It runs as the process `dox <command> <args>`:

```dart
s.command('queue:prune', args: <String>['--hours=48']).hourly();
```

The task name is the command line, like `dox queue:prune --hours=48`, and it shows in the logs and in `list`. So if `args` holds a secret, give the task your own name:

```dart
s.command('sync', args: <String>['--token=$token'], name: 'sync');
```

The output of `exec` and `command` tasks is dropped. Use the [output hooks](#task-output) to keep it.

## Frequency options

Chain one of these methods to say how often a task runs:

| Method | Runs |
| --- | --- |
| `everySecond()` | every second. Also `everyTwoSeconds`, `everyFiveSeconds`, `everyTenSeconds`, `everyFifteenSeconds`, `everyTwentySeconds`, `everyThirtySeconds` |
| `everyMinute()` | every minute (the default) |
| `everyTwoMinutes()` | every 2 minutes |
| `everyThreeMinutes()` | every 3 minutes |
| `everyFourMinutes()` | every 4 minutes |
| `everyFiveMinutes()` | every 5 minutes |
| `everyTenMinutes()` | every 10 minutes |
| `everyFifteenMinutes()` | every 15 minutes |
| `everyThirtyMinutes()` | at minute 0 and 30 |
| `hourly()` | at minute 0 of every hour |
| `hourlyAt(17)` | at minute 17 of every hour |
| `everyTwoHours()` | every 2 hours at minute 0. Also `everyThreeHours`, `everyFourHours`, `everySixHours`. Pass a minute: `everyTwoHours(15)` |
| `everyOddHour()` | at 01:00, 03:00 ... 23:00. Pass a minute: `everyOddHour(30)` |
| `daily()` | every day at 00:00 |
| `dailyAt('13:00')` | every day at 13:00 |
| `twiceDaily(1, 13)` | every day at 01:00 and 13:00 |
| `twiceDailyAt(1, 13, 15)` | every day at 01:15 and 13:15 |
| `at('13:00')` | same as `dailyAt('13:00')` |
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

### Day constraints

If a task should run only on some days, add a day method:

| Method | Runs |
| --- | --- |
| `weekdays()` | Monday to Friday |
| `weekends()` | Saturday and Sunday |
| `mondays()` ... `sundays()` | only on that day of the week |
| `days(<int>[DateTime.monday, DateTime.friday])` | only on these days |

```dart
s.call('standup', remind).weekdays().dailyAt('09:00');
```

A day method and a time method like `dailyAt()` can come in any order.

### Sub-minute tasks

A task with a seconds method, like `everyFiveSeconds()`, repeats inside each due minute. You can still limit the minutes with a frequency, days or filters. Call the seconds method first, because it also sets the task to every minute:

```dart
s.call('poll', poll).everyFiveSeconds().between('09:00', '17:00');
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

## Time zones

The schedule uses UTC by default. Use `timezone()` to read the time of a task in another zone:

```dart
s.call('report', sendReport).dailyAt('08:00').timezone('Asia/Yangon');
```

The name is an IANA name, like `Europe/London` or `America/New_York`. An unknown name throws an `ArgumentError` when the schedule starts.

To use one zone for every task, set it in the config. A task's own `timezone()` still wins:

```dart
ScheduleConfig scheduleConfig = const ScheduleConfig(timezone: 'Asia/Yangon');
```

## Limiting when a task runs

### Between times

Use `between` to run a task only in one time of day. Use `unlessBetween` to skip a time of day. Both ends are included, and a range can cross midnight:

```dart
s.call('sync', sync).everyFiveMinutes().between('09:00', '17:00');
s.call('night', night).hourly().between('22:00', '06:00');
s.call('quiet', quiet).hourly().unlessBetween('23:00', '04:00');
```

### Truth tests

Sometimes a task should run only when a condition is true. `when` runs the task when the function gives `true`, and `skip` skips it when the function gives `true`. The function can give a `bool` or a `Future<bool>`:

```dart
s.call('promo', promo).daily().when(isPromoOn);
s.call('backup', backup).daily().skip(isHoliday);
```

### Environments

Use `environments` to run a task only when `APP_ENV` is one of the names. When `APP_ENV` is not set, the task does not run:

```dart
s.call('emails', sendEmails).daily().environments(<String>['production']);
```

## Preventing task overlaps

A slow task may still run when its next minute comes. If it must not run twice at the same time, use `withoutOverlapping`. The task is then skipped while the last run still runs:

```dart
s.call('report', sendReport).everyFiveMinutes().withoutOverlapping();
```

The lock expires after 24 hours, in case the process dies. You can pass another expiry: `withoutOverlapping(Duration(hours: 1))`. After a crash, remove the lock at once with [`clear-cache`](#clearing-overlap-locks).

## Running tasks on one server

A task runs only once per tick across all isolates and servers. This is on by default (`onOneServer()`). Before a task runs, the scheduler takes a lock named after the task and the minute. The first process to get it runs the task, and the others skip it.

The locks live in a [cache](cache.md) store. If many servers run the schedule, use a shared store like Redis, because a `memory` or `file` store is not shared between servers:

```dart
ScheduleConfig scheduleConfig = const ScheduleConfig(store: 'redis');
```

If a task should run on every process instead, use `onEveryServer()`:

```dart
s.call('clear-tmp', clearTmp).hourly().onEveryServer();
```

## Background tasks

Tasks of the same minute run one after another. If a long task should not hold back the next one, use `runInBackground`:

```dart
s.call('export', export).daily().runInBackground();
```

## Timeouts

Use `timeout` to count a run as failed when it takes too long. The failure hooks then run:

```dart
s.exec('pg_dump', args: <String>['mydb']).daily().timeout(Duration(minutes: 5));
```

For an `exec()` or `command()` task, the process is killed at the timeout. A Dart function can not be stopped, so its work may go on after the timeout.

## Running the scheduler

`bin/schedule.dart` runs your schedule. With `app`, the runner starts your app providers first (like the database), and it stops them at the end:

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

The `dox` CLI runs the same file. For example, `dox schedule:work` is the same as `dart run bin/schedule.dart work`.

### Running the worker

`work` is a long running process. It wakes at each full minute and runs the due tasks. Run it next to your server, with the same deploy tool (systemd, Docker, Kubernetes):

```bash
dox schedule:work
```

On Ctrl+C or SIGTERM it starts no new task and waits for the running ones. A second signal stops it at once.

### Running from cron

If you would rather use the system cron, `run` runs the tasks of this minute once, waits for them, and exits. Add one line to the crontab:

```bash
* * * * * cd /path/to/app/build/bundle && ./bin/schedule run
```

`./bin/schedule` is the binary that `dox build` makes in `build/bundle`. It starts fast and needs no Dart SDK. Do not use `dart compile exe`, because it can not build apps with native libraries like SQLite. The exit code is 1 when a task failed.

### Listing tasks

`list` shows each task, its schedule and its next run time:

```bash
dox schedule:list
```

```
Task     Schedule                   Next run
cleanup  0 2 * * *                  2026-10-26 02:00 UTC
report   0 * * * *                  2026-10-25 14:00 UTC
ping     */5 * * * * Asia/Yangon    2026-10-25 20:35 Asia/Yangon
```

### Running one task now

`test` runs one task now, with its hooks. It does not check the schedule, the filters or the locks:

```bash
dox schedule:test cleanup
```

### Clearing overlap locks

If the process crashed while a task ran, its `withoutOverlapping()` lock stays in the store, so the task is skipped until the lock expires. `clear-cache` removes these locks:

```bash
dox schedule:clear-cache
```

Only run it when the task does not really run on another process or server. Otherwise that task could start a second time.

## Run inside the server

For a small app, you can run the schedule inside your Dox server instead of a `work` process. Add a provider that extends `SchedulerProvider`:

```dart title="lib/providers/schedule_provider.dart"
import 'package:dox_scheduler/dox_scheduler.dart';
import 'package:my_app/config/schedule.dart';

class ScheduleProvider extends SchedulerProvider {
  ScheduleProvider() : super(schedule: schedule, config: scheduleConfig);
}
```

Then turn it on in the config, and run `dart run build_runner build` so the generated container finds the provider:

```dart title="lib/config/schedule.dart"
ScheduleConfig scheduleConfig = const ScheduleConfig(inProcess: true);
```

Only the first isolate of the web server runs the tasks, and the other isolates only serve requests. A `bin/queue.dart` worker, a test or the `work` process does not start this in-process schedule. The `work` process runs the tasks on its own. In a test of the in-process schedule, set `Dox().isWebServer = true;` first. With many servers, each server runs the loop, and the once-per-tick lock makes each task run once. Use a Redis store for this. When the server stops, it waits for the running tasks.

The tasks use the CPU of the server, so they can slow down requests on the first isolate. A separate `work` process can be deployed, scaled and restarted on its own. So use `work` for heavy tasks.

## Logging the schedule

By default the scheduler prints its own plain `[schedule]` lines. To send them through the app `Logger` instead, turn on `loggerLines`:

```dart title="lib/config/schedule.dart"
ScheduleConfig scheduleConfig = const ScheduleConfig(
  flags: SchedulerFlags(loggerLines: true),
);
```

The lines get the tag `[scheduler]`, for example `[scheduler] ran cleanup in 12ms`. They follow `LoggerConfig.enabled`, `level` and `prettyPrint`. `SchedulerFlags.all()` turns on every flag.

## Task output

These hooks keep the output (stdout and stderr) of an `exec()` or `command()` task. They do nothing on a function task.

Use `sendOutputTo` to write the output to a file. It replaces the file each run:

```dart
s.exec('pg_dump', args: <String>['mydb']).daily().sendOutputTo('storage/logs/backup.log');
```

Use `appendOutputTo` to add the output to the end of the file:

```dart
s.exec('pg_dump', args: <String>['mydb']).daily().appendOutputTo('storage/logs/backup.log');
```

Use `onOutput` to get the output in code after the process ends. It holds the whole output in memory, so do not use it for a very large output:

```dart
s.exec('pg_dump', args: <String>['mydb']).daily().onOutput((String output) {...});
```

## Task hooks

Hooks run code around a task, for example to log it or to alert your team when it fails:

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
| `before` | before the task. If it throws, the task does not run and counts as failed |
| `onSuccess` | after the task worked |
| `onFailure` | after the task threw or timed out. It gets the error and the stack trace |
| `after` | after the task, always |

An error in a task is logged, and the next task still runs.

### Pinging URLs

You can send a GET request to a URL around a task, for example to a health check service:

```dart
s
    .call('backup', backup)
    .daily()
    .pingBefore('https://health.example.com/backup/start')
    .pingOnSuccess('https://health.example.com/backup')
    .pingOnFailure('https://health.example.com/backup/fail');
```

`thenPing(url)` pings after the task, always. Each ping method also has an `If` form that takes a bool first, like `pingOnFailureIf(isProduction, url)`. A failed ping is logged, but it never fails the task.

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

With no `app`, no providers start, and the locks use a memory store. For many servers, pass a shared `CacheStore` from `dox_cache`, like `SchedulerRunner(schedule: schedule, store: myRedisStore)`. The commands are the same.

## Testing

`Scheduler` runs the tasks. Give it a fake clock, so you can test a schedule with no waiting:

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

To check a schedule without running anything, use `ScheduledTask.isDue(time)` and `ScheduledTask.nextRun(time)`. To replace the ping request in tests, set `ScheduledTask.sendPing = (Uri url) async {...};`.

## Details

This section is for special cases. Most apps do not need it.

### Frequencies

- The day methods, `weekly()`, `weeklyOn()` and `cron()` all set the day of the week. The last call wins: `.mondays().weekly()` runs on Sundays.
- `weekly()` and `weeklyOn()` also set the time (00:00 unless you pass one). So `.dailyAt('09:00').weekly()` runs at 00:00, but `.weekly().dailyAt('09:00')` runs at 09:00.
- A day of the month and a day of the week join with OR, like standard cron: `monthlyOn(15).fridays()` and `0 0 1 * MON` run on that date and on every such weekday. When one day field of a cron expression starts with `*`, both must match.
- `lastDayOfMonth()` runs only on the last day of the month, whatever day methods you add. `list` shows it as `28-31`, but the next run time is right.
- `yearlyOn()` with a day the month never has, like `yearlyOn(2, 30)`, throws.
- A seconds method called last undoes the frequency before it: `.everyFiveSeconds().hourly()` repeats in minute 0 of each hour, but `.hourly().everyFiveSeconds()` repeats in every minute.
- With a sub-minute task, `when()` and `skip()` are checked before each repeat. A run that takes longer than its step skips the steps it missed. `run` from cron then stays until the end of the minute, and `work` also wakes inside the minute.
- With summer time (DST), a time that does not exist that day does not run, and a time that happens twice runs once. `hourly()` and other "every" frequencies keep running every real hour.
- The zone data comes from the `timezone` package.

### Filters and locks

- `environments()` ignores case and spaces around the names. It is read at run time. An empty list or a blank name throws.
- With `loggerLines` on, the plain `[schedule]` line is left out on stdout and stderr when the Logger printed it. So the lock store warning goes to stdout, not to stderr. Other sinks (like a `StringBuffer`) still get every plain line.
- The once-per-tick lock is not released, so a late server can not run the same minute again. It expires after 10 minutes. When the store is `null`, the scheduler uses a memory store.
- At start, the scheduler prints one warning to stderr when a task uses `onOneServer()` and the lock store is `memory`, `file` or `null`. It does not print when `APP_ENV` is `development` or `local`. With one server you can ignore it.
- `clear-cache` removes only the `withoutOverlapping()` lock of each task, by its exact name. Other cache keys and the once-per-tick locks stay. It exits with 0, also when there was no lock. A `memory` store loses its locks with the process, so `clear-cache` is for `file` and Redis stores.

### Processes

- The stdin of an `exec()` or `command()` process is closed, so a program that waits for input ends at once.
- At a timeout the process gets SIGTERM, and SIGKILL 5 seconds later (`Schedule.processGrace`). Only the process itself is killed, so the children of a shell (`sh -c 'a | b'`) may live on.
- A stop of `work` waits for the processes to end.
- If `dox` is not on PATH, set its full path: `Schedule.doxExecutable = '/usr/local/bin/dox';`.
- A `name:` also lets you add the same command line twice.

### Output and pings

- The file gets the output as it comes. Two runs at the same time write to the same file, so use `withoutOverlapping()` or `appendOutputTo()`.
- A file that can not be written fails the task, and so does a throwing `onOutput` hook. `onOutput` still gets the output first. When more than one thing fails, the error is the first of: a non-zero exit code, an `onOutput` error, a file error.
- After a timeout, the file and `onOutput` finish a bit later, after the failure hooks ran. An error there is lost.
- A ping fails after 10 seconds (`ScheduledTask.pingTimeout`), or on a status of 400 or more. A URL that is not `http` or `https` throws an `ArgumentError` when the schedule is made.
- The next run time in `list` checks the frequency, `between()` and `unlessBetween()`. It does not check `when()`, `skip()` and `environments()`.

## See also

- [Queue](queue.md): jobs that must not get lost.
- [Background work](../guides/background-work.md): pick the right tool for work after the response.
- [CLI](../reference/cli.md): the `schedule:*` commands.
