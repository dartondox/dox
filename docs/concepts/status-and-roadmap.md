# Status and roadmap

Checked on 2026-10-22, for version `3.0.0-alpha.4`.

Dox 3.0 is an **alpha**. You can build with it, but the API can still change between alpha versions.
All packages share one version number.

## Packages

What the states mean:

- **May change**: works and has tests. Names and options can still change before 3.0 is stable.
- **Experimental**: new code. It changed in a breaking way during the alphas, or it has a known gap.

No package is marked "stable API" yet. That comes with 3.0 stable.

| Package | What it does | State | Tests |
| --- | --- | --- | --- |
| `dox_core` | Routes, middleware, controllers, request and response, isolates, config | May change | 29 test files. CI runs them on the native server. |
| `dox_orm` | Query builder, models, relations, transactions, drivers | May change | 16 test files. CI runs them on Postgres, MariaDB, MySQL 8.4 and SQLite, with the native and the Dart drivers. |
| `dox_validation` | `@Dto` rules, fluent schemas, JSON Schema, Standard Schema | May change | 6 test files |
| `dox_builder` | Code generator for models, DTOs, env classes and OpenAPI | May change | 4 test files |
| `dox_annotation` | Annotations used by the generator | May change | 1 small test file. Mostly tested through `dox_builder`. |
| `dox` (CLI) | `dox create`, `dox serve`, `dox build`, `make:*`, `migration:*` | May change | 5 test files |
| `dox_migration` | Migrations for Postgres, MySQL, MariaDB and SQLite | May change | 2 test files. CI runs them on each database. |
| `dox_auth` | JWT auth guard and middleware, password hashing | May change | 2 test files |
| `dox_cache` | Memory, file and Redis cache, tags, locks | May change | 4 test files, with Redis in CI |
| `dox_storage` | Local disk and S3 (and S3-compatible) storage | May change | 7 test files, with MinIO in CI |
| `dox_openapi` | OpenAPI 3.1 document and a docs page | May change | 4 test files |
| `dox_websocket` | WebSocket routes and events | May change | 4 test files, with Redis in CI |
| `dox_socketio` | Socket.IO v4 server with a Redis adapter | May change | 6 test files, with the real `socket.io-client` in CI |
| `dox_http_native` | Native HTTP/1.1 server (Rust hyper), the default server | Experimental | 2 Dart test files and Rust tests. No WebSocket yet. Big responses are held in memory. |
| `dox_postgres_native` | Native Postgres client (Rust tokio-postgres), the default Postgres driver | Experimental | 1 Dart test file, plus the `dox_orm` tests. No TLS yet. |
| `dox_mysql_native` | Native MySQL and MariaDB client (Rust mysql_async), the default MySQL driver | Experimental | 1 Dart test file, plus the `dox_orm` tests |

!!! note "About test coverage"
    The repo does not measure line coverage. The "Tests" column counts test files and says where CI runs them.
    The CI setup is in `.github/workflows/test.yaml` and `native.yaml`.

## What Dox does not have yet

These were checked by searching the code in `packages/*/lib` with `rg`.

| Feature | Status | What to do today |
| --- | --- | --- |
| Queues and jobs | Not there | Use a database table, Redis or a separate worker process. See [Background work](../guides/background-work.md). |
| Task scheduler | Not there | Use cron or a systemd timer to call a route or a Dart script. |
| Mail | Not there | Use a Dart mail package or an HTTP mail API. |
| Events and listeners | Not there | Model events are there. See [Model events](../database/model/events.md). |
| Views and templates | Not there | Dox is for APIs. Serve the front end on its own. |
| Rate limiting | Not there | Write a middleware with the cache, or use a proxy. |
| Sessions | Not there | Auth uses JWT. On the native server, `req.httpRequest.session` throws `UnsupportedError`. |
| Policies and gates | Not there | Check the user in a middleware or in the controller. |
| Database seeders | Not there | Write a Dart script, or a migration with data. |

## Planned

!!! warning "This is a plan, not a promise. Open an issue to discuss."
    Items come from the code (`TODO` and `ponytail:` notes in `packages/*/lib`) and from the owner.
    There are no dates.

| Item | Source |
| --- | --- |
| Stream big responses to the socket on the native server. Today a big file is held in memory. | `ponytail:` note in `dox_http_native/lib/src/response.dart` |
| TLS for the native Postgres driver | `ponytail:` note in `dox_orm/lib/src/drivers/postgres_native_driver.dart` |
| Savepoints for nested transactions. Today a nested `transaction()` joins the outer one. | `ponytail:` notes in the `dox_orm` drivers and in `dox_migration` |
| A queue package (`dox_queue`) | Wanted by the owner. Not started. |
| A mail package (`dox_mail`) | Wanted by the owner. Not started. |
| 3.0 stable | After the alpha API settles |

The package CHANGELOGs have no `Unreleased` section today. When one is added, it lists the next changes.

## How to help

- Try the alpha and open an issue when something breaks or is missing.
- Pick an item above and open an issue first, so the design can be discussed.
- See [Contribute](../others/contribute.md) to set up the repo and run the tests.
