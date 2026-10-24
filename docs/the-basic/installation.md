# Installation

This page shows how to install the Dox CLI, make a new project and start the server.

!!! warning "3.x is alpha"
    Dox 3 is in alpha (`3.0.0-alpha.x`). It needs **Dart 3.13** or newer.

## Install the CLI

```bash
dart pub global activate dox ^3.0.0-alpha
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

`dox create` downloads the newest 3.x release of
[dox-sample](https://github.com/dartondox/dox-sample), the starter project.
To get one exact version, add `--version`, for example `dox create new_blog --version 3.0.0-alpha.5`.

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
    Add the packages you need to `pubspec.yaml`. All Dox packages share one
    version, so use `^3.0.0-alpha` for each of them. It picks the newest alpha.

```yaml title="pubspec.yaml"
dependencies:
  dox_core: ^3.0.0-alpha
  dox_orm: ^3.0.0-alpha
  dox_migration: ^3.0.0-alpha

dev_dependencies:
  dox_builder: ^3.0.0-alpha
  build_runner: ^2.17.1
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

At the first start it also runs the migrations in `db/migration`.
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
docker-compose up -d --build
```

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

All Dox packages use the same version.

| Package | What it does |
| --- | --- |
| `dox` | the CLI |
| `dox_core` | HTTP server, routing, requests, responses, validation |
| `dox_orm` | query builder and models |
| `dox_migration` | database migrations |
| `dox_auth` | JWT authentication |
| `dox_websocket` | WebSocket server |
| `dox_builder`, `dox_annotation` | code generation for models and DTOs |
| `dox_validation` | [typed validation schemas](../packages/validation.md) |
| `dox_openapi` | [OpenAPI docs](../packages/openapi.md) |
| `dox_storage` | [file storage: local, S3](../packages/storage.md) |
| `dox_cache` | [cache: memory, file, Redis](../packages/cache.md) |
| `dox_socketio` | [Socket.IO server](../packages/socketio.md) |
| `dox_http_native` | [native HTTP server](../digging-deeper/native-server.md) (Rust) |
| `dox_postgres_native`, `dox_mysql_native` | native database drivers for Postgres and MySQL/MariaDB |
