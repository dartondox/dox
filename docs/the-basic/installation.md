# Installation

This page shows how to install the Dox CLI, make a new project and start the server.

!!! warning "3.x is alpha"
    The latest version is `3.0.0-alpha.4`. It needs **Dart 3.13** or newer.

## Install the CLI

```bash
dart pub global activate dox 3.0.0-alpha.4
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

`dox create` downloads the latest release of [dox-sample](https://github.com/dartondox/dox-sample).
To get one exact version, add `--version`:

```bash
dox create new_blog --version v2.0.1
```

!!! info "Use 3.x in an existing project"
    Set every Dox package in `pubspec.yaml` to `^3.0.0-alpha.4`.
    Use `dox_orm` for the database. `dox_query_builder` only re-exports `dox_orm` now.

```yaml title="pubspec.yaml"
dependencies:
  dox_core: ^3.0.0-alpha.4
  dox_orm: ^3.0.0-alpha.4
  dox_migration: ^3.0.0-alpha.4

dev_dependencies:
  dox_builder: ^3.0.0-alpha.4
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

The server uses the port in `APP_PORT` in the `.env` file.

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

=== "Watch"

    ```bash
    dox build_runner:watch
    ```

=== "Build once"

    ```bash
    dox build_runner:build
    ```

## Packages

All Dox packages use the same version.

| Package | What it does |
| --- | --- |
| `dox` | the CLI |
| `dox_core` | HTTP server, routing, requests, responses, validation |
| `dox_orm` | query builder and models (was `dox_query_builder`) |
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
