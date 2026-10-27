---
icon: lucide/map
---

# Status and roadmap

This page shows what works in Dox today, what is missing and what is planned.

Checked on 2026-10-26.

## Packages

What the states mean:

- **Stable**: works, has tests and has had real use.
- **New**: works and has tests, but it is newer and has had less real use.

All packages follow semantic versioning: a breaking change only comes in a new major version.

The packages in the main repo share one version number. The other packages live in their own repos and have their own version numbers. See [Contribute](../community/contribute.md#packages-in-other-repos).

| Package | What it does | State | Tests |
| --- | --- | --- | --- |
| `dox_core` | Routes, middleware, controllers, request and response, isolates, config, the IoC container, exception handler, sessions, CSRF, rate limit, security headers, health check, test client | Stable | 334 tests in 44 files. CI runs them on the native server. |
| `dox_orm` | Query builder, models, relations, `whereHas`, scopes, casts, `withCount`, transactions, row locks, factories, seeders | Stable | 355 tests in 37 files. CI runs them on Postgres, MariaDB, MySQL 8.4 and SQLite. |
| `dox_validation` | `@Dto` rules, fluent schemas, JSON Schema, Standard Schema | Stable | 90 tests in 6 files |
| `dox_builder` | Code generator for models, DTOs, env classes, the container and OpenAPI | Stable | 59 tests in 5 files |
| `dox_annotation` | Annotations used by the generator | Stable | 1 test in 1 file. Mostly tested through `dox_builder`. |
| `dox` (CLI) | `dox create`, `dox serve`, `dox build`, `make:*`, `migration:*`, `db:seed`, `queue:*`, `schedule:*` | Stable | 73 tests in 9 files |
| `dox_migration` | Migrations for Postgres, MySQL, MariaDB and SQLite | Stable | 31 tests in 5 files. CI runs them on each database. |
| `dox_auth` | JWT and session auth guards and middleware | Stable | 43 tests in 4 files |
| `dox_cache` | Memory, file and Redis cache, tags, locks | Stable | 63 tests in 4 files, with Redis in CI |
| `dox_storage` | Local disk and S3 (and S3-compatible) storage | Stable | 119 tests in 10 files, with MinIO in CI |
| `dox_openapi` | OpenAPI 3.1 document and a docs page | Stable | 56 tests in 4 files |
| `dox_socketio` | Socket.IO v4 server with a Redis adapter | Stable | 85 tests in 10 files, with Redis and the real `socket.io-client` in CI |
| `dox_queue` | Queues and jobs | New | 43 tests in 5 files, with Postgres, MariaDB and Redis in CI |
| `dox_scheduler` | Run tasks on a schedule | New | 74 tests in 6 files, with Redis in CI |
| `dox_view` | [Views](../the-basic/views.md): `.dox.html` templates with layouts and components | New | 36 tests in 2 files |
| [`dox_inertia`](../the-basic/inertia.md) | Inertia.js server side: single page apps with React, Vue or Svelte and Dox controllers | New | 26 tests in 2 files |
| `dox_mailer` | Email with SMTP, Amazon SES, Azure, Resend, Mailgun, Postmark and sendmail | New | 72 tests in 10 files, with a fake SMTP server |
| `dox_http_native` | Native HTTP/1.1 and WebSocket server in Rust, on the isolate's own thread. Dox has no other server. | New | 55 Dart tests in 3 files, and 27 Rust tests |
| `dox_postgres_native` | Native Postgres client (Rust tokio-postgres), the Postgres driver. Has TLS (`sslmode`, `sslRootCert`). | New | 31 Dart tests in 5 files, plus the `dox_orm` tests |
| `dox_mysql_native` | Native MySQL and MariaDB client (Rust mysql_async), the MySQL driver. Has TLS. | New | 13 Dart tests in 1 file, plus the `dox_orm` tests |

`Hash` (bcrypt password hashing) is in `dox_core`.

!!! note "About test coverage"
    The repos do not measure line coverage. The "Tests" column counts the `test(` calls and the `*_test.dart` files in the `test/` folder of each package, and says where CI runs them.
    A test inside a loop counts once, so `dart test` can report more tests.
    The CI setup of the main repo is in `.github/workflows/test.yaml`. The packages in their own repos have their own CI.

## What Dox does not have yet

These were checked by searching the code with `rg`.

| Feature | Status | What to do today |
| --- | --- | --- |
| Notifications | Not there | Send them from your own service class. |
| Events and listeners | Not there | Model events are there. See [Model events](../database/model/events.md). |
| Password reset | Not there | Make a signed, short-lived token, send it with [Mail](../digging-deeper/mail.md) and check it in a controller. |
| Policies and gates | Not there | Check the user in a middleware or in the controller. |
| Localization | Partly | Validation messages can follow the request locale (`req.locale`). There is no general translation helper. Keep your own message maps. |

## Planned

### Later

- Notifications
- Password reset
- Gates and policies
- Localization

The package CHANGELOGs have an `Unreleased` section when changes wait for the next version.

## How to help

- Try Dox and open an issue when something breaks or is missing.
- Pick an item above and open an issue first, so the design can be discussed.
- See [Contribute](../community/contribute.md) to set up the repo and run the tests.
