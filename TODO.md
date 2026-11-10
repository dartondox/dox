# Dox todo

How to read this file:

- Every item here is **not done**. When an item is done, delete it.
- An item says only what is left to do.
- The first line of an item is the task. The lines under it are details.
- `(HIGH)` = fix first. `(MED)` = fix soon. `(LOW)` = nice to have.
- `BREAKING` = it changes released behavior, so it waits for the next major release. No `BREAKING` tag = safe for a patch release.
- Paths start at the folder that holds all the Dox repos. So `dox/...` is this repo and `dox-orm/...` is the dox-orm repo.

Sections:

1. Next release
2. Next major release
3. Missing features
4. Laravel parity
5. Small fixes
6. Fuzzing

## 1. Next release

The release order is in `release.md`. Include every merged PR.

### Docs to write

- [ ] (LOW) Add `dispatchAfterResponse()` to the queue page
  - Say: no `await`; runs in the same process after the response; not queued, no job id, no retry; lost if the server stops; `Queue.fake()` does not catch it.
  - Link it from the `AfterResponse` part of middleware.md.

## 2. Next major release

Not for a patch release.

- [ ] Add TLS/HTTPS to the native server
  - Today a proxy is always needed.
  - Where: `dox-http-native/lib/src/server.dart:90`
- [ ] Add brotli, and compress streamed responses too
  - Where: `dox-http-native/lib/src/server.dart:541`
- [ ] Every item tagged `BREAKING` in section 4

## 3. Missing features

### Core / HTTP

- [ ] WebSocket: add permessage-deflate
- [ ] Add a sliding-window or token-bucket `RateLimit`
- [ ] Add a database session driver
- [ ] dox_cache: add a database cache store, so locks and sessions can be shared without Redis

### ORM / DB drivers

- [ ] `hasManyThrough` and `hasOneThrough`
- [ ] `cursor()` / `lazy()` streaming
- [ ] Read/write replica split
- [ ] Pool settings: a configurable request timeout (fixed 300s today), Postgres max connection age and idle timeout, query cancel

### Auth / OpenAPI

- [ ] Auth: `logoutOtherDevices`, and end sessions after a password change
- [ ] OpenAPI: add 401, 403 and 422 responses automatically for auth and validation middleware

### Queue / scheduler / Socket.IO

- [ ] Queue: batches, chains, unique jobs, rate limiting, job middleware, events
- [ ] Broadcasting: broadcast events, private and presence channels with an auth endpoint
- [ ] Socket.IO: an `allowRequest` hook and a session limit
- [ ] Scheduler: tasks that run more often than once a minute, `exec`/`command` tasks, a `job()` shortcut, output/ping hooks

### View / Inertia

- [ ] dox-view: `@extends` / `@section` / `@yield`, `@stack` / `@push`, `@csrf` / `@method`, custom directives
- [ ] Inertia: SSR. Make `clearHistory` and `encryptHistory` work

### CLI / sample app

- [ ] CLI: make:provider, make:view, make:mail, make:command, make:test, route:list
- [ ] Sample app: an auth starter, a web route example with session + CSRF, and dox-view or Inertia setup

## 4. Laravel parity

Compared with Laravel 12.x. Line numbers may have moved since the audit.

### dox_core

- [ ] (HIGH, BREAKING) Send 422 errors in the Laravel format
  - Now: a flat map with one string per field (`{"email": "..."}`). Laravel sends `{message, errors: {field: [all messages]}}`. Frontends built for Laravel cannot read it.
  - Safe first step: an opt-in Laravel format.
  - Where: `dox/packages/dox-core/lib/validation/request_validator.dart:85,94`, `dox/packages/dox-annotation/lib/src/core_annotation.dart:44-48`
- [ ] (HIGH, BREAKING) `req.only([...])`: leave out missing keys
  - Now: missing keys are added as `null`. So `model.update(req.only([...]))` writes NULL into columns the client never sent.
  - Where: `dox/packages/dox-core/lib/http/request/dox_request.dart:174-179`
- [ ] (HIGH, BREAKING) `DoxCookie`: default to `path=/` and `SameSite=Lax`
  - Now: no default `Path`, no `SameSite`, and a 1-hour `maxAge`. A cookie set on `/auth/login` is not sent to `/dashboard`.
  - Safe first step: warn, or opt-in defaults.
  - Where: `dox/packages/dox-core/lib/http/response/dox_cookie.dart:27-37`
- [ ] (HIGH, BREAKING) `req.has('x')`: only check that the key is there
  - Now: it is false for `''` or null, so it works like Laravel `filled`.
  - `filled`, `exists` and `missing` already exist. Only the change to `has` is left.
  - Where: `dox/packages/dox-core/lib/http/request/dox_request.dart:225-231`
- [ ] (MED, BREAKING) Send a string from a controller as `text/html`
  - Now: it is sent as `text/plain`.
  - Safe first step: add a `res.html()` helper.
  - Where: `dox/packages/dox-core/lib/http/http_response_handler.dart:154-155`
- [ ] (MED) `route()` / `Route.url()`: put extra params in the query string, add `absolute: true`
  - Now: it returns only the path, and an extra param throws `ArgumentError`. Laravel returns a full URL.
  - The `query:` param already exists.
  - Where: `dox/packages/dox-core/lib/router/route.dart:366,402-408`
- [ ] (MED) `Route.resource`: add a `parameter:` option
  - Now: the param is named `{id}`. Laravel uses the singular name (`{photo}`), so `Route.bind('photo', ...)` never runs on resource routes.
  - Where: `dox/packages/dox-core/lib/router/route.dart:878-902`
- [ ] (MED) Add an opt-in HTML error renderer
  - Now: errors are always JSON, even for browser page requests. Laravel shows an HTML page when the client does not want JSON.
  - Where: `dox/packages/dox-core/lib/http/http_response_handler.dart:129-144`
- [ ] (LOW, BREAKING) `res.header(k, v)`: replace the value
  - Now: it adds a second value.
  - Safe first step: a `replace:` flag.
  - Where: `dox/packages/dox-core/lib/http/response/dox_response.dart:140`
- [ ] (LOW, BREAKING) `session.regenerate()`: keep the CSRF token
  - Now: it also makes a new CSRF token, so forms open in other tabs get 419 after login. In Laravel `regenerateToken()` is separate.
  - Safe first step: `regenerate(keepToken: true)`.
  - Where: `dox/packages/dox-core/lib/session/session.dart:141-147`
- [ ] (LOW, BREAKING) `DecryptException`: answer 500 and report it
  - Now: it is a 400 and is not reported, so corrupt data looks like a client mistake.
  - Where: `dox/packages/dox-core/lib/utils/aes_encryptor.dart:11`
- [ ] (LOW) `.env`: add `${OTHER}` expansion, `\n` in double quotes, `export KEY=`
  - These three are safe.
  - Also: `KEY=` gives the default, Laravel gives `''`. Changing that is breaking.
  - Where: `dox/packages/dox-core/lib/env/env.dart:53,129-138`

### dox_cache

- [ ] (MED, BREAKING) `lock.block(timeout)`: throw on timeout
  - Now: with no callback it returns `false`. Code like `await lock.block(...); work();` runs without the lock. Laravel throws `LockTimeoutException`.
  - Safe first step: a new throwing method or flag.
  - Where: `dox/packages/dox-cache/lib/src/cache_lock.dart:55-57`
- [ ] (LOW, BREAKING) `Cache().store('x')` and `.tags()`: return a new object
  - Now: they change the same object, so a reused `Cache` stays on the last store.
  - Where: `dox/packages/dox-core/lib/cache/cache.dart:26-44`

### dox_orm (models and relations)

- [ ] (HIGH) Add public dirty tracking
  - Missing: `isDirty`, `isClean`, `getDirty`, `getOriginal`, `getChanges`, `wasChanged`, `wasRecentlyCreated`. The data is already in the model.
  - Where: `dox-orm/packages/dox-orm/lib/src/model.dart:118`
- [ ] (MED) Model query `update()`: set `updated_at`
  - Where: `dox-orm/packages/dox-orm/lib/src/model.dart:945`
- [ ] (MED, BREAKING) `save()` with no changes: do not fire `updating`/`updated`
  - Where: `dox-orm/packages/dox-orm/lib/src/model.dart:182`
- [ ] (MED) Instance `increment()`/`decrement()`: fire events and set `updated_at`, as opt-in
  - Where: `dox-orm/packages/dox-orm/lib/src/model.dart:356`
- [ ] (MED) Put relations loaded with `$getRelation()` in `toJson()`
  - Laravel includes relations loaded with `load()`.
  - Where: `dox/packages/dox-builder/lib/src/dox_builder.dart:474`, `dox-orm/packages/dox-orm/lib/src/model.dart:741`
- [ ] (MED) `preload()`: throw on an unknown relation, support dot nesting
  - Now: `preload('typo')` and `preload('posts.comments')` load nothing, with no error.
  - Where: `dox-orm/packages/dox-orm/lib/src/model.dart:761`
- [ ] (MED) Add `refresh()` and `fresh()` for the columns
  - Now: `reload()` reloads only relations.
  - Where: `dox-orm/packages/dox-orm/lib/src/model.dart:594`
- [ ] (MED, BREAKING) belongsTo: take the default foreign key from the relation name
  - Now: it comes from the class name. `@BelongsTo(User) User? author` uses `user_id`. Laravel uses `author_id`.
  - Where: `dox-orm/packages/dox-orm/lib/src/relationships/belongs_to.dart:30`
- [ ] (MED, BREAKING) Make the default table name plural
  - Now: `user`. Laravel: `users`.
  - Where: `dox-orm/packages/dox-orm/lib/src/model.dart:126`
- [ ] (MED) Add missing relation and model helpers
  - Relation writes that set the foreign key: `comments().create/save/saveMany`, `associate`, `dissociate`.
  - `trashed()` and the `trashed` event.
  - Eager-load constraints: `with({'posts': fn})`.
  - `makeHidden`, `makeVisible`, `visible`.
  - Where: `dox-orm/packages/dox-orm/lib/src/relationships/has_many.dart:31`, `dox-orm/packages/dox-orm/lib/src/soft_deletes.dart:5`
- [ ] (LOW, BREAKING) `create()`: write NULL for null keys
  - Now: null keys are dropped, so the column default is used.
  - Where: `dox-orm/packages/dox-orm/lib/src/model.dart:245`

### dox_orm (query builder)

- [ ] (MED, BREAKING) `sum()`: return 0 when no row matches
  - Now: it returns null.
  - Where: `dox-orm/packages/dox-orm/lib/src/count.dart:79`
- [ ] (MED, BREAKING) `selectRaw()`: add to the select list
  - Now: it replaces the list, so `select('a').selectRaw('count(*) c')` loses `a`.
  - Where: `dox-orm/packages/dox-orm/lib/src/select.dart:62`
- [ ] (MED, BREAKING) A second `groupBy()`: add to the first
  - Now: it replaces the first.
  - Where: `dox-orm/packages/dox-orm/lib/src/group_by.dart:27`
- [ ] (MED) Support JSON path columns (`meta->lang`) in `where`/`select`/`orderBy`
  - Now: `wrap()` throws.
  - Where: `dox-orm/packages/dox-orm/lib/src/drivers/db_driver.dart:146`
- [ ] (MED) Add join with a closure (several `on`/`orOn`/`where`) and `crossJoin`
  - Where: `dox-orm/packages/dox-orm/lib/src/join.dart:49`
- [ ] (MED) Add missing query methods
  - `orderByDesc`, `reorder`, `skip`, `forPage`, `sole`, `updateOrInsert`, `whereAny`/`whereAll`, bindings for `selectRaw`.
  - Where: `dox-orm/packages/dox-orm/lib/src/order_by.dart:23`, `dox-orm/packages/dox-orm/lib/src/limit.dart:82`
- [ ] (MED) Transactions: add deadlock retry (`attempts`) and manual `beginTransaction`/`commit`/`rollBack`
  - Where: `dox-orm/packages/dox-orm/lib/src/query_builder.dart:235`
- [ ] (LOW, BREAKING) `paginate()`: give `lastPage` 1 for no rows
  - Now: it gives 0.
  - Where: `dox-orm/packages/dox-orm/lib/src/get.dart:166`, `dox-orm/packages/dox-orm/lib/src/types/pagination_result.dart:33`

### dox_migration

- [ ] (MED) Schema: add `disableForeignKeyConstraints`/`enableForeignKeyConstraints`, `hasIndex`, `hasColumns`
  - Where: `dox-orm/packages/dox-orm/lib/src/schema.dart:64`
- [ ] (LOW, BREAKING) Postgres: make `timestamp` and `json` columns like Laravel
  - Now: `timestamps()`/`softDeletes()` make TIMESTAMPTZ and `json()` makes JSONB.
  - Where: `dox-orm/packages/dox-orm/lib/src/schema/table.dart:222`, `dox-orm/packages/dox-orm/lib/src/schema/grammars/postgres_grammar.dart:51`

### dox_validation

- [ ] (HIGH, BREAKING) Fluent schemas: turn `""` into null first
  - Now: with `req.validateSchema`, `""` passes `required`, and `.optional()` still runs `.email()` on `""`.
  - Safe first step: opt-in.
  - Where: `dox-validation/lib/src/core/schema.dart:184`
- [ ] (HIGH, BREAKING, LOW RISK) DTO: report all errors at once
  - Now: if one field is missing or has the wrong type, no other field's rules run.
  - Where: `dox/packages/dox-builder/lib/src/dto/dto_writer.dart:185`
- [ ] (MED, BREAKING) DTO: a required `List` field must reject `[]`
  - Where: `dox/packages/dox-builder/lib/src/dto/dto_writer.dart:174`
- [ ] (MED) DTO: add opt-in `@Dto(trim: true)`
  - Now: a DTO keeps spaces, so `"   "` passes `required` unless the field has `@Trim`. Laravel trims all input.
  - Where: `dox-validation/lib/src/dto/dto_state.dart:265`
- [ ] (MED, BREAKING) `Maybe` field: fail on `""`
  - Now: `""` counts as "not sent" and passes. Laravel `sometimes|required` fails on `""`.
  - Where: `dox/packages/dox-builder/lib/src/dto/dto_writer.dart:169`
- [ ] (MED) DTO: accept `"18"`, `"1"` and `1` for int/num/bool in a JSON body, as opt-in
  - Now: it only converts form and query text.
  - Where: `dox-validation/lib/src/dto/dto_state.dart:288`
- [ ] (MED) Add an attribute-names map for messages
  - Now: "The first_name is required". Laravel: "The first name field is required." No custom attribute names.
  - Changing the default text is breaking.
  - Where: `dox-validation/lib/src/constants/default_messages.dart:7`, `dox-validation/lib/src/core/parse_state.dart:81`
- [ ] (MED) Add Laravel rule names as aliases in the message lookup
  - Now: codes differ (`min_length` for `min`, `start_with`, `alpha_numeric`, `greater_than`, `min_items`, `mime_types`). A message key like `name.min` never matches.
  - Where: `dox-validation/lib/src/constants/issue_codes.dart:25`
- [ ] (MED, BREAKING) `alpha`, `alpha_num`, `alpha_dash`: accept Unicode letters
  - Now: ASCII only, so "José" fails.
  - Safe first step: opt-in.
  - Where: `dox-validation/lib/src/constants/patterns.dart:18`
- [ ] (MED) `@After`/`@Before`: accept another field and words like `today`; add `@AfterOrEqual`
  - Now: only an ISO date or `'now'`.
  - Where: `dox/packages/dox-builder/lib/src/dto/dto_model.dart:274,787`
- [ ] (MED) Add missing common rules
  - `accepted`/`declined`, `prohibited`/`prohibited_if`, `exclude_if`/`exclude_unless`, `required_unless`/`required_without`/`required_without_all`, `different`, `filled`, `present`, `ulid`, `bail`, compare with another field (`gt:field`).
  - Where: `dox-validation/lib/src/dto/dto_annotations.dart:420`
- [ ] (LOW, BREAKING) `in` message: say "The selected x is invalid."
  - Now: it lists every allowed value.
  - Where: `dox-validation/lib/src/constants/default_messages.dart:22`

### dox_auth

- [ ] (LOW, BREAKING) `authorize` and `Can`: give a guest 403
  - Now: 401.
  - Where: `dox-auth/lib/src/can_middleware.dart:31`
- [ ] (LOW, BREAKING) `AuthMiddleware(redirectTo:)`: give JSON and XHR clients 401
  - Now: it redirects them too.
  - Where: `dox-auth/lib/src/auth_middleware.dart:32`

### dox_queue

- [ ] (MED) Sync driver: serialize and read back the job, as opt-in
  - Now: a job missing from the registry or with non-JSON fields passes tests and fails in the worker.
  - Where: `dox-queue/lib/src/queue.dart:62`
- [ ] (MED) Let jobs call `release()`, `attempts()`, `fail()`, `delete()` inside `handle()`
  - Where: `dox-queue/lib/src/job.dart:49`
- [ ] (MED) Add opt-in `afterCommit`
  - Now: a job is pushed at once, so it can run before the commit or after a rollback.
  - Where: `dox-queue/lib/src/queue.dart:55`
- [ ] (MED) Add `onConnection()` and several queue connections
  - Now: one driver for the whole app.
  - Where: `dox-queue/lib/src/queue_config.dart:20`
- [ ] (LOW, BREAKING) `failed_jobs` table: add a `connection` column, store `failed_at` as a timestamp
  - Now: `failed_at` is in milliseconds.
  - Where: `dox-queue/lib/src/queue_tables.dart:42`

### dox_scheduler

- [ ] (MED) Add `schedule:clear-cache`
  - Now: after a crash, a `withoutOverlapping()` task is skipped for up to 24 hours.
  - Where: `dox-scheduler/lib/src/scheduler_runner.dart:52`

### dox_mailer

- [ ] (MED) `LogTransport`: write to the app log and show both bodies, as opt-in
  - Now: it uses `print`, and shows only one body (text or HTML).
  - Where: `dox-mailer/lib/src/transports/log_transport.dart:13,39`

### dox_storage

- [ ] (HIGH, BREAKING) `Storage().put(path, contents)`: write to that exact path
  - Now: the first arg is a folder and the file name is random. That is Laravel's `putFile`.
  - Safe first step: add `putFile`, `putFileAs` and an exact-path write.
  - Where: `dox-storage/lib/src/dox/storage.dart:116`
- [ ] (MED) `Storage()` facade: add the missing methods
  - `copy`, `move`, `files`, `allFiles`, `directories`, `deleteDirectory`, `missing`, `getVisibility`, `setVisibility`.
  - Now: you must call `use()` and then `listAll`/`deleteAll`.
  - Where: `dox-storage/lib/src/dox/storage.dart:84`
- [ ] (MED) `download(path)`: allow a download file name and headers
  - Where: `dox-storage/lib/src/dox/storage.dart:194`
- [ ] (MED) Local driver: make `setVisibility` do a chmod, as opt-in
  - Now: it does nothing and gives no error. `getVisibility` returns the disk setting.
  - Where: `dox-storage/lib/src/drivers/local_driver.dart:164`

### dox_cli

- [ ] (MED) `make:model`: accept `-m -c -r -f -s -a` and joined flags like `-mcr`
  - Now: only `-m`. `-mc` fails.
  - Where: `dox-cli/lib/src/command_registry.dart:93`
- [ ] (MED) `make:controller`: support `--resource`, `--api`, `--model`
  - Now: `--resource` makes a plain controller with no warning. Only `-r` works.
  - Where: `dox-cli/lib/src/command_registry.dart:181`

### dox_view

- [ ] (MED) Blade syntax: add aliases, or warn on Blade names
  - Now: `{!! !!}`, `@foreach`, `@endif`, `@forelse` print as plain text with no error. Dox uses Edge names (`{{{ }}}`, `@each`, `@end`), and Blade's `@each` means something else.
  - Where: `dox-view/lib/src/template_parser.dart:60`
- [ ] (MED, BREAKING) Print values like Blade
  - Now: `true` prints `true`, `false` prints `false`, `10.0` prints `10.0`. Blade prints `1`, nothing, `10`.
  - Where: `dox-view/lib/src/expression.dart:211`
- [ ] (MED) Add `@includeWhen`
  - Now: `@includeIf` means "include when true". In Blade it means "include if the view exists".
  - Changing `@includeIf` itself is breaking.
  - Where: `dox-view/lib/src/template_parser.dart:84`
- [ ] (MED) `@include`: pass data (`@include('view', {x: 1})`)
  - Now: it takes only the name.
  - Where: `dox-view/lib/src/template_parser.dart:82`
- [ ] (MED) Loop variable: add `iteration`, `count`, `remaining`, `even`, `odd`, `depth`, `parent`
  - Now: only `index`, `first`, `last`, `length`.
  - Where: `dox-view/lib/src/nodes.dart:177`
- [ ] (MED) Add a `@json` / `json()` helper
  - Now: `{{ map }}` prints Dart's `{a: 1}`. There is no safe way to pass data to JavaScript.
  - Where: `dox-view/lib/src/view.dart:96`
- [ ] (MED) Add an `@error('field')` directive
  - `errors` is already shared in every view.
- [ ] (LOW, BREAKING) Undefined variable: throw. `'0'`: false
  - Now: an undefined variable prints nothing, and `'0'` is true.
  - Where: `dox-view/lib/src/scope.dart:19`, `dox-view/lib/src/expression.dart:200`

### dox_inertia

- [ ] (MED) Add `withViewData()` and `setRootView()`
  - Now: the root view is a fixed HTML file, so no per-page title, meta tags or CSRF meta.
  - Where: `dox-inertia/lib/src/inertia.dart:67`

## 5. Small fixes

All items here are low. Grouped by repo.

### dox (dox_core, dox_builder, docs)

- [ ] dox-core test: add a request with no body (`BodyKind.none`)
  - The test "requestBody tells invalid JSON from no body" never sends one.
- [ ] `@OrDefault` fixes (dox#352 review)
  - Code: on `Maybe<int>` the build stops ("needs a default value or a nullable type"). Fix `!field.maybe && field.required` in dox_builder `dto_model.dart`, case 'OrDefault'.
  - Code or docs: async rules (`@Unique`, `@Exists`, `AsyncRule`) still give 422, but the docs promise the default.
  - Docs: `emptyStringsToNull` also gives `required` to a non-nullable field with a default.
  - Docs: "On a query field" reads as query-only.
  - Docs: the `@HexColor` row misses `short: true`.
  - Docs: "What the generator checks" misses the `@OrDefault` build error.
  - Docs: `@OrDefault` sits in the `@Dto` options table.
  - Tests: run a real DTO with these options in dox-core. Test `renderError` with `issues`.
- [ ] Server-Timing fixes (dox#367)
  - On routes with a next middleware, `_chain` wraps every controller in `ServerTiming.measure` even when the middleware is off. Check the zone first.
  - The dartdoc example in `server_timing.dart` shows `handler` first. The real order is `db, ..., handler, total`.
  - User code that adds `total` or `handler` sums into the built-in times. Reserve the names.
  - `res.header` replaces an app's own `Server-Timing` header. It should add to it.
  - production-checklist: "1-2 isolates is enough" -> "are enough".
  - Add a test for `measure` with an async function that throws.
- [ ] Changelog line for deep DTO errors (dox#369)
  - Say that apps may now see DTO errors at depth 2+ (`List<List<A>>`) that were skipped before.
- [ ] Docs fixes (dox#371)
  - `docs/the-basic/middleware.md`: the Server timing example shows no import for `SqlQueryBuilder`/`QueryEvent` (they come from dox_orm).
  - Same example: a second `setup()` adds the listener twice. Mention `removeListener`.
  - `docs/digging-deeper/file-storage.md`: the `directoryExists('')` line needs a blank line before it.
- [ ] `IsolateBus` / `AfterResponse` doc fixes (dox#370)
  - The `IsolateBus.publish` doc and changelog say it throws for a value that cannot be sent. In the main isolate with no other member it does not throw. Say "throws when another isolate is listening".
  - A blank line splits the dox_core `## Unreleased` list.
  - `AfterResponse` docs: say callbacks of one request run one after another, so one that never ends blocks the rest.
  - Remove the "Test:" changelog line. It is not for users.

### dox-orm

- [ ] Query listener fixes (dox-orm#44, dox#368)
  - A failed query is not sent to listeners or the slow log. Add this to the changelog and the docs page.
  - Internal calls (sqlite `sequence` reset in truncate, schema/migration DDL) skip the listener.
  - The slow-query test relies on a heavy query taking > 0 ms.
  - One long doc line in `database_config.dart`.
  - Docs: with `debug` on, a slow query logs twice.
- [ ] SQLite background mode fixes (dox-orm#46, dox#373)
  - Docs: a database that fails to open throws on the first query, not at startup.
  - `DATABASE_URL` cannot turn it on, because the sqlite branch of `fromUrl` drops query options. The docs (line ~224) say other URL options go to `extra`.
  - `extra['background']` must be a real bool. The string `'true'` does not work.
  - A plain query can slip into a transaction that starts in the same event-loop turn (also in default mode).
- [ ] Add a test for `--force` placed before `--step` in `Migrator.run` (dox-orm#45)
- [ ] `pivot` key (dox-orm#45)
  - `pivot` is a new key in API answers of many-to-many rows (same as Laravel; hide with `hidden`).
  - A model with a real column named `pivot` gets it overwritten.

### dox-cli

- [ ] `dox make:migration`: format `db/migration/migrations.dart` after writing it
  - Now `dart format` changes the file (dox-sample#19).
- [ ] `queue:prune-failed` passes a second extra word on to dox_queue (dox-cli#18)

### dox-validation

- [ ] `DtoSchema.run`: use `state.keepValues = usesRequiredWhen` (dox-validation#18)
  - Now it only ever sets `keepValues` to false. A reused `DtoState` that was turned off stays off for a rules DTO.

### dox-queue / dox-mailer

- [ ] `dispatchAfterResponse` tests (dox-queue#22)
  - Add a test for a job that throws (`failed()` called, error reported).
  - The "outside a request" test waits only 10 ms. It can fail on slow CI.
  - `Queue.fake()` does not record `dispatchAfterResponse` (same as `dispatchSync`).
- [ ] Add tests for the warning in `Queue.retryUntilOf()` and for `Queue.retriedPayload()` (dox-queue#21)
- [ ] dox-mailer: the stderr fallback for the hook error log catches only `Error`, not `Exception` (dox-mailer#18)

### dox-auth / dox-storage

- [ ] dox-auth: reset `_requestToken` in `once()`/`attempt()` (dox-auth#18)
  - Now `logout()` can still revoke the old request token.
  - Where: `lib/src/auth.dart:73`
- [ ] dox-storage: `storeAs` returns the cleaned key (dox-storage#14)
  - It differs from the raw name only for names already changed on disk.

### dox-view

- [ ] Parser fixes (dox-view#10)
  - `@empty (none)` alone on its own line still throws (documented).
  - `_hasEnd` and `_opensBlock` call each other, so many nested spaced tags could get slow.

### dox-socketio

- [ ] A closed `IsolateAdapter` keeps its bus listener until `IsolateBus.close()` (dox-socketio#18)
  - An app that opens and closes many servers in one isolate piles up listeners.

### Native drivers (http, postgres, mysql)

- [ ] dox-postgres-native: the skip error in `lib/src/pool.dart` should say "the app's root pubspec.yaml"
  - Now it says "in pubspec.yaml". Same fix as dox-mysql-native#19.
- [ ] dox-postgres-native: name host and port in auth and SSL connect errors (dox-postgres-native#17)
- [ ] dox-mysql-native: `is_ddl` does not handle `NO_BACKSLASH_ESCAPES` (dox-mysql-native#19)
  - Only effect: a missed schema count.
- [ ] dox-http-native: the Rust test `idle_timeout_comes_from_the_limits` fails sometimes in a parallel run (timing)

### ioredis

- [ ] `onError` and `setSocket` fixes (ioredis#24)
  - One reset can call `onError` 2-3 times.
  - One socket error can reach `onError` twice (stream onError and socket.done).
  - `setSocket()` on an already connected connection is not watched for write errors.
  - A `setSocket` fake whose `done` is null now throws in `_connect`.

### dox-mcp

- [ ] OAuth tests (dox-mcp#4 review)
  - The expiry test waits 2 seconds. Use a fake clock.
  - Add tests that a verifier of exactly 43 and 128 characters works.
  - `invalid_client` answers 400. RFC 6749 5.2 suggests 401.

### dox-sample

- [ ] SKILL.md recipes (dox-sample#19 review)
  - Recipe 4 puts the `/posts` routes in a middleware group but does not say to remove them from recipe 1. An AI may add them twice.
  - Recipe 1 needs the `Post` model of recipe 2. Put the model recipe first.
- [ ] dox-sample + dox-test: in the examples, put the `app/models` import before `app/serializers` (dox-sample#20, dox-test#39 review)

### CI scripts

- [ ] `ci/system-sqlite.sh`: merge `sqlite3: source: system` into an existing `hooks:` block
  - Now a pubspec that already has a `hooks:` block (the new dox-sample template has one) only gets a warning. CI that runs this script on the template still downloads SQLite.
  - dox already does the merge. dox-orm, dox-cli, dox-auth, dox-queue still only warn.

### dox-test (test suite only)

- [ ] `Inertia.shareGlobal` in e2e_310b_packages.dart stays set for the rest of the run
  - dox_inertia has no way to remove a global. Harmless now. It matters if Inertia tests run after `packages310bTests`.
- [ ] The production `schedule work` test could run `prune-failed-jobs` if it starts slowly across 17:00 UTC
  - Rare. It only flushes test data.
- [ ] The ioredis socket test calls `redis.disconnect()` inside the zone body, not in a `finally` (dox-test#34)
- [ ] Storage and queue tests (dox-test#33)
  - Two storage signed-URL tests use files from earlier tests. They fail when run alone.
  - In the queue group tearDown, a throwing `flush()` skips `Queue.restore()` and the config reset.
  - The Markdown link check is only `isNot(contains('href="javascript'))`.
  - The scheduler warning tests skip quietly when APP_ENV is a real env variable.
- [ ] ORM tests (dox-test#31)
  - `expect(results.length, 21)` always passes. The real check is that Future.wait does not throw.
  - `throwsA(anything)` could check the driver exception type.
  - The two nested transaction tests overlap.
  - `core.dto.g.dart` and `system.dto.g.dart` are out of date on main.
- [ ] e2e tests (dox-test#32)
  - Move the isolate server start to setUpAll.
  - Cookie tests reuse `web` from an earlier test, and socket.io reuses the dox_auth user (order dependence).
  - The `--uuid and --string-ids` test runs only `--uuid`.
  - The duplicate-cookie test checks only 200.
  - The socket logout test does not check the login 200.
  - The `/ping` wait loop has no delay on a non-200.

## 6. Fuzzing

For the Scorecard check "project is not fuzzed". Scorecard does not support Dart, so `dox` itself cannot pass this check. Add `cargo-fuzz` targets (`fuzz_target!`) in the Rust native repos instead. Scorecard detects these.

- [ ] (MED) dox-http-native: fuzz the code that reads raw HTTP requests
  - Request line, headers, chunked body. This is the best place for fuzzing.
- [ ] (LOW) dox-postgres-native: fuzz the code that reads data from the database server
  - Wire protocol messages, row values.
- [ ] (LOW) dox-mysql-native: fuzz the code that reads data from the database server
  - Packets, result rows.
