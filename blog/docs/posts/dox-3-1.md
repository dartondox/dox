---
date:
  created: 2026-11-08
  updated: 2026-11-09
authors:
  - dox
categories:
  - Releases
tags:
  - release
slug: dox-3-1
---

# Dox 3.1 is out

Dox 3.1 adds new routing tools, request helpers, new ORM features, access tokens, a new MCP package, mail and queue features, and many security and bug fixes.

<!-- more -->

This post covers 3.1.0 (November 8) and the two patch releases after it, 3.1.1 and 3.1.2 (November 9).
A change that came in a patch has its version after it, like "(3.1.1)".
Everything else came in 3.1.0.

## How to update

1. Update the `dox` CLI:

    ```bash
    dox update
    ```

2. In your `pubspec.yaml`, set the Dox packages to `^3.1.0` (or newer), then get them:

    ```bash
    dart pub upgrade
    ```

3. Make the generated code again. Relations and DTOs get new code in 3.1.

    ```bash
    dox build_runner:build
    ```

4. Read the next section. Some changes need a code change.

## Read before you update

These changes can change how your app works.

### ORM

- **Models are guarded by default.** `guarded` is now `['*']`. A model with no `fillable` list throws `MassAssignmentException` when `create()`, `update()`, `insert()`, `upsert()`, `firstOrCreate()` or a similar method gets a map. Before, it took every key, so `User().create(req.body)` could set `id` or `is_admin`. To fix it, add `fillable` with the columns a map may set. Or set `guarded` to `const <String>[]` to take every key, as before. `save()` and fields you set in code do not change. See [Mass assignment](/latest/database/model/#mass-assignment).
- **A write with no key and no `where()` throws.** `Blog().delete()`, `Blog().update({...})`, `forceDelete()`, `increment()` and `decrement()` on a model with no primary key value and no `where()` used to change every row of the table. Now they throw a `StateError` and run no query. To change every row on purpose, use `Blog().whereRaw('1 = 1').delete()` (or `.update()`). `restore()` on a query with no `where()` throws too.
- **`findOrFail()` and `firstOrFail()` answer 404**, not 500. `ModelNotFoundException` is now an HTTP exception with code 404. Its constructor is no longer `const`.
- **A digit in a model name gets no `_`.** `Address2` now gives the table `address2`, the foreign key `address2_id`, the pivot table `address2_tag` and the count key `address2_count`. Before, it was `address_2`. If you use these default names, rename the table or column, or set `tableName`, `foreignKey` and the pivot names by hand.
- **New many to many methods on every model**: `attach`, `detach`, `sync`, `syncWithoutDetaching`, `toggle`, `updateExistingPivot` and `pivot`. A `@Scope()` with one of these names is hidden when you call it right on a model, like `Song().sync()`. Rename such a scope.
- **A nullable list relation is `[]` after a preload with no rows**, not `null`. For example `List<Tag>? tags`. Run `build_runner` again.
- **`@Unique` trusts the database.** On MySQL and MariaDB, text compares without case. So `TAKEN@dox.dev` now fails `@Unique` when `taken@dox.dev` is in the table.
- **`update()` and `delete()` with `groupBy()` or `having()` throw an `ArgumentError`.** The SQL was never valid.

### Routing and core

- **`RateLimit` counts are shared by all isolates** (without Redis). `max` now holds for the whole server, not for each isolate. An app with more than one isolate gets a lower real limit than before. Raise `max` if you need the old number.
- **`Route.mount` matches whole path parts.** A mount at `/admin` gets `/admin` and `/admin/...`, but no longer `/administrator`. When two mount prefixes match, the longest one wins. Before, the first one added won.
- **Removed helpers:** `getDoxRequest` and `middlewareAndControllerHandler` are gone from `dox_core`. They were not used. Use `DoxRequest`.

### Validation

- `IpRule` is no longer a `RegexRule`, so `IpRule().pattern` is gone.
- `v.string().ip()` now takes IPv6 too, like `@Ip`. Its JSON Schema is `anyOf` IPv4 and IPv6.
- `ip()` and `@Ip` now say no to IPv4 addresses with leading zeros, like `01.1.1.1`.
- `alphaDash()` and `@AlphaDash` now allow digits, like `post-123`. The message and the JSON Schema pattern change too.
- `email()` now takes `+` and `'` before the `@`, like `ann+tag@x.com`.

### CLI

- `dox` exits with code 1 when there is no command, an unknown command, bad arguments, or a command that throws. Before, it exited with 0.
- `dox make:model Post` now writes `@DoxModel(table: 'posts')`, the same plural table that `-m` makes. The new model has an empty `fillable` list.
- `migration:fresh`, `migration:reset`, `migration:refresh`, `migration:rollback` and `key:generate` ask first when `APP_ENV=production` and you run them in a terminal. `--force` skips the question. Without a terminal (CI, deploy scripts), they print a warning and run as before.
- `dox make:serializer` makes the file in `lib/app/serializers/`, not `lib/app/http/serializers/` (3.1.1).

### Other packages

- **Queue:** deploy the queue worker together with the web app. An old worker does not know the new built-in mail job, so it fails queued emails. `dox_queue` now depends on `dox_mailer`.
- **Custom queue drivers:** `release()` must now also save `job.payload`, so the worker can keep the exception count. The new `clear()` and `pruneFailed()` throw an `UnsupportedError` on a custom driver that does not override them.
- **Storage:** `url()` on a local disk with no `url` option gives `/storage/<path>`. Before, it threw. New signed URLs include the disk name, so they do not work on 3.0.1. During a rolling deploy, they can get 403 until they expire. A signed `Storage.route()` on a disk that is not local still gives 403, and now also reports an `UnsupportedOperationException`.
- **Mail:** `Attachment.fromFile` reads the file when the message is sent or queued, so a missing file now throws from `send()`.
- **Views:** components always get `$slot` and `$slots.main`, as empty text when there is no body. So `{{ $slots.main ?? 'x' }}` no longer prints `x`. An empty `SafeString` is false in `@if`.
- **OpenAPI:** a route with an optional param, like `/greet/{name?}`, gives two paths: `/greet/{name}` and `/greet`. The short path gets its own summary and operation id.
- **Inertia:** an empty `200` answer to an Inertia request now goes back to the page it came from.

## New

### Routing

- `Route.match(methods, path, handler)` and `Route.any(path, handler)`.
- `Route.redirect(from, to)` (302) and `Route.permanentRedirect(from, to)` (301).
- `.where(param, regex)`: the route matches only when the param matches the regex. The value is checked after `%` decoding, and a leading `^` and trailing `$` are fine.
- `Route.fallback(handler)` answers a GET or HEAD that matches no route. It follows the group prefix, also one with a param like `{tenant}`.
- `Route.staticFiles(prefix, folder, maxAge:)` serves a folder, with `ETag`, `Last-Modified`, `304` and Range support. Files in `.well-known` are served too. The folders reach every isolate.
- `MethodOverride` middleware: a plain HTML form can reach `Route.put`, `Route.patch` and `Route.delete` with a `_method` field. `MethodOverride(header: true)` also reads the `X-HTTP-Method-Override` header.
- `Route.mount(prefix, handler, middleware: true)` runs the global middleware before a raw handler.
- `Route.websocket(maxMessageSize:)`.
- `AppConfig.idleTimeout` and `AppConfig.maxConnections` for the server.
- In development, a warning when a middleware returns `null`.

```dart
Route.redirect('/home', '/');
Route.get('/users/{id}', (UserController c) => c.show).where('id', '[0-9]+');
Route.staticFiles('/', 'public');
Route.fallback((DoxRequest req) {
  return response(<String, String>{'message': 'Page not found'}).statusCode(404);
});
```

Docs: [Routing](/latest/the-basic/routing/), [Static files](/latest/guides/static-files/), [Native server](/latest/digging-deeper/native-server/)

### Requests and responses

- `req.input(key, defaultValue)` with dot keys, like `user.name` or `items.0.id`.
- `filled`, `exists`, `missing`, `except`, `boolean` and `integer`.
- `file(key)` and `hasFile(key)` for uploads.
- `bearerToken()`, `path()`, `fullUrl()`, `pathIs(pattern)` and `routeIs(pattern)`. `pathIs()` cleans the path like the router, so `/admin/` and `/admin//` match `admin`.
- `req.auth?.id()` gives the id of the logged-in user.
- `SessionMiddleware().fromCookie(value)` loads a session with no request, for a Socket.IO login.
- `DoxCookie.decrypt(name, value)` decrypts a cookie value.
- `RequestBody` and `BodyKind` are exported, so `req.requestBody.kind` can tell invalid JSON from no body (3.1.1).
- `ValidationException.issues` keeps every issue of a failed check, for your own 422 shape (3.1.1).
- `RequestFile.head` keeps more bytes of an upload, so image size checks work.

Docs: [Request](/latest/the-basic/request/), [Session](/latest/the-basic/session/)

### Security, encryption and cache

- WebSocket `Origin` check: `Route.websocket(allowedOrigins: [...])` or `AppConfig.webSocketAllowedOrigins`. It is off by default. A WebSocket route with no check prints a warning at start.
- A warning when CORS has origin `*` together with `credentials: true`.
- `Crypt.encryptString`, `Crypt.decryptString`, `Crypt.encrypt` and `Crypt.decrypt` with the `APP_KEY`. A value that can not be decrypted throws `DecryptException` (400).
- `Hash.check`, the same as `Hash.verify`.
- `Hash.sha256(value)` to store API keys and tokens as a hash (3.1.1). Do not use it for passwords.
- `Cache().many(keys)` and `Cache().putMany(values)`.
- `Cache().flexible` takes a null `stale`: it keeps the last good value until a refresh replaces it (3.1.1).
- The file cache driver can delete old files by itself, with the `prune_every` option.

Docs: [Encryption](/latest/security/encryption/), [Hashing](/latest/security/hashing/), [Cache](/latest/digging-deeper/cache/)

### Validation and DTOs

- New rules, each as a fluent rule and a DTO annotation: `same` / `@Same`, `confirmed` / `@Confirmed`, `requiredIf` / `@RequiredIf`, `requiredWith` / `@RequiredWith`, `json` / `@Json`, `digits` / `@Digits`, `digitsBetween` / `@DigitsBetween`, `dateFormat` / `@DateFormatted` and `password` / `@Password`.
- `between(1, 10)` on `v.int()` and `v.num()`.
- `exists('teams')` and `unique('users', column: 'email')` in fluent schemas. The ORM answers them.
- File rules: `maxSize`, `minSize` / `@MinSize`, `mimes`, `mimeTypes` / `@MimeTypes` and `dimensions` / `@Dimensions`. The MIME type is checked against the real file bytes.
- `hexColor()` / `@HexColor()` (3.1.1).
- `@Dto(emptyStringsToNull: true)` reads `""` as `null` (3.1.1).
- `@OrDefault()` gives a field its default for a bad value, not an error. Use it for query strings like `?page=abc` (3.1.1).
- `@Describe('...')` puts a `description` in the JSON Schema of a field and in the OpenAPI docs (3.1.2).
- `@Dto(messages:)` matches the full dotted path first, like `tags.*.required`.
- `RuleContext.sibling('key')` reads another key of the same object.
- `ImageSize.read(head)`, `FileTypes.matchesMimeTypes` and `FileTypes.extensionsOf` for your own file rules.
- The build stops with a clear error when a rule names a Dart field instead of its input key.

```dart
@Dto()
class Register {
  @Describe('Shown on the profile page.')
  @Length(min: 1, max: 40)
  final String name;

  @Password(min: 8, mixedCase: true, numbers: true)
  @Confirmed()
  final String password;

  @RequiredIf('type', 'company')
  final String? vat;

  // ...
}
```

Docs: [Validation](/latest/the-basic/validation/), [Validation rules](/latest/the-basic/validation-rules/)

### ORM and database

- Many to many writes: `attach()`, `detach()`, `sync()`, `syncWithoutDetaching()`, `toggle()` and `updateExistingPivot()`.
- `@ManyToMany(withPivot: [...], withTimestamps: true)` reads extra pivot columns, with `song.pivot['role']`.
- Polymorphic relations: `@MorphMany`, `@MorphOne` and `@MorphTo`, with `Model.morphMap()`.
- Pages: `simplePaginate()` (no total count) and `cursorPaginate()` (a page after a cursor, no `OFFSET`).
- Sub queries: `whereIn()` with a query or any `Iterable` (like a `Set`), `joinSub()`, `leftJoinSub()` and `fromSub()`.
- `union()` and `unionAll()`. Read a union with `get()`. Methods that need one row or one part, like `find()` or `pluck()`, throw a `StateError` on a union.
- Dates: `whereDate()`, `whereTime()`, `whereYear()`, `whereMonth()` and `whereDay()`.
- JSON: `whereJsonContains()` and `whereJsonDoesntContain()`.
- `whereNot(column, value)`, `orWhereNot()`, `unless()` and `whenValue()`.
- `first()` and `doesntExist()`, the same as `getFirst()` and `hasNoRows()`.
- `insertGetId()`, `insertMany()` and `insertOrIgnore()`.
- `onlyTrashed()`, `touch()`, `touchQuietly()` and `replicate()`.
- `withAvg()`, `withMin()` and `withExists()`.
- `forceCreate()`, `forceUpdate()`, `forceFill()` and `Model.unguarded()` skip `fillable` and `guarded`. Do not pass user input to them. `forceFill()` throws an `ArgumentError` when it can not set a column.
- `toRawSql()` gives the SQL with the values in it, for logs.
- `ConnectionConfig.logRedact` hides values, like passwords, in the query log. Each named connection uses its own list.
- `FileQueryPrinter(buffered: true)` writes the query log in the background.
- Schema helpers: `foreignIdFor()`, `ulid()`, `foreignUlid()`, `year()`, `ipAddress()`, `softDeletesTz()`, `nullableMorphs()`, `uuidMorphs()`, `dropTimestamps()`, `dropSoftDeletes()`, `dropConstrainedForeignId()`, `dropPrimary()`, `renameIndex()`, `fullText()`, `nullOnUpdate()` and `restrictOnUpdate()`.
- Postgres with `useSSL: true` prints a warning that the server certificate is not checked. Set `extra['sslMode'] = 'verify-full'` to check it.
- MySQL: the new `sslRootCert` option (URL option `ssl_ca`) trusts a private CA. Without TLS, it prints a warning that it is ignored.
- MySQL: a pool that can not open now says why.
- `find(5, null)` throws a clear `ArgumentError`: the first arg must be a column name.
- `package:dox_migration/env.dart` exports `loadEnv`.

```dart
// many to many
PivotSyncResult result = await artist.sync('songs', <int>[1, 2, 3]);

// a page after a cursor
CursorPagination<Blog> page = await Blog()
    .orderBy('id')
    .cursorPaginate(perPage: 10, cursor: req.input('cursor'));
```

Docs: [Query builder](/latest/database/query-builder/), [Model](/latest/database/model/), [Many to many](/latest/database/model/relationship/many-to-many/), [Polymorphic](/latest/database/model/relationship/polymorphic/), [Schema](/latest/database/schema/), [Pagination](/latest/guides/pagination/)

### Auth

- Access tokens, opt-in. A token looks like `oat_<id>.<secret>`. The table keeps only a hash of the secret. Each token has a name, abilities and an expiry.
- `dox auth:tokens-table` writes the migration for the access tokens table.
- `AuthMiddleware(guards: ['web', 'api'])` tries several guards in order.
- `AuthMiddleware(optional: true)` lets guests through too, so `req.can()` works on a public page.
- `GuestMiddleware` lets only guests through, for login and register pages.
- `Auth().check()`, `Auth().id()`, `Auth().guest()` and `Auth().once(credentials)`.
- `Auth().userFromToken(token)` and `Auth().userFromSession(session)` check a login with no request, like in Socket.IO.
- Opt-in login throttle: `Auth.throttle = LoginThrottle(...)`. Give the ip with `Auth(ip: req.ip())`.
- Opt-in JWT revocation: `JwtAuthDriver(revocation: true)`, with `revokeToken`, `revokeAllTokens` and `forgetUser`.
- Opt-in small JWT: `JwtAuthDriver(minimalPayload: true)` puts only the user id in the token.
- `Auth.needsRehash(hash)` and `Auth.hashCost(hash)` to raise the password hash cost.
- `JwtAuthDriver.bearerToken(req)` reads the token. `AuthDriver.reportError()` reports errors.
- New JWTs carry a `jti` claim. Tokens made before still work.
- The error of `logout()` on a token guard now says to use `revokeToken()`.

No auth change is breaking. Apps work the same with no code change, and no user is logged out.

```dart
AccessToken token = await Auth(guard: 'api').createAccessToken(
  user,
  name: 'cli',
  abilities: <String>['posts:read'],
  expiresIn: const Duration(days: 30),
);
return <String, dynamic>{'token': token.value}; // shown only once
```

Docs: [Authentication](/latest/security/authentication/)

### MCP

`dox_mcp` is a new package. It turns a Dox app into an MCP server, so AI tools can call your code.

- `McpServer` (Streamable HTTP), `McpTool` with `dox_validation` input schemas, `McpTool.of`, `McpToolResult` and `McpContext`.
- `SignedMcpSessions`: session ids signed with the `APP_KEY`.
- `McpOAuth`: the OAuth 2.1 sign-in of the MCP spec, with PKCE and dynamic client registration (3.1.1). From 3.1.2, the `code_verifier`, `code_challenge` and redirect address are checked strictly.
- `McpDtoTool<T>`: a tool that takes a `@Dto` class as its input. `handle` gets the typed object. `McpToolResult.invalidArguments()` gives the error result for bad arguments (3.1.2).

```dart
class CreateCategory extends McpDtoTool<NewCategory> {
  @override
  String get name => 'create_category';

  @override
  String get description => 'Add a category.';

  @override
  DtoSchema<NewCategory> get dto => NewCategory.schema;

  @override
  Future<McpToolResult> handle(NewCategory input, McpContext context) async {
    return McpToolResult.text('Added ${input.name}.');
  }
}
```

Docs: [MCP](/latest/packages/mcp/)

### Queue

- `Queue.fake()` for tests, with `assertPushed`, `assertPushedTimes`, `assertNotPushed` and `assertNothingPushed`.
- Job settings: `retryUntil`, `maxExceptions` and `failOnTimeout`.
- `dispatch(delayUntil: DateTime)`, `dispatchIf()` and `dispatchUnless()`.
- Worker flags: `--backoff`, `--max-jobs`, `--max-time`, `--memory` and `--timeout-grace`.
- Commands: `dox queue:clear`, `dox queue:restart`, `dox queue:prune-failed` and `dox queue:table`.
- `ShouldBeEncrypted`: save the job data encrypted with the `APP_KEY`.
- A built-in job sends `Mail.queue()` and `Mail.later()`.
- `QueueConfig.redisFromEnv()` reads the Redis server from `REDIS_URL`, or from `REDIS_HOST`, `REDIS_PORT`, `REDIS_USERNAME`, `REDIS_PASSWORD` and `REDIS_TLS`.

Docs: [Queue](/latest/digging-deeper/queue/)

### Mail and notifications

- Mailables: one class per kind of email, with `send()`, `queue()` and `later()`.
- Markdown mail, from a `dox_view` template. A text value from `data` stays text. Pass a `SafeString` to put Markdown from a value.
- `MailMessage`: an email made of lines and a button, with no template.
- Notifications: `Notification`, `MailChannel`, `Notifiable` and your own channels.
- `Mail.queue()` and `Mail.later()` send the email from the job queue. With `encrypt: true`, a send error in the log does not show the recipient.
- `Message.toJson()` and `Message.fromJson()`, and the `MailQueue` interface with `Mail.useQueue()`.
- `Mail.raw()`, and `Mail.to(...).cc(...).bcc(...).send(...)`.
- `Mail.alwaysTo(address)` sends every email to one address, for example on staging.
- `Mail.onSending()` and `Mail.onSent()` hooks, and `Mail.clearHooks()`.
- Test checks on `Mail.fake()`: `assertSent`, `assertSentCount`, `assertNotSent`, `assertNothingSent`, `assertQueued`, `assertNotQueued` and `assertNothingQueued`.

Docs: [Mail](/latest/digging-deeper/mail/), [Notifications](/latest/digging-deeper/notifications/)

### Scheduler

- `ScheduleConfig(timezone: ...)`: the default time zone of every task.
- `environments(['production'])`: run a task only in these environments.
- `unlessBetween(start, end)`.
- New frequencies, like `everyTwoHours`, `twiceDailyAt`, `lastDayOfMonth`, `quarterly`, `yearlyOn` and `mondays()` to `sundays()`.
- A warning when `onOneServer()` uses a lock store that is not shared between servers.
- `Scheduler.close()` frees the overlap locks.
- When a provider's `setup()` throws, `SchedulerRunner` shuts down the providers that already started.

Docs: [Scheduler](/latest/digging-deeper/scheduler/)

### Storage

- `append()`, `prepend()`, `size()`, `lastModified()`, `makeDirectory()` and `directoryExists()`.
- `temporaryUrl()`, the same as `signedUrl()`.
- `file.store(folder, disk: 's3')`, `file.storeAs(folder, name)` and `Storage().putRequestFileAs()`.
- `atomic_writes`: a failed upload never leaves a half-written file.
- `assertExists()` and `assertMissing()` on a fake disk, for tests.

Docs: [File storage](/latest/digging-deeper/file-storage/)

### Socket.IO

- `SocketAuth` logs a socket in at connect time. The user is in `socket.user`.
- `handshake.token`, `handshake.cookie(name)` and `await handshake.session()`.
- `ServerOptions(allowedOrigins:)` turns on an origin check.

Docs: [Socket.IO](/latest/packages/socketio/)

### Views

- New tags: `@isset`, `@empty`, `@auth`, `@guest`, `@env`, `@production`, `@once`, `@verbatim`, `@class`, `@checked`, `@selected` and `@disabled`.
- Components get `$attributes` (with `merge()`) and `$slot`.
- `ViewEngine(environment:)` sets the environment for `@env` and `@production`. By default it is `APP_ENV`.

Docs: [Views](/latest/the-basic/views/)

### Inertia

- `Inertia.render()`, the same as `inertia()`, and `Inertia.lazy`, the same as `Inertia.optional`.
- `Inertia.shareGlobal(key, value)` shares a prop with every page.
- A deferred prop can be merged: `Inertia.defer(fn).merge()`.
- The asset version is checked before the controller runs, so an old page gets `409` at once.
- The root view and the Vite manifest are kept in memory.
- A prop that can not become JSON gives an error that names the prop and its type.

Docs: [Inertia](/latest/the-basic/inertia/)

### OpenAPI

- `paramResponses` on `RouteDoc`: answers that only happen when the path has a param, like `404`.
- `namedResponses`: responses with a text key, like `default` or `2XX`.
- The `body` of a GET or DELETE route goes in the query string.

Docs: [OpenAPI](/latest/packages/openapi/)

### CLI

- Package commands: a package adds its own `dox` commands with the `dox: commands:` key in its `pubspec.yaml`. `dox help` lists them. They work in a pub workspace too.
- `package:dox_core/command.dart` with `Command` and `MigrationFile`, to write these commands.
- `dox migrate` makes `bin/migrate.dart` when it is missing.
- `dox key:generate --show` prints a new key and writes nothing.
- `--step` given twice is an error.
- `dox serve --port=...` prints a warning that says to set `APP_PORT`.

Docs: [CLI](/latest/reference/cli/), [Package commands](/latest/digging-deeper/package-commands/)

### App template

The template that `dox create` uses got new files too.

- Safer Docker Compose defaults, and a queue worker service.
- `AGENTS.md` and the `.agents/skills/dox` skill: rules and recipes for AI coding tools. `CLAUDE.md` points to the same files (3.1.1).
- Serializers live in `lib/app/serializers/` (3.1.2).

### Redis client

- `RedisOptions.fromUrl(url)` reads a `redis://` or `rediss://` URL.
- `RedisSetOption` is deprecated. It was empty and not used.

## Fixes

### Security

- `back()` only follows a `Referer` of the same host. Before, it was an open redirect.
- ORM `guarded` could be skipped with a changed key, like `' is_admin'` or `'IS_ADMIN'`. Now the check trims the name and ignores case.
- A local signed URL for one disk no longer works on the route of another disk.
- Inertia ignores the Vite `public/hot` file when `APP_ENV` is `production`.
- On MySQL, a key with a letter that is not ASCII can no longer set a guarded column.
- Postgres: an unknown `verify` value now means the full certificate check.

### Routing and core

- A bad multipart body gets 400, not 500.
- `abort()` headers are kept on routes with a next middleware.
- A mounted handler that throws gives 500. Before, the client could hang.
- A download name with quotes or non-ASCII letters gets a safe `Content-Disposition`.
- `res.withHeaders` and `res.header` no longer drop or double headers.
- A resumed download with `If-Range` no longer mixes two versions of a file. `If-Range` is used only when it matches the file's `Last-Modified` date or its strong `ETag`.
- A `Range` header sent on two lines no longer gives 500.
- `req.session.reflash()` keeps the flash data on the first use of the session.

### ORM and database

- A model write with no key and no `where()` no longer changes every row.
- `blog.update({...})` on a loaded model changes only that row and sets `updated_at`.
- `save()` keeps an `updated_at` that you set.
- A soft delete and `restore()` set `updated_at` too.
- `restore()` on a query restores the soft deleted rows of the query.
- `reload()` and preload clear a relation when the related rows are gone.
- `find('email', null)` finds the row where `email` is null.
- `limit()` with a negative number is ignored.
- `having('x', '!=', null)` builds `x IS NOT NULL`.
- `update()` and `delete()` with `join()`, `orderBy()` or `limit()` work on Postgres and SQLite.
- `foreignId('x').unique().constrained()` compiles.
- A failed nested transaction releases its savepoint.
- `@Unique` and `@Exists` on Postgres with a value that does not fit the column no longer give 500.
- `@name` inside a quoted string or a comment is no longer read as a param on MySQL and SQLite.
- The query log lists the values in the right order.
- `Logger.warn` prints yellow.
- Rollback goes on when the file of a migration that already ran is gone.
- MySQL 8.4 and Postgres: a text param is no longer stored with the wrong type after a table change.
- MySQL 8.4: the same SQL with a number param first and a text param later no longer gives wrong rows.
- Postgres: a broken server message gives an error, not a crash of the process.
- Postgres: a query in a transaction is not sent again after a "cached plan" error.
- MySQL: a slow DNS lookup when a pool opens no longer stops the other isolates.

### Auth

- The `Bearer` prefix is matched in any case.
- A JWT check no longer hides unexpected errors. They go to the exception handler.
- A request with two `Authorization` headers is a normal 401.

### Other packages

- **Cache:** `FileDriver.prune()` no longer deletes a value written at the same time.
- **Mail:** `Attachment.fromFile` no longer blocks the server while it reads the file. An `onError` of `FailoverTransport` that throws no longer stops the failover.
- **Scheduler:** `schedule work` ends a few seconds after Ctrl+C or SIGTERM. `dailyAt('13')` means 13:00. The overlap lock stays until the work really ends.
- **Socket.IO:** CORS origin matching ignores case and a trailing `/`.
- **Views:** `{{ errors.email }}` works with no session. A global named `errors` shows. The `toJson()` cache lasts one render.
- **Inertia:** flash messages are kept after a deploy. A function prop inside a map or a list runs too.
- **CLI:** `migration:rollback --step 2` (with a space) works.
- **Redis client:** the client waits for AUTH and SELECT before it sends commands. A failed AUTH on reconnect no longer crashes the app. The connect has a timeout. A server that closes the connection right after connect no longer crashes the app. The handshake tries again when the server is not ready yet (`LOADING`, `BUSY`, `MASTERDOWN`, `TRYAGAIN`). The wait between tries grows, and a long run of tries no longer ends in a stack overflow. `disconnect()` stops a try that is waiting.

## Full list

Every change is in the changelogs:

- The [Changelog](/latest/reference/changelog/) page of the docs (`dox_core`, `dox_builder`, `dox_annotation`, `dox_cache`).
- GitHub releases: [dox](https://github.com/dartondox/dox/releases), [dox-orm](https://github.com/dartondox/dox-orm/releases), [dox-auth](https://github.com/dartondox/dox-auth/releases), [dox-validation](https://github.com/dartondox/dox-validation/releases), [dox-mcp](https://github.com/dartondox/dox-mcp/releases), [dox-cli](https://github.com/dartondox/dox-cli/releases), [dox-queue](https://github.com/dartondox/dox-queue/releases), [dox-mailer](https://github.com/dartondox/dox-mailer/releases), [dox-scheduler](https://github.com/dartondox/dox-scheduler/releases), [dox-storage](https://github.com/dartondox/dox-storage/releases), [dox-socketio](https://github.com/dartondox/dox-socketio/releases), [dox-view](https://github.com/dartondox/dox-view/releases), [dox-inertia](https://github.com/dartondox/dox-inertia/releases) and [dox-openapi](https://github.com/dartondox/dox-openapi/releases).
