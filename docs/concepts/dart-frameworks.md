---
icon: lucide/scale
---

# Dox and the other Dart backends

This page compares Dox with five other ways to build a backend in Dart: Dart Frog, Serverpod, Shelf (with shelf_router), Vania and Alfred.

Each project is good at different things, so this page gives facts only. Projects change, so read their docs before you decide. For a shorter guide, read the blog post [Dart backend frameworks: how to choose](https://dartondox.dev/blog/dart-backend-frameworks-how-to-choose/).

## What each one is for

- Dox is a full backend framework. It has routes, controllers, typed DTOs, an ORM, migrations, auth, cache, storage and a CLI.
- Dart Frog is a small backend framework built on Shelf. Routes come from the files in the `routes/` folder. It describes itself as "a fast, minimalistic backend framework for Dart".
- Serverpod is a full-stack framework for Flutter. You write endpoint methods on the server, and Serverpod generates a typed Dart client for the Flutter app. It has an ORM, auth, streaming and a hosted service (Serverpod Cloud).
- Shelf is the request and middleware model from the Dart team. It is a library, not a framework. `shelf_router` adds a router, and you pick every other part yourself.
- Vania is a full backend framework. Its core has routes, validation, an ORM, migrations, sessions, a cache, mail and storage. Auth, OpenAPI and WebSocket rooms come as add-on packages. It works with MySQL, Postgres and MongoDB.
- Alfred is a small server in the style of Express.js. Routes, middleware, WebSocket and static files are built in.

## Feature table

"Not built in" means the project does not ship it, but you can still add a package for it.

| Feature | Dox | Dart Frog | Serverpod | Shelf + shelf_router | Alfred | Vania |
| --- | --- | --- | --- | --- | --- | --- |
| Routing | Route classes: `Route.get(...)`, groups, resources, domain routes | Routes from files in `routes/`, dynamic and nested routes | Endpoint classes become typed client methods. A separate web server (Relic) has its own routing. | `Router()` with `<param>` patterns, nested routers | Express-like, `:id:int` params with types or regex | `Router.get(...)`, groups, prefixes, constraints, resource routes |
| Typed request validation | `@Dto` classes, checks generated at build time, `422` with errors | Not in their feature list (see their docs) | Typed, generated parameters for endpoints. Rules: see their docs. | Not built in | Route params only (type or regex) | Rules in strings (`'required\|email'`), fluent rules and `FormValidation` classes. Not typed classes. |
| ORM and relations | `dox_orm`: models, has one, has many, belongs to, many to many | Not built in | Built in: filters, joins, one-to-one, one-to-many, many-to-many | Not built in | Not built in | Built in: models, one-to-one, one-to-many, many-to-many, polymorphic |
| Migrations | `dox migrate` (SQL or Dart files) | Not built in | Built in, versioned migrations | Not built in | Not built in | Built in, versioned migrations (`vania migrate`) |
| Auth | `dox_auth`: JWT and session guards. Password hashing (`Hash`) is in `dox_core`. | `dart_frog_auth`: Basic, Bearer and Cookie middleware | Built in: email and password, Google, Apple, GitHub, passkeys and more | Not built in | See their docs | `vania_auth`: JWT, guards, personal access tokens, gates |
| WebSocket | A Socket.IO v4 server (`dox_socketio`) and raw `Route.websocket` | `dart_frog_web_socket` (`webSocketHandler`) | Streaming methods over a managed WebSocket | `shelf_web_socket` | Built in | Built in. `vania_websocket` adds rooms and presence. |
| OpenAPI | Generated OpenAPI 3.1 (JSON, YAML) and a docs page | On their roadmap, not done | Not built in (third-party packages exist) | See their docs | See their docs | `vania_swagger`: OpenAPI 3.1 and Swagger UI |
| CLI and code generation | `dox` CLI, `build_runner` for DTOs, models and OpenAPI | `dart_frog` CLI: `create`, `dev` (hot reload), `build` | `serverpod` CLI, generates server and client code | No CLI (`shelf_router_generator` for routes from annotations) | No CLI | `vania` CLI: `create`, `serve` (hot reload), `make:*`, `migrate`, `build` |
| Native binary | `dox build` makes an AOT binary | `dart_frog build` makes a production build with a Dockerfile | Deploy to Serverpod Cloud, Docker or Terraform. Binary: see their docs. | Your app is plain Dart. Compile it like any Dart program. | Your app is plain Dart. Compile it like any Dart program. | `vania build` makes a native binary |
| Multi-core | One isolate per CPU core by default | See their docs | One isolate per process. Scale with more processes and server roles. | `serve(..., shared: true)` and your own isolates | Yes, a multi-isolate mode is in their README | `APP_ISOLATES` runs more isolates (since 2.1.0) |
| HTTP server | Native server in Rust, also for WebSocket | Shelf on `dart:io` | Relic (their own, 2.0 in November 2026) for the web server. API server: see their docs. | `dart:io` `HttpServer` (`shelf_io`) | `dart:io` | `dart:io` |
| Databases | Postgres, MySQL, MariaDB, SQLite | Not built in | Postgres, SQLite (also SQLite on the device). Redis for cache. | Not built in | Not built in | MySQL, MariaDB, Postgres, MongoDB (a driver package for each) |
| Code sharing with Flutter | `@Dto` classes in a pure Dart package, see [Share code with Flutter](../guides/share-code-with-flutter.md) | Plain Dart packages. A generated client is marked "in progress" in their feature list. | Generated client package, and shared packages for models | Plain Dart packages | Plain Dart packages | Plain Dart packages |
| License | MIT | MIT | BSD-3 for most packages. The main `serverpod` package is SSPL. | BSD-3-Clause | MIT for the core. Some parts BSD. | MIT |
| First release and maturity | First on pub.dev in 2023 | First on pub.dev in 2022, 1.0 in 2023 | First on pub.dev in 2021, now 4.x | First on pub.dev in 2014, 1.0 in 2021 | First on pub.dev in 2021, 1.x | First on pub.dev in 2024, now 2.x |
| Maintenance (on 2026-11-17) | Active | Active. Moved to the `dart-frog-dev` group in 2025. Last `dart_frog` release: 1.2.6 (November 2025). | Active. Release 4.1.2 in November 2026. | Active. Published by `tools.dart.dev` (the Dart team). | Last release 1.1.3, in May 2025. Unverified uploader. | Active. Release 2.1.0 in October 2026. |

Facts checked on 2026-11-17.

Sources:

- Dart Frog: [dart-frog.dev](https://dart-frog.dev), [github.com/dart-frog-dev/dart_frog](https://github.com/dart-frog-dev/dart_frog) (docs in `docs/src/content/docs`, the roadmap and "The Future of Dart Frog"), [pub.dev/packages/dart_frog](https://pub.dev/packages/dart_frog)
- Serverpod: [docs.serverpod.dev](https://docs.serverpod.dev), [github.com/serverpod/serverpod](https://github.com/serverpod/serverpod), [github.com/serverpod/serverpod_docs](https://github.com/serverpod/serverpod_docs) (scalability, streaming, shared packages, database connection), [pub.dev/packages/serverpod](https://pub.dev/packages/serverpod)
- Shelf: [pub.dev/packages/shelf](https://pub.dev/packages/shelf), [pub.dev/packages/shelf_router](https://pub.dev/packages/shelf_router), [github.com/dart-lang/shelf](https://github.com/dart-lang/shelf), [`serve` API docs](https://pub.dev/documentation/shelf/latest/shelf_io/serve.html)
- Vania: [vdart.dev/docs](https://vdart.dev/docs/intro), [github.com/vania-dart/framework](https://github.com/vania-dart/framework) (README and CHANGELOG), [pub.dev/packages/vania](https://pub.dev/packages/vania)
- Alfred: [pub.dev/packages/alfred](https://pub.dev/packages/alfred), [github.com/rknell/alfred](https://github.com/rknell/alfred)

## Speed

The numbers of Dox are on [Performance](../digging-deeper/performance.md). To compare, run the same test on your machine, with each server on the same number of cores.

## When to pick Dox

- You want a full framework in one place: routes, typed input, ORM, migrations, auth, cache, storage and OpenAPI docs.
- You come from a PHP framework. See [Coming from Laravel](coming-from-laravel.md).
- You need MySQL or MariaDB, not only Postgres.
- You want typed DTOs with the same rules on the server and in a Dart or Flutter client. See [Share code with Flutter](../guides/share-code-with-flutter.md).
- You want an OpenAPI document made from your code, for clients that are not written in Dart.

## When to pick something else

- You want a framework with many years of use. Dart Frog, Serverpod and Shelf have been out for years, and Dox is new.
- You want a hosted service. Serverpod has Serverpod Cloud. You deploy Dox yourself, as a binary or with Docker.
- Your app is Flutter only, and you want a generated client. Serverpod makes a typed client for each endpoint. Dox makes an OpenAPI document.
- You want a small tool with few parts. Dart Frog is simpler, and you add only what you need.
- You want to build your own stack. Shelf gives you the base parts, and the Dart team publishes it.
- You need a feature that Dox does not have yet, like events and listeners. See [What Dox does not have yet](status-and-roadmap.md#what-dox-does-not-have-yet).

## Next steps

- [Status and roadmap](status-and-roadmap.md): what works today and what is missing.
- [Performance](../digging-deeper/performance.md): the numbers of Dox.
- [Installation](../getting-started/installation.md): make your first Dox app.
