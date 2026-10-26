---
icon: lucide/map
---

# Status and roadmap

This page shows what works in Dox today, what is missing and what is planned.

Checked on 2026-10-25, for version `3.0.0-alpha.14`.

Dox 3.0 is an **alpha**. Every feature planned for 3.0.0 is in. What is left before 3.0 stable is testing and small fixes.
The API can still change between alpha versions.

## Packages

What the states mean:

- **Ready for stable**: works, has tests and has not changed in a breaking way for a while. Only bug fixes are planned before 3.0.
- **May change**: works and has tests. Names and options can still change before 3.0 is stable.
- **Experimental**: new code. It changed in a breaking way during the alphas, or it has a known gap.

The packages in the main repo share one version number. The other packages live in their own repos and have their own version numbers. See [Contribute](../community/contribute.md#packages-in-other-repos).

| Package | What it does | State | Tests |
| --- | --- | --- | --- |
| `dox_core` | Routes, middleware, controllers, request and response, isolates, config, the IoC container, exception handler, sessions, CSRF, rate limit, security headers, health check, test client | May change | 44 test files. CI runs them on the native server. |
| `dox_orm` | Query builder, models, relations, `whereHas`, scopes, casts, `withCount`, transactions, row locks, factories, seeders | May change | 36 test files. CI runs them on Postgres, MariaDB, MySQL 8.4 and SQLite. |
| `dox_validation` | `@Dto` rules, fluent schemas, JSON Schema, Standard Schema | Ready for stable | 6 test files |
| `dox_builder` | Code generator for models, DTOs, env classes, the container and OpenAPI | May change | 5 test files |
| `dox_annotation` | Annotations used by the generator | May change | 1 small test file. Mostly tested through `dox_builder`. |
| `dox` (CLI) | `dox create`, `dox serve`, `dox build`, `make:*`, `migration:*`, `queue:*`, `schedule:*` | May change | 9 test files |
| `dox_migration` | Migrations for Postgres, MySQL, MariaDB and SQLite | Ready for stable | 5 test files. CI runs them on each database. |
| `dox_auth` | JWT and session auth guards and middleware | May change | 4 test files |
| `dox_cache` | Memory, file and Redis cache, tags, locks | Ready for stable | 4 test files, with Redis in CI |
| `dox_storage` | Local disk and S3 (and S3-compatible) storage | Ready for stable | 10 test files, with MinIO in CI |
| `dox_openapi` | OpenAPI 3.1 document and a docs page | Ready for stable | 4 test files |
| `dox_socketio` | Socket.IO v4 server with a Redis adapter | May change | 10 test files, with the real `socket.io-client` in CI |
| `dox_queue` | Queues and jobs | Experimental | 5 test files |
| `dox_scheduler` | Run tasks on a schedule | Experimental | 6 test files |
| `dox_view` | [Views](../the-basic/views.md): `.dox.html` templates with layouts and components | Experimental | 2 test files |
| `dox_inertia` | Inertia.js server side: single page apps with React, Vue or Svelte and Dox controllers | Experimental | 2 test files |
| `dox_mailer` | Email with SMTP, Amazon SES, Azure, Resend, Mailgun, Postmark and sendmail | Experimental | 6 test files, with a fake SMTP server |
| `dox_http_native` | Native HTTP/1.1 and WebSocket server (Rust hyper). Dox has no other server. | Experimental | 3 Dart test files and Rust tests |
| `dox_postgres_native` | Native Postgres client (Rust tokio-postgres), the Postgres driver. Has TLS (`sslmode`, `sslRootCert`). | Experimental | 5 Dart test files, plus the `dox_orm` tests |
| `dox_mysql_native` | Native MySQL and MariaDB client (Rust mysql_async), the MySQL driver. Has TLS. | Experimental | 1 Dart test file, plus the `dox_orm` tests |

`Hash` (bcrypt password hashing) is in `dox_core`.

!!! note "About test coverage"
    The repo does not measure line coverage. The "Tests" column counts test files and says where CI runs them.
    The CI setup is in `.github/workflows/test.yaml`. The packages in their own repos have their own CI.

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
