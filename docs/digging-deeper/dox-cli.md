# Dox CLI

The `dox` CLI creates projects and files, runs the dev server, builds for production and runs migrations.

Every `make:*` command also answers to its `create:*` name.
Run `dox help` to see all commands. Run `dox help <command>` for one command.

## Installation

```bash
dart pub global activate dox ^3.0.0-alpha
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
| `dox make:controller <name> [-r]` | create a controller |
| `dox make:middleware <name>` | create a middleware |
| `dox make:dto <name>` | create a DTO (typed, checked input) |
| `dox make:serializer <name>` | create a serializer |
| `dox make:model <name> [-m]` (old name `create:model`) | create a model, and with `-m` its migration |
| `dox make:migration <name> [--sql]` (old name `create:migration`) | create a Dart migration, or a `.sql` one with `--sql` |
| `dox migration:run` (or `dox migrate`) | run new migrations |
| `dox migration:rollback [--step=N]` | undo the last batch, or the last N migrations |
| `dox migration:reset` | undo all migrations |
| `dox migration:refresh` | undo all, then run all again |
| `dox migration:fresh` (or `migrate:fresh`) | drop all tables, then run all migrations |
| `dox migration:status` | show which migrations ran, and their batch |
| `dox make:factory <model>` | create a model factory in `db/factories`, see [Factories](../database/factories.md) |
| `dox make:seeder <name>` | create a seeder in `db/seeders`, see [Seeders](../database/seeders.md) |
| `dox db:seed [--class=<name>]` | run `DatabaseSeeder`, or another seeder |
| `dox make:job <name>` | create a queue job in `lib/app/jobs` (and `bin/queue.dart`) |
| `dox queue:work [--queue=a,b] [--concurrency=N] [--once] [--tries=N] [--timeout=S] [--sleep=S] [--stop-when-empty]` | run the queue worker |
| `dox queue:failed` | list the failed jobs |
| `dox queue:retry <id\|all>` | put a failed job (or all) back on the queue |
| `dox queue:forget <id>` | delete one failed job |
| `dox queue:flush` | delete all failed jobs |
| `dox schedule:work` | run the scheduler and keep it running |
| `dox schedule:run` | run the tasks that are due now, once |
| `dox schedule:list` | list the scheduled tasks |
| `dox schedule:test <name>` | run one scheduled task now |
| `dox key:generate` | make a new `APP_KEY` |
| `dox env:generate` | make `lib/config/env.dart` (the typed env class) from `.env.example`, see [Environment Variables](env.md) |
| `dox env:check` | check the env against `lib/config/env.dart`. Prints every missing or bad key (exit code 1) |
| `dox openapi:generate [dir]` | write `openapi.json` and `openapi.yaml` (default `storage/openapi`), see [OpenAPI](../packages/openapi.md#write-the-files-dox-openapigenerate) |
| `dox update` | update the CLI |
| `dox version` (or `dox -v`) | show the CLI version |
| `dox help [command]` | show help |

## Project

### Create a project

```bash
dox create new_blog
dox create new_blog --version v3.0.0-alpha.5
```

`dox create` copies the [dox-sample](https://github.com/dartondox/dox-sample) template from GitHub. Without `--version`, it uses the newest template release with the same major version as the CLI.

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
dox make:middleware Auth
dox make:dto CreateBlog         # lib/app/http/dtos/create_blog.dto.dart
dox make:serializer Blog
dox make:model Blog -m          # model and its create_blogs_table migration
dox make:migration create_blogs_table          # .dart file (default)
dox make:migration create_blogs_table --sql    # .sql file
```

- `-r` adds the methods `index`, `create`, `store`, `show`, `edit`, `update` and `destroy`.
- Word breaks are kept. `BlogPost` makes `blog_post.controller.dart` with the class `BlogPostController`.
- After `make:dto`, run `dox build_runner:build`. See [Validation](../the-basic/validation.md).
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

`dox update` installs the newest version with the same major version as your CLI, previews included.
To pick the version yourself, run the install command again.
