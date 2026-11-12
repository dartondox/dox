---
date:
  created: 2026-11-12
authors:
  - dox
categories:
  - Guides
tags:
  - queue
  - scheduler
  - mail
  - tutorial
slug: background-jobs-and-scheduled-tasks
---

# Background jobs and scheduled tasks in Dox

This post shows how to move slow work out of the request with a queue, and how to run work on a timer with the scheduler.

<!-- more -->

Some work is too slow for a request.
Sending an email can take a second or more. A report can take a minute.
The user should not wait for it.

Some work has no request at all.
A daily summary email, or a cleanup of old rows at night.

Dox has two packages for this:

- `dox_queue` runs jobs in the background. It has retries, delays and a worker process.
- `dox_scheduler` runs tasks on a schedule, like cron, written in Dart.

The example is a team app with projects and tasks.
It sends a welcome email when a user signs up, a daily summary of open tasks, and it cleans up old data at night.

## The steps in short

1. Pick a queue driver. A new app already has the queue and the scheduler.
2. Add `dox_mailer` to send email.
3. Queue the welcome email with one line.
4. Write a job for the daily summary.
5. Put the job and a cleanup task on the schedule.
6. Run the worker and the scheduler next to the server.
7. Test it with no real queue.

## 1. The queue

A new app from `dox create` already has `dox_queue` and `dox_scheduler`, with these files:

- `lib/config/queue.dart` and `lib/providers/queue_provider.dart`
- `lib/config/schedule.dart` and `lib/providers/schedule_provider.dart`
- `bin/queue.dart` and `bin/schedule.dart`

The queue uses the database driver by default. Make its tables once:

```bash
dox queue:table
dox migrate
```

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

The database driver needs nothing more than the database you already have.
For many jobs, switch to `redis`.

## 2. Add mail

```bash
dart pub add dox_mailer
```

```dart title="lib/config/mail.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_mailer/dox_mailer.dart';

MailConfig mailConfig = MailConfig(
  defaultMailer: Env.get('MAIL_MAILER', 'log'),
  from: Address(Env.get('MAIL_FROM', 'hello@example.com'), 'Team app'),
  mailers: <String, Transport>{
    'smtp': SmtpTransport(
      host: Env.get('MAIL_HOST', 'localhost'),
      port: Env.get<int>('MAIL_PORT', 587),
      username: Env.get<String?>('MAIL_USERNAME'),
      password: Env.get<String?>('MAIL_PASSWORD'),
    ),

    /// prints emails, sends nothing. Good for local work.
    'log': LogTransport(),
  },
);
```

```dart title="lib/providers/mail_provider.dart"
import 'package:dox_mailer/dox_mailer.dart';

import '../config/mail.dart';

class AppMailProvider extends MailProvider {
  AppMailProvider() : super(mailConfig);
}
```

SMTP, Amazon SES, Resend, Mailgun and Postmark all work. You change the provider in the config, not in the code.

## 3. Queue the welcome email

A mailable is one kind of email in its own class:

```bash
dox make:mail Welcome
```

```dart title="lib/app/mail/welcome_mail.dart"
class WelcomeMail extends Mailable {
  WelcomeMail(this.user);

  final User user;

  @override
  List<Address> get to => <Address>[Address(user.email!, user.name)];

  @override
  String get subject => 'Welcome to the team';

  @override
  String? get view => 'emails/welcome';

  @override
  Map<String, Object?> get data => <String, Object?>{'name': user.name};
}
```

Now send it from the queue, after sign up:

```dart title="lib/app/services/user.service.dart"
Future<User> signUp(SignUp body) async {
  User user = await users.create(body);
  await WelcomeMail(user).queue();
  return user;
}
```

`queue()` renders the email at once and puts it on the queue.
The request answers right away. A worker sends the email.
You need no job class for this. `dox_queue` has a built-in job for email.

## 4. Write a job

For your own work, write a job class.
The daily summary loads the open tasks of a user and emails them:

```bash
dox make:job SendDailySummary
```

```dart title="lib/app/jobs/send_daily_summary.job.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_queue/dox_queue.dart';

@Job()
class SendDailySummary extends DoxJob {
  SendDailySummary({required this.userId});

  final int userId;

  /// run up to 3 times
  @override
  int get tries => 3;

  /// wait 1 minute before the 2nd try, 5 minutes before the 3rd
  @override
  List<Duration> get backoff => const <Duration>[
    Duration(minutes: 1),
    Duration(minutes: 5),
  ];

  @override
  String get queue => 'emails';

  @override
  Future<void> handle() async {
    SummaryService summary = Dox().ioc.get<SummaryService>();
    await summary.sendTo(userId);
  }

  /// runs once, after the last try failed
  @override
  Future<void> failed(Object error, StackTrace stack) async {
    Logger.warn('daily summary of user $userId failed: $error');
  }
}
```

Run `dart run build_runner build` after you add or change a job.
It writes `lib/generated/jobs.g.dart`, so the worker knows how to save and load the job.

Two rules for jobs:

- **Save an id, not an object.** The job saves `userId`, not a `User`. The user can change between dispatch and run. The id gives fresh data.
- **Get services in `handle()`.** A job is made again from its saved data, so it can not get services in its constructor. Use `Dox().ioc.get<T>()`.

Dispatch it from anywhere:

```dart
await SendDailySummary(userId: user.id!).dispatch();

// later, or at a time
await SendDailySummary(userId: 1).dispatch(delay: Duration(minutes: 10));
```

## 5. The schedule

The schedule is one Dart file.
Each task is a plain function, or a job.

```dart title="lib/config/schedule.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_scheduler/dox_scheduler.dart';
import 'package:team/app/jobs/send_daily_summary.job.dart';
import 'package:team/app/models/task/task.model.dart';
import 'package:team/app/services/user.service.dart';

ScheduleConfig scheduleConfig = const ScheduleConfig(timezone: 'Asia/Yangon');

void schedule(Schedule s) {
  /// every morning, put one summary job per user on the queue
  s.call('daily-summary', queueSummaries).weekdays().dailyAt('08:00');

  /// at night, delete tasks that were done more than 90 days ago
  s.call('cleanup', cleanup).dailyAt('02:00').withoutOverlapping();

  /// remove failed jobs older than 2 days
  s.command('queue:prune-failed', args: <String>['--hours=48']).daily();
}

Future<void> queueSummaries() async {
  List<int> ids = await Dox().ioc.get<UserService>().idsWithOpenTasks();
  for (int id in ids) {
    await SendDailySummary(userId: id).dispatch();
  }
}

Future<void> cleanup() async {
  DateTime before = DateTime.now().subtract(const Duration(days: 90));
  await Task().where('done_at', '<', before).delete();
}
```

- The scheduler does the timing. The queue does the work. The summary task only puts jobs on the queue, so 1,000 users do not block the scheduler.
- `timezone` reads `08:00` in your zone, not in UTC.
- `withoutOverlapping()` skips a run while the last one still runs.
- Each task runs once per tick, even when many isolates or servers run the schedule. With many servers, use a Redis cache store for the locks.

See the next run of each task:

```bash
dox schedule:list
```

Run one task now, to try it:

```bash
dox schedule:test cleanup
```

## 6. Run the worker and the scheduler

In dev, run three processes:

```bash
dox s
dox queue:work --queue=emails,default
dox schedule:work
```

`--queue=emails,default` works both queues. The first one goes first.

In production, `dox build` makes binaries for all three in `build/bundle/bin`.
Run them next to each other. For example with Docker Compose:

```yaml
services:
  web:
    build: .
    command: /app/bin/server
  worker:
    build: .
    command: /app/bin/queue work --queue=emails,default --concurrency=4
  scheduler:
    build: .
    command: /app/bin/schedule work
```

- `--concurrency=4` runs four jobs at once. It helps for jobs that wait, like email and HTTP calls.
- On `docker stop`, the worker takes no new job and waits for the running ones.
- The worker keeps your code in memory. Restart it on each deploy.

For a small app, you can skip the extra processes.
`QueueConfig(workInProcess: true)` runs jobs inside the web server, and `ScheduleConfig(inProcess: true)` runs the schedule there too.
Use separate processes when the jobs get heavy, so they do not slow down your API.

## 7. Failed jobs

When `handle()` throws, the worker waits the `backoff` time and tries again.
After the last try, the job goes to the failed jobs, and `failed()` runs.

```bash
dox queue:failed          # list them
dox queue:retry <id>      # put one back on its queue
dox queue:retry all       # put all back
```

Dart can not stop a running `Future`.
After a timeout, the try counts as failed, but the code can keep running.
So write jobs that are safe to run twice.

## 8. Test it

`Queue.fake()` records each dispatch, and runs nothing.
`Mail.fake()` does the same for email. A queued email goes to `mail.queued`, not to the job queue:

```dart
late QueueFake queue;
late ArrayTransport mail;

setUp(() {
  queue = Queue.fake();
  mail = Mail.fake();
});

tearDown(() {
  Queue.restore();
  Mail.restore();
});

test('sign up queues the welcome email', () async {
  await userService.signUp(const SignUp(name: 'Ann', email: 'ann@example.com'));
  mail.assertQueued((Message m) => m.subject == 'Welcome to the team');
  mail.assertNothingSent();
});

test('the morning task queues one summary per user', () async {
  await queueSummaries();
  queue.assertPushedTimes<SendDailySummary>(2);
});
```

To test the job itself, call `handle()`:

```dart
await SendDailySummary(userId: 1).handle();
```

## What you get

- Requests answer at once. Slow work runs in a worker.
- Retries, delays and failed jobs with no extra code.
- The schedule in Dart, in one file, with time zones.
- Each scheduled task runs once, on one server or many.
- Fakes for the queue and mail, so tests need no Redis and no SMTP.

Full docs: [Background work](/latest/guides/background-work/), [Queue](/latest/digging-deeper/queue/), [Scheduler](/latest/digging-deeper/scheduler/), [Mail](/latest/digging-deeper/mail/)
