# Getting Started

Dox is a web backend framework for Dart, like Laravel.
It gives you routing, an ORM, migrations, validation, auth, WebSocket and a CLI in one place.

!!! warning "You are reading the 3.x docs (alpha)"
    `3.0.0-alpha.1` is a preview. Things can still change before the stable release.

    - New here? Start with [Installation](the-basic/installation.md).
    - Coming from 2.x? Read the [upgrade guide](the-basic/upgrade.md).
    - Need the old docs? Pick **2.x** in the version menu at the top.

---

## Features

**Fast, multi-core HTTP server**: Dox runs one isolate per CPU core. Bodies are streamed, and `dox build` makes a small native binary. See [Performance](digging-deeper/performance.md).

**Simple routing**: Define routes, groups, middleware and resource routes in a few lines. See [Routing](the-basic/routing.md).

**ORM and query builder**: Models and a query builder for Postgres, MySQL/MariaDB and SQLite, with transactions. See [Database](database/index.md).

**Migrations**: Create and change tables with `.sql` or Dart files, and roll them back. See [Migration](database/migration.md).

**Validation**: Rule strings with `req.validate()`, or typed schemas with [`dox_validation`](packages/validation.md).

**WebSocket and Socket.IO**: Real-time events with [WebSocket](digging-deeper/websocket.md) or [Socket.IO](packages/socketio.md).

**Storage and cache**: Local disk and S3 with [`dox_storage`](packages/storage.md). Memory, file and Redis cache with [`dox_cache`](packages/cache.md).

**OpenAPI**: Make OpenAPI 3.1 docs and a Swagger UI page with [`dox_openapi`](packages/openapi.md).

**Security**: JWT [authentication](security/authentication.md), [CORS](security/cors.md), [encryption](security/encryption.md) and [hashing](security/hashing.md).

**CLI**: Create projects, controllers, models and migrations, and build for production. See [Dox CLI](digging-deeper/dox-cli.md).
