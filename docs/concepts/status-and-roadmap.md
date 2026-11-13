---
icon: lucide/map
---

# Status and roadmap

This page shows what works in Dox today, what is missing and what is planned.

## Packages

What the states mean:

- **Stable**: works, has tests and has had real use.
- **New**: works and has tests, but it is newer and has had less real use.

All packages follow semantic versioning: a breaking change only comes in a new major version.

The packages in the main repo share one version number. The other packages live in their own repos and have their own version numbers. See [Contribute](../community/contribute.md#packages-in-other-repos).

| Package | What it does | State | Tests |
| --- | --- | --- | --- |
| `dox_core` | Routes, middleware, controllers, request and response, isolates, config, the IoC container, exception handler, sessions, CSRF, rate limit, security headers, health check, test client | Stable | 528 tests in 61 files. CI runs them on the native server. |
| `dox_orm` | Query builder, models, relations, `whereHas`, scopes, casts, `withCount`, transactions, row locks, many to many writes, polymorphic relations, factories, seeders | Stable | 549 tests in 51 files. CI runs them on Postgres, MariaDB, MySQL 8.4 and SQLite. |
| `dox_validation` | `@Dto` rules, fluent schemas, JSON Schema, Standard Schema | Stable | 149 tests in 8 files |
| `dox_builder` | Code generator for models, DTOs, env classes, the container and OpenAPI | Stable | 86 tests in 5 files |
| `dox_annotation` | Annotations used by the generator | Stable | 6 tests in 1 file. Mostly tested through `dox_builder`. |
| `dox` (CLI) | `dox create`, `dox serve`, `dox build`, `make:*`, `migration:*`, `db:seed`, `queue:*`, `schedule:*`, package commands | Stable | 132 tests in 12 files |
| `dox_migration` | Migrations for Postgres, MySQL, MariaDB and SQLite | Stable | 36 tests in 5 files. CI runs them on each database. |
| `dox_auth` | JWT and session auth guards and middleware, access tokens you can revoke, gates and policies | Stable | 201 tests in 8 files |
| `dox_cache` | Memory, file and Redis cache, tags, locks | Stable | 94 tests in 4 files, with Redis in CI |
| `dox_storage` | Local disk and S3 (and S3-compatible) storage | Stable | 153 tests in 10 files, with MinIO in CI |
| `dox_openapi` | OpenAPI 3.1 document and a docs page | Stable | 63 tests in 4 files |
| `dox_socketio` | Socket.IO v4 server with a Redis adapter | Stable | 119 tests in 11 files, with Redis and the real `socket.io-client` in CI |
| `dox_queue` | Queues and jobs, the Redis and sync drivers, chains, batches, workers | New | 44 tests in 7 files. Most queue tests run in `dox_queue_database`, on every store. |
| `dox_queue_database` | The database queue driver, the batch store and `afterCommit` for `dox_queue` | New | 234 tests in 16 files, with SQLite, Postgres, MariaDB and Redis in CI |
| `dox_scheduler` | Run tasks on a schedule | New | 106 tests in 6 files, with Redis in CI |
| [`dox_mcp`](../packages/mcp.md) | MCP server: tools for AI clients over Streamable HTTP, signed sessions | New | 15 tests in 1 file |
| `dox_view` | [Views](../the-basic/views.md): `.dox.html` templates with layouts and components | New | 40 tests in 2 files |
| [`dox_inertia`](../the-basic/inertia.md) | Inertia.js server side: single page apps with React, Vue or Svelte and Dox controllers | New | 34 tests in 2 files |
| `dox_mailer` | Email with SMTP, Amazon SES, Azure, Resend, Mailgun, Postmark and sendmail, mailables, Markdown mail, notifications | New | 167 tests in 16 files, with a fake SMTP server |
| `dox_http_native` | Native HTTP/1.1 and WebSocket server in Rust, on the isolate's own thread. Dox has no other server. | New | 65 Dart tests in 4 files, and 32 Rust tests |
| `dox_postgres_native` | Native Postgres client (Rust tokio-postgres), the Postgres driver. Has TLS (`sslmode`, `sslRootCert`). | New | 41 tests in 7 files, plus the `dox_orm` tests |
| `dox_mysql_native` | Native MySQL and MariaDB client (Rust mysql_async), the MySQL driver. Has TLS. | New | 30 tests in 2 files, plus the `dox_orm` tests |

`Hash` (bcrypt password hashing) is in `dox_core`.

!!! note "About test coverage"
    The repos do not measure line coverage. Counts are `test(` calls in each package's `test/` folder.
    A test inside a loop counts once, so `dart test` can report more tests.
    The CI setup of the main repo is in `.github/workflows/test.yaml`. The packages in their own repos have their own CI.

## What Dox does not have yet

| Feature | Status | What to do today |
| --- | --- | --- |
| Events and listeners | Not there | Model events are there. See [Model events](../database/model/events.md). |
| Password reset | Not there | Make a signed, short-lived token, send it with [Mail](../digging-deeper/mail.md) and check it in a controller. |
| Localization | Partly | Validation messages can follow the request locale (`req.locale`). There is no general translation helper. Keep your own message maps. |

## Planned

### Later

- Localization

The package CHANGELOGs have an `Unreleased` section when changes wait for the next version.

## How to help

- Try Dox and open an issue when something breaks or is missing.
- Pick an item above and open an issue first, so the design can be discussed.
- See [Contribute](../community/contribute.md) to set up the repo and run the tests.
