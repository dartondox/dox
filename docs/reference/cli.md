# CLI

Every `dox` command, with its options and the files it writes.

The commands come from `packages/dox-cli/lib/src/command_registry.dart`. The file templates are Dart strings inside `packages/dox-cli/lib/src/tools/`. The path of each template is given below.

How to install the CLI is on the [Dox CLI](../digging-deeper/dox-cli.md) page.

Rules that apply to every command:

- `dox` with no command prints `Could not find a command. Run `dox help` for more information.`
- An unknown command prints `Could not find a command named "<name>".`
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
| `--version <v>` (or `--v`) | The release tag to clone, like `3.0.0-alpha.5` or `v3.0.0-alpha.5`. Without it, the newest `dox-sample` release with the same major version as the CLI is used (pre-releases included). |

What it does:

1. Turns the name into `snake_case`. Stops with `Folder name "<name>" already exist` when the folder is there.
2. Picks the release (see `--version` above) from the release list of `dartondox/dox-sample`.
3. Runs `git clone --depth 1 --branch v<version> https://github.com/dartondox/dox-sample.git <name>`.
4. Deletes the `.git` folder.
5. Replaces `dox_sample` with your project name in every file, except files under `bin/dox`.
6. Copies `.env.example` to `.env` and writes a new random `APP_KEY` to it, like `dox key:generate`. It skips this step when `.env` is already there.

Needs `curl` and `git` on the `PATH`.

Source: `packages/dox-cli/lib/src/tools/create_project.dart`.

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
3. Watches the project folder. When a `.dart` file changes it prints `[Dox] File changed: <file>`, waits 500 ms, kills the server and starts it again.

Source: `packages/dox-cli/lib/src/tools/server_serve.dart`.

### `dox build`

```
dox build
```

AOT compiles the app for production into `build/bundle`. Use this in production, not `dart run`.

What it does:

1. When `pubspec.yaml` contains `build_runner`: runs `dart run build_runner build`. Stops with exit code 1 when it fails.
2. Runs `dart build cli --target bin/server.dart --output build`.
3. Copies `db/` to `build/bundle/db` (migrations are read at start).
4. Copies `.env.example` to `build/bundle/.env.example`.
5. Prints `[Dox] Built build/bundle. Run it with: cd build/bundle && ./bin/server`.

Output:

| Path | What |
| --- | --- |
| `build/bundle/bin/server` | the native binary, no Dart SDK needed |
| `build/bundle/lib/` | native libraries from build hooks (SQLite, `dox_http_native`, ...) |
| `build/bundle/db/` | your migrations |
| `build/bundle/.env.example` | copy it to `.env` or set real env vars |

`dart compile exe` can not build packages with build hooks, so the CLI uses `dart build cli`.

Source: `packages/dox-cli/lib/src/tools/server_serve.dart` (`buildServer`).

### `dox build_runner:build` and `dox build_runner:watch`

```
dox build_runner:build
dox build_runner:watch
```

Run `dart run build_runner build` once, or `dart run build_runner watch`. No options.
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

Source: `packages/dox-cli/lib/src/tools/generate_key.dart`.

### `dox env:generate`

```
dox env:generate
```

Writes `lib/config/env.dart`, the typed env class, from `.env.example`.

- Stops with `.env.example is missing.` (exit code 1) when there is no example file.
- Stops with `lib/config/env.dart is already there. Delete it to make it again.` (exit code 1) when the file exists.
- Prints `Run `dart run build_runner build` to make env.g.dart.` when done.

Rules for each key: digits give `int get x => <value>;`, `true`/`false` give `bool`, an empty value gives `String? get x;`, any other value gives `String get x;` (required, no default). `#` comment lines above a key become its doc comment. A key that does not map back from `camelCase` gets `@EnvKey('KEY')`.

Source: `packages/dox-cli/lib/src/tools/env_tools.dart` (`EnvScaffold`).

### `dox env:check`

```
dox env:check
```

Loads `AppEnv` from `lib/config/env.dart` with the real environment and `.env`. Prints `The env is valid.` or an `EnvException` with every missing or bad key (exit code 1).

It writes a small script to `.dart_tool/dox/env_check.dart` and runs it with `dart run`. It needs `lib/config/env.dart` and a `name:` in `pubspec.yaml`.

Source: `packages/dox-cli/lib/src/tools/env_tools.dart` (`envCheck`).

### `dox openapi:generate`

```
dox openapi:generate [dir]
```

Runs `dart run bin/openapi.dart [dir]`. That file writes `openapi.json` and `openapi.yaml` into `dir` (default `storage/openapi`).
Stops with `bin/openapi.dart is missing.` (exit code 1) when the file is not there. See [OpenAPI](../packages/openapi.md).

Source: `packages/dox-cli/lib/src/tools/openapi_generate.dart`.

### `dox update`

```
dox update
```

Installs the newest CLI with the same major version as the one you have. Pre-releases count.
It reads the version list from pub.dev, then runs `dart pub global activate dox <version>`.

Source: `packages/dox-cli/lib/src/tools/update_dox.dart`.

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
```

Without a command: lists every command by category. With a command: prints its usage, description, category, aliases and argument count.

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
| plain | `lib/app/http/controllers/<name>.controller.dart` | `_getSample` in `packages/dox-cli/lib/src/tools/create_controller.dart` |
| `-r` | `lib/app/http/controllers/<name>.controller.dart` | `_getResourceSample` in the same file |

The class has `@Inject()`, so the container makes it. A comment shows the route to add, like `Route.get<BlogController>('path', (BlogController c) => c.index);`.
After the file is made, the CLI tells you to run `dart run build_runner build`. That adds the controller to `lib/container.g.dart`.

### `dox make:middleware`

```
dox make:middleware <name>
```

Writes `lib/app/http/middleware/<name>.middleware.dart`: a class `<Name>Middleware extends IDoxMiddleware` with a `handle(IDoxRequest req)` that returns `req`.
A trailing `Middleware` in the name is removed.

Template: `_getSample` in `packages/dox-cli/lib/src/tools/create_middleware.dart`.

### `dox make:dto`

```
dox make:dto <name>
```

Writes `lib/app/http/dtos/<name>.dto.dart`: a `@Dto()` class with one `name` field and `part '<name>.dto.g.dart';`.
A trailing `Dto` in the name is removed. Prints `Run `dox build_runner:build` to make <name>.dto.g.dart.`

Template: `_getSample` in `packages/dox-cli/lib/src/tools/create_dto.dart`.

### `dox make:serializer`

```
dox make:serializer <name>
```

Writes `lib/app/http/serializers/<name>.serializer.dart`: a class `<Name>Serializer extends Serializer<<Name>>`. It imports the model from `lib/app/models/<name>/<name>.model.dart`.
A trailing `Serializer` in the name is removed.

Template: `_getSample` in `packages/dox-cli/lib/src/tools/create_serializer.dart`.

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

Template: `_getSample` in `packages/dox-cli/lib/src/tools/create_model.dart`.

### `dox make:migration`

```
dox make:migration <name> [--sql]
dox create:migration <name> [--sql]
```

| Option | Meaning |
| --- | --- |
| `--sql` | Make a `.sql` file with `-- up` and `-- down` sections instead of a Dart class. |

Writes `db/migration/<yyyy>_<mm>_<dd>_<hhmmss>_<name>.dart` (or `.sql`). Characters that are not letters, digits or `_` are removed from the name.

For a Dart migration it also:

- writes `db/migration/migrations.dart`, the registry of every Dart migration in the folder, sorted by name;
- writes `bin/migrate.dart` when it is missing, and prints `bin/migrate.dart created.`

The Dart template depends on the name:

| Name | `up()` | `down()` |
| --- | --- | --- |
| `create_<table>_table` | `schema.create('<table>', ...)` with `id()` and `timestamps()` | `schema.dropIfExists('<table>')` |
| `<x>_to_<table>_table` (also `from`, `in`, `on`) | `schema.table('<table>', ...)` | `schema.table('<table>', ...)` |
| anything else | a comment | a comment |

Templates: `dartMigrationSource`, `migrateEntrySource` and `_sampleSql` in `packages/dox-cli/lib/src/tools/create_migration.dart`.

## Migrations

All `migration:*` commands work the same way:

1. When `bin/migrate.dart` exists: write the registry again, then run `dart run bin/migrate.dart <command> [args]`. Your app code runs, so Dart migrations work.
2. When there is no `bin/migrate.dart` but `db/migration` has Dart files: print `db/migration has Dart migrations, but bin/migrate.dart is missing.` (exit code 1).
3. Else: run the `.sql` migrations with `Migrator()` from `dox_migration` in the CLI process.

The database comes from `DB_CONNECTION`, `DB_HOST`, `DB_PORT`, `DB_USERNAME`, `DB_PASSWORD` and `DB_DATABASE` (or `DB_NAME`). See [Environment variables](env.md).
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

## Factories and seeders

| Command | Aliases | What it does |
| --- | --- | --- |
| `dox make:factory <model>` | `dox create:factory` | Make `db/factories/<model>.factory.dart`. It imports the model with the package name of `pubspec.yaml`. |
| `dox make:seeder <name>` | `dox create:seeder` | Make `db/seeders/<name>.seeder.dart`. It writes `db/seeders/seeders.dart` again, and makes `bin/seed.dart` when it is missing. |
| `dox db:seed [--class=<name>]` | | Write `db/seeders/seeders.dart` again, then run `dart run bin/seed.dart`. Default seeder: `DatabaseSeeder`. |

Templates: `createFactory` in `packages/dox-cli/lib/src/tools/create_factory.dart`, and `createSeeder` and `seedEntrySource` in `packages/dox-cli/lib/src/tools/create_seeder.dart`.

## Queue

These commands run the app script `bin/queue.dart` with `dart run`. The script comes from the `dox_queue` package. `dox make:job` makes it when it is missing.
Input, output and errors go straight to your terminal. `Ctrl+C` (SIGINT) and SIGTERM are sent on to the script, so a worker can finish its job and stop. The exit code of the script is the exit code of `dox`.
When `bin/queue.dart` is missing, the command prints how to set it up and exits with code 1.

| Command | Runs | What it does |
| --- | --- | --- |
| `dox make:job <name>` | | Make `lib/app/jobs/<name>.job.dart` with a `@Job()` class that extends `DoxJob`. Make `bin/queue.dart` when it is missing. Print a hint to add `dox_queue` to `pubspec.yaml` and to run `dox build_runner:build`. |
| `dox queue:work [flags]` | `bin/queue.dart work [flags]` | Run the worker. |
| `dox queue:failed` | `bin/queue.dart failed` | List the failed jobs. |
| `dox queue:retry <id\|all>` | `bin/queue.dart retry <id\|all>` | Put one failed job, or all of them, back on the queue. |
| `dox queue:forget <id>` | `bin/queue.dart forget <id>` | Delete one failed job. |
| `dox queue:flush` | `bin/queue.dart flush` | Delete all failed jobs. |

Flags of `queue:work`, passed on as they are:

| Flag | Meaning |
| --- | --- |
| `--queue=a,b` | The queues to read, in this order. |
| `--concurrency=N` | How many jobs run at the same time. |
| `--once` | Run one job, then stop. |
| `--tries=N` | How many times a job may run before it is marked as failed. |
| `--timeout=S` | Seconds a job may run. |
| `--sleep=S` | Seconds to wait when the queue is empty. |
| `--stop-when-empty` | Stop when the queue is empty. |

The `bin/queue.dart` that `make:job` writes (`<app>` is the `name` in `pubspec.yaml`):

```dart
import 'dart:io';

import 'package:dox_queue/dox_queue.dart';
import 'package:<app>/config/app.dart';
import 'package:<app>/jobs.g.dart';

Future<void> main(List<String> args) async {
  exitCode = await QueueWorker(jobs: jobRegistry, app: appConfig).run(args);
}
```

Templates: `createJob` and `queueEntrySource` in `packages/dox-cli/lib/src/tools/create_job.dart`.

## Schedule

These commands run the app script `bin/schedule.dart` with `dart run`. They pass the signals, the terminal and the exit code the same way as the queue commands.
When `bin/schedule.dart` is missing, the command prints how to set it up and exits with code 1.

| Command | Runs | What it does |
| --- | --- | --- |
| `dox schedule:work` | `bin/schedule.dart work` | Run the scheduler and keep it running. |
| `dox schedule:run` | `bin/schedule.dart run` | Run the tasks that are due now, once. |
| `dox schedule:list` | `bin/schedule.dart list` | List the scheduled tasks. |
| `dox schedule:test <name>` | `bin/schedule.dart test <name>` | Run one task now. |

To set it up, add `dox_scheduler` to `pubspec.yaml`, then make two small files.
The exact names come from the `dox_scheduler` package. This is the shape:

```dart
// lib/config/schedule.dart
import 'package:dox_scheduler/dox_scheduler.dart';

final Schedule schedule = Schedule()
  ..call('report', () async {/* your task */}).dailyAt('02:00');
```

```dart
// bin/schedule.dart
import 'dart:io';

import 'package:dox_scheduler/dox_scheduler.dart';
import 'package:<app>/config/app.dart';
import 'package:<app>/config/schedule.dart';

Future<void> main(List<String> args) async {
  exitCode = await ScheduleRunner(schedule: schedule, app: appConfig).run(args);
}
```

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
| `help` | | System |
