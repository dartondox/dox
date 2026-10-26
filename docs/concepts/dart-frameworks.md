---
icon: lucide/scale
---

# Dox and the other Dart backends

This page compares Dox with four other ways to build a backend in Dart: Dart Frog, Serverpod, Shelf (with `shelf_router`) and Alfred.
It lists facts only. Each project is good at different things.

!!! note "Checked on 2026-10-22"
    The facts about the other projects come from their own docs, READMEs and pub.dev pages, read on 2026-10-22.
    Projects change. Check their docs before you decide.
    Where this page is not sure, the table says "see their docs".

## What each one is for

- **Dox** is a full backend framework, in the style of Laravel. It has routes, controllers, typed DTOs, an ORM, migrations, auth, cache, storage and a CLI.
  It is in **3.0 alpha**. The API can still change.
- **Dart Frog** is a small backend framework. It is built on Shelf. Routes come from the files in the `routes/` folder.
  It describes itself as "a fast, minimalistic backend framework for Dart".
- **Serverpod** is a full-stack framework for Flutter. You write endpoint methods on the server. Serverpod generates a typed Dart client for the Flutter app.
  It has an ORM, auth, streaming and a hosted service (Serverpod Cloud).
- **Shelf** is the request and middleware model from the Dart team. It is a library, not a framework.
  `shelf_router` adds a router. You pick every other part yourself.
- **Alfred** is a small server in the style of Express.js. Routes, middleware, WebSocket and static files are built in.

## Feature table

"Not built in" means the project does not ship it. You can still add a package for it.

| Feature | Dox | Dart Frog | Serverpod | Shelf + shelf_router | Alfred |
| --- | --- | --- | --- | --- | --- |
| Routing | Route classes: `Route.get(...)`, groups, resources, domain routes | Routes from files in `routes/`, dynamic and nested routes | Endpoint classes become typed client methods. A separate web server (Relic) has its own routing. | `Router()` with `<param>` patterns, nested routers | Express-like, `:id:int` params with types or regex |
| Typed request validation | `@Dto` classes, checks generated at build time, `422` with errors | Not in their feature list (see their docs) | Typed, generated parameters for endpoints. Rules: see their docs. | Not built in | Route params only (type or regex) |
| ORM and relations | `dox_orm`: models, has one, has many, belongs to, many to many | Not built in | Built in: filters, joins, one-to-one, one-to-many, many-to-many | Not built in | Not built in |
| Migrations | `dox migrate` (SQL or Dart files) | Not built in | Built in, versioned migrations | Not built in | Not built in |
| Auth | `dox_auth`: JWT and session guards. Password hashing (`Hash`) is in `dox_core`. | `dart_frog_auth`: Basic, Bearer and Cookie middleware | Built in: email and password, Google, Apple, GitHub, passkeys and more | Not built in | See their docs |
| WebSocket | A Socket.IO v4 server (`dox_socketio`) and raw `Route.websocket` | `dart_frog_web_socket` (`webSocketHandler`) | Streaming methods over a managed WebSocket | `shelf_web_socket` | Built in |
| OpenAPI | Generated OpenAPI 3.1 (JSON, YAML) and a docs page | On their roadmap, not done | See their docs | See their docs | See their docs |
| CLI and code generation | `dox` CLI, `build_runner` for DTOs, models and OpenAPI | `dart_frog` CLI: `create`, `dev` (hot reload), `build` | `serverpod` CLI, generates server and client code | No CLI (`shelf_router_generator` for routes from annotations) | No CLI |
| Native binary | `dox build` makes an AOT binary | `dart_frog build` makes a production build with a Dockerfile | Deploy to Serverpod Cloud, Docker or Terraform. Binary: see their docs. | Your app is plain Dart. Compile it like any Dart program. | Your app is plain Dart. Compile it like any Dart program. |
| Multi-core | One isolate per CPU core by default | See their docs | One isolate per process. Scale with more processes and server roles. | `serve(..., shared: true)` and your own isolates | Yes, a multi-isolate mode is in their README |
| HTTP server | Native server in Rust (hyper), also for WebSocket | Shelf on `dart:io` | Relic (their own) for the web server. API server: see their docs. | `dart:io` `HttpServer` (`shelf_io`) | `dart:io` |
| Databases | Postgres, MySQL, MariaDB, SQLite | Not built in | Postgres, SQLite (also SQLite on the device). Redis for cache. | Not built in | Not built in |
| Code sharing with Flutter | `@Dto` classes in a pure Dart package, see [Share code with Flutter](../guides/share-code-with-flutter.md) | Plain Dart packages. A generated client is marked "in progress" in their feature list. | Generated client package, and shared packages for models | Plain Dart packages | Plain Dart packages |
| License | MIT | MIT | BSD-3 for most packages. The main `serverpod` package is SSPL. | BSD-3-Clause | MIT for the core. Some parts BSD. |
| First release and maturity | 3.0 alpha (2026) | First on pub.dev in 2022, 1.0 about three years ago | First on pub.dev in 2021, now 4.x | First on pub.dev in 2014, 1.0 in 2021 | First on pub.dev in 2021, 1.x |
| Maintenance (on 2026-10-22) | Active | Active. Moved to the `dart-frog-dev` group in 2025. Last `dart_frog` release: 1.2.6 (November 2025). | Active. Release 4.0.4 in October 2026. | Active. Published by `tools.dart.dev` (the Dart team). | Last release 1.1.3, about 17 months ago. Unverified uploader. |

Sources (checked on 2026-10-22):

- Dart Frog: [dart-frog.dev](https://dart-frog.dev), [github.com/dart-frog-dev/dart_frog](https://github.com/dart-frog-dev/dart_frog) (docs in `docs/src/content/docs`, the roadmap and "The Future of Dart Frog"), [pub.dev/packages/dart_frog](https://pub.dev/packages/dart_frog)
- Serverpod: [docs.serverpod.dev](https://docs.serverpod.dev), [github.com/serverpod/serverpod](https://github.com/serverpod/serverpod), [github.com/serverpod/serverpod_docs](https://github.com/serverpod/serverpod_docs) (scalability, streaming, shared packages, database connection), [pub.dev/packages/serverpod](https://pub.dev/packages/serverpod)
- Shelf: [pub.dev/packages/shelf](https://pub.dev/packages/shelf), [pub.dev/packages/shelf_router](https://pub.dev/packages/shelf_router), [github.com/dart-lang/shelf](https://github.com/dart-lang/shelf), [`serve` API docs](https://pub.dev/documentation/shelf/latest/shelf_io/serve.html)
- Alfred: [pub.dev/packages/alfred](https://pub.dev/packages/alfred), [github.com/rknell/alfred](https://github.com/rknell/alfred)

## Speed

This page does not compare speed. Dox's own numbers (hello world and a `/db` read) are on [Performance](../digging-deeper/performance.md).
To compare, run the same test on your own machine, with each server on the same number of cores.

## When to pick Dox

- You want a full framework in one place: routes, typed input, ORM, migrations, auth, cache, storage and OpenAPI docs.
- You know Laravel. See [Coming from Laravel](coming-from-laravel.md).
- You need MySQL or MariaDB, not only Postgres.
- You want typed DTOs with the same rules on the server and in a Dart or Flutter client. See [Share code with Flutter](../guides/share-code-with-flutter.md).
- You want an OpenAPI document made from your code, for clients that are not written in Dart.
- You can accept an alpha: the API can change before 3.0 is stable. See [Status and roadmap](status-and-roadmap.md).

## When to pick something else

- **You need a stable API today.** Dox is alpha. Dart Frog, Serverpod and Shelf have had 1.0 or later for years.
- **You want a hosted service.** Serverpod has Serverpod Cloud. Dox has no hosted service. You deploy it yourself (a binary or Docker).
- **Your app is Flutter only, and you want the client made for you.** Serverpod generates a typed client for every endpoint. Dox does not generate a Dart client. It generates an OpenAPI document.
- **You want a small tool with few parts.** Dart Frog is simpler. You add only what you need.
- **You want to build your own stack.** Shelf gives you the base parts, and the Dart team publishes it.
- **You need features Dox does not have yet**, like notifications, events and listeners, or policies. See [What Dox does not have yet](status-and-roadmap.md#what-dox-does-not-have-yet).
