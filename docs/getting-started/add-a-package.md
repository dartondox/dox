---
icon: material/package-variant-plus
---

# Add a package

`dox add` adds a Dox package to your app and sets it up.

Many packages need config files and `.env` keys. `dox add` writes them for you, so you do not set up each package by hand:

```bash
dox add orm
```

## What it does

`dox add orm` does three steps:

1. Runs `dart pub add dox_orm`. `orm` is short for `dox_orm`. The full name works too.
2. Runs `dart pub get`.
3. Runs the setup command of the package, `dox orm:install`.

The setup command writes the config files, adds the keys to `.env` and `.env.example`, and runs `build_runner` when the package needs it. At the end it prints what it did and the next steps.

A package with no setup command is only added, and `dox add` says so.

## Options

Words after the name go to the setup command, for example to pick a driver:

```bash
dox add orm --driver=postgres
```

`--dev` adds the package as a dev dependency.

## Safe to run twice

The setup command never overwrites a file and never changes a `.env` key that is already there. So you can run `dox add` again, and it only adds what is missing.

## Packages with a setup command

These packages have a setup command:

| Command | What it sets up |
| --- | --- |
| `dox add orm [--driver=sqlite\|postgres\|mysql]` | The ORM and migrations. See [Database](../database/index.md). |
| `dox add queue [--driver=database\|redis\|sync]` | Queued jobs and `bin/queue.dart`. `database` is the default and needs `dox add orm` first. See [Queue](../digging-deeper/queue.md). |
| `dox add scheduler` | Scheduled tasks and `bin/schedule.dart`. See [Scheduler](../digging-deeper/scheduler.md). |
| `dox add mailer [--transport=log\|smtp\|resend\|mailgun\|postmark\|ses]` | Mail. `log` is the default. See [Mail](../digging-deeper/mail.md). |
| `dox add cache [--store=file\|redis\|memory\|database]` | Cache stores. `database` needs `dox add orm` first. See [Cache](../digging-deeper/cache.md). |
| `dox add auth` | Access token auth. Needs `dox add orm` and a `User` model first. See [Authentication](../security/authentication.md). |
| `dox add storage [--disk=local\|s3]` | File storage. See [File storage](../digging-deeper/file-storage.md). |
| `dox add socketio [--broadcasting]` | Socket.IO, and broadcasting with the flag. See [Socket.IO](../packages/socketio.md). |
| `dox add view` | Views and `resources/views/`. See [Views](../the-basic/views.md). |
| `dox add inertia` | The server side of Inertia. It prints the Vite steps. See [Inertia](../the-basic/inertia.md). |
| `dox add mcp` | An MCP server with a sample tool. See [MCP](../packages/mcp.md). |
| `dox add grpc` | gRPC: a sample `.proto` file, a router with the health service and `APP_HTTP2` in `.env`. See [gRPC](../digging-deeper/grpc.md). |

The first `dox add orm` can download (or build) the Postgres and MySQL drivers once, also the one you do not use. After that, `pubspec.yaml` skips the unused drivers, so later builds do not get them.

To add a setup command to your own package, see [Package commands](../digging-deeper/package-commands.md#ship-an-install-command).
