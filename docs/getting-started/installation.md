---
icon: lucide/download
---

# Installation

This page shows how to install the Dox CLI, make a new project and start the server.

Dox needs **Dart 3.13** or newer.

## Install the CLI

```bash
dart pub global activate dox
```

Check that it works:

```bash
dox version
```

!!! warning "`dox: command not found`"
    The shell can not find the CLI when the pub `bin` folder is not in your `PATH`.
    Add this line to `~/.bashrc` or `~/.zshrc`, then open a new terminal:

    ```bash
    export PATH="$PATH":"$HOME/.pub-cache/bin"
    ```

## Create a new project

```bash
dox create new_blog
```

`dox create` downloads the newest release of
[dox-sample](https://github.com/dartondox/dox-sample), the starter project.
To get one exact release, add `--version` with a release tag of dox-sample.

It also makes your `.env` file from `.env.example`, with a new random `APP_KEY`.
Then get the packages:

```bash
cd new_blog
dart pub get
```

The starter project uses SQLite, so there is no database to install.
The file `db/dox.sqlite` is created at the first start.
To use Postgres or MySQL instead, change `DB_CONNECTION` and the `DB_*`
values in `.env`. See [Database](../database/index.md).

!!! info "Add Dox to an existing Dart project"
    Add the packages you need with `dart pub add`:

    ```bash
    dart pub add dox_core dox_orm dox_migration
    dart pub add dev:dox_builder dev:build_runner
    ```

## Start the server

```bash
dox s
```

`dox s` does two things:

- It runs `dart run build_runner watch`, so generated files stay up to date.
- It runs `dart run bin/server.dart`, and restarts it when a `.dart` file changes.

To skip the builder, use `dox s --ignore-build-runner`.
To start the server without the CLI, run `dart run bin/server.dart`.

At each start it also runs the new migrations in `db/migration`.
The server uses the port in `APP_PORT` in the `.env` file (`3000` by default).
Check it:

```bash
curl localhost:3000/ping
```

```text
pong
```

## Start the server with Docker

```bash
docker compose up -d --build
```

This starts the app and a Postgres database.
The app reads `.env`, so set `DB_CONNECTION=postgres` and `DB_NAME=postgres` there first.
To start only the database and run the app with `dox s`, use `docker compose up -d postgres`.

!!! tip "Production"
    Do not use `dox s` or `dart run` in production.
    Build a native binary with `dox build`. See [Deployment](../digging-deeper/deployment.md).

## Run the code generator

Dox makes code for models and DTOs with `build_runner`.
`dox s` already runs it. To run it alone:

```bash
dox build_runner:watch   # runs again on every file change
dox build_runner:build   # runs once
```

## Packages

| Package | What it does |
| --- | --- |
| `dox` | the CLI |
| `dox_core` | HTTP server, routing, requests, responses, validation |
| `dox_orm` | query builder and models |
| `dox_migration` | database migrations |
| `dox_auth` | JWT authentication |
| `dox_builder`, `dox_annotation` | code generation for models, DTOs and the container |
| `dox_validation` | [typed validation schemas](../packages/validation.md) |
| `dox_openapi` | [OpenAPI docs](../packages/openapi.md) |
| `dox_storage` | [file storage: local, S3](../packages/storage.md) |
| `dox_cache` | [cache: memory, file, Redis](../packages/cache.md) |
| `dox_socketio` | [Socket.IO server](../packages/socketio.md) |
| `dox_queue` | [background jobs](../digging-deeper/queue.md) |
| `dox_scheduler` | [scheduled tasks](../digging-deeper/scheduler.md) |
| `dox_mailer` | [send email](../digging-deeper/mail.md) |
| `dox_view` | [HTML views](../the-basic/views.md) |
| `dox_inertia` | [Inertia.js pages](../the-basic/inertia.md) |
| `dox_http_native` | [native HTTP server](../digging-deeper/native-server.md) (Rust) |
| `dox_postgres_native`, `dox_mysql_native` | native drivers for [Postgres](../database/postgres-native.md) and [MySQL/MariaDB](../database/mysql-native.md) |
