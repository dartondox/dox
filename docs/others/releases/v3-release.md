# 3.x

All Dox packages now share one version.

### v3.0.0-alpha.1

**New packages**

- `dox_orm`: the new name of `dox_query_builder`.
- [`dox_validation`](../../packages/validation.md): typed schemas, coercion, custom rules, JSON Schema.
- [`dox_openapi`](../../packages/openapi.md): OpenAPI 3.1 as JSON and YAML, Swagger UI.
- [`dox_storage`](../../packages/storage.md): local, S3 and memory disks, signed URLs.
- [`dox_cache`](../../packages/cache.md): memory, file and Redis cache with tags and locks.
- [`dox_socketio`](../../packages/socketio.md): Socket.IO v4 server with a Redis adapter.

**Database**

- SQLite support.
- MySQL uses `mysql_dart` with a real pool. MySQL 8 login works.
- Postgres uses a real pool.
- `QueryBuilder.transaction()`.
- `whereNull`, `whereNotNull`, `whereNotIn`, `orWhereIn`, `orWhereNotIn`, `selectRaw`, `boolean()` column.
- Table and column names are quoted.
- Fixed: `model.delete()` deleted every row. `orWhere` returned soft deleted rows. MySQL `update()` changed nothing.
- `whereIn` and `orderBy` no longer put user values into the SQL.

**Migrations**

- MySQL and SQLite.
- Rollback undoes only the last batch. New `--step`, `migration:reset` and `migration:refresh`.
- A failed migration stops the run.

**Core**

- Uploads over 1 MB stream to a temp file. A 50 MB upload needs about 75 MB of memory, not 1.1 GB.
- Body limits answer `413`.
- File responses stream, with `Range` support.
- One isolate per CPU core by default. A crashed isolate restarts.
- `trustedProxies` for `X-Forwarded-For` and `X-Forwarded-Proto`.
- Faster router.
- `dox build` makes a native binary. The Docker image is about 11 MB.
- Fixed: CORS preflight, cookie `Max-Age`, `RequestFile.size`, validation of missing fields, websocket rooms.

**Auth**

- Fixed: a login with only a password could match the first user.

Full notes: [release PR #112](https://github.com/dartondox/dox/pull/112).
