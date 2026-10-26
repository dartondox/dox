---
icon: lucide/terminal
---

# CLI

Every `dox` command, with its options and the files it writes.

The CLI lives in the [dox-cli](https://github.com/dartondox/dox-cli) repo. The paths below are in that repo. The commands come from `lib/src/command_registry.dart`. The file templates are Dart strings inside `lib/src/tools/`. The path of each template is given below.

How to install the CLI is on the [Dox CLI](../digging-deeper/dox-cli.md) page.

Rules that apply to every command:

- `dox` with no command prints `Could not find a command. Run `dox help` for more information.`
- An unknown command prints `Could not find a command named "<name>". Run `dox help` for more information.`
- Too few or too many arguments prints `Invalid number of arguments for command "<name>".` with the expected count.
- A name you pass is turned into `snake_case` for the file and `PascalCase` for the class. `BlogPost` and `blog_post` give the same result.
- Every `make:*` command also answers to its `create:*` name, like `create:model`. `dox help <command>` shows the aliases.
- A `make:*` command does not overwrite. When the file exists it prints `<name> already exists` and stops.

## Project

### `dox create`

```
dox create <project_name> [--version <version>]
```

Makes a new project from the [dox-sample](https://github.com/dartondox/dox-sample) repo.

| Option | Meaning |
| --- | --- |
| `--version <v>` (or `--v`) | A release tag of `dox-sample` to clone. Without it, the newest `dox-sample` release with the same major version as the CLI is used (pre-releases included). |

What it does:

1. Turns the name into `snake_case`. Stops with `Folder name "<name>" already exist` when the folder is there.
2. Picks the release (see `--version` above) from the release list of `dartondox/dox-sample`.
3. Runs `git clone --depth 1 --branch v<version> https://github.com/dartondox/dox-sample.git <name>`.
4. Deletes the `.git` folder.
5. Replaces `dox_sample` with your project name in every text file, except files under `bin/dox`.
6. Copies `.env.example` to `.env` and writes a new random `APP_KEY` to it, like `dox key:generate`. It skips this step when `.env` is already there.
7. Prints the next steps: `cd <name>`, `dart pub get` and `dox serve`.

Needs `curl` and `git` on the `PATH`. When it can not find a release (no network), it prints `Could not find a template release for Dox <version>. Check your network, or pass --version.`

The new project already has `bin/server.dart`, `bin/migrate.dart`, `bin/seed.dart`, `bin/queue.dart` and `bin/schedule.dart`. So the migration, seed, queue and schedule commands below work in it right away.

Source: `lib/src/tools/create_project.dart`.

### `dox serve`

```
dox serve [--ignore-build-runner]
dox s
dox server
```

Starts the dev server.

| Option | Meaning |
| --- | --- |
| `--ignore-build-runner` | Do not start `dart run build_runner watch`. |

What it does:

1. Starts `dart run build_runner watch` (unless the option is set).
2. Starts `dart run bin/server.dart` and prints its output.
3. Watches the project folder. When a `.dart` file changes it prints `[Dox] File changed: <file>`. It waits until no file changed for 500 ms, then kills the server and starts it again.

Source: `lib/src/tools/server_serve.dart`.

### `dox build`

```
dox build
```

AOT compiles the app for production into `build/bundle`. Use this in production, not `dart run`.

What it does:

1. When `pubspec.yaml` contains `build_runner`: runs `dart run build_runner build`. Stops with exit code 1 when it fails.
2. Runs `dart build cli --target bin/server.dart --output build`.
3. When `bin/queue.dart` or `bin/schedule.dart` exists: builds it the same way, to `build/bundle/bin/queue` and `build/bundle/bin/schedule`.
4. Deletes the old `build/bundle/db`, then copies `db/` to `build/bundle/db`. It leaves out SQLite files (`*.sqlite`, `*.sqlite3`, `*.db`, and their `-wal`, `-shm`, `-journal` and `.lock` files), so your local data does not go to production.
5. Copies `.env.example` to `build/bundle/.env.example`.
6. Prints `[Dox] Built build/bundle. Run it with: cd build/bundle && ./bin/server`.

Output:

| Path | What |
| --- | --- |
| `build/bundle/bin/server` | the native binary, no Dart SDK needed |
| `build/bundle/bin/queue` | the queue worker, when `bin/queue.dart` exists |
| `build/bundle/bin/schedule` | the scheduler, when `bin/schedule.dart` exists |
| `build/bundle/lib/` | native libraries from build hooks (SQLite, `dox_http_native`, ...) |
| `build/bundle/db/` | your migrations and seeders. SQLite files are not copied. |
| `build/bundle/.env.example` | copy it to `.env` or set real env vars |

`dart compile exe` can not build packages with build hooks, so the CLI uses `dart build cli`.

Source: `lib/src/tools/server_serve.dart` (`buildServer`).

### `dox build_runner:build` and `dox build_runner:watch`

```
dox build_runner:build
dox build_runner:watch
```

Run `dart run build_runner build` once, or `dart run build_runner watch`. No options.
`build_runner:build` prints only the first line of each output block of build_runner. Run `dart run build_runner build` yourself to see all of it.
The CLI does not pass `--delete-conflicting-outputs` (build_runner removed that flag).

### `dox key:generate`

```
dox key:generate
```

Makes a 32 character key (A-Z, a-z, 0-9, from `Random.secure()`) and writes it to `APP_KEY` in `.env`.
Prints `<key> : Key have been updated successfully in .env!`.

What it does with `.env`:

- Reads `.env` in the current folder. The file must exist, else the command fails with a file error.
- Replaces the value of `APP_KEY`. Every other line stays as it is, in the same order. This keeps comments, blank lines, quotes and values with more than one `=` (like `DATABASE_URL=postgres://u:p@h/db?a=b`).
- Adds `APP_KEY=<key>` as the first line when there is no `APP_KEY`.

Source: `lib/src/tools/generate_key.dart`.

### `dox env:generate`

```
dox env:generate
```

Writes `lib/config/env.dart`, the typed env class, from `.env.example`.

- Stops with `.env.example is missing.` (exit code 1) when there is no example file.
- Stops with `lib/config/env.dart is already there. Delete it to make it again.` (exit code 1) when the file exists.
- Prints `Run `dart run build_runner build` to make env.g.dart.` when done.

Rules for each key: a whole number (like `3000` or `-1`) gives `int get x => <value>;`, `true`/`false` give `bool get x => <value>;`, an empty value gives `String? get x;`, any other value gives `String get x;` (required, no default). `#` comment lines above a key become its doc comment. A key that does not map back from `camelCase` gets `@EnvKey('KEY')`.

Source: `lib/src/tools/env_tools.dart` (`EnvScaffold`).

### `dox env:check`

```
dox env:check
```

Loads `AppEnv` from `lib/config/env.dart` with the real environment and `.env`. Prints `The env is valid.` or an `EnvException` with every missing or bad key (exit code 1).

It writes a small script to `.dart_tool/dox/env_check.dart` and runs it with `dart run`. It needs `lib/config/env.dart` and a `name:` in `pubspec.yaml`.
Without `lib/config/env.dart` it prints `lib/config/env.dart is missing. Run `dox env:generate` first.` (exit code 1).

Source: `lib/src/tools/env_tools.dart` (`envCheck`).

### `dox openapi:generate`

```
dox openapi:generate [dir]
```

Runs `dart run bin/openapi.dart [dir]`. That file writes `openapi.json` and `openapi.yaml` into `dir` (default `storage/openapi`).
A new project has no `bin/openapi.dart`. You add it yourself, see [OpenAPI](../packages/openapi.md).
When the file is not there, the command prints `bin/openapi.dart is missing.` and the code to put in it (exit code 1).

Source: `lib/src/tools/openapi_generate.dart`.

### `dox update`

```
dox update
```

Installs the newest CLI with the same major version as the one you have. Pre-releases count.
It reads the version list from pub.dev (retracted versions are skipped), then runs `dart pub global activate dox <version>`.
Needs `curl` on the `PATH`.

Source: `lib/src/tools/update_dox.dart`.

### `dox version`

```
dox version
dox v
dox -v
dox --version
```

Prints `Dox version: <version>`. Aliases: `--version`, `-version`, `v`, `-v`, `--v`.

### `dox help`

```
dox help [command]
dox --help
dox -h
```

Aliases: `--help`, `-h`. Without a command: lists every command by category. With a command: prints its usage, description, category, aliases and argument count.

## Create files

### `dox make:controller`

```
dox make:controller <name> [-r]
```

Alias: `create:controller`. The other `make:*` commands below have the same kind of alias.

| Option | Meaning |
| --- | --- |
| `-r` | A resource controller with `index`, `create`, `store`, `show`, `edit`, `update`, `destroy`. |

A trailing `Controller` in the name is removed: `UserController` and `User` give the same file.

| Form | Writes | Template |
| --- | --- | --- |
| plain | `lib/app/http/controllers/<name>.controller.dart` | `_getSample` in `lib/src/tools/create_controller.dart` |
| `-r` | `lib/app/http/controllers/<name>.controller.dart` | `_getResourceSample` in the same file |

The class has `@Inject()`, so the container makes it. A comment shows the route to add, like `Route.get('path', (BlogController c) => c.index);`.
After the file is made, the CLI tells you to run `dart run build_runner build`. That adds the controller to `lib/generated/container.g.dart`.

### `dox make:middleware`

```
dox make:middleware <name>
```

Writes `lib/app/http/middleware/<name>.middleware.dart`: a class `<Name>Middleware implements IDoxMiddleware` with a `handle(IDoxRequest req)` that returns `req`.
A trailing `Middleware` in the name is removed.

Template: `_getSample` in `lib/src/tools/create_middleware.dart`.

### `dox make:dto`

```
dox make:dto <name>
```

Writes `lib/app/dtos/<name>/<name>.dto.dart`: a `@Dto()` class with one `name` field and `part '<name>.dto.g.dart';`.
The class name has no `Dto` at the end: `dox make:dto CreateBlog` gives the class `CreateBlog` in `lib/app/dtos/create_blog/create_blog.dto.dart`.
A trailing `Dto` in the name is removed. Prints `Run `dox build_runner:build` to make <name>/<name>.dto.g.dart.`

Template: `_getSample` in `lib/src/tools/create_dto.dart`.

### `dox make:serializer`

```
dox make:serializer <name>
```

Writes `lib/app/http/serializers/<name>.serializer.dart`: a class `<Name>Serializer extends Serializer<<Name>>`. It imports the model from `lib/app/models/<name>/<name>.model.dart`.
A trailing `Serializer` in the name is removed.

Template: `_getSample` in `lib/src/tools/create_serializer.dart`.

### `dox make:model`

```
dox make:model <name> [-m|--migration]
dox create:model <name> [-m|--migration]
```

Writes `lib/app/models/<name>/<name>.model.dart`: a `@DoxModel()` class with `part '<name>.model.g.dart';`.

| Option | Meaning |
| --- | --- |
| `-m` or `--migration` | Also make a `create_<table>_table` migration. The table is the plural snake name: `BlogPost` gives `blog_posts`. The model then gets `@DoxModel(table: 'blog_posts')`. |

Any other second argument prints `Invalid option <x>, use -m or --migration` (exit code 1).

Template: `_getSample` in `lib/src/tools/create_model.dart`.

### `dox make:migration`

```
dox make:migration <name> [--sql]
dox create:migration <name> [--sql]
```

| Option | Meaning |
| --- | --- |
| `--sql` | Make a `.sql` file with `-- up` and `-- down` sections instead of a Dart class. |

Writes `db/migration/<yyyy>_<mm>_<dd>_<hhmmss>_<name>.dart` (or `.sql`). Characters that are not letters, digits or `_` are removed from the name. A second argument other than `--sql` is ignored.

Migrations run sorted by file name. So the new file always sorts after every file already in `db/migration`. When the current time is not later than the newest file (for example, two migrations in the same second), it uses the newest time plus 1 second.

For a Dart migration it also:

- writes `db/migration/migrations.dart`, the registry of every Dart migration in the folder, sorted by name. A file with no class that `extends Migration` is skipped with a warning;
- writes `bin/migrate.dart` when it is missing, and prints `bin/migrate.dart created.`

The Dart template depends on the name:

| Name | `up()` | `down()` |
| --- | --- | --- |
| `create_<table>_table` | `schema.create('<table>', ...)` with `id()` and `timestamps()` | `schema.dropIfExists('<table>')` |
| `<x>_to_<table>_table` (also `from`, `in`, `on`) | `schema.table('<table>', ...)` | `schema.table('<table>', ...)` |
| anything else | a comment | a comment |

Templates: `dartMigrationSource`, `migrateEntrySource` and `_sampleSql` in `lib/src/tools/create_migration.dart`.

## Migrations

All `migration:*` commands work the same way:

1. When `bin/migrate.dart` exists: write the registry again, then run `dart run bin/migrate.dart <command> [args]`. Your app code runs, so Dart migrations work.
2. When there is no `bin/migrate.dart` but `db/migration` has Dart files: print `db/migration has Dart migrations, but bin/migrate.dart is missing.` (exit code 1).
3. Else: run the `.sql` migrations with `Migrator()` from `dox_migration` in the CLI process.

The database comes from `DATABASE_URL` when it is set. Else it comes from `DB_CONNECTION`, `DB_HOST`, `DB_PORT`, `DB_USERNAME`, `DB_PASSWORD` and `DB_DATABASE` (or `DB_NAME`). See [Environment variables](env.md).
A failed run prints the error and sets exit code 1.

| Command | Aliases | What it does |
| --- | --- | --- |
| `dox migration:run` | `dox migrate` | Run the migrations that did not run yet. |
| `dox migration:rollback [--step=<count>]` | `dox migrate:rollback` | Undo the last batch, or the last `<count>` migrations. Any other option prints `Invalid option <x>, use --step=<count>` (exit code 1). |
| `dox migration:reset` | `dox migrate:reset` | Undo every migration. |
| `dox migration:refresh` | `dox migrate:refresh` | Undo every migration, then run them all again. |
| `dox migration:fresh` | `dox migrate:fresh` | Drop every table, then run all migrations. |
| `dox migration:status` | `dox migrate:status` | Print which migrations ran, and their batch. |

`--seed` after `migration:run`, `migration:refresh` or `migration:fresh` runs `dox db:seed` when the migrations end well.

`bin/migrate.dart` takes the same commands: `dart run bin/migrate.dart <run|rollback [--step=n]|reset|refresh|fresh|status>`. With no command it runs `run`.

## Factories and seeders

| Command | Aliases | What it does |
| --- | --- | --- |
| `dox make:factory <model>` | `dox create:factory` | Make `db/factories/<model>.factory.dart`. It imports the model with the package name of `pubspec.yaml`. |
| `dox make:seeder <name>` | `dox create:seeder` | Make `db/seeders/<name>.seeder.dart`. It writes `db/seeders/seeders.dart` again, and makes `bin/seed.dart` when it is missing. |
| `dox db:seed [--class=<name>]` | | Write `db/seeders/seeders.dart` again, then run `dart run bin/seed.dart [--class=<name>]`. Default seeder: `DatabaseSeeder`. `--class <name>` (with a space) works too. When `bin/seed.dart` is missing, it prints `bin/seed.dart is missing.` (exit code 1). |

Templates: `createFactory` in `lib/src/tools/create_factory.dart`, and `createSeeder` and `seedEntrySource` in `lib/src/tools/create_seeder.dart`.

## Queue

These commands run the app script `bin/queue.dart` with `dart run`. A new project already has it. It uses the `dox_queue` package.
Input, output and errors go straight to your terminal. `Ctrl+C` (SIGINT) and SIGTERM are sent on to the script, so a worker can finish its job and stop. The exit code of the script is the exit code of `dox`.
When `bin/queue.dart` is missing, the command prints how to set it up and exits with code 1.

| Command | Runs | What it does |
| --- | --- | --- |
| `dox make:job <name>` | | Make `lib/app/jobs/<name>.job.dart` with a `@Job()` class that extends `DoxJob`. A trailing `Job` in the name is removed. Make `bin/queue.dart` when it is missing. Print a hint to add `dox_queue` to `pubspec.yaml` when it is not there, and to run `dox build_runner:build` (it makes `lib/generated/jobs.g.dart`). |
| `dox queue:work [flags]` | `bin/queue.dart work [flags]` | Run the worker. |
| `dox queue:failed` | `bin/queue.dart failed` | List the failed jobs. |
| `dox queue:retry <id\|all>` | `bin/queue.dart retry <id\|all>` | Put one failed job, or all of them, back on the queue. |
| `dox queue:forget <id>` | `bin/queue.dart forget <id>` | Delete one failed job. |
| `dox queue:flush` | `bin/queue.dart flush` | Delete all failed jobs. |

Flags of `queue:work`, passed on as they are:

| Flag | Default | Meaning |
| --- | --- | --- |
| `--queue=a,b` | `default` | The queues to read, the first one first. |
| `--concurrency=N` | `1` | How many jobs run at the same time in this process. |
| `--once` | off | Run one job, then stop. |
| `--tries=N` | `1` | How many times a job may run before it is marked as failed. A job can set its own `tries`. |
| `--timeout=S` | `60` | Seconds a job may run. |
| `--sleep=S` | `3` | Seconds to wait when the queues are empty. |
| `--stop-when-empty` | off | Stop when the queues are empty. |

An unknown flag or command prints the usage and exits with code 64.

The `bin/queue.dart` of a new project (`<app>` is the `name` in `pubspec.yaml`). The jobs come from `queueConfig` in `lib/config/queue.dart`:

```dart
import 'dart:io';

import 'package:dox_queue/dox_queue.dart';
import 'package:<app>/config/app.dart';

Future<void> main(List<String> args) async {
  exitCode = await QueueWorker(app: appConfig).run(args);
}
```

Templates: `createJob` and `queueEntrySource` in `lib/src/tools/create_job.dart`.

## Schedule

These commands run the app script `bin/schedule.dart` with `dart run`. A new project already has it. They pass the signals, the terminal and the exit code the same way as the queue commands.
When `bin/schedule.dart` is missing, the command prints how to set it up and exits with code 1.

| Command | Runs | What it does |
| --- | --- | --- |
| `dox schedule:work` | `bin/schedule.dart work` | Run the scheduler and keep it running. |
| `dox schedule:run` | `bin/schedule.dart run` | Run the tasks that are due now, once. |
| `dox schedule:list` | `bin/schedule.dart list` | List the scheduled tasks. |
| `dox schedule:test <name>` | `bin/schedule.dart test <name>` | Run one task now. |

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

See [Scheduler](../digging-deeper/scheduler.md) for the task methods. See [Queue](../digging-deeper/queue.md) for jobs.

## Command list

| Command | Aliases | Category |
| --- | --- | --- |
| `create` | | Project |
| `serve` | `server`, `s` | Development |
| `make:controller` | `create:controller` | Development |
| `make:middleware` | `create:middleware` | Development |
| `make:dto` | `create:dto` | Development |
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
| `schedule:work` | | Schedule |
| `schedule:run` | | Schedule |
| `schedule:list` | | Schedule |
| `schedule:test` | | Schedule |
| `db:seed` | | Database |
| `version` | `--version`, `-version`, `v`, `-v`, `--v` | System |
| `update` | | System |
| `env:check` | | System |
| `help` | `--help`, `-h` | System |
