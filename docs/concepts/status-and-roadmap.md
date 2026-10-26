---
icon: lucide/map
---

# Status and roadmap

This page shows what works in Dox today, what is missing and what is planned.

Checked on 2026-10-26. The main repo is at version `3.0.0-alpha.17`.

Dox 3.0 is an **alpha**. Every feature planned for 3.0.0 is in. What is left before 3.0 stable is testing and small fixes.
The API can still change between alpha versions.

## Packages

What the states mean:

- **Ready for stable**: works, has tests and has not changed in a breaking way for a while. Only bug fixes are planned before 3.0.
- **May change**: works and has tests. Names and options can still change before 3.0 is stable.
- **Experimental**: new code. It changed in a breaking way during the alphas, or it has a known gap.

The packages in the main repo share one version number. The other packages live in their own repos and have their own version numbers. See [Contribute](../community/contribute.md#packages-in-other-repos).

| Package | Version | What it does | State | Tests |
| --- | --- | --- | --- | --- |
| `dox_core` | `3.0.0-alpha.17` | Routes, middleware, controllers, request and response, isolates, config, the IoC container, exception handler, sessions, CSRF, rate limit, security headers, health check, test client | May change | 334 tests in 44 files. CI runs them on the native server. |
| `dox_orm` | `3.0.0-alpha.14` | Query builder, models, relations, `whereHas`, scopes, casts, `withCount`, transactions, row locks, factories, seeders | May change | 355 tests in 37 files. CI runs them on Postgres, MariaDB, MySQL 8.4 and SQLite. |
| `dox_validation` | `3.0.0-alpha.17` | `@Dto` rules, fluent schemas, JSON Schema, Standard Schema | Ready for stable | 90 tests in 6 files |
| `dox_builder` | `3.0.0-alpha.17` | Code generator for models, DTOs, env classes, the container and OpenAPI | May change | 59 tests in 5 files |
| `dox_annotation` | `3.0.0-alpha.17` | Annotations used by the generator | May change | 1 test in 1 file. Mostly tested through `dox_builder`. |
| `dox` (CLI) | `3.0.0-alpha.17` | `dox create`, `dox serve`, `dox build`, `make:*`, `migration:*`, `db:seed`, `queue:*`, `schedule:*` | May change | 73 tests in 9 files |
| `dox_migration` | `3.0.0-alpha.14` | Migrations for Postgres, MySQL, MariaDB and SQLite | Ready for stable | 31 tests in 5 files. CI runs them on each database. |
| `dox_auth` | `3.0.0-alpha.17` | JWT and session auth guards and middleware | May change | 43 tests in 4 files |
| `dox_cache` | `3.0.0-alpha.17` | Memory, file and Redis cache, tags, locks | Ready for stable | 63 tests in 4 files, with Redis in CI |
| `dox_storage` | `3.0.0-alpha.13` | Local disk and S3 (and S3-compatible) storage | Ready for stable | 119 tests in 10 files, with MinIO in CI |
| `dox_openapi` | `3.0.0-alpha.17` | OpenAPI 3.1 document and a docs page | Ready for stable | 56 tests in 4 files |
| `dox_socketio` | `3.0.0-alpha.15` | Socket.IO v4 server with a Redis adapter | May change | 85 tests in 10 files, with Redis and the real `socket.io-client` in CI |
| `dox_queue` | `3.0.0-alpha.5` | Queues and jobs | Experimental | 43 tests in 5 files, with Postgres, MariaDB and Redis in CI |
| `dox_scheduler` | `3.0.0-alpha.2` | Run tasks on a schedule | Experimental | 74 tests in 6 files, with Redis in CI |
| `dox_view` | `3.0.0-alpha.3` | [Views](../the-basic/views.md): `.dox.html` templates with layouts and components | Experimental | 36 tests in 2 files |
| [`dox_inertia`](../the-basic/inertia.md) | `3.0.0-alpha.4` | Inertia.js server side: single page apps with React, Vue or Svelte and Dox controllers | Experimental | 26 tests in 2 files |
| `dox_mailer` | `3.0.0-alpha.2` | Email with SMTP, Amazon SES, Azure, Resend, Mailgun, Postmark and sendmail | Experimental | 72 tests in 10 files, with a fake SMTP server |
| `dox_http_native` | `3.0.0-alpha.8` | Native HTTP/1.1 and WebSocket server (Rust hyper). Dox has no other server. | Experimental | 35 Dart tests in 3 files, and 16 Rust tests |
| `dox_postgres_native` | `3.0.0-alpha.8` | Native Postgres client (Rust tokio-postgres), the Postgres driver. Has TLS (`sslmode`, `sslRootCert`). | Experimental | 31 Dart tests in 5 files, plus the `dox_orm` tests |
| `dox_mysql_native` | `3.0.0-alpha.7` | Native MySQL and MariaDB client (Rust mysql_async), the MySQL driver. Has TLS. | Experimental | 13 Dart tests in 1 file, plus the `dox_orm` tests |

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

### Later (3.1 and after)

- Notifications
- Password reset
- Gates and policies
- Localization

The package CHANGELOGs have an `Unreleased` section when changes wait for the next version.

## How to help

- Try the alpha and open an issue when something breaks or is missing.
- Pick an item above and open an issue first, so the design can be discussed.
- See [Contribute](../community/contribute.md) to set up the repo and run the tests.
