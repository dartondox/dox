---
icon: lucide/square-terminal
---

# Dox CLI

The `dox` CLI creates projects and files, runs the dev server, builds for production and runs migrations.

Many `make:*` commands also answer to a `create:*` name.
Run `dox help` to see all commands. Run `dox help <command>` for one command.

## Installation

```bash
dart pub global activate dox
```

!!! warning "Add the pub bin folder to your PATH"
    If your shell can not find `dox`, add this line to `~/.bashrc` or `~/.zshrc`, and open a new terminal:

    ```bash
    export PATH="$PATH":"$HOME/.pub-cache/bin"
    ```

To remove the CLI:

```bash
dart pub global deactivate dox
```

## All commands

| Command | What it does |
| --- | --- |
| `dox create <name> [--version <v>]` | create a new project |
| `dox serve` (or `dox s`) | start the dev server with build_runner watch |
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
| `dox migration:rollback [--step=N]` | undo the last batch, or the last N migrations |
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
| `dox queue:table` | create a migration for the `jobs` and `failed_jobs` tables (from the `dox_queue` package) |
| `dox auth:tokens-table` | create a migration for the `auth_access_tokens` table (from the `dox_auth` package) |
| `dox schedule:work` | run the scheduler and keep it running |
| `dox schedule:run` | run the tasks that are due now, once |
| `dox schedule:list` | list the scheduled tasks |
| `dox schedule:test <name>` | run one scheduled task now |
| `dox schedule:clear-cache` | remove the `withoutOverlapping()` locks left by a crash |
| `dox key:generate [--show] [--force]` | make a new `APP_KEY`. `--show` prints a key and writes nothing. In production it asks first, `--force` skips |
| `dox env:generate` | make `lib/config/env.dart` (the typed env class) from `.env.example`, see [Environment Variables](env.md) |
| `dox env:check` | check the env against `lib/config/env.dart`. Prints every missing or bad key (exit code 1) |
| `dox openapi:generate [dir]` | run `bin/openapi.dart` to write `openapi.json` and `openapi.yaml` (default `storage/openapi`). A new project has no `bin/openapi.dart` yet, see [OpenAPI](../packages/openapi.md#write-the-files-dox-openapigenerate) |
| `dox update` | update the CLI |
| `dox version` (or `dox -v`) | show the CLI version |
| `dox help [command]` | show help |

## Project

### Create a project

```bash
dox create new_blog
dox create new_blog --version <release tag>
```

`dox create` copies the [dox-sample](https://github.com/dartondox/dox-sample) template from GitHub. Without `--version`, it uses the newest template release with the same major version as the CLI.

- The folder name is the project name in snake case: `NewBlog` makes `new_blog`.
- It makes `.env` from `.env.example`, with a new `APP_KEY`.
- Then run `cd new_blog`, `dart pub get` and `dox serve`.

### Run the dev server

```bash
dox serve                         # or: dox s
dox s --ignore-build-runner       # do not run build_runner watch
```

`dox serve` runs `dart run bin/server.dart` and restarts it when a `.dart` file changes.
It also runs `build_runner watch`, so generated files stay up to date.

### Build for production

```bash
dox build
cd build/bundle
./bin/server
```

See [Deployment](deployment.md#build).

## Create files

```bash
dox make:controller Blog        # lib/app/http/controllers/blog.controller.dart
dox make:controller Blog -r     # resource controller
dox make:controller Blog --api  # resource controller without create and edit
dox make:controller Blog --model=Post  # resource controller that uses the Post model
dox make:middleware Auth        # lib/app/http/middleware/auth.middleware.dart
dox make:dto CreateBlog         # lib/app/dtos/create_blog/create_blog.dto.dart
dox make:serializer Blog        # lib/app/serializers/blog.serializer.dart
dox make:provider Cache         # lib/providers/cache_provider.dart
dox make:command send_report    # lib/app/commands/send_report_command.dart, run it with dox app:send-report
dox make:mail Welcome           # lib/app/mail/welcome_mail.dart and resources/views/emails/welcome.dox.html
dox make:mail Invoice --no-view # the mail only, with a plain text body
dox make:view pages/about       # resources/views/pages/about.dox.html
dox make:test Ping              # test/ping_test.dart, starts the app with DoxTestClient
dox make:test Math --unit       # test/math_test.dart, a plain test
dox make:model Blog -m          # lib/app/models/blog/blog.model.dart and a create_blogs_table migration
dox make:model Blog -mcr        # model, migration and a resource controller
dox make:model Blog -a          # model, migration, factory, seeder and a resource controller
dox make:migration create_blogs_table          # .dart file (default)
dox make:migration create_blogs_table --sql    # .sql file
```

- `-r` (or `--resource`) adds the methods `index`, `create`, `store`, `show`, `edit`, `update` and `destroy`. `--api` adds the same methods without `create` and `edit`.
- `make:model` options: `-m` migration, `-c` controller, `-r` resource controller, `--api` resource controller without `create` and `edit`, `-f` factory, `-s` seeder, `-a` migration, factory, seeder and resource controller. Join them, like `-mfs`. See [CLI reference](../reference/cli.md#dox-makemodel).
- `dox route:list` prints the routes of the app. See [`dox route:list`](../reference/cli.md#dox-routelist).
- Word breaks are kept. `BlogPost` makes `blog_post.controller.dart` with the class `BlogPostController`.
- After `make:controller` or `make:dto`, run `dox build_runner:build` (or keep `dox serve` running). See [Validation](../the-basic/validation.md).
- The table of a model is its name in plural snake case: `BlogPost` makes `blog_posts`. The model gets `@DoxModel(table: 'blog_posts')`.

## Migrations

### Database settings

The migration commands read the database settings from the `.env` file and the real environment. A real environment variable wins.

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

- `DB_CONNECTION` defaults to `postgres`. The default port is `5432` for postgres and `3306` for mysql.
- `DB_DATABASE` works too, in place of `DB_NAME`.
- `DATABASE_URL` wins over all the `DB_*` keys when it is set.
- Put comments on their own line. A `#` after a value becomes part of the value.

All keys are in the [Env reference](../reference/env.md#read-by-the-framework).

### Run and undo migrations

```bash
dox migration:run                # or: dox migrate
dox migration:status
dox migration:rollback           # undo the last batch
dox migration:rollback --step=2  # undo the last 2 migrations
dox migration:reset              # undo all migrations
dox migration:refresh            # undo all migrations, then run them again
dox migration:fresh              # drop all tables, then run all migrations
```

`migrate:rollback`, `migrate:reset`, `migrate:refresh`, `migrate:fresh` and `migrate:status` also work.
Add `--seed` to `migration:run`, `migration:refresh` or `migration:fresh` to run the seeders after it.

- A failed migration stops the run, and the CLI exits with code 1.
- On MySQL, statements like `CREATE`, `ALTER` and `DROP` save right away. So when a migration fails half way, these changes are not undone.

## Update the CLI

`dox update` installs the newest version with the same major version as your CLI.
To pick the version yourself, run the install command again.
