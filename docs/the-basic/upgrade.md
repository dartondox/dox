# Upgrade from 2.x to 3.x

!!! warning "3.x is alpha"
    `3.0.0-alpha.1` can still change before the stable release. The 2.x docs stay online: pick **2.x** in the version menu at the top.

## Do these first

1. Use Dart **3.6** or newer.
2. Set every Dox package to the same version, `^3.0.0-alpha.1`. All Dox packages now share one version.
3. Replace `dox_query_builder` with `dox_orm`.
4. If you use `ioredis` in your app, update it to `^2.0.0-alpha.1`.
5. Run `dart pub upgrade`, then `dox build_runner:build`.
6. Read the list below. Each item says what breaks and how to fix it.

```yaml
environment:
  sdk: ^3.6.0

dependencies:
  dox_core: ^3.0.0-alpha.1
  dox_orm: ^3.0.0-alpha.1        # was dox_query_builder
  dox_migration: ^3.0.0-alpha.1
  dox_auth: ^3.0.0-alpha.1
  dox_websocket: ^3.0.0-alpha.1
  ioredis: ^2.0.0-alpha.1        # only if you use redis

dev_dependencies:
  dox_builder: ^3.0.0-alpha.1
  build_runner: ^2.3.3
```

```dart
// old
import 'package:dox_query_builder/dox_query_builder.dart';
// new
import 'package:dox_orm/dox_orm.dart';
```

!!! info
    `dox_query_builder` 3.x still works. It only re-exports `dox_orm`. New fixes go to `dox_orm` only.

## Database and query builder

**Names are quoted.**
Table and column names are now quoted (`"name"` on Postgres, `` `name` `` on MySQL).
On Postgres a quoted name is case sensitive.
If you made a column with `CREATE TABLE ... (userId int)` without quotes, Postgres saved it as `userid`.
Now `where('userId', 1)` looks for `"userId"` and fails.
Fix: use the real (lower case) name, or rename the column. For raw SQL use `selectRaw` and `whereRaw`.

**`orderBy` checks the direction.**
A direction that is not `asc` or `desc` now throws an `ArgumentError`. Before, it was put into the SQL.
Fix: only pass `asc` or `desc`.

**`toSql()` output changed.**
The where part is wrapped in brackets, and names are quoted.
Fix: update tests that compare SQL text.

**`count()` changed.**
It ignores `limit`, `offset` and `orderBy`.
With `groupBy` it returns the number of groups. Before, it returned the size of the first group.

**`model.delete()` and `model.forceDelete()` delete only that row.**
Before, they had no where condition and deleted **every row** of the table.

**`forceDelete()` also deletes soft deleted rows.**
`withTrash(false)` on a model without soft deletes no longer adds a `deleted_at` filter.

**Postgres uses a real pool.**
Each query no longer runs in its own transaction. Use [`QueryBuilder.transaction()`](../database/transactions.md) when you need one.

**`save()` can set a field to `null` on update.** Before, `null` fields were skipped.

**MySQL driver is now `mysql_dart` (was `mysql1`).**

- `extra['characterSet']` is not read any more. Use `extra['collation']` (default `utf8mb4_general_ci`).
- `TIME` columns are now a `String` (was a `Duration`).
- `BLOB` columns are now a `Uint8List` (was text).
- Only JSON columns are decoded to `Map`/`List`. MariaDB still decodes JSON-like text.
- `getDatabaseConnection()` returns a `MySQLConnectionPool`.
- A connection you pass to the migration package must be a `mysql_dart` `MySQLConnection` or `MySQLConnectionPool`.

**New:** SQLite, `whereNull`, `whereNotNull`, `whereNotIn`, `orWhereIn`, `orWhereNotIn`, `selectRaw`, `boolean()` column, transactions.
See [Database](../database/index.md).

## Migrations

**Rollback undoes only the last batch, newest first.**
Use `dox migration:rollback --step=2` for more. `migration:reset` undoes all. `migration:refresh` undoes all and runs them again.

**A failed migration stops the run.**
The command throws and the CLI exits with code 1. Each file runs in one transaction.

**`.sql` parsing is stricter.**
Only lines `-- up` and `-- down` start a section. A `;` inside quotes, comments or `$$` bodies does not split a statement.

**The `dox_migration` executable is gone.** Use the `dox` CLI.

See [Migration](../database/migration.md).

## Requests and responses

**Big uploads go to a temp file.**
A file over 1 MB is streamed to a temp file. The temp file is deleted when the response is sent.
Fix: save the file (`store`, `moveTo` or `stream`) before your controller returns.

**Body size limits.**
A JSON or urlencoded body over 10 MB, or a form-data body over 100 MB, gets `413 Payload Too Large`.
Fix: raise `maxBodySize` or `maxMultipartSize` in `AppConfig` if you need more.

**`RequestFile` changed.**

- The constructor takes `filename`, `filetype`, `length`, and `bytes` or `file`. The `stream` argument is gone.
- `size` is now right: it is the size in KB. Before, it added up the byte values.
- New: `length` (bytes), `stream()`, `moveTo()`, `file`.

**Cookie `Max-Age` is in seconds.**
Before, Dox sent milliseconds, so a 1 hour cookie lived 1000 hours.
`req.cookie()` now returns the decrypted value, and many cookies in one header work.

**CORS preflight.** An `OPTIONS` request with no route answers `204` with the CORS headers.

See [Request](request.md) and [Response](response.md).

## Server and config

**Isolates default to the CPU count (was 3).**
Each isolate has its own memory. Websocket rooms without a Redis adapter only reach clients on the same isolate.
Fix: use the Redis adapter, or set `totalIsolate: 1` (or `APP_TOTAL_ISOLATE=1`). See [Isolate](../digging-deeper/isolate.md).

**Real environment variables win over `.env`.**
Before, `Env.get()` only read the `.env` file. Now a variable set in the shell or in Docker wins.

**gzip is off by default.** Turn it on with `AppConfig(compress: true)`, or let your proxy do it.

**`dox build` makes an AOT binary in `build/server`.** See [Deployment](../digging-deeper/deployment.md).

## Validation

**A missing or `null` field skips its rules.**
Only `required`, `required_if` and `required_if_not` still run.
Before, `'status': 'in:active,inactive'` failed when `status` was not sent. Now it passes.
Fix: add `required` where the field must be sent. Use `nullable` and `sometimes` for the other cases.
See [Validation](validation.md).

## WebSocket

**Rooms use the plain room name.**
Emit to the same name the client sent with `joinRoom`. `room()` returns a new emitter and does not stay set for later events.

## Auth

**`attempt()` returns `null` when the email, the password or the stored hash is missing.**
Before, a login with only a password could match the first user in the table.

## CLI

**Generated names keep word breaks.**
`dox create:controller BlogPost` makes `blog_post.controller.dart` with class `BlogPostController`.
Generated models import `package:dox_orm/dox_orm.dart`.

**`create:model` no longer takes `-m`.**
Make the migration on its own: `dox create:migration create_blog_table`.

## Moving to the new packages (optional)

The built-in `Cache()` and `Storage()` in `dox_core` still work. If you move to the new packages, note:

- [`dox_cache`](../packages/cache.md): values must be JSON types. `put` with no ttl keeps the value **forever** (the old `Cache()` kept it 1 hour).
- [`dox_storage`](../packages/storage.md): a new `Disk` API with S3 and signed URLs.
- [`dox_validation`](../packages/validation.md): typed schemas. `v.fromRules()` takes your old rule strings.
