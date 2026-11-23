---
icon: lucide/download
---

# Installation

This page shows how to install the Dox CLI, make a new project and start the server.

Dox needs **Dart 3.13** or newer.

## Install the CLI

The `dox` CLI makes projects, runs the server and makes files for you. Install it with pub:

```bash
dart pub global activate dox
```

Check that it works:

```bash
dox version
```

!!! warning "`dox: command not found`"
    The shell can not find the CLI, because the pub `bin` folder is not in your `PATH`.
    Add this line to `~/.bashrc` or `~/.zshrc`, then open a new terminal:

    ```bash
    export PATH="$PATH":"$HOME/.pub-cache/bin"
    ```

## Create a new project

Use `dox create` with the name of your app:

```bash
dox create new_blog
```

It downloads the newest release of [dox-sample](https://github.com/dartondox/dox-sample), the starter project. To get one exact release, add `--version` with a release tag of dox-sample.

It also makes your `.env` file from `.env.example`, with a new random `APP_KEY`. Then get the packages:

```bash
cd new_blog
dart pub get
```

The starter project uses SQLite, so there is no database to install. The file `db/dox.sqlite` is created at the first start. To use Postgres or MySQL instead, change `DB_CONNECTION` and the `DB_*` values in `.env`. See [Database](../database/index.md).

!!! info "Add Dox to an existing Dart project"
    If you already have a Dart project, add the packages you need with `dart pub add`:

    ```bash
    dart pub add dox_core dox_orm dox_migration
    dart pub add dev:dox_builder dev:build_runner
    ```

## Start the server

Start the server in dev mode:

```bash
dox s
```

`dox s` does two things:

- It runs `dart run bin/server.dart`. When you change a file in `lib/app/`, it hot reloads the new code, so no restart is needed. For routes, providers, config and other start-up code, it restarts the server.
- It runs `dart run build_runner watch`, so generated files stay up to date.

At each start it also runs the new migrations in `db/migration`. The server uses the port in `APP_PORT` in the `.env` file (`3000` by default). Check that it works:

```bash
curl localhost:3000/ping
```

```text
pong
```

These options change `dox s`:

- `dox s --ignore-build-runner` skips the builder.
- `dox s --no-reload` turns hot reload off.

To start the server without the CLI, run `dart run bin/server.dart`.

## Start the server with Docker

The starter project has a Docker setup. This starts the app, a queue worker and a Postgres database:

```bash
docker compose up -d --build
```

The app and the worker always use the Postgres service. They set `DB_CONNECTION` and `DB_NAME` themselves. The database port is open on this machine only (`127.0.0.1`), not on the network.

If you want only the database in Docker, and the app with `dox s`, run `docker compose up -d postgres`. Then set `DB_CONNECTION=postgres` and `DB_NAME=dox` in `.env`.

!!! tip "Production"
    Do not use `dox s` or `dart run` in production.
    Build a native binary with `dox build`. See [Deployment](../digging-deeper/deployment.md).

## Run the code generator

Dox makes code for models and DTOs with `build_runner`. `dox s` already runs it. To run it alone:

```bash
dox build_runner:watch   # runs again on every file change
dox build_runner:build   # runs once
```

## AI agents

If you use an AI coding agent, give it the real API of each package. Run `dart run skills@ get` in your app after `dart pub get`. See [AI agents](ai-agents.md) for the skills, `AGENTS.md` and the llms files.

## Packages

Dox is split into packages, so you add only what you need:

| Package | What it does |
| --- | --- |
| `dox` | the CLI |
| `dox_core` | HTTP server, routing, requests, responses, validation |
| `dox_orm` | query builder and models |
| `dox_migration` | database migrations |
| `dox_auth` | Login with access tokens, JWT or sessions |
| `dox_builder`, `dox_annotation` | code generation for models, DTOs and the container |
| `dox_validation` | [typed validation schemas](../packages/validation.md) |
| `dox_openapi` | [OpenAPI docs](../packages/openapi.md) |
| `dox_storage` | [file storage: local, S3](../digging-deeper/file-storage.md) |
| `dox_cache` | [cache: memory, file, Redis](../digging-deeper/cache.md) |
| `dox_cache_database` | [cache in a database table](../digging-deeper/cache.md#database-store) |
| `dox_socketio` | [Socket.IO server](../packages/socketio.md) |
| `dox_queue` | [background jobs](../digging-deeper/queue.md) |
| `dox_queue_database` | [queue in a database table](../digging-deeper/queue.md#database-driver) |
| `dox_scheduler` | [scheduled tasks](../digging-deeper/scheduler.md) |
| `dox_mailer` | [send email](../digging-deeper/mail.md) |
| `dox_view` | [HTML views](../the-basic/views.md) |
| `dox_inertia` | [Inertia.js pages](../the-basic/inertia.md) |
| `dox_http_native` | [native HTTP server](../digging-deeper/native-server.md) (Rust) |
| `dox_postgres_native`, `dox_mysql_native` | native drivers for [Postgres](../database/postgres-native.md) and [MySQL/MariaDB](../database/mysql-native.md) |
