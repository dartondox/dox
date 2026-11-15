---
icon: lucide/square-terminal
---

# Dox CLI

The `dox` CLI creates projects and files, runs the dev server, builds for production and runs migrations.

Run `dox help` to see all commands, or `dox help <command>` for one command. Many `make:*` commands also answer to a `create:*` name. Every command is in the [table at the end](#all-commands).

## Installation

Install the CLI with `dart pub`:

```bash
dart pub global activate dox
```

If your shell can not find `dox`, add the pub bin folder to your `PATH`. Put this line in `~/.bashrc` or `~/.zshrc`, then open a new terminal:

```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

### Updating the CLI

`dox update` installs the newest version with the same major version as your CLI. To pick the version yourself, run the install command again.

```bash
dox update
```

To remove the CLI, run `dart pub global deactivate dox`.

## Creating a project

Use `dox create` to start a new project:

```bash
dox create new_blog
```

It copies the [dox-sample](https://github.com/dartondox/dox-sample) template from GitHub and makes `.env` from `.env.example`, with a new `APP_KEY`. The folder name is the project name in snake case, so `NewBlog` makes `new_blog`.

Then run `cd new_blog`, `dart pub get` and `dox serve`.

By default it uses the newest template release with the same major version as the CLI. To pick a release, pass `--version`:

```bash
dox create new_blog --version <release tag>
```

## Running the dev server

`dox serve` (or `dox s`) starts your app for development:

```bash
dox serve
```

When a file in `lib/app/` changes, it hot reloads the new code into the running server. This takes about 0.1 to 0.2 seconds. When routes, providers, config, `bin/`, `db/` or generated files change, it restarts the server instead. It also runs `build_runner watch`, so generated files stay up to date.

Hot reload does not run code again that already ran once. So a changed static or global value keeps its old value until a restart.

The server prints the VM service link. Open it in a browser to get DevTools, the debugger and the profiler.

If you do not want hot reload, or you run `build_runner` yourself, use these options:

```bash
dox s --no-reload             # restart on every change, no hot reload
dox s --ignore-build-runner   # do not run build_runner watch
```

See [dox serve](../reference/cli.md#dox-serve) for all details.

## Building for production

`dox build` builds a native (AOT) bundle into `build/bundle`. Run the server from there:

```bash
dox build
cd build/bundle
./bin/server
```

See [Deployment](deployment.md#build).

## Creating files

The `make:*` commands write new files with the right names and folders. Names keep their word breaks, so `BlogPost` makes `blog_post.controller.dart` with the class `BlogPostController`.

After `make:controller` or `make:dto`, run `dox build_runner:build`, or keep `dox serve` running. See [Validation](../the-basic/validation.md).

### Controllers

`make:controller` writes a controller in `lib/app/http/controllers`:

```bash
dox make:controller Blog        # lib/app/http/controllers/blog.controller.dart
```

If you want a controller for all actions of a resource, add `-r` (or `--resource`). It adds the methods `index`, `create`, `store`, `show`, `edit`, `update` and `destroy`. For an API, `--api` adds the same methods without `create` and `edit`. To use a model in it, add `--model`:

```bash
dox make:controller Blog -r
dox make:controller Blog --api
dox make:controller Blog --model=Post
```

### Models

`make:model` writes a model. The options also make the files that belong to it:

```bash
dox make:model Blog -m          # model and a create_blogs_table migration
dox make:model Blog -mcr        # model, migration and a resource controller
dox make:model Blog -a          # model, migration, factory, seeder and a resource controller
```

The options are `-m` migration, `-c` controller, `-r` resource controller, `--api` resource controller without `create` and `edit`, `-f` factory, `-s` seeder and `-a` for all of them. You can join them, like `-mfs`. See [CLI reference](../reference/cli.md#dox-makemodel).

The table of a model is its name in plural snake case. So `BlogPost` gets `@DoxModel(table: 'blog_posts')`.

### Migrations

`make:migration` writes a Dart migration. Add `--sql` for a `.sql` file:

```bash
dox make:migration create_blogs_table
dox make:migration create_blogs_table --sql
```

### Mail and views

`make:mail` writes a mailable in `lib/app/mail` and its view. If you want a plain text body, add `--no-view`. `make:view` writes a `.dox.html` view:

```bash
dox make:mail Welcome           # lib/app/mail/welcome_mail.dart and resources/views/emails/welcome.dox.html
dox make:mail Invoice --no-view # the mail only, with a plain text body
dox make:view pages/about       # resources/views/pages/about.dox.html
```

### Tests

`make:test` writes a test that starts the app with `DoxTestClient`. Add `--unit` for a plain test:

```bash
dox make:test Ping              # test/ping_test.dart
dox make:test Math --unit       # test/math_test.dart
```

### Other files

```bash
dox make:middleware Auth        # lib/app/http/middleware/auth.middleware.dart
dox make:dto CreateBlog         # lib/app/dtos/create_blog/create_blog.dto.dart
dox make:serializer Blog        # lib/app/serializers/blog.serializer.dart
dox make:provider Cache         # lib/providers/cache_provider.dart
dox make:command send_report    # lib/app/commands/send_report_command.dart, run it with dox app:send-report
```

## Listing routes

`dox route:list` prints every route of the app, without starting the server. Add `--json` for JSON output:

```bash
dox route:list
```

See [`dox route:list`](../reference/cli.md#dox-routelist).

## Running migrations

The migration commands read the database settings from `.env` and the real environment. A real environment variable wins over `.env`:

```ini title=".env"
# postgres, mysql or sqlite
DB_CONNECTION=postgres
DB_HOST=localhost
DB_PORT=5432
# for sqlite: the file path
DB_NAME=postgres
DB_USERNAME=admin
DB_PASSWORD=password
```

`DB_CONNECTION` defaults to `sqlite`. If `DATABASE_URL` is set, it wins over all the `DB_*` keys. All keys are in the [Env reference](../reference/env.md#read-by-the-framework).

Use `migration:run` (or `migrate`) to run new migrations, and `migration:status` to see which ones ran:

```bash
dox migration:run
dox migration:status
```

A failed migration stops the run, and the CLI exits with code 1. On MySQL, statements like `CREATE`, `ALTER` and `DROP` save right away. So when a migration fails half way, these changes are not undone.

### Rolling back migrations

`migration:rollback` undoes the last batch. Use `--step` to undo the last N migrations, or `--batch` to undo only one batch:

```bash
dox migration:rollback
dox migration:rollback --step=2
dox migration:rollback --batch=3
```

### Resetting the database

`migration:reset` undoes all migrations. `migration:refresh` undoes all, then runs them again. `migration:fresh` drops all tables, then runs all migrations:

```bash
dox migration:reset
dox migration:refresh
dox migration:fresh
```

If you also want to run the seeders, add `--seed` to `migration:run`, `migration:refresh` or `migration:fresh`.

The `migrate:*` names also work, like `migrate:rollback` and `migrate:fresh`.

## All commands

| Command | What it does |
| --- | --- |
| `dox create <name> [--version <v>]` | create a new project |
| `dox serve` (or `dox s`) | start the dev server with hot reload and build_runner watch |
| `dox build` | build the native (AOT) bundle into `build/bundle` |
| `dox build_runner:watch` / `dox build_runner:build` | run the code generator |
| `dox make:controller <name> [-r] [--api] [--model=<model>]` | create a controller |
| `dox make:middleware <name>` | create a middleware |
| `dox make:dto <name>` | create a DTO (typed, checked input) |
| `dox make:serializer <name>` | create a serializer |
| `dox make:provider <name>` | create a provider in `lib/providers` |
| `dox make:command <name>` | create a command in `lib/app/commands` and add it to the commands list |
| `dox make:mail <name> [--no-view]` | create a mailable in `lib/app/mail`, and its view unless you pass `--no-view` |
| `dox make:view <name>` | create a `.dox.html` view in `resources/views` |
| `dox make:test <name> [--unit]` | create a test in `test/` that uses `DoxTestClient`, or a plain one with `--unit` |
| `dox route:list [--json]` | list every route of the app, without starting the server |
| `dox make:model <name> [-m] [-c] [-r] [--api] [-f] [-s] [-a]` | create a model, and with the options its migration, controller, factory and seeder |
| `dox make:migration <name> [--sql]` | create a Dart migration, or a `.sql` one with `--sql` |
| `dox migration:run` (or `dox migrate`) | run new migrations |
| `dox migration:rollback [--step=N] [--batch=N]` | undo the last batch, the last N migrations, or only batch N |
| `dox migration:reset` | undo all migrations |
| `dox migration:refresh` | undo all, then run all again |
| `dox migration:fresh` (or `migrate:fresh`) | drop all tables, then run all migrations |
| `dox migration:status` | show which migrations ran, and their batch |
| `dox make:factory <model>` | create a model factory in `db/factories`, see [Factories](../database/factories.md) |
| `dox make:seeder <name>` | create a seeder in `db/seeders` (and `bin/seed.dart`), see [Seeders](../database/seeders.md) |
| `dox db:seed [--class=<name>]` | run `DatabaseSeeder`, or another seeder |
| `dox make:job <name>` | create a queue job in `lib/app/jobs` (and `bin/queue.dart`) |
| `dox queue:work [--queue=a,b] [--concurrency=N] [--once] [--tries=N] [--timeout=S] [--sleep=S] [--stop-when-empty] [--timeout-grace=S]` | run the queue worker |
| `dox queue:failed` | list the failed jobs |
| `dox queue:retry <id\|all>` | put a failed job (or all) back on the queue |
| `dox queue:forget <id>` | delete one failed job |
| `dox queue:flush` | delete all failed jobs |
| `dox queue:clear [queue]` | delete the jobs of a queue |
| `dox queue:restart` | stop the running workers after their current jobs |
| `dox queue:prune-failed [--hours=N]` | delete failed jobs older than N hours (default 24) |
| `dox queue:table` | create a migration for the `jobs`, `failed_jobs` and `job_batches` tables (from the `dox_queue_database` package) |
| `dox auth:tokens-table` | create a migration for the `auth_access_tokens` table (from the `dox_auth` package) |
| `dox schedule:work` | run the scheduler and keep it running |
| `dox schedule:run` | run the tasks that are due now, once |
| `dox schedule:list` | list the scheduled tasks |
| `dox schedule:test <name>` | run one scheduled task now |
| `dox schedule:clear-cache` | remove the `withoutOverlapping()` locks left by a crash |
| `dox key:generate [--show] [--force]` | make a new `APP_KEY`. `--show` prints a key and writes nothing. In production it asks first, `--force` skips |
| `dox env:generate` | make `lib/config/env.dart` (the typed env class) from `.env.example`, see [Environment Variables](env.md) |
| `dox env:check` | check the env against `lib/config/env.dart`. Prints every missing or bad key (exit code 1) |
| `dox openapi:generate [dir]` | run `bin/openapi.dart` to write `openapi.json` and `openapi.yaml` (default `storage/openapi`). A new project has no `bin/openapi.dart` yet, see [OpenAPI](../packages/openapi.md#write-the-files) |
| `dox update` | update the CLI |
| `dox version` (or `dox -v`) | show the CLI version |
| `dox help [command]` | show help |

## Details

- `DB_CONNECTION` must be `sqlite`, `postgres` or `mysql`. Any other value is an error. The default port is `5432` for postgres and `3306` for mysql.
- `DB_DATABASE` works too, in place of `DB_NAME`.
- In `.env`, a `#` after a space starts a comment, the same as in the app. The migration commands do not expand `${VAR}` and do not read `.env.testing`.
- `dox serve` runs `dart run bin/server.dart`. A failed hot reload restarts the server. One save gives one restart.
