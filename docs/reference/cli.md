# CLI

Every `dox` command, from the command registry in `packages/dox-cli/lib/src/command_registry.dart`.
The file templates are Dart strings inside `packages/dox-cli/lib/src/tools/`. The path of each template is given below.

How to install the CLI is on the [Dox CLI](../digging-deeper/dox-cli.md) page.

Rules that apply to every command:

- `dox` with no command prints `Could not find a command. Run `dox help` for more information.`
- An unknown command prints `Could not find a command named "<name>".`
- Too few or too many arguments prints `Invalid number of arguments for command "<name>".` with the expected count.
- A name you pass is turned into `snake_case` for the file and `PascalCase` for the class. `BlogPost` and `blog_post` give the same result.
- A `create:*` command does not overwrite. When the file exists it prints `<name> already exists` and stops.

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
2. Reads the release list of `dartondox/dox-sample` and takes the newest release with the same major version as the CLI.
3. Runs `git clone --depth 1 --branch v<version> https://github.com/dartondox/dox-sample.git <name>`.
4. Deletes the `.git` folder.
5. Replaces `dox_sample` with your project name in every file, except files under `bin/dox`.

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
So a 3.x alpha CLI updates to the newest 3.x alpha, not to the old 2.x stable.
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

### `dox create:controller`

```
dox create:controller <name> [-r] [-ws]
```

| Option | Meaning |
| --- | --- |
| `-r` | A resource controller with `index`, `create`, `store`, `show`, `edit`, `update`, `destroy`. |
| `-ws` | A WebSocket controller. |

A trailing `Controller` in the name is removed: `UserController` and `User` give the same file.

| Form | Writes | Template |
| --- | --- | --- |
| plain | `lib/app/http/controllers/<name>.controller.dart` | `_getSample` in `packages/dox-cli/lib/src/tools/create_controller.dart` |
| `-r` | `lib/app/http/controllers/<name>.controller.dart` | `_getResourceSample` in the same file |
| `-ws` | `lib/app/ws/controllers/<name>.controller.dart` | `_getWsSample` in the same file |

The plain and resource templates also make an instance: `<Name>Controller <name>Controller = <Name>Controller();`.

### `dox create:middleware`

```
dox create:middleware <name>
```

Writes `lib/app/http/middleware/<name>.middleware.dart`: a class `<Name>Middleware extends IDoxMiddleware` with a `handle(IDoxRequest req)` that returns `req`.
A trailing `Middleware` in the name is removed.

Template: `_getSample` in `packages/dox-cli/lib/src/tools/create_middleware.dart`.

### `dox create:dto`

```
dox create:dto <name>
```

Writes `lib/app/http/dtos/<name>.dto.dart`: a `@Dto()` class with one `name` field and `part '<name>.dto.g.dart';`.
A trailing `Dto` in the name is removed. Prints `Run `dox build_runner:build` to make <name>.dto.g.dart.`

Template: `_getSample` in `packages/dox-cli/lib/src/tools/create_dto.dart`.

### `dox create:serializer`

```
dox create:serializer <name>
```

Writes `lib/app/http/serializers/<name>.serializer.dart`: a class `<Name>Serializer extends Serializer<<Name>>`. It imports the model from `lib/app/models/<name>/<name>.model.dart`.
A trailing `Serializer` in the name is removed.

Template: `_getSample` in `packages/dox-cli/lib/src/tools/create_serializer.dart`.

### `dox create:model`

```
dox create:model <name> [-m|--migration]
dox make:model <name> [-m|--migration]
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
| `dox migration:status` | `dox migrate:status` | Print which migrations ran, and their batch. |

## Command list

| Command | Aliases | Category |
| --- | --- | --- |
| `create` | | Project |
| `serve` | `server`, `s` | Development |
| `create:controller` | | Development |
| `create:middleware` | | Development |
| `create:dto` | | Development |
| `build` | | Build |
| `build_runner:build` | | Build Runner |
| `build_runner:watch` | | Build Runner |
| `create:model` | `make:model` | Generation |
| `create:serializer` | | Generation |
| `key:generate` | | Generation |
| `env:generate` | | Generation |
| `openapi:generate` | | Generation |
| `migration:run` | `migrate` | Database |
| `migration:rollback` | `migrate:rollback` | Database |
| `migration:reset` | `migrate:reset` | Database |
| `migration:refresh` | `migrate:refresh` | Database |
| `migration:status` | `migrate:status` | Database |
| `make:migration` | `create:migration` | Database |
| `version` | `--version`, `-version`, `v`, `-v`, `--v` | System |
| `update` | | System |
| `env:check` | | System |
| `help` | | System |
