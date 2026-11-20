---
title: "Dox vs Serverpod: which Dart backend fits your app"
date:
  created: 2026-11-20
authors:
  - dox
categories:
  - Guides
tags:
  - comparison
slug: dox-vs-serverpod
description: "Dox and Serverpod side by side: endpoints, models, ORM, migrations, background jobs, auth, mail and deploy, with code from each, so you can pick a Dart backend."
---

# Dox vs Serverpod: which Dart backend fits your app

Dox and Serverpod are both full Dart backends with an ORM and migrations, but Serverpod is built around a Flutter client, and Dox is a plain HTTP API for any client.

<!-- more -->

Our post [Dart backend frameworks: how to choose](dart-backend-frameworks-how-to-choose.md) puts five options in one table.
This post looks only at Dox and Serverpod, because they are the two that people compare most when they want a full backend.
We show the same tasks in both, with code.

We build Dox, so we are not neutral.
Every fact about Serverpod links to [its own docs](https://docs.serverpod.dev).
We checked them on 2026-11-20, on Serverpod 4.1.

!!! tip "In brief"
    - Your client is a Flutter app, and you want the client code made for you: pick **Serverpod**.
    - Your API has many kinds of clients, you want a queue and mail in the box, or you use MySQL: pick **Dox**.

## The main difference

The two frameworks start from a different idea.

- **Serverpod** makes your server and your Flutter app one project.
  You write a Dart method on the server.
  Serverpod [generates a client](https://docs.serverpod.dev/concepts/endpoints-and-apis), and the app calls the method like a local function.
  A new project has three packages: `_server`, `_client` and `_flutter` ([How it works](https://docs.serverpod.dev/how-it-works)).
- **Dox** makes a plain HTTP API.
  You write routes and controllers.
  Any client can call them: a Flutter app, a web app, or another server.
  Dox makes an [OpenAPI document](/latest/packages/openapi/) from your routes, so other teams can see the API and make clients from it.

Most other differences come from this one.

## Side by side

| | Dox | Serverpod |
| --- | --- | --- |
| API style | HTTP routes and controllers | Endpoint methods, called through a generated Dart client |
| Client | Any. OpenAPI document made for you. | Generated Dart client for Flutter |
| Models | Dart classes with `@DoxModel` | YAML files (`.spy.yaml`) |
| Input checks | `@Dto` classes, `422` on bad input | Typed method parameters |
| Databases | Postgres, MySQL, MariaDB, SQLite | Postgres 16+, SQLite |
| Migrations | Written in Dart, `dox migrate` | Made from model files, `serverpod create-migration` |
| Background jobs | Queue (database or Redis) with retries | Future calls, stored in the database |
| Scheduled tasks | Scheduler (cron, `dailyAt`, time zones) | Recurring future calls (interval or cron) |
| Auth | JWT, sessions, access tokens | Email, Google, Apple, Facebook, GitHub, Microsoft, Firebase, passkeys |
| Mail | SMTP, SES, Resend, Mailgun and more | Sign-in emails on Serverpod Cloud; otherwise your own package |
| Real-time | Socket.IO server, raw WebSocket | Streaming methods over a WebSocket |
| Hosting | You deploy it: binary or Docker | Serverpod Cloud, or you deploy it with Docker |
| License | MIT | BSD-3, except the main `serverpod` package (SSPL) |

Sources for the Serverpod column:
[endpoints](https://docs.serverpod.dev/concepts/endpoints-and-apis),
[models](https://docs.serverpod.dev/concepts/data-and-the-database/models),
[database connection](https://docs.serverpod.dev/concepts/data-and-the-database/database/connection),
[future calls](https://docs.serverpod.dev/concepts/scheduling/overview),
[auth setup](https://docs.serverpod.dev/concepts/authentication/setup),
[email sign-in](https://docs.serverpod.dev/concepts/authentication/providers/email/setup),
[streaming](https://docs.serverpod.dev/concepts/endpoints-and-apis/streaming),
[deploy](https://docs.serverpod.dev/deployments/custom-hosting/hosting-elsewhere),
[pub.dev](https://pub.dev/packages/serverpod).

## Start a project

Both start with no database to install.

```bash title="Dox"
dart pub global activate dox
dox create team_app
cd team_app
dart pub get
dox s
```

A new Dox app uses SQLite.
The database file is made at the first start.

```bash title="Serverpod"
dart install serverpod_cli
serverpod quickstart team_app
cd team_app
serverpod start
```

A new Serverpod app runs an embedded Postgres that Serverpod downloads for you ([Installation](https://docs.serverpod.dev/installation)).
Serverpod 4 needs Flutter 3.44.4 or later on your machine.

## Write an endpoint

The example app has projects and tasks.
We want one call that makes a task.

In Serverpod, an endpoint is a class with methods.
The first parameter is always a `Session`:

```dart title="Serverpod"
class TaskEndpoint extends Endpoint {
  Future<Task> create(Session session, String title, int projectId) async {
    return await Task.db.insertRow(
      session,
      Task(title: title, projectId: projectId),
    );
  }
}
```

The Flutter app then calls `await client.task.create('Write docs', 1);`.
You write no HTTP code and no JSON parsing.
That is the strongest part of Serverpod.

In Dox, you write a DTO, a controller method and a route:

```dart title="lib/app/dtos/save_task/save_task.dto.dart"
@Dto()
class SaveTask {
  @Trim()
  @Length(min: 3, max: 100)
  final String title;

  final int projectId;

  const SaveTask({required this.title, required this.projectId});

  static const DtoSchema<SaveTask> schema = $SaveTaskDto;
}
```

```dart title="lib/app/http/controllers/task.controller.dart"
@Inject()
class TaskController {
  Future<DoxResponse> store(SaveTask body) async {
    Task task = Task()
      ..title = body.title
      ..projectId = body.projectId;
    await task.save();
    return response(task).statusCode(201);
  }
}
```

```dart title="lib/routes/api.dart"
Route.post('/tasks', (TaskController c) => c.store);
```

This is more code than Serverpod.
In return, you get a normal `POST /tasks` that any HTTP client can call.
Bad input gets a `422` with the errors, and the same DTO goes into the OpenAPI document.
For a Flutter app, you can put the DTO in a shared package, so the app checks input with the same rules. See [Share code with Flutter](/latest/guides/share-code-with-flutter/).

## Models and the ORM

**Serverpod** models are YAML files.
Serverpod makes the Dart class from them:

```yaml title="Serverpod: task.spy.yaml"
class: Task
table: task
fields:
  title: String
  projectId: int
```

You query with a generated `db` object and typed column functions ([CRUD](https://docs.serverpod.dev/concepts/data-and-the-database/database/crud)):

```dart title="Serverpod"
var tasks = await Task.db.find(
  session,
  where: (t) => t.projectId.equals(1),
  limit: 50,
);
```

**Dox** models are Dart classes.
You write the fields yourself, and `build_runner` makes the rest:

```dart title="lib/app/models/project/project.model.dart"
@DoxModel(table: 'projects')
class Project extends ProjectGenerator {
  @Column()
  String? name;

  @HasMany(Task)
  List<Task> tasks = <Task>[];
}
```

```dart title="Dox"
List<Task> tasks = await Task().where('project_id', 1).limit(50).get();

Project? project = await Project().preload('tasks').find(1);
```

Both ORMs have relations, transactions and typed results.
Pick by taste: YAML that makes the class (Serverpod), or a Dart class you write (Dox).

## Migrations

**Serverpod** makes the migration from your model files.
You change a `.spy.yaml` file and run `serverpod create-migration`.
In development, you press `M` in the `serverpod start` terminal.
In production, you start the server with `--apply-migrations` ([Migrations](https://docs.serverpod.dev/concepts/data-and-the-database/database/migrations)).

**Dox** migrations are Dart files that you write, with `up` and `down`:

```bash
dox make:migration create_tasks_table
dox migrate
```

```dart title="db/migration/2026_11_20_120000_create_tasks_table.dart"
class CreateTasksTable extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await schema.create('tasks', (Table table) {
      table.id();
      table.string('title');
      table.foreignId('project_id').constrained();
      table.timestamps();
    });
  }

  @override
  Future<void> down(Schema schema) async {
    await schema.dropIfExists('tasks');
  }
}
```

The Serverpod way is less work, because the schema follows the models.
The Dox way gives you full control, and the same file runs on Postgres, MySQL, MariaDB and SQLite. See [Migration](/latest/database/migration/).

## Background jobs and schedules

**Serverpod** has [future calls](https://docs.serverpod.dev/concepts/scheduling/future-calls).
A future call is a method that runs later.
It is stored in the database, so it survives a restart:

```dart title="Serverpod"
await pod.futureCalls
    .callWithDelay(const Duration(hours: 1))
    .example
    .doWork();
```

[Recurring future calls](https://docs.serverpod.dev/concepts/scheduling/recurring-tasks) take an interval or a cron line.
On Serverpod Cloud, future calls need the Growth or Enterprise plan ([overview](https://docs.serverpod.dev/concepts/scheduling/overview)).

**Dox** has a [queue](/latest/digging-deeper/queue/) and a [scheduler](/latest/digging-deeper/scheduler/).
A job is a class.
A worker process runs it, with retries and delays:

```dart title="lib/app/jobs/send_task_report.dart"
@Job()
class SendTaskReport extends DoxJob {
  SendTaskReport({required this.projectId});

  final int projectId;

  @override
  Future<void> handle() async {
    // build the report and send it
  }
}
```

```dart
await SendTaskReport(projectId: 1).dispatch();
```

The scheduler runs plain functions on a schedule, with time zones:

```dart title="lib/config/schedule.dart"
void schedule(Schedule s) {
  s.call('cleanup', cleanup).dailyAt('02:00').timezone('Asia/Yangon');
  s.call('report', () => SendTaskReport(projectId: 1).dispatch()).hourly();
}
```

Both cover "run this later" and "run this every night".
Dox adds a separate worker process, retries, and a Redis driver for apps with many jobs.

## Auth and mail

**Serverpod** has more sign-in providers in the box: email, Google, Apple, Facebook, GitHub, Microsoft, Firebase and passkeys ([auth setup](https://docs.serverpod.dev/concepts/authentication/setup)).
It also has the Flutter sign-in widgets.
For mail, Serverpod Cloud sends the sign-in emails.
When you host it yourself, the docs suggest the [`mailer`](https://pub.dev/packages/mailer) package ([email setup](https://docs.serverpod.dev/concepts/authentication/providers/email/setup)).

**Dox** has [JWT, sessions and access tokens](/latest/security/authentication/).
Social login and password reset are up to your app.
[Mail](/latest/digging-deeper/mail/) is built in, with SMTP, SES, Resend, Mailgun and more, for any email your app sends.

If social login in a Flutter app is the main need, Serverpod saves you more time.
If your app sends many kinds of email, Dox saves you more time.

## Deploy

**Serverpod** has [Serverpod Cloud](https://docs.serverpod.dev/deployments/deploy-to-serverpod-cloud), a hosted service.
You run `serverpod cloud deploy`, and it runs your server, database and migrations for you.
You can also host it yourself with the Dockerfile in the server package ([hosting elsewhere](https://docs.serverpod.dev/deployments/custom-hosting/hosting-elsewhere)).

**Dox** has no hosted service.
`dox build` makes a native binary, and you run it on a VPS or in Docker.
The docs have guides for [Docker](/latest/guides/docker/), [a VPS](/latest/guides/deploy-vps/), [Fly.io](/latest/guides/deploy-fly/) and [Cloud Run](/latest/guides/deploy-cloud-run/).

## Speed

We did not run this benchmark.
The numbers come from the public [Web Frameworks Benchmark](https://web-frameworks-benchmark.vercel.app/) by [the-benchmarker](https://github.com/the-benchmarker/web-frameworks).

Serverpod itself is not in that benchmark.
[Relic](https://pub.dev/packages/relic) is in it.
Relic is the HTTP server from the Serverpod team, and Serverpod's [web server](https://docs.serverpod.dev/concepts/web-server/overview) is built on it.
So this compares the HTTP layer of the two projects.
It does not measure Serverpod endpoint calls or a database.

| Connections | Dox (requests per second) | Relic (requests per second) |
| --- | --- | --- |
| 64 | 157,805 | 45,785 |
| 256 | 189,869 | 45,034 |
| 512 | 189,851 | 44,291 |

At 64 connections, half of the Dox requests took 0.11 ms or less.
For Relic, it was 0.86 ms.

How they measured it:

- Three small routes: `GET /`, `GET /user/:id` and `POST /user`.
- One machine with an AMD Ryzen 7 5700U. The server and the load tool run on it, with the same limits for every framework.
- Both apps are AOT builds, and both start one isolate per CPU that Dart reports.
- Versions: `dox_core` 3.2 and `relic` 2.0. Results from 2026-11-18. See [the raw data](https://github.com/the-benchmarker/web-frameworks/blob/32b8757714a4ceac24cf0eafb5edd99f0522224c/data.min.json) and the code of [the Dox app](https://github.com/the-benchmarker/web-frameworks/tree/master/dart/dox) and [the Relic app](https://github.com/the-benchmarker/web-frameworks/tree/master/dart/relic).

Small routes show the cost of the framework itself.
In a real app, the database and your own code often take most of the time.
For how Dox gets these numbers, see [What makes Dox fast](what-makes-dox-fast.md).

## When to pick Serverpod

- Your only client is a Flutter app, and you want the client made for you.
- You want many social sign-in providers and the Flutter sign-in widgets.
- You want a hosted service, so you do not run servers yourself.
- You want a project with many years of use. Serverpod has been on pub.dev for about five years.

## When to pick Dox

- Your API has more than one kind of client, like a web app, a mobile app or other servers.
- You want an OpenAPI document made from your code.
- You use MySQL or MariaDB.
- You want a job queue with a worker, a scheduler and mail in one framework.
- You want a fast HTTP layer. See [Speed](#speed).
- The license matters to you. Dox uses the MIT license.

### When not to pick Dox

- **You want the Dart client made for you.** Dox does not generate one.
- **You want a hosted service.** You deploy Dox yourself.

More gaps are on [What Dox does not have yet](/latest/concepts/status-and-roadmap/#what-dox-does-not-have-yet).

## FAQ

### Can a non-Flutter client call a Serverpod server?

Serverpod's docs show the generated Dart client.
For plain REST routes, Serverpod has a separate [web server](https://docs.serverpod.dev/concepts/web-server/overview), built on Relic, where you add routes by hand.
In Dox, every route is plain HTTP, so any client can call it.

### Can I share models between Flutter and Dox?

Yes.
Put the `@Dto` classes in a plain Dart package that the app and the server both use.
See [Share code with Flutter](/latest/guides/share-code-with-flutter/).

### Can I move from Serverpod to Dox?

Yes, but it is a rewrite of the server code.
Your Postgres data can stay.
You turn each `.spy.yaml` model into a `@DoxModel` class, each endpoint method into a route and a controller method, and each future call into a job.
The Flutter app then calls HTTP routes instead of the generated client.

## Summary

- Both are full Dart backends with an ORM and migrations.
- Serverpod is the better fit for a Flutter-only app that wants the client made for it, and for a hosted service.
- Dox is the better fit for a plain HTTP API with many clients, MySQL, or a queue and mail in the box.

Want to try Dox?
The [tutorial](/latest/tutorial/) builds a small API with a database, validation, login and tests.
If you find a wrong fact about Serverpod here, open a [GitHub issue](https://github.com/dartondox/dox/issues), and we will fix it.
