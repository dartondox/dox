# Dox CLI

The `dox` CLI creates projects and files, runs the server, builds for production and runs migrations.

Run `dox help` to see all commands. Run `dox help <command>` for one command.

## Installation

```py
dart pub global activate dox 3.0.0-alpha.1
```

!!! warning "Export bin path"
    Please make sure you have included `bin` path to your profile. If you did not added path to your profile yet, open `~/.bashrc` or `~/.zshrc` and paste below line.

    ```bash
    export PATH="$PATH":"~/.pub-cache/bin"
    ```

!!! tips
    You can also use `bin/dox {command}` from your project folder to run server or create migration etc..

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
| `dox migration:rollback [--step=N]` | undo the last batch |
| `dox migration:reset` | undo all migrations |
| `dox migration:refresh` | undo all, then run all again |
| `dox migration:status` | show which migrations ran |
| `dox key:generate` | make a new `APP_KEY` |
| `dox openapi:generate [dir]` | write `openapi.json` and `openapi.yaml` (default `storage/openapi`), see [OpenAPI](../packages/openapi.md#write-the-files-dox-openapigenerate) |
| `dox update` | update the CLI |
| `dox version` (or `dox -v`) | show the CLI version |
| `dox help [command]` | show help |

## Create new project

```py
dox create new_blog
dox create new_blog --version v2.0.1
```

## Serve project

Run the http server for development.

```py
dox serve
or
dox s

dox s --ignore-build-runner // do not run build_runner watch
```

## Run build runner

```py
dox build_runner:watch
dox build_runner:build
```

## Build project for production

```py
dox build      // runs build_runner, then dart build cli
cd build/bundle
./bin/server   // start the server
```

`dox build` exits with code 1 when a step fails, so CI can stop. See [Deployment](deployment.md).

## Generate app key

```py
dox key:generate
```

## Create controller

=== "Default"

    ```py
    dox create:controller admin_controller
    ```

=== "Resource controller"

    ```py
    dox create:controller admin_controller -r
    ```

=== "Websocket controller"

    ```py
    dox create:controller admin_controller -ws
    ```

!!! info "File and class names"
    Word breaks are kept. `dox create:controller BlogPost` makes `blog_post.controller.dart`
    with the class `BlogPostController`. The same is true for middleware, DTOs and serializers.

## Create middleware

```py
dox create:middleware auth_middleware
```

## Create DTO

```py
dox create:dto CreateBlog
```

It makes `lib/app/http/dtos/create_blog.dto.dart`. Then run `dox build_runner:build`.
See [Validation](../the-basic/validation.md).

## Create serializer

```py
dox create:serializer Blog
```

## Create model

```py
dox create:model Blog
dox create:model Blog -m   // also makes the create_blogs_table migration
```

`-m` (or `--migration`) makes a Dart migration `create_<table>_table`.
The table name is the model name in plural snake case: `BlogPost` makes `blog_posts`.
The model gets `@DoxModel(table: 'blog_posts')`, so it uses the same table.
`make:model` is the same command.

## Create migration

```py
dox make:migration create_blogs_table          // .dart file (default)
dox make:migration create_blogs_table --sql    // .sql file
```

## Run migration

```py
dox migration:run
or
dox migrate
```

!!! info
    To run migration, make sure that you have create `.env` file with with below variable names.

```py
DB_CONNECTION=postgres # postgres, mysql or sqlite
DB_HOST=localhost
DB_PORT=5432
DB_NAME=postgres       # for sqlite: the file path
DB_USERNAME=admin
DB_PASSWORD=password
```

!!! info
    `DB_CONNECTION` can be `postgres`, `mysql` or `sqlite`. The default is `postgres`.
    The default port is `5432` for postgres and `3306` for mysql.
    On MySQL, statements like `CREATE`, `ALTER` and `DROP` save right away.
    So if a migration fails half way, these changes are not undone.

## Rollback migration

```py
dox migration:rollback          // undo the last batch
dox migration:rollback --step=2 // undo the last 2 migrations
dox migration:reset             // undo all migrations
dox migration:refresh           // undo all migrations, then run them again
```

!!! info
    `migrate:rollback`, `migrate:reset` and `migrate:refresh` also work.
    A failed migration stops the run, and the CLI exits with code 1.

## Deactivate CLI

```py
dart pub global deactivate dox
```
