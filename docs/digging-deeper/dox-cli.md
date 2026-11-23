---
icon: lucide/square-terminal
---

# Dox CLI

The `dox` CLI creates projects and files, runs the dev server, builds for production and runs migrations.

Run `dox help` to see all commands, or `dox help <command>` for one command. The [CLI reference](../reference/cli.md) has every command and option.

## Setup

Install the CLI with `dart pub`:

```bash
dart pub global activate dox
```

If your shell can not find `dox`, add the pub bin folder to your `PATH` in `~/.bashrc` or `~/.zshrc`:

```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

### Updating the CLI

`dox update` installs the newest version with the same major version as your CLI:

```bash
dox update
```

To remove the CLI, run `dart pub global deactivate dox`.

## Creating a project

`dox create` copies the [dox-sample](https://github.com/dartondox/dox-sample) template and makes `.env` with a new `APP_KEY`:

```bash
dox create new_blog
cd new_blog
dart pub get
dox serve
```

To pick a template release, pass `--version <release tag>`.

## Running the dev server

`dox serve` (or `dox s`) starts your app and runs `build_runner watch`:

```bash
dox serve
```

A change in `lib/app/` hot reloads into the running server. A change in routes, providers, config, `bin/`, `db/` or generated files restarts the server. Hot reload keeps the old value of a changed static or global value until a restart.

The server prints the VM service link. Open it in a browser to get DevTools, the debugger and the profiler.

Turn off hot reload or `build_runner watch` with these options:

```bash
dox s --no-reload             # restart on every change
dox s --ignore-build-runner   # do not run build_runner watch
```

See [`dox serve`](../reference/cli.md#dox-serve).

## Building for production

`dox build` builds a native (AOT) bundle into `build/bundle`. Run the server from there:

```bash
dox build
cd build/bundle
./bin/server
```

See [Deployment](deployment.md#build).

## Creating files

The `make:*` commands write new files with the right names and folders. So `BlogPost` makes `blog_post.controller.dart` with the class `BlogPostController`.

After `make:controller` or `make:dto`, run `dox build_runner:build`, or keep `dox serve` running.

### Controllers

`make:controller` writes a controller in `lib/app/http/controllers`. Add `-r` for all resource methods, `--api` for the resource methods with no `create` and `edit`, and `--model` to use a model:

```bash
dox make:controller Blog
dox make:controller Blog -r
dox make:controller Blog --api
dox make:controller Blog --model=Post
```

### Models

`make:model` writes a model. The options also make the files that belong to it:

```bash
dox make:model Blog -m      # model and a create_blogs_table migration
dox make:model Blog -mcr    # model, migration, resource controller
dox make:model Blog -a      # all of the files
```

The options are `-m` migration, `-c` controller, `-r` resource controller, `--api` API controller, `-f` factory, `-s` seeder and `-a` all. You can join them, like `-mfs`. The table is the name in plural snake case, so `BlogPost` gets `blog_posts`.

### Migrations

`make:migration` writes a Dart migration. Add `--sql` for a `.sql` file:

```bash
dox make:migration create_blogs_table
dox make:migration create_blogs_table --sql
```

### Mail and views

`make:mail` writes a mailable in `lib/app/mail` and its view. Add `--no-view` for a plain text body. `make:view` writes a `.dox.html` view:

```bash
dox make:mail Welcome
dox make:mail Invoice --no-view
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
dox make:middleware Auth     # lib/app/http/middleware/auth.middleware.dart
dox make:dto CreateBlog      # lib/app/dtos/create_blog/create_blog.dto.dart
dox make:serializer Blog     # lib/app/serializers/blog.serializer.dart
dox make:provider Cache      # lib/providers/cache_provider.dart
dox make:command send_report # run it with dox app:send-report
```

## Listing routes

`dox route:list` prints every route of the app. Add `--json` for JSON output:

```bash
dox route:list
```

See [`dox route:list`](../reference/cli.md#dox-routelist).

## Running migrations

The migration commands read the database settings from `.env` and the real environment. A real environment variable wins:

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

`DB_CONNECTION` is `sqlite` by default. A `DATABASE_URL` wins over all the `DB_*` keys. See the [Env reference](../reference/env.md#read-by-the-framework).

Run new migrations with `migration:run` (or `migrate`). `migration:status` shows which ones ran:

```bash
dox migration:run
dox migration:status
```

A failed migration stops the run with exit code 1. On MySQL, a `CREATE`, `ALTER` or `DROP` statement saves at once, so a migration that fails half way keeps these changes.

### Rolling back migrations

`migration:rollback` undoes the last batch. `--step` undoes the last N migrations, and `--batch` undoes one batch:

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

Add `--seed` to `migration:run`, `migration:refresh` or `migration:fresh` to also run the seeders. The `migrate:*` names also work, like `migrate:fresh`.

## Next steps

- [CLI reference](../reference/cli.md): every command and option.
- [Add a package](../getting-started/add-a-package.md): `dox add`.
- [Package commands](package-commands.md): commands that come from a package.
