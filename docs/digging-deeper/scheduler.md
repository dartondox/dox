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

Or run `dox add scheduler`. It adds the package and writes the three files below. It never overwrites a file.

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

To send the job to a queue connection, pass `connection:` to `dispatch()`:

```dart
void schedule(Schedule s) {
  s.call('send-report', () => SendReport().dispatch()).dailyAt('08:00');
  s.call('prune', () => PruneFiles().dispatch(connection: 'redis')).hourly();
}
```

The task name must be unique in the schedule.
`connection:` of `dispatch()` is a [queue connection](queue.md#queue-connections). Without it, the main connection is used.

### Processes and dox commands

```dart
s.exec('pg_dump', args: <String>['-f', 'backup.sql', 'mydb']).daily();
s.command('queue:prune', args: <String>['--hours=48']).hourly();
```

`exec(executable, args: [...])` runs a process. No shell is used, so `|`, `>` and `*` are plain text.
Use `s.exec('sh', args: <String>['-c', '...'])` when you need a shell.
A non-zero exit code fails the task.
Its stdin is closed, so a program that waits for input ends at once.
With `timeout()`, the process gets SIGTERM when the time is up, and SIGKILL 5 seconds later (`Schedule.processGrace`).
Only the process itself is killed. The children of a shell (`sh -c 'a | b'`) may live on.
A stop of `work` waits for the process to end.

`command(command, args: [...])` runs a `dox` command of your app, as the process `dox <command> <args>`.
When `dox` is not on PATH, set its full path: `Schedule.doxExecutable = '/usr/local/bin/dox';`.

The task name is the command line, like `dox queue:prune --hours=48`.
It shows in the logs, the lock keys and `list`.
So do not put a secret (like `--token=...`) in `args` without your own name: `s.command('sync', args: <String>['--token=$token'], name: 'sync')`.
A name also lets you add the same command line twice.

The output is dropped. Use the [output hooks](#output-hooks) to keep it.

## Frequencies

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
| `yearlyOn(6, 1, '17:00')` | June 1st at 17:00. A day the month never has, like `yearlyOn(2, 30)`, throws |
| `cron('*/5 9-17 * * 1-5')` | any 5 field cron expression |

A task that runs every few seconds repeats inside each due minute.
A frequency, the days, the filters and `timezone()` still decide if the minute is due: `s.call('poll', poll).everyFiveSeconds().between('09:00', '17:00')`.
Call the seconds method first, then the other frequency.
`everyFiveSeconds()` also sets the task to every minute. If you call it last, it undoes the frequency before it.
`.everyFiveSeconds().hourly()` repeats in minute 0 of each hour. `.hourly().everyFiveSeconds()` repeats in every minute.
`when()` and `skip()` are checked before each repeat.
A run that takes longer than its step skips the steps it missed.
With such a task, `run` from cron stays until the end of the minute.

You can limit the days. The order does not matter between the day methods (like `weekdays()` or `mondays()`) and a time method like `dailyAt()`.
The day methods, `weekly()`, `weeklyOn()` and `cron()` all write the day of the week. The last call wins: `.mondays().weekly()` runs on Sundays.
`weekly()` and `weeklyOn()` also set the time, to 00:00 unless you pass one. So call `dailyAt()` after them, or pass the time to `weeklyOn()`: `.dailyAt('09:00').weekly()` runs at 00:00, but `.weekly().dailyAt('09:00')` runs at 09:00.

| Method | Runs |
| --- | --- |
| `weekdays()` | Monday to Friday |
| `weekends()` | Saturday and Sunday |
| `mondays()` ... `sundays()` | only on that day of the week |
| `days(<int>[DateTime.monday, DateTime.friday])` | only on these days |

```dart
s.call('standup', remind).weekdays().dailyAt('09:00');
```

A day of the month and a day of the week join with OR, like cron.
`monthlyOn(15).fridays()` runs on the 15th and on every Friday.
`lastDayOfMonth()` is different: it runs only on the last day of the month.
`lastDayOfMonth().fridays()` runs on every last day of the month, on any day of the week. The `fridays()` part has no effect.

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

To use one zone for every task, set it in the config.
A task's own `timezone()` still wins.

```dart
ScheduleConfig scheduleConfig = const ScheduleConfig(timezone: 'Asia/Yangon');
```

An unknown name throws an `ArgumentError` when the schedule starts.

With summer time (DST):

- A time that does not exist that day (it is skipped when the clock goes forward) does not run that day.
- A time that happens twice (when the clock goes back) runs once.
- `hourly()` and other "every" frequencies keep running every real hour.

## Filters

```dart
s.call('sync', sync).everyFiveMinutes().between('09:00', '17:00');
s.call('night', night).hourly().between('22:00', '06:00'); // crosses midnight
s.call('quiet', quiet).hourly().unlessBetween('23:00', '04:00');
s.call('emails', sendEmails).daily().environments(<String>['production']);
s.call('promo', promo).daily().when(isPromoOn);
s.call('backup', backup).daily().skip(isHoliday);
```

| Method | What it does |
| --- | --- |
| `between('09:00', '17:00')` | runs only in this time of day, both ends included, in the task zone |
| `unlessBetween('23:00', '04:00')` | does not run in this time of day, both ends included, in the task zone |
| `environments(<String>['production'])` | runs only when `APP_ENV` is one of these names. Case and spaces around the names do not matter. When `APP_ENV` is not set or empty, the task does not run. It is read at run time. An empty list or a blank name throws |
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
| `timeout(Duration(minutes: 5))` | counts the run as failed when it takes longer. It kills the process of an `exec()` or `command()` task |

### withoutOverlapping

A lock is held while the task runs.
When the next minute comes and the lock is still held, the task is skipped.
The lock expires after 24 hours, in case the process dies.
Pass another expiry like this: `withoutOverlapping(Duration(hours: 1))`.

When the process crashes, the lock stays in the store.
The task is then skipped until the lock expires.
To run it again at once, remove the lock with [`clear-cache`](#clear-cache):

```bash
dox schedule:clear-cache
```

### Once per tick

Before a task runs, the scheduler takes a lock named after the task and the minute.
The first process to take it runs the task. The others skip it.
The lock is not released, so a late server can not run the same minute again. It expires after 10 minutes.

The locks use a [cache](cache.md) store.

!!! warning "Many servers need Redis"
    A `memory` store lives inside one process. A `file` store lives on one machine.
    It works for one `work` process, or for many isolates of one server.
    When many servers run the schedule, set a Redis store:
    `ScheduleConfig(store: 'redis')`.

When the store has no locks (`null`), the scheduler uses a memory store.

At start, the scheduler prints one warning to stderr when a task uses `onOneServer()` and the lock store is `memory` or `file` (or `null`).
These stores are not shared between servers, so the lock works only inside one server.
The warning does not print when `APP_ENV` is `development` or `local`, because a dev machine is one server.
With one server you can ignore it.

### Timeout

Dart can not stop a running function.
After the timeout, the run counts as failed and the hooks run, but the work may go on.
The process of an `exec()` or `command()` task is killed at the timeout.

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

### Output hooks

These work on `exec()` and `command()` tasks. On a function task they do nothing.

| Hook | What it does |
| --- | --- |
| `sendOutputTo('storage/logs/backup.log')` | writes the output (stdout and stderr) to the file. It replaces the file each run |
| `appendOutputTo('storage/logs/backup.log')` | adds the output to the end of the file |
| `onOutput((String output) {...})` | gets the output after the process ends |

- The file gets the output as it comes. `onOutput` holds the whole output in memory, so do not use it for a very large output.
- Two runs at the same time write to the same file. Use `withoutOverlapping()` or `appendOutputTo()`.
- A file that can not be written fails the task. `onOutput` still gets the output first.
- A throwing `onOutput` hook fails the task.
- When more than one thing fails, the task fails with the first of: a non-zero exit code, an `onOutput` error, a file error.
- After a timeout, the file and `onOutput` finish a bit later, after the failure hooks ran. An error there is lost.

### Ping hooks

```dart
s
    .call('backup', backup)
    .daily()
    .pingBefore('https://health.example.com/backup/start')
    .pingOnSuccess('https://health.example.com/backup')
    .pingOnFailure('https://health.example.com/backup/fail');
```

| Hook | Sends a GET request |
| --- | --- |
| `pingBefore(url)` | before the task |
| `thenPing(url)` | after the task, always |
| `pingOnSuccess(url)` | after the task worked |
| `pingOnFailure(url)` | after the task failed |

Each one also has an `If` form that takes a bool first, like `pingOnFailureIf(isProduction, url)`.

- A ping fails after 10 seconds (`ScheduledTask.pingTimeout`), or on a status of 400 or more.
- A failed ping is logged. It never fails the task.
- A url that is not `http` or `https` throws an `ArgumentError` when the schedule is made.
- In tests, replace the request: `ScheduledTask.sendPing = (Uri url) async {...};`.

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
| `dart run bin/schedule.dart clear-cache` | removes the `withoutOverlapping()` locks, after a crash |

The `dox` CLI runs the same file: `dox schedule:work`, `dox schedule:run`, `dox schedule:list`, `dox schedule:test <name>` and `dox schedule:clear-cache`.

### work

`work` is a long running process. Run it next to your server, with the same deploy tool (systemd, Docker, Kubernetes).

It wakes at each full minute and runs the due tasks.
With a task that runs every few seconds, it also wakes inside the minute.
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

The next run time checks the frequency, `between()` and `unlessBetween()`. It does not check `when()`, `skip()` and `environments()`.

`lastDayOfMonth()` shows `28-31` in the day field, but it runs only on the last day of the month.
The next run time is right.

### test

`test <name>` runs one task now, with its hooks.
It does not check the schedule, the filters or the locks.

### clear-cache

`clear-cache` removes the `withoutOverlapping()` lock of each task in the schedule.
Use it after a crash, when a task is skipped because its lock is still there.

```
$ dox schedule:clear-cache
Removed the overlap lock of report.
```

When there is no lock, it prints this:

```
No overlap locks found. Nothing to clear.
```

The exit code is 0 in both cases.

It removes only the lock key of each task, by its exact name.
Other keys in the cache store stay.
It does not remove the once-per-tick locks of `onOneServer()`. Each one is for one minute only, and it expires after 10 minutes.

!!! warning "Only when the task is not running"
    Do not run it while a task really runs on another process or server.
    That task could then start a second time.

A `memory` store lives inside one process, so its locks end with the process.
`clear-cache` is for `file` and Redis stores.

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

`ScheduledTask.isDue(time)` and `ScheduledTask.nextRun(time)` check a schedule with no run at all.
