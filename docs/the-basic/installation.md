# Installation

!!! warning "3.x is alpha"
    The latest version is `3.0.0-alpha.1`. It needs **Dart 3.6** or newer.
    Coming from 2.x? Read the [upgrade guide](upgrade.md).

## Install the CLI

```py
dart pub global activate dox 3.0.0-alpha.1
```

!!! warning "Export bin path"
    Please make sure you have included `bin` path to your profile. If you did not added path to your profile yet, open `~/.bashrc` or `~/.zshrc` and paste below line.

    ```bash
    export PATH="$PATH":"~/.pub-cache/bin"
    ```

## Create a new project

```py
dox create new_blog
```

`dox create` downloads the latest release of [dox-sample](https://github.com/dartondox/dox-sample).
To get one version, add `--version`:

```py
dox create new_blog --version v2.0.1
```

!!! info "Use 3.x in a project"
    Set every Dox package in `pubspec.yaml` to `^3.0.0-alpha.1`, and `dox_query_builder` to `dox_orm`.
    The [upgrade guide](upgrade.md#do-these-first) shows the full `pubspec.yaml`.

## Packages

All Dox packages share one version.

| Package | What it does |
| --- | --- |
| `dox_core` | HTTP server, routing, requests, responses, validation |
| `dox_orm` | query builder and models (was `dox_query_builder`) |
| `dox_migration` | database migrations |
| `dox_auth` | JWT authentication |
| `dox_websocket` | WebSocket server |
| `dox_builder`, `dox_annotation` | code generation for models |
| `dox_validation` | [typed validation schemas](../packages/validation.md) |
| `dox_openapi` | [OpenAPI docs](../packages/openapi.md) |
| `dox_storage` | [file storage: local, S3](../packages/storage.md) |
| `dox_cache` | [cache: memory, file, Redis](../packages/cache.md) |
| `dox_socketio` | [Socket.IO server](../packages/socketio.md) |

## Start server

```py
dox s

or

bin/dox s
```

## Start server with docker

```py
docker-compose up -d --build
```

!!! tips
    Set `APP_ENV=development` in `.env` for hot reload while you work.
    For production, build a native binary with `dox build`. See [Deployment](../digging-deeper/deployment.md).

## Watch the builder

```py
dart run build_runner watch

or

dox build_runner:watch
```
