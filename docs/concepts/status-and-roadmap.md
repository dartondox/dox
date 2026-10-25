# Status and roadmap

Checked on 2026-10-25, for version `3.0.0-alpha.7`.

Dox 3.0 is an **alpha**. You can build with it, but the API can still change between alpha versions.
All packages share one version number.

## Packages

What the states mean:

- **May change**: works and has tests. Names and options can still change before 3.0 is stable.
- **Experimental**: new code. It changed in a breaking way during the alphas, or it has a known gap.

No package is marked "stable API" yet. That comes with 3.0 stable.

| Package | What it does | State | Tests |
| --- | --- | --- | --- |
| `dox_core` | Routes, middleware, controllers, request and response, isolates, config | May change | 36 test files. CI runs them on the native server. |
| `dox_orm` | Query builder, models, relations, transactions, drivers | May change | 26 test files. CI runs them on Postgres, MariaDB, MySQL 8.4 and SQLite. |
| `dox_validation` | `@Dto` rules, fluent schemas, JSON Schema, Standard Schema | May change | 6 test files |
| `dox_builder` | Code generator for models, DTOs, env classes and OpenAPI | May change | 4 test files |
| `dox_annotation` | Annotations used by the generator | May change | 1 small test file. Mostly tested through `dox_builder`. |
| `dox` (CLI) | `dox create`, `dox serve`, `dox build`, `make:*`, `migration:*` | May change | 8 test files |
| `dox_migration` | Migrations for Postgres, MySQL, MariaDB and SQLite | May change | 4 test files. CI runs them on each database. |
| `dox_auth` | JWT auth guard and middleware | May change | 2 test files |
| `dox_cache` | Memory, file and Redis cache, tags, locks | May change | 4 test files, with Redis in CI |
| `dox_storage` | Local disk and S3 (and S3-compatible) storage | May change | 7 test files, with MinIO in CI |
| `dox_openapi` | OpenAPI 3.1 document and a docs page | May change | 4 test files |
| `dox_socketio` | Socket.IO v4 server with a Redis adapter | May change | 8 test files, with the real `socket.io-client` in CI |
| `dox_http_native` | Native HTTP/1.1 and WebSocket server (Rust hyper). Dox has no other server. | Experimental | 3 Dart test files and Rust tests |
| `dox_postgres_native` | Native Postgres client (Rust tokio-postgres), the Postgres driver. Has TLS (`sslmode`). | Experimental | 5 Dart test files, plus the `dox_orm` tests |
| `dox_mysql_native` | Native MySQL and MariaDB client (Rust mysql_async), the MySQL driver. Has TLS. | Experimental | 1 Dart test file, plus the `dox_orm` tests |

`Hash` (bcrypt password hashing) is in `dox_core`.

!!! note "About test coverage"
    The repo does not measure line coverage. The "Tests" column counts test files and says where CI runs them.
    The CI setup is in `.github/workflows/test.yaml`. The three native packages live in their own repos, with their own CI.

## What Dox does not have yet

These were checked by searching the code in `packages/*/lib` with `rg`.

| Feature | Status | What to do today |
| --- | --- | --- |
| Queues and jobs | Not there | Use a database table, Redis or a separate worker process. See [Background work](../guides/background-work.md). |
| Task scheduler | Not there | Use cron or a systemd timer to call a route or a Dart script. |
| Mail | Not there | Use a Dart mail package or an HTTP mail API. |
| Notifications | Not there | Send them from your own service class. |
| Events and listeners | Not there | Model events are there. See [Model events](../database/model/events.md). |
| Views and templates | Not there | Dox is for APIs. Serve the front end on its own. |
| Rate limiting | Not there | Write a middleware with the cache, or use a proxy. |
| Sessions and password reset | Not there | Auth uses JWT. `req.httpRequest.session` throws `UnsupportedError`. |
| Policies and gates | Not there | Check the user in a middleware or in the controller. |
| Database factories and seeders | Not there | Write a Dart script, or a migration with data. |
| Savepoints | Not there | A nested `transaction()` joins the outer one. |
| Localization | Not there | Keep your own message maps. |

## Planned

!!! warning "This is a plan, not a promise. Open an issue to discuss."
    Items come from the code (`ponytail:` notes in `packages/*/lib`) and from the owner.
    There are no dates.

### For 3.0.0

| Item | Notes |
| --- | --- |
| Small fixes | `nosniff` and a `download` option for `Route.files`, a stricter BMP check, `maxAttachments` for Socket.IO, `X-Forwarded-For` hops with a port, a minimum JWT secret length, one `Hash` class. |
| Savepoints for nested transactions | Today a nested `transaction()` joins the outer one (`ponytail:` notes in the `dox_orm` drivers). |
| `sslRootCert` for Postgres | Trust a private CA, like AWS RDS. `dox_postgres_native` has it. `dox_orm` does not pass it on yet. |
| Named routes and route model binding | |
| One exception handler | One place to turn every error into a response. |
| ORM scopes, casts and `withCount` | |
| Model factories and seeders | |
| HTTP test client and database refresh | For app tests. |
| Rate limiting | |
| Security headers | |
| Health check route | |
| `dox_queue` | Queues and jobs. New package: [github.com/dartondox/dox-queue](https://github.com/dartondox/dox-queue). |
| `dox_scheduler` | Run tasks on a schedule. New package: [github.com/dartondox/dox-scheduler](https://github.com/dartondox/dox-scheduler). |
| 3.0 stable | After the alpha API settles |

### Later (3.1 and after)

- Mail
- Notifications
- Sessions and password reset
- Gates and policies
- Localization

The package CHANGELOGs have an `Unreleased` section when changes wait for the next version.

## How to help

- Try the alpha and open an issue when something breaks or is missing.
- Pick an item above and open an issue first, so the design can be discussed.
- See [Contribute](../others/contribute.md) to set up the repo and run the tests.
