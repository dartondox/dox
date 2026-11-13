---
date:
  created: 2026-11-13
authors:
  - dox
categories:
  - Releases
tags:
  - release
slug: dox-3-2
---

# Dox 3.2 is out

Dox 3.2 adds `dox add` to set up a package with one command, read replicas, streaming queries, model dirty tracking, job batches and chains, a database cache store, broadcasting for Socket.IO, sub-minute schedules, layouts in views, and many more features and fixes.

<!-- more -->

Every Dox package is released as 3.2.0. This includes `dox_http_native`, `dox_postgres_native`, `dox_mysql_native` and `ioredis`.
Two packages are new: `dox_cache_database` and `dox_queue_database`.

## How to update

1. Update the `dox` CLI:

    ```bash
    dox update
    ```

2. In your `pubspec.yaml`, set every Dox package to `^3.2.0`, then get them. Do not mix versions.

    ```bash
    dart pub upgrade
    ```

3. Make the [Breaking changes](#breaking-changes) that apply to your app.
4. Make the generated code again:

    ```bash
    dox build_runner:build
    ```

### Update with an AI agent

You can also let your AI coding agent do the update. Copy this prompt into it:

```text
Update this Dox app to Dox 3.2.

1. Read the release post: https://dartondox.dev/blog/dox-3-2/
   Follow the "How to update" steps and every item in "Breaking changes"
   that applies to this app. Also check the "Rare cases" list.
2. Set every Dox package in pubspec.yaml to ^3.2.0 and run
   `dart pub upgrade`. Make the breaking changes, then run
   `dox build_runner:build`.
3. Run `dart run skills@ get --all` to get the Dox 3.2 agent skills, and use
   them for the code changes.
4. Run `dart analyze` and `dart test`. Fix every error.
5. Do not change app behaviour that is not part of the update.
   At the end, list what you changed and anything I must check by hand,
   like log dashboards that read the old JSON field names.
```

## New

### Add a package with one command

`dox add` adds a Dox package and sets it up: config files, provider, `bin/` file, migrations and `.env` keys. It never overwrites a file, so you can run it again.

```bash
dox add orm --driver=postgres
dox add queue
dox add mailer --transport=smtp
```

It works for `orm`, `queue`, `scheduler`, `mailer`, `cache`, `auth`, `storage`, `socketio`, `view`, `inertia` and `mcp`. Each package ships its own setup command, so a package you write can have one too.

Docs: [Add a package](/latest/getting-started/add-a-package/)

### Opt-in flags

Behaviors that change old results are opt-in. Each package has a flags class. Every flag is off by default, so nothing changes until you turn one on. `.all()` turns on all of them.

- `CoreFlags` (in `AppConfig(flags: ...)`): `envExpand`, `onlyPresent`, `cookieDefaults`, `hasKeyOnly`, `htmlStrings`, `replaceHeaders`, `decryptServerError`, `cacheCopies` and a flag for the shape of a `422`.
- `OrmFlags` (in `DatabaseConfig(flags: ...)`): `skipCleanUpdateEvents`, `belongsToKeyFromRelation`, `pluralTableNames`, `createWritesNull`, `sumReturnsZero`, `selectRawAdds`, `groupByAdds`, `lastPageAtLeastOne`, a Postgres column type flag, `toJsonLoadedRelations`, `preloadUnknownThrows`, `updateSetsUpdatedAt` and `incrementFiresEvents`.
- `AuthFlags` (in `AuthConfig(flags: ...)`): `forbidGuest`, `jsonNoRedirect` and `endSessionsOnPasswordChange`.
- `ValidationFlags` (`Validator.flags = ...`): `emptyStringsToNull`, `unicodeAlpha`, `shortInMessage`, a message key flag, `dtoAllErrors`, `dtoRejectEmptyList` and `dtoMaybeRejectsEmpty`.
- `CacheFlags` (in `CacheConfig(flags: ...)`): `lockThrows`.

Docs: [Core flags](/latest/reference/app-config/#core-flags), [ORM flags](/latest/database/#orm-flags), [Validation flags](/latest/packages/validation/#opt-in-flags), [Auth flags](/latest/security/authorization/#auth-flags)

### ORM and database

- Read replicas: `ConnectionConfig(read: [...], write: {...}, sticky: ...)`. A plain `SELECT` goes to a read host. Writes, locks and transactions go to the write host. `query.onWriteConnection()` forces the write host.
- Streams: `query.cursor()` reads rows from one query as you are ready for them, so a big result does not fill the memory. `query.lazy()` and `lazyById()` read in chunks. `DBDriver.stream()` is the driver call under them.
- Cancel a running query with `QueryCancelToken` and `query.cancelWith(token)` (Postgres and MySQL).
- Pool settings in `extra`: `requestTimeout`, `maxConnectionAge`, `idleTimeout` and `serverKill`.
- Relations: `@HasManyThrough` and `@HasOneThrough`. `preload('posts.comments')` with a dot path, and `preload(name, where)` with conditions. `createRelated()`, `saveRelated()` and `saveManyRelated()` set the foreign key for you.
- Dirty tracking: `isDirty()`, `isClean()`, `getDirty()`, `getOriginal()`, `getChanges()`, `wasChanged()` and `wasRecentlyCreated`.
- `refresh()` reads the row again in place. `fresh()` gives a new model.
- `visibleFields` (the opposite of `hidden`), `makeHidden()` and `makeVisible()`.
- `trashed()` and a new `trashed` model event, with `onTrashed()` and `TrashedObserver`.
- `toJson()` of a many to many model has a `pivot` key.
- Transactions: `transaction(callback, attempts: n)` runs again on a deadlock. `beginTransaction()` gives a transaction you commit or roll back yourself. `QueryBuilder.afterCommit(callback)` runs work after the commit.
- Logging: `SqlQueryBuilder().listen(listener)` runs after each query. `slowQueryMs` logs slow queries. `PrettyQueryPrinter` prints each query on one line, with the values in the SQL.
- SQLite: `extra: {'background': true}` runs queries in a helper isolate, so one slow query does not stop the other requests.
- Query builder: JSON paths like `where('meta->lang', 'en')`, join callbacks (`JoinClause`), `crossJoin()`, `orderByDesc()`, `reorder()`, `skip()`, `forPage()`, `sole()`, `updateOrInsert()`, `whereAny()`, `whereAll()` and `selectRaw(sql, params)`.
- Schema: `.collation()`, `hasColumns()`, `hasIndex()`, `disableForeignKeyConstraints()`, `enableForeignKeyConstraints()` and `withoutForeignKeyConstraints()`.
- Migrations: `rollback --batch=3`. `Migrator(flags: ...)`. Migration queries reach the query listeners and the slow query log.
- Postgres and MySQL native: `PgCancelToken` and `MysqlCancelToken`, `stream()` in chunks, and the host and port in connect errors.

```dart
// rows one by one, with a small memory use
await for (Blog blog in Blog().orderBy('id').cursor()) {
  print(blog.title);
}

// posts, and the comments of those posts
List<User> users = await User().preload('posts.comments').get();
```

Docs: [Replicas](/latest/database/replicas/), [Transactions](/latest/database/transactions/), [Query builder](/latest/database/query-builder/), [Model](/latest/database/model/), [Has many through](/latest/database/model/relationship/through/), [Schema](/latest/database/schema/), [Migration](/latest/database/migration/)

### Queue

- New package `dox_queue_database`: the `database` driver, batches, `afterCommit`, `QueueTables` and `dox queue:table`. `DatabaseQueueProvider` sets it up for you.
- The generated `jobs.g.dart` now also lists the mail jobs of `dox_mailer`, so a worker knows them without extra setup.
- `QueueConfig(inProcess: true)` runs a worker inside the web server. It is the same name as `ScheduleConfig(inProcess:)`. The old name `workInProcess` still works, but is deprecated.
- Job batches: `Queue.batch(jobs)` with `then`, `catchError`, `whenComplete`, `progress`, `allowFailures()` and `cancel()`. A batch can hold chains. They need `dox_queue_database`.
- Job chains: `Queue.chain(jobs)`. The next job is pushed when the one before is done. If one fails for good, the rest is dropped and a catch job runs.
- Job middleware: `HasMiddleware`, `RateLimited`, `WithoutOverlapping` and `ThrottlesExceptions`.
- Unique jobs: `ShouldBeUnique` and `ShouldBeUniqueUntilProcessing`.
- `InteractsWithQueue`: `attempts()`, `release()`, `fail()` and `delete()` inside `handle()`.
- Queue events: `Queue.queued()`, `before()`, `after()`, `released()`, `exceptionOccurred()`, `failing()` and the batch events.
- `dispatch(afterCommit: true)` and `QueueConfig(afterCommit: true)`. They need `dox_queue_database`.
- `dispatchAfterResponse()` runs a job after the response is sent.
- Named connections: `QueueConfig(connections: {...})`, `dispatch(connection: ...)` and `--connection=NAME`. `failed_jobs` gets a nullable `connection` column. A table without it keeps working.
- `QueueConfig(failedAtTimestamp: true)`, `QueueConfig(serializeSync: true)` and `Queue.extend(name, factory)`.
- `Queue.fake()` keeps `dispatchedSync` and `dispatchedAfterResponse`.

Docs: [Queue](/latest/digging-deeper/queue/), [Background work](/latest/guides/background-work/)

### Cache

- New package `dox_cache_database`: a cache store on SQLite, Postgres, MySQL and MariaDB. It keeps items, locks and sessions in a table. Register it with `Dox().cache.extend('database', DatabaseCacheDriverFactory(encrypter))`. `dox cache:table` writes the migration. A write that hits a deadlock runs again after a short wait.
- `'encrypt': true` on a store encrypts its values with the `APP_KEY`. It works for `file`, `redis` and the database store.
- `CacheLock.throwOnTimeout` and the `CacheFlags.lockThrows` flag: `lock.block(timeout)` throws `LockTimeoutException`.

Docs: [Cache](/latest/packages/cache/), [Cache in the app](/latest/digging-deeper/cache/)

### Core

- `RateLimit(sliding: true)` uses a sliding window.
- `.env` files: `${OTHER}` values (with `CoreFlags.envExpand`) and `export KEY=value` lines.
- `AppConfig(htmlErrors: true)` sends a small HTML error page to a client that does not want JSON. `AppConfig(errorPage: ...)` replaces the page.
- `Route.resource(..., parameter: 'photo')` names the param of one item.
- `route()` and `Route.url()` put a param that is not in the path into the query string. `absolute: true` gives the full URL.
- `Dox().addGlobalMiddleware()` lets a provider add global middleware.
- `Dox().loadRoutes()` gives the routes with no server. `RouteData.isWebSocket` marks WebSocket routes.
- `res.header(k, v, replace: true)`, and `session.regenerate(keepToken: true)`.
- `ServerTiming` middleware, `ServerTiming.add()` and `ServerTiming.measure()`.
- `AfterResponse.run(work)` runs work after the response is sent.
- The `JSON` helper: `JSON.stringify`, `JSON.bytes` and `JSON.parse`.
- OpenAPI answers: a route with `Can`, `GuestMiddleware`, `ValidateSignature`, `req.authorize()`, `Gate.authorize()` or `req.validateSchema()` gets the `401`, `403` or `422` answer in the docs. A `@Response` with the same status wins.

Docs: [Routing](/latest/the-basic/routing/), [Rate limiting](/latest/security/rate-limiting/), [Environment](/latest/digging-deeper/env/)

### Validation and DTOs

- New rules, each as a fluent rule and a DTO annotation: `requiredUnless`, `requiredWithout`, `requiredWithoutAll`, `filled`, `present`, `prohibited`, `prohibitedIf`, `accepted`, `declined`, `different`, `ulid`, `afterOrEqual` and `beforeOrEqual`, and the field compare rules.
- `@After` and `@Before` take `'today'`, `'tomorrow'`, `'yesterday'` and the key of another `DateTime` field.
- `@ExcludeIf` and `@ExcludeUnless`, and `.excludeIf()` and `.excludeUnless()` for fluent objects.
- `.bail()` stops the other rules of a schema at the first failure.
- `@Dto(trim: true)` trims text. `@Dto(coerce: true)` lets JSON send `"18"` or `"true"`. `@Dto(attributes: {...})` names the fields in messages.
- DTOs that have no `@RequiredIf` or `@RequiredWith` field are faster.

Docs: [Validation](/latest/the-basic/validation/), [Validation rules](/latest/the-basic/validation-rules/)

### Auth

- `Auth().logoutOtherDevices(req, password)` ends the other sessions of the user. It needs the `endSessionsOnPasswordChange` flag.
- `Auth().updateSessionPasswordHash(req, user)` keeps the current session after your own password change.
- `Auth().rotateAccessToken()` makes a new access token in place of an old one, with an optional `grace` time. It needs a nullable `rotated_at` column. `dox auth:tokens-table` adds it to new tables. For an old table, add it in a new migration.
- `Auth().setAccessTokenAbilities()` changes the abilities of a token.
- `AccessTokenAuthDriver(throwOnError: true)` sends a token check error to your `ExceptionHandler`, so the app can answer `503`.

Docs: [Authentication](/latest/security/authentication/)

### Scheduler

- Sub-minute tasks: `everySecond()`, `everyFiveSeconds()`, `everyThirtySeconds()` and more.
- `schedule.exec(executable, args: [...])` runs a process with no shell. `schedule.command('queue:work')` runs a `dox` command.
- Output hooks for these tasks: `sendOutputTo()`, `appendOutputTo()` and `onOutput()`.
- Ping hooks: `pingBefore()`, `thenPing()`, `pingOnSuccess()` and `pingOnFailure()`, and the `If` forms.
- `dox schedule:clear-cache` removes the overlap locks that a crash left behind.

Docs: [Scheduler](/latest/digging-deeper/scheduler/)

### Socket.IO

- Broadcasting, off by default. Turn it on with `SocketIoConfig(broadcasting: true)`. `Broadcast.channel()` adds rules for private and presence channels. `ShouldBroadcast` and `broadcast(event)` send events. `Broadcast.routes()` adds `POST /broadcasting/auth`. `Broadcast.fake()` is for tests.
- Queued broadcasting with `ShouldBroadcastQueued` and `Broadcast.useQueue()`. It does not depend on `dox_queue`.
- Whisper: client to client events on private and presence channels, with `whisper: true`.
- `ServerOptions(allowRequest:)` and `ServerOptions(maxSessions:)`.

Docs: [Broadcasting](/latest/digging-deeper/broadcasting/), [Socket.IO](/latest/packages/socketio/)

### Mail

- `LogTransport(bothBodies: true)` shows the text body and the HTML body.
- Queued mail lives in `dox_mailer` now. `Mail.queue()` and `Mail.later()` use `dox_queue` by default. `Mail.configure()` registers the mail jobs for the worker.

Docs: [Mail](/latest/digging-deeper/mail/)

### Storage

- `Storage().put(path, contents, exact: true)` writes to that exact path.
- `putFile()` and `putFileAs()`.
- `copy`, `move`, `files`, `allFiles`, `directories`, `deleteDirectory`, `missing`, `getVisibility` and `setVisibility` on `Storage()`.
- `Storage().download(path, name: ...)` sets the name that the browser saves.
- Local disk `permissions: true` makes visibility a file mode. It is off by default and does nothing on Windows.

Docs: [File storage](/latest/digging-deeper/file-storage/)

### Views

- Layouts: `@extends`, `@section` and `@yield`.
- `@stack`, `@push` and `@prepend`.
- `@csrf` and `@method('PUT')`.
- Your own tags: `View.directive('datetime', DateTimeDirective())`.
- `@include('card', {...})` with variables, `@includeWhen`, `@json` and `@error`. Every template has a `json()` function. A variable named `json` in your data still wins.
- More `$loop` fields: `iteration`, `count`, `remaining`, `even`, `odd`, `depth` and `parent`.
- `$attributes.except([...])`.
- Options in `ViewConfig`: `strictVariables`, `stringZeroIsFalse` and `bladeOutput`. All are off by default.
- A warning for tags that Dox does not have, like `@foreach`. `bladeWarnings: false` turns it off.

Docs: [Views](/latest/the-basic/views/)

### Inertia

- `Inertia.withViewData(req, data)` gives values to the root view. `{{ csrfToken }}` is filled for you.
- `Inertia.setRootView()` and `RootViewMiddleware` use another root view.
- Server side rendering: `ssr: InertiaSsr()` in `InertiaConfig`. If the SSR server is down, the normal page is sent.
- History encryption with `encryptHistory: true`, and `Inertia.clearHistory(req)`.

Docs: [Inertia](/latest/the-basic/inertia/)

### OpenAPI, MCP and CLI

- OpenAPI: `ApiDoc.route()` takes `paramResponses`. A model `visibleFields` list is read for the schema.
- MCP: `McpOAuth(now:)` takes a fake clock for tests.
- CLI: `dox route:list` (and `--json`), `make:provider`, `make:command`, `make:mail`, `make:view` and `make:test`.
- CLI: `make:model` takes `-m`, `-c`, `-r`, `--api`, `-f`, `-s` and `-a`. `make:controller` takes `--resource`, `--api` and `--model`.

Docs: [CLI](/latest/reference/cli/), [Package commands](/latest/digging-deeper/package-commands/)

### AI skills

Most packages now ship an AI agent skill, like `dox-core-guide` and `dox-orm-guide`. `skills get` finds the packages in your `pubspec.yaml`, so list `dox_cache`, `dox_validation` and `dox_openapi` there too to get their skills. Install them in your app:

```bash
dart run skills@ get --all
```

A 3.1 app can delete the old `.agents/skills/dox` folder and the `.claude/skills/dox` link.

## Breaking changes

These are the changes that most apps need to act on.

- **Upgrade the Dox packages together.** The new `dox_builder` finds providers in `dox_annotation`, so an old `dox_builder` does not find them. The native drivers changed too, so upgrade `dox_postgres_native` and `dox_mysql_native` together with `dox_orm`.
- **New field names in the JSON logs.** In `Logger` lines, `level` is now `status` and `name` is now `logger.name`. The values are lower case now (`info`, `warn`, `danger`). In `LogMiddleware` lines, `source_ip` is now `network.client.ip` and `request_id` is now `http.request_id`. Check your log parsers and dashboards. `LogMiddleware` now also follows `LoggerConfig`: with the logger off, or its `level` above `info`, no request lines are written.
- **The database queue moved to its own package.** Only apps that use the `database` queue driver need these steps:

    1. Add the package:

        ```bash
        dart pub add dox_queue_database
        ```

    2. Make `AppQueueProvider` extend `DatabaseQueueProvider` in place of `QueueProvider`:

        ```dart
        import 'package:dox_queue_database/dox_queue_database.dart';

        class AppQueueProvider extends DatabaseQueueProvider {
          AppQueueProvider() : super(queueConfig);
        }
        ```

        Remove the old `package:dox_queue/dox_queue.dart` import if nothing else uses it.
        If you skip this step, the app still builds and starts. The first `dispatch()` then fails, so check it by hand.

    3. In your `create_queue_tables` migration, import `package:dox_queue_database/dox_queue_database.dart`.
    4. Only if you want job batches: add a new migration that calls `QueueTables.upBatches(schema)`.

    Mail jobs that are already in a queue keep their names, so they still run.

- **The scheduler process no longer runs queue jobs.** In 3.1, `bin/schedule.dart` also started a queue worker when the in-process worker was on. Now only the web server (`QueueConfig(inProcess: true)`) or `bin/queue.dart` runs jobs. If your jobs only ran in the scheduler process, start a worker.
- **`maxConnectionAge` is a real age now.** On MySQL, a connection older than this closes when it is next free, even if it was busy. Before, it was the idle time. Use `idleTimeout` for the idle time. Postgres now uses this option too.

### Rare cases

Most apps are not affected by these. Check them if your app does one of these things.

- **A model field with the name of a new query method** (`skip`, `sole`, `reorder`, `forPage`, `orderByDesc`, `updateOrInsert`, `whereAny`, `orWhereAny`, `whereAll`, `orWhereAll`, `crossJoin`) does not compile. Rename the Dart field and keep the column name with `@Column(name: ...)`. The table does not change:

    ```dart
    @Column(name: 'skip')
    int? skipCount;
    ```
- **MySQL behind a proxy with its own connection ids**, like ProxySQL: a timed out query now gets a `KILL`, so set `serverKill: false`. Each new connection also runs one small query to learn the server name.
- **The job code generator moved to `dox_builder`.** Upgrade `dox_builder` and `dox_queue` together. If your `build.yaml` names `dox_queue:jobs`, change it to `dox_builder:jobs`. A plain Dart app needs `dart pub add dev:dox_builder`.
- **Nested DTOs deeper in lists and maps are now checked**, like `List<List<A>>`. Such a DTO can now give validation errors.
- **View text like `@json(...)` or `@error(...)`** is now a tag. To print it as text, write `@@json(...)`.
- **`RedactedMailError`** is now imported from `package:dox_mailer/dox_mailer.dart`.
- **`Queue.fake()`** no longer catches a custom queue set with `Mail.useQueue()`.
- **Custom queue drivers:** call `Queue.retriedPayload()` in place of `JobPayload.retried()`.
- **`Logger` writes in groups**, every 20 ms or 64 KB. Warnings and errors are still written at once.
- **The native HTTP server refuses broken requests** that used to pass, like `Transfer-Encoding` in an HTTP/1.0 request, or a method like `GOT` that came in as `GET`.
- **MCP:** the token route answers `401` for `invalid_client`, not `400`.
- **OpenAPI:** operation ids that clashed for optional routes now both use the long form.

## Fixes

### Security

- Native HTTP: `Transfer-Encoding` in an HTTP/1.0 request or in two headers is refused. A proxy in front could read the body another way (request smuggling).

### Routing and core

- `Route.group`, `Route.domain`, `Route.middleware` and the CORS helpers restore their state when the callback throws. Before, the next routes got the wrong path or middleware.
- `Dox().stop()` closes the `IsolateBus` again, so the process can end.
- Pretty `Logger` lines for `debug`, `warning` and `error` have a color.

### ORM and database

- `orWhere` inside `whereHas`, `withCount` and `preload` callbacks no longer matches rows of other parents.
- When the UPDATE of `save()` fails, the model stays dirty, so the next `save()` sends the changes again.
- `chunk()` with an `orderBy()` on a column that is not unique no longer reads a row twice or skips one.
- `transaction(connection: 'main')` with the name of the default connection now joins the transaction.
- `insertGetId()` drops keys that `fillable` and `guarded` do not allow, before it looks for the id.
- SQLite: a plain query no longer runs inside a transaction that started in the same event-loop turn.
- Postgres native: a query that times out now gets a CancelRequest. A wrong DataRow is refused. A server error that is not UTF-8 no longer hides the real error. A query in a hand-opened transaction is not sent again after a "cached plan" error.
- MySQL native: a schema change inside a multi-statement query is seen. `--` with no space is not a comment. A backslash is read both ways with `NO_BACKSLASH_ESCAPES`. A bad auth switch, a huge column name, a result over 4 GiB, a text that is not UTF-8 and a bad JSON value no longer stop the process or hang the request.
- Native drivers: each download try of the native library has a 60 second limit.

### Packages

- **Builder:** `@OrDefault()` on a `Maybe<T>` field no longer stops the build.
- **Queue:** the worker now stops on SIGTERM when Redis is down. A job that a late pop returns is released back to the queue.
- **Auth:** after `once()` or `attempt()` logs in another user, the access token of the request is dropped. So `revokeToken()` and `tokenCan()` use the right user.
- **Mail:** an error in an `onSent` hook no longer fails `send()` after the email was sent. In a queue worker, it no longer sends the email again.
- **Scheduler:** `schedule list` shows `between()`, `unlessBetween()` and `environments()`.
- **Socket.IO:** a closed `IsolateAdapter` no longer piles up listeners, and no longer makes other isolates wait 5 seconds in a shutdown.
- **Storage:** `copy()` and `move()` of a missing file throw `FileNotFoundException` and make no folders. `size()` and `lastModified()` of a missing file answer 404, not 500. `directoryExists('')` is true on every disk. `storeAs()` and `putRequestFileAs()` return the stored key.
- **Views:** text like `@empty (none)` or `@class (see docs)` no longer throws. Many nested tags with a space before the `(` no longer parse very slowly. Spaces after the last tag are removed.
- **Inertia:** an empty `200` that goes back to the page keeps the headers and cookies of the controller.
- **MCP:** the token route gives `invalid_grant`, not `500`, when a lock of a code times out. A code now ends exactly after `codeTtl`.
- **Redis client:** one socket failure calls `onError` once. `setSocket()` on a connected client uses the new socket.

## Full list

Every change is in the changelogs:

- The [Changelog](/latest/reference/changelog/) page of the docs (`dox_core`, `dox_builder`, `dox_annotation`, `dox_cache`, `dox_cache_database`).
- GitHub releases: [dox](https://github.com/dartondox/dox/releases), [dox-orm](https://github.com/dartondox/dox-orm/releases), [dox-auth](https://github.com/dartondox/dox-auth/releases), [dox-validation](https://github.com/dartondox/dox-validation/releases), [dox-mcp](https://github.com/dartondox/dox-mcp/releases), [dox-cli](https://github.com/dartondox/dox-cli/releases), [dox-queue](https://github.com/dartondox/dox-queue/releases), [dox-mailer](https://github.com/dartondox/dox-mailer/releases), [dox-scheduler](https://github.com/dartondox/dox-scheduler/releases), [dox-storage](https://github.com/dartondox/dox-storage/releases), [dox-socketio](https://github.com/dartondox/dox-socketio/releases), [dox-view](https://github.com/dartondox/dox-view/releases), [dox-inertia](https://github.com/dartondox/dox-inertia/releases), [dox-openapi](https://github.com/dartondox/dox-openapi/releases), [dox-http-native](https://github.com/dartondox/dox-http-native/releases), [dox-postgres-native](https://github.com/dartondox/dox-postgres-native/releases) and [dox-mysql-native](https://github.com/dartondox/dox-mysql-native/releases).
