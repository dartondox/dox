---
icon: lucide/download
---

# Installation

This page shows how to install the Dox CLI, make a new project and start the server.

Dox needs Dart 3.13 or newer.

## Install the CLI

The `dox` CLI makes projects, runs the server and makes files. Install it with pub:

```bash
dart pub global activate dox
```

Check that it works:

```bash
dox version
```

If the shell shows "dox: command not found", the pub bin folder is not in your path. Add this line to `~/.bashrc` or `~/.zshrc`, then open a new terminal:

```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

## Create a new project

Give `dox create` the name of your app, then get the packages:

```bash
dox create new_blog
cd new_blog
dart pub get
```

It downloads the newest release of the starter project, [dox-sample](https://github.com/dartondox/dox-sample). Add `--version` with a release tag to get one release. It also makes your `.env` file with a new random app key.

The starter project uses SQLite, so you do not install a database. To use Postgres or MySQL, change `DB_CONNECTION` and the other database keys in `.env`. See [Database](../database/index.md).

## Add Dox to a Dart project

In a Dart project that you have, add the packages with `dart pub add`:

```bash
dart pub add dox_core dox_orm dox_migration
dart pub add dev:dox_builder dev:build_runner
```

## Start the server

Start the server in dev mode:

```bash
dox s
```

It runs `bin/server.dart` and `build_runner watch`. It hot reloads a change in `lib/app/`, and it restarts the server for a change to routes, providers or config. At each start the server runs the new migrations, on the port in `APP_PORT` (default 3000):

```bash
curl localhost:3000/ping
```

```text
pong
```

Add `--ignore-build-runner` to skip the builder, or `--no-reload` to stop hot reload. To start the server with no CLI, run `dart run bin/server.dart`.

For production, build a native binary with `dox build`. See [Deployment](../digging-deeper/deployment.md).

## Start the server with Docker

The starter project has a Docker setup. This starts the app, a queue worker and a Postgres database:

```bash
docker compose up -d --build
```

The app and the worker always use the Postgres service. The database port is open on this machine only.

To run only the database in Docker and the app with `dox s`, run `docker compose up -d postgres`. Then set `DB_CONNECTION=postgres` and `DB_NAME=dox` in `.env`.

## Run the code generator

Dox makes code for models and DTOs with build_runner. `dox s` runs it. To run it alone:

```bash
dox build_runner:watch   # runs again on each file change
dox build_runner:build   # runs one time
```

## AI agents

To give an AI coding agent the real API of each package, run `dart run skills@ get` after `dart pub get`. See [AI agents](ai-agents.md).

## Packages

Dox has many packages, so you add only what you need:

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
| `dox_storage` | [file storage: local, S3, Azure](../digging-deeper/file-storage.md) |
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

## Next steps

- [Build a blog API](../tutorial/index.md): a full app, step by step.
- [Add a package](add-a-package.md): add a feature with one command.
- [CLI](../reference/cli.md): all commands of the CLI.
