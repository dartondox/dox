---
icon: lucide/terminal
---

# CLI

This page lists every `dox` command, with its options and the files it writes.

To install the CLI, see the [Dox CLI](../digging-deeper/dox-cli.md) page. Run `dox help` to list the commands, and `dox help <command>` to see one.

A few rules hold for every command:

- A name you pass becomes `snake_case` for the file and `PascalCase` for the class. So `BlogPost` and `blog_post` give the same result.
- A `make:*` command never overwrites a file. When the file exists, it prints `<name> already exists` and stops.
- Many `make:*` commands also answer to a `create:*` name, like `create:model`.
- Packages and your app can add their own commands. See [Package commands](../digging-deeper/package-commands.md).

## Project

### `dox create`

```
dox create <project_name> [--version <version>]
```

Makes a new project from the [dox-sample](https://github.com/dartondox/dox-sample) repo.

| Option | Meaning |
| --- | --- |
| `--version <v>` (or `--v`) | A release tag of `dox-sample` to clone. Without it, the newest `dox-sample` release with the same major version as the CLI is used. |

It clones the template into a new `snake_case` folder, puts your project name in the files, and makes a `.env` with a new random `APP_KEY`. Then it prints the next steps: `cd <name>`, `dart pub get` and `dox serve`. It needs `curl` and `git` on the `PATH`.

The new project already has `bin/server.dart`, `bin/migrate.dart`, `bin/seed.dart`, `bin/queue.dart` and `bin/schedule.dart`, so the migration, seed, queue and schedule commands work in it right away.

### `dox add`

```
dox add <package> [--dev] [options]
```

Adds a Dox package and sets it up, like `dox add orm --driver=postgres`. `orm` is short for `dox_orm`.

It runs `dart pub add` and `dart pub get`. Then it runs the `<package>:install` command of the package, with your options, if the package has one.
See [Add a package](../getting-started/add-a-package.md).

### `dox serve`

```
dox serve [--no-reload] [--ignore-build-runner]
dox s
dox server
```

Starts the dev server with hot reload. It also runs `dart run build_runner watch`, so generated files stay up to date.

To change the port, set `APP_PORT` in `.env`, or run `APP_PORT=9000 dox serve`. A `--port` option is ignored.

| Option | Meaning |
| --- | --- |
| `--no-reload` | Turn hot reload off. Every change restarts the server. |
| `--ignore-build-runner` | Do not start `dart run build_runner watch`. |

When you save a file, `dox serve` does one of these:

| Changed | Result |
| --- | --- |
| A `.dart` file in `lib/app/` (not `.g.dart`) | Hot reload. The new code runs in the server at once, in about 0.1 to 0.2 seconds. |
| Routes, providers, config, `lib/generated/`, `bin/`, `db/` or a generated `.g.dart` file | The server restarts, because this code or data is built only at start. |
| A hot reload that fails, for example a compile error | The server restarts. |

Hot reload does not run code again that already ran. So a changed static or global value keeps its old value until a restart.

The server prints a VM service link at start. Open it in a browser to get DevTools (debugger, CPU profiler, memory). VS Code can also attach to it with "Dart: Attach to Dart Process".

### `dox build`

```
dox build
```

Compiles the app to a native binary for production, in `build/bundle`. Use this in production, not `dart run`.

It runs `build_runner` first (when the app uses it), then `dart build cli`. It also builds `bin/queue.dart` and `bin/schedule.dart` when they exist. Then run the app with `cd build/bundle && ./bin/server`.

It writes:

| Path | What |
| --- | --- |
| `build/bundle/bin/server` | the native binary, no Dart SDK needed |
| `build/bundle/bin/queue` | the queue worker, when `bin/queue.dart` exists |
| `build/bundle/bin/schedule` | the scheduler, when `bin/schedule.dart` exists |
| `build/bundle/lib/` | native libraries from build hooks (SQLite, `dox_http_native`, ...) |
| `build/bundle/db/` | your migrations and seeders. SQLite files are not copied. |
| `build/bundle/.env.example` | copy it to `.env` or set real env vars |

Do not use `dart compile exe`. It can not build the native libraries.

### `dox build_runner:build` and `dox build_runner:watch`

```
dox build_runner:build
dox build_runner:watch
```

Run `dart run build_runner build` once, or `dart run build_runner watch`. `build_runner:build` prints a short output. Run `dart run build_runner build` yourself to see all of it.

### `dox key:generate`

```
dox key:generate [--show] [--force]
```

Makes a random 32 character key and writes it to `APP_KEY` in `.env`. Every other line of `.env` stays as it is. When there is no `APP_KEY` line, it adds one at the top.

| Option | Meaning |
| --- | --- |
| `--show` | Print a new key and write nothing. |
| `--force` | Skip the question below. |

When `APP_ENV=production`, a new key logs every user out, so the command asks first. Without a terminal it prints a warning and runs. The `.env` file must exist.

### `dox env:generate`

```
dox env:generate
```

Writes `lib/config/env.dart`, the typed env class, from `.env.example`. It does not overwrite an existing file. Run `dart run build_runner build` after it.

The type of each getter comes from the example value:

| Value in `.env.example` | Getter |
| --- | --- |
| a whole number, like `3000` | `int get x => 3000;` |
| `true` or `false` | `bool get x => true;` |
| empty | `String? get x;` |
| any other text | `String get x;` (required) |

A `#` comment line above a key becomes its doc comment.

### `dox env:check`

```
dox env:check
```

Checks the env with your `AppEnv` class, from the real environment and `.env`. It prints `The env is valid.`, or every missing or bad key and exits with code 1. Run it in CI or before a deploy.

It needs `lib/config/env.dart` (see `dox env:generate`) and a `name:` in `pubspec.yaml`.

### `dox openapi:generate`

```
dox openapi:generate [dir]
```

Writes `openapi.json` and `openapi.yaml` into `dir` (default `storage/openapi`). It runs `bin/openapi.dart`, which a new project does not have. When it is missing, the command prints the code to put in it. See [OpenAPI](../packages/openapi.md).

### `dox update`

```
dox update
```

Installs the newest CLI with the same major version as the one you have. It needs `curl` on the `PATH`.

### `dox version`

```
dox version
dox v
dox -v
dox --version
```

Prints the CLI version.

### `dox help`

```
dox help [command]
dox --help
dox -h
```

Without a command, it lists every command. With a command, it prints its usage, options and aliases.

## Create files

### `dox make:controller`

```
dox make:controller <name> [-r|--resource] [--api] [--model=<model>]
```

Writes `lib/app/http/controllers/<name>.controller.dart`. A trailing `Controller` in the name is removed, so `UserController` and `User` give the same file.

| Option | Meaning |
| --- | --- |
| `-r` or `--resource` | A resource controller with `index`, `create`, `store`, `show`, `edit`, `update`, `destroy`. |
| `--api` | A resource controller without `create` and `edit`, the two form pages. `Route.resource` makes no route for them. |
| `--model=<model>` or `--model <model>` | A resource controller that uses the model. It imports `package:<app>/app/models/<model>/<model>.model.dart`. `index` returns all rows, and `store` creates a row from `req.body`. `show`, `edit`, `update` and `destroy` take the model as a parameter, so [route model binding](../the-basic/dependency-injection.md#route-model-binding) loads it by the `{id}`. |

`--api` and `--model` work together, and each one makes a resource controller, also without `-r`.

The class has `@Inject()`, so the container makes it. A comment in the file shows the route to add. Run `dart run build_runner build` after it, so the controller is added to the container.

### `dox make:middleware`

```
dox make:middleware <name>
```

Writes `lib/app/http/middleware/<name>.middleware.dart`: a class `<Name>Middleware implements IDoxMiddleware` with a `handle(IDoxRequest req)` that returns `req`.
A trailing `Middleware` in the name is removed.

### `dox make:dto`

```
dox make:dto <name>
```

Writes `lib/app/dtos/<name>/<name>.dto.dart`: a `@Dto()` class with one `name` field and `part '<name>.dto.g.dart';`.
A trailing `Dto` in the name is removed: `dox make:dto CreateBlog` gives the class `CreateBlog` in `lib/app/dtos/create_blog/create_blog.dto.dart`. Run `dox build_runner:build` after it. See [DTOs](../the-basic/dto.md).

### `dox make:serializer`

```
dox make:serializer <name>
```

Writes `lib/app/serializers/<name>.serializer.dart`: a class `<Name>Serializer extends Serializer<<Name>>`. It imports the model with `package:<app>/app/models/<name>/<name>.model.dart`.
A trailing `Serializer` in the name is removed.

### `dox make:provider`

```
dox make:provider <name>
```

Writes `lib/providers/<name>_provider.dart`: a class `<Name>Provider extends DoxProvider` with an empty `setup()` and an optional `shutdown()`.
A trailing `Provider` in the name is removed: `dox make:provider Cache` gives `CacheProvider` in `lib/providers/cache_provider.dart`. Run `dox build_runner:build` after it, so Dox finds the provider. See [Providers](../digging-deeper/providers.md).

### `dox make:command`

```
dox make:command <name>
```

Writes `lib/app/commands/<name>_command.dart`: a class `<Name>Command extends Command`. Its name is `app:<name>`, and `_` in the name becomes `-`. So `dox make:command send_report` makes the command `app:send-report`.
A trailing `Command` in the name is removed.

It also adds the class to `lib/app/commands/commands.dart`, and adds `dox: commands:` to `pubspec.yaml` when it is not set. Then run `dart pub get` and `dox app:send-report`.

It makes all the changes or none. If a file is not in the shape it expects, it prints what to add by hand.

See [Package commands](../digging-deeper/package-commands.md#add-a-command-to-your-app).

### `dox make:mail`

```
dox make:mail <name> [--no-view]
```

| Form | Writes |
| --- | --- |
| plain | `lib/app/mail/<name>_mail.dart` and the view `resources/views/emails/<name>.dox.html` |
| `--no-view` | `lib/app/mail/<name>_mail.dart` only, with a plain text body |

The class is `<Name>Mail extends Mailable`, and takes the recipient `Address` in its constructor. A trailing `Mail` in the name is removed. With the view, the mail uses the view `emails/<name>`. With `--no-view`, it has a `text` getter.

It tells you when `pubspec.yaml` still needs `dox_mailer`, or `dox_view` for the view.

See [Mail](../digging-deeper/mail.md#mailables).

### `dox make:view`

```
dox make:view <name>
```

Writes `resources/views/<name>.dox.html` with a small sample. A `/` in the name makes a folder, and each part becomes `snake_case`: `Pages/About` gives `resources/views/pages/about.dox.html`.

See [Views](../the-basic/views.md).

### `dox make:test`

```
dox make:test <name> [--unit]
```

| Form | Writes |
| --- | --- |
| plain | `test/<name>_test.dart` that starts the app with `DoxTestClient` and checks `GET /ping`. Change the path to match your route. |
| `--unit` | `test/<name>_test.dart` with a plain `package:test` test. It does not start the app. |

A trailing `Test` in the name is removed.

See [Testing](../digging-deeper/testing.md).

### `dox make:model`

```
dox make:model <name> [-m] [-c] [-r] [-f] [-s] [-a] [--api]
dox create:model <name> [-m] [-c] [-r] [-f] [-s] [-a] [--api]
```

Writes `lib/app/models/<name>/<name>.model.dart`, a `@DoxModel` class. The table name is the plural `snake_case` name, so `BlogPost` gives `blog_posts`. Add your columns to its empty `fillable` list.

| Option | Meaning |
| --- | --- |
| `-m` or `--migration` | Also make a `create_<table>_table` migration. |
| `-c` or `--controller` | Also make a plain controller, `<name>.controller.dart`. |
| `-r` or `--resource` | Also make a resource controller that uses the model. |
| `--api` | Also make a resource controller without `create` and `edit`, that uses the model. |
| `-f` or `--factory` | Also make a factory, `db/factories/<name>.factory.dart`. |
| `-s` or `--seed` | Also make a seeder, `db/seeders/<name>.seeder.dart`. |
| `-a` or `--all` | Also make the migration, the factory, the seeder and a resource controller. |

You can join short options: `-mcr` is the same as `-m -c -r`. With `-c` and `-r` together, the controller is a resource controller.

Each extra file is the same as the one from its own command:

| Command | Same file as |
| --- | --- |
| `dox make:model Post -m` | `dox make:migration create_posts_table` |
| `dox make:model Post -c` | `dox make:controller Post` |
| `dox make:model Post -r` | `dox make:controller Post -r --model=Post` |
| `dox make:model Post --api` | `dox make:controller Post --api --model=Post` |
| `dox make:model Post -f` | `dox make:factory Post` |
| `dox make:model Post -s` | `dox make:seeder Post` |

When the model file exists, the command makes no file at all. When one of the extra files exists, only that file is skipped.

### `dox make:migration`

```
dox make:migration <name> [--sql]
dox create:migration <name> [--sql]
```

| Option | Meaning |
| --- | --- |
| `--sql` | Make a `.sql` file with `-- up` and `-- down` sections instead of a Dart class. |

Writes `db/migration/<yyyy>_<mm>_<dd>_<hhmmss>_<name>.dart` (or `.sql`). Migrations run in file name order, and a new file always sorts last.

For a Dart migration, it also updates `db/migration/migrations.dart` (the list of all migrations), and makes `bin/migrate.dart` when it is missing.

The code in the new file depends on the name:

| Name | `up()` | `down()` |
| --- | --- | --- |
| `create_<table>_table` | `schema.create('<table>', ...)` with `id()` and `timestamps()` | `schema.dropIfExists('<table>')` |
| `<x>_to_<table>_table` (also `from`, `in`, `on`) | `schema.table('<table>', ...)` | `schema.table('<table>', ...)` |
| anything else | a comment | a comment |

## Routes

### `dox route:list`

```
dox route:list [--json]
```

Prints every route of the app: method, path, name, handler and middleware. Run it in the app folder.

```
METHOD  PATH           NAME  HANDLER             MIDDLEWARE
GET     /api/ping            ApiController.pong  LogMiddleware
GET     /ping                WebController.pong  LogMiddleware
GET     /docs                serve
GET     /openapi.json        serve
GET     /openapi.yaml        serve

5 routes
```

| Option | Meaning |
| --- | --- |
| `--json` | Print the same data as one JSON list. |

```bash
dox route:list --json
```

```json
[{"method":"GET","path":"/api/ping","name":null,"handler":"ApiController.pong","middleware":["LogMiddleware"]}]
```

It does not start the server, and providers do not run. So a route that a provider adds, like the Socket.IO mount, is not in the list.

In the table, a function with no name shows as `Closure`. Fallback routes have the method `FALLBACK`, and `Route.mount` handlers have the method `MOUNT`.

## Migrations

These commands run `bin/migrate.dart` of your app. If it is missing and you have Dart migrations, they make it first. With only `.sql` migrations, the CLI runs them itself.

The database comes from `DATABASE_URL`, or else from the `DB_*` keys. See [Environment variables](env.md).

| Command | Aliases | What it does |
| --- | --- | --- |
| `dox migration:run` | `dox migrate` | Run the migrations that did not run yet. |
| `dox migration:rollback [--step=<count>] [--batch=<number>] [--force]` | `dox migrate:rollback` | Undo the last batch, the last `<count>` migrations, or only batch `<number>`. Give `--step` or `--batch`, not both. |
| `dox migration:reset` | `dox migrate:reset` | Undo every migration. |
| `dox migration:refresh` | `dox migrate:refresh` | Undo every migration, then run them all again. |
| `dox migration:fresh` | `dox migrate:fresh` | Drop every table, then run all migrations. |
| `dox migration:status` | `dox migrate:status` | Print which migrations ran, and their batch. |

Add `--seed` to `migration:run`, `migration:refresh` or `migration:fresh` to run `dox db:seed` after the migrations.

When `APP_ENV=production`, the commands that undo or drop ask first. Add `--force` to skip the question.

## Factories and seeders

| Command | Aliases | What it does |
| --- | --- | --- |
| `dox make:factory <model>` | `dox create:factory` | Make `db/factories/<model>.factory.dart`. It imports the model with the package name of `pubspec.yaml`. |
| `dox make:seeder <name>` | `dox create:seeder` | Make `db/seeders/<name>.seeder.dart`. It updates `db/seeders/seeders.dart`, and makes `bin/seed.dart` when it is missing. |
| `dox db:seed [--class=<name>]` | | Run the seeders with `bin/seed.dart`. The default seeder is `DatabaseSeeder`. |

## Queue

These commands run `bin/queue.dart` of your app, which a new project already has. `Ctrl+C` and `SIGTERM` are passed on, so a worker can finish its job before it stops.

| Command | Runs | What it does |
| --- | --- | --- |
| `dox make:job <name>` | | Make `lib/app/jobs/<name>.job.dart` with a `@Job()` class that extends `DoxJob`. It makes `bin/queue.dart` when it is missing. Run `dox build_runner:build` after it. |
| `dox queue:work [flags]` | `bin/queue.dart work [flags]` | Run the worker. |
| `dox queue:failed` | `bin/queue.dart failed` | List the failed jobs. |
| `dox queue:retry <id\|all>` | `bin/queue.dart retry <id\|all>` | Put one failed job, or all of them, back on the queue. |
| `dox queue:forget <id>` | `bin/queue.dart forget <id>` | Delete one failed job. |
| `dox queue:flush` | `bin/queue.dart flush` | Delete all failed jobs. |
| `dox queue:clear [queue]` | `bin/queue.dart clear [queue]` | Delete the jobs of a queue. The default queue is `default`. |
| `dox queue:restart` | `bin/queue.dart restart` | Make the running workers stop after their current jobs. The workers must share the cache store. |
| `dox queue:prune-failed [--hours=N]` | `bin/queue.dart prune-failed [--hours=N]` | Delete failed jobs older than N hours. The default is 24. |
| `dox queue:table` | | From `dox_queue_database`. Make a migration for the queue tables. |
| `dox auth:tokens-table` | | From `dox_auth`. Make a migration for the `auth_access_tokens` table. |

Flags of `queue:work`:

| Flag | Default | Meaning |
| --- | --- | --- |
| `--queue=a,b` | `default` | The queues to read, the first one first. |
| `--concurrency=N` | `1` | How many jobs run at the same time in this process. |
| `--once` | off | Run one job, then stop. |
| `--tries=N` | `1` | How many times a job may run before it is marked as failed. A job can set its own `tries`. |
| `--timeout=S` | `60` | Seconds a job may run. |
| `--sleep=S` | `3` | Seconds to wait when the queues are empty. |
| `--stop-when-empty` | off | Stop when the queues are empty. |
| `--timeout-grace=S` | none | After a timeout, wait up to `S` seconds for the old run to end before the next try. |

Flags of `auth:tokens-table`:

| Flag | Meaning |
| --- | --- |
| `--uuid` | The users have uuid ids. Set `uuidIds: true` on `AccessTokenAuthDriver` too. |
| `--string-ids` | The users have text ids. Set `stringIds: true` on `AccessTokenAuthDriver` too. Do not use it with `--uuid`. |
| `--users-table=<table>` | Add a foreign key from `tokenable_id` to this table, with cascade delete. |
| `--users-key=<column>` | The column of `--users-table` for the foreign key. Default: `id`. It does nothing without `--users-table`. |

This is the `bin/queue.dart` of a new project. The jobs come from `queueConfig` in `lib/config/queue.dart`:

```dart
import 'dart:io';

import 'package:dox_queue/dox_queue.dart';
import 'package:<app>/config/app.dart';

Future<void> main(List<String> args) async {
  exitCode = await QueueWorker(app: appConfig).run(args);
}
```

## Schedule

These commands run `bin/schedule.dart` of your app, which a new project already has.

| Command | Runs | What it does |
| --- | --- | --- |
| `dox schedule:work` | `bin/schedule.dart work` | Run the scheduler and keep it running. |
| `dox schedule:run` | `bin/schedule.dart run` | Run the tasks that are due now, once. |
| `dox schedule:list` | `bin/schedule.dart list` | List the scheduled tasks. |
| `dox schedule:test <name>` | `bin/schedule.dart test <name>` | Run one task now. |
| `dox schedule:clear-cache` | `bin/schedule.dart clear-cache` | Remove the `withoutOverlapping()` locks that a crash left behind. Do not run it while a task runs. |

You add tasks in `lib/config/schedule.dart`. These are the two files of a new project:

```dart title="lib/config/schedule.dart"
import 'package:dox_scheduler/dox_scheduler.dart';

ScheduleConfig scheduleConfig = const ScheduleConfig();

void schedule(Schedule s) {
  // s.call('cleanup', cleanup).dailyAt('02:00');
}
```

```dart title="bin/schedule.dart"
import 'dart:io';

import 'package:dox_scheduler/dox_scheduler.dart';
import 'package:<app>/config/app.dart';
import 'package:<app>/config/schedule.dart';

Future<void> main(List<String> args) async {
  exitCode = await SchedulerRunner(
    schedule: schedule,
    app: appConfig,
    config: scheduleConfig,
  ).run(args);
}
```

See [Scheduler](../digging-deeper/scheduler.md) for the task methods, and [Queue](../digging-deeper/queue.md) for jobs.

## Command list

| Command | Aliases | Category |
| --- | --- | --- |
| `create` | | Project |
| `add` | | Project |
| `serve` | `server`, `s` | Development |
| `make:controller` | `create:controller` | Development |
| `make:middleware` | `create:middleware` | Development |
| `make:dto` | `create:dto` | Development |
| `make:provider` | | Development |
| `make:command` | | Development |
| `make:mail` | | Development |
| `make:view` | | Development |
| `make:test` | | Development |
| `route:list` | | Development |
| `build` | | Build |
| `build_runner:build` | | Build Runner |
| `build_runner:watch` | | Build Runner |
| `make:model` | `create:model` | Generation |
| `make:serializer` | `create:serializer` | Generation |
| `key:generate` | | Generation |
| `env:generate` | | Generation |
| `openapi:generate` | | Generation |
| `migration:run` | `migrate` | Database |
| `migration:rollback` | `migrate:rollback` | Database |
| `migration:reset` | `migrate:reset` | Database |
| `migration:refresh` | `migrate:refresh` | Database |
| `migration:fresh` | `migrate:fresh` | Database |
| `migration:status` | `migrate:status` | Database |
| `make:migration` | `create:migration` | Database |
| `make:factory` | `create:factory` | Database |
| `make:seeder` | `create:seeder` | Database |
| `make:job` | | Queue |
| `queue:work` | | Queue |
| `queue:failed` | | Queue |
| `queue:retry` | | Queue |
| `queue:forget` | | Queue |
| `queue:flush` | | Queue |
| `queue:clear` | | Queue |
| `queue:restart` | | Queue |
| `queue:prune-failed` | | Queue |
| `schedule:work` | | Schedule |
| `schedule:run` | | Schedule |
| `schedule:list` | | Schedule |
| `schedule:test` | | Schedule |
| `schedule:clear-cache` | | Schedule |
| `db:seed` | | Database |
| `version` | `--version`, `-version`, `v`, `-v`, `--v` | System |
| `update` | | System |
| `env:check` | | System |
| `help` | `--help`, `-h` | System |

## See also

- [Dox CLI](../digging-deeper/dox-cli.md): a guide to the commands you use most.
- [Package commands](../digging-deeper/package-commands.md): commands that come from a package.
