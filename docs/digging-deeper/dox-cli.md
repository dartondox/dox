# Dox CLI

The `dox` CLI creates projects and files, runs the dev server, builds for production and runs migrations.

Run `dox help` to see all commands. Run `dox help <command>` for one command.

## Installation

```bash
dart pub global activate dox 3.0.0-alpha.4
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
| `dox create:controller <name> [-r] [-ws]` | create a controller |
| `dox create:middleware <name>` | create a middleware |
| `dox create:dto <name>` | create a DTO (typed, checked input) |
| `dox create:serializer <name>` | create a serializer |
| `dox create:model <name> [-m]` (or `make:model`) | create a model, and with `-m` its migration |
| `dox make:migration <name> [--sql]` (or `create:migration`) | create a Dart migration, or a `.sql` one with `--sql` |
| `dox migration:run` (or `dox migrate`) | run new migrations |
| `dox migration:rollback [--step=N]` | undo the last batch, or the last N migrations |
| `dox migration:reset` | undo all migrations |
| `dox migration:refresh` | undo all, then run all again |
| `dox migration:status` | show which migrations ran, and their batch |
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
dox create new_blog --version v3.0.0-alpha.4
```

`dox create` copies the [dox-sample](https://github.com/dartondox/dox-sample) template from GitHub. Without `--version`, it uses the latest release of the template.

### Run the dev server

```bash
dox serve                         # or: dox s
dox s --ignore-build-runner       # do not run build_runner watch
```

`dox serve` runs `dart run bin/server.dart`. When a `.dart` file changes, it restarts the server.
It also runs `build_runner watch`, so generated files stay up to date.

### Run the code generator

```bash
dox build_runner:watch   # watch files and build again on each change
dox build_runner:build   # build once
```

### Build for production

```bash
dox build
cd build/bundle
./bin/server
```

`dox build` does these steps:

1. It runs `build_runner` (when your app uses it).
2. It runs `dart build cli --target bin/server.dart --output build`.
3. It copies `db/` and `.env.example` into `build/bundle`.

When a step fails, it stops with exit code 1, so CI can stop too. See [Deployment](deployment.md).

### Make an app key

```bash
dox key:generate
```

It writes a new `APP_KEY` to your `.env` file.

## Create files

### Controller

```bash
dox create:controller Blog       # default controller
dox create:controller Blog -r    # resource controller
dox create:controller Chat -ws   # WebSocket controller
```

- A default or resource controller goes to `lib/app/http/controllers/`.
- A WebSocket controller goes to `lib/app/ws/controllers/`. See [WebSocket](websocket.md).
- `-r` adds the methods `index`, `create`, `store`, `show`, `edit`, `update` and `destroy`.

!!! info "File and class names"
    Word breaks are kept. `dox create:controller BlogPost` makes `blog_post.controller.dart`
    with the class `BlogPostController`. The same is true for middleware, DTOs and serializers.

### Middleware

```bash
dox create:middleware Auth
```

### DTO

```bash
dox create:dto CreateBlog
```

It makes `lib/app/http/dtos/create_blog.dto.dart`. Then run `dox build_runner:build`.
See [Validation](../the-basic/validation.md).

### Serializer

```bash
dox create:serializer Blog
```

### Model

```bash
dox create:model Blog
dox create:model Blog -m   # also makes the create_blogs_table migration
```

- `-m` (or `--migration`) makes a Dart migration `create_<table>_table`.
- The table name is the model name in plural snake case: `BlogPost` makes `blog_posts`.
- The model gets `@DoxModel(table: 'blog_posts')`, so it uses the same table.
- `make:model` is the same command.

### Migration

```bash
dox make:migration create_blogs_table          # .dart file (default)
dox make:migration create_blogs_table --sql    # .sql file
```

## Migrations

### Database settings

The migration commands read the database settings from the `.env` file:

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

- `DB_CONNECTION` is `postgres`, `mysql` or `sqlite`. The default is `postgres`.
- The default port is `5432` for postgres and `3306` for mysql.
- `DB_DATABASE` works too, in place of `DB_NAME`.
- Put comments on their own line. A `#` after a value becomes part of the value.

!!! warning "`.env` or environment, not both"
    When a `.env` file exists, these commands read only the `.env` file.
    They use the real environment variables only when there is no `.env` file.
    This is different from `Env.get()`, where a real environment variable wins.

### Run migrations

```bash
dox migration:run    # or: dox migrate
dox migration:status
```

### Undo migrations

```bash
dox migration:rollback           # undo the last batch
dox migration:rollback --step=2  # undo the last 2 migrations
dox migration:reset              # undo all migrations
dox migration:refresh            # undo all migrations, then run them again
```

`migrate:rollback`, `migrate:reset`, `migrate:refresh` and `migrate:status` also work.

- A failed migration stops the run, and the CLI exits with code 1.
- On MySQL, statements like `CREATE`, `ALTER` and `DROP` save right away. So when a migration fails half way, these changes are not undone.

## Update the CLI

`dox update` runs `dart pub global activate dox`. This installs the latest **stable** version, not a preview.
To stay on a preview version, run the install command with the version again:

```bash
dart pub global activate dox 3.0.0-alpha.4
```
