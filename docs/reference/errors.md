# Error index

A lookup table of the messages Dox prints or throws. Search this page for the text you see.

- `<...>` is a part that changes, like a name or a number.
- Dart adds a prefix to some errors: `Bad state:` (`StateError`), `Invalid argument(s):` (`ArgumentError`), `Unsupported operation:` (`UnsupportedError`), `Exception:` (`Exception`).
- For problems that need a longer story, see [Troubleshooting](troubleshooting.md).

## dox_core: start of the app

| Text | When | What to do |
| --- | --- | --- |
| `APP_KEY is not set. Run `dox key:generate` and put the key in .env` | `appKey` is empty. A warning, or a `StateError` that stops the app when `APP_ENV=production`. | Run `dox key:generate`, or set `APP_KEY` in the env. |
| `[dox] warning: dox_http_native did not load, using the dart:io server (<reason>)` | The native HTTP library is missing or from another version. | See [Troubleshooting](troubleshooting.md#the-native-http-library-did-not-load). Or set `DOX_SERVER=dartio`. |
| `Server started at http://127.0.0.1:<port> with <n> isolate (<backend>)` | Normal start. `<backend>` is `native` or `dart:io`. | Nothing. |
| `WebSocket or Socket.IO routes: using the dart:io server` | The app has WebSocket or Socket.IO. The native server can not upgrade yet. | Nothing. This is info. |
| `Windows: the native server runs on one isolate` | Windows has no `SO_REUSEPORT`. | Nothing, or `DOX_SERVER=dartio` to use every core. |
| `Socket.IO runs on <n> isolates: clients should use transports: ['websocket'] ...` | Socket.IO with more than one isolate and long-polling on. | Use a Redis adapter, and `transports: ['websocket']` in the client. |
| `[dox] isolate <n> error: <error>` | An error killed a worker isolate. The stack is on the next line. | Fix the error. Dox restarts the isolate. |
| `[dox] isolate <n> exited, restarting` | A worker isolate died. A new one starts after 1 second. | Look at the error line above it. |
| `SocketException: Failed to create server socket (OS Error: Address already in use, ...)` | The port is in use (`dart:io` server). | See [Troubleshooting](troubleshooting.md#port-already-in-use). |
| `SocketException: dox_http_native: bind failed (<code>), port = <port>` | The port is in use (native server). | Same as above. |

## dox_core: routes and controllers

These stop the app at start, so a bad route never reaches a request.

| Text | When | What to do |
| --- | --- | --- |
| `Route <where>: the controller parameter type <T> is not known. Use DoxRequest, a @Dto class, or String, int, double, num, bool for path params. ...` | A controller parameter has another type, or the DTO is not in `AppConfig.dtos`. | Change the type, or run `dart run build_runner build` and set `dtos: dtos`. |
| `Route <where>: the controller has more path params than the route has {...} params (<n>).` | The method asks for more path params than the path has. | Add the `{param}` to the path, or remove the parameter. |
| `Route <where>: a controller can have one @Dto only.` | Two DTO parameters. | Merge them into one DTO. |
| `Route <where>: only positional parameters are supported, not named or [optional] ones (<type>).` | Named or `[optional]` parameters. | Use positional parameters. Use `int?` with `{id?}` for an optional param. |
| `Route <where>: a controller can not be generic.` | The handler has type parameters. | Remove them. |
| `Route <where>: can not read the controller type <type>.` | Dox can not read the function type of the handler. | Use a plain method or function. |
| `Exception: websocket is not registered` | `Route.websocket()` runs before a `WebsocketServer(Dox())` exists. | Add the WebSocket service to `services`. See [WebSocket](../digging-deeper/websocket.md). |

## dox_core: env

| Text | When | What to do |
| --- | --- | --- |
| `EnvException: the env is not valid` then `  - <KEY> is missing` | `AppEnv.load()` found a required key with no value. | Set the key, or give the getter a default. |
| `  - <KEY> must be <type>, not "<value>"` | A value does not fit the getter type. | Fix the value. Check for a `# comment` after it. |
| `Env key "<KEY>" is not set and has no default` | `Env.get<int>()`, `<num>`, `<double>` or `<bool>` with no value and no default. | Set the key, or pass a default. |
| `Env key "<KEY>" is not a valid <type>: "<value>"` | `Env.get<int>()` (or another type) got text that is not that type. | Fix the value. |

See [Environment variables](../digging-deeper/env.md).

## dox_core: requests (what the client gets)

| Status | Body text | When | What to do |
| --- | --- | --- | --- |
| `404` | `<METHOD> <path> not found` | No route matches. | Check the method, the path and the router `prefix`. |
| `404` | `Not Found` | A typed path param does not fit, like `abc` for `int id`. | Send a valid value. |
| `400` | `The body is not valid JSON` | A DTO reads a JSON body that does not parse. | Send valid JSON. |
| `400` | `The form body is not valid` | A urlencoded body that can not be decoded. | Fix the client encoding. |
| `415` | `Unsupported Media Type` | A DTO reads a body that is not JSON or form data. | Send `Content-Type: application/json` or form data. |
| `413` | `Payload Too Large` | The body is bigger than `maxBodySize` or `maxMultipartSize`. | Send less, or raise the limit. |
| `422` | `{"_root":"The input has too many items (max 1000) or levels (max 10)"}` | Form or query keys with more than 1000 list items or 10 levels. | Send less nested data. |
| `422` | `{"<field>":"<message>"}` | A DTO check failed. | See [Validation rules](../the-basic/validation-rules.md). |
| `431` | (no text) | Native server: request line plus headers over 16 KB. | Send smaller headers or cookies. |
| `500` | `<error>.toString()` | Any error that is not an `IHttpException`. It also goes to `errorHandler`. | Look at the server log. |

## dox_core: DTOs, storage and config

| Text | When | What to do |
| --- | --- | --- |
| `Bad state: <T> is not a known DTO. Add @Dto() to it, run `dart run build_runner build` and set `dtos: dtos` (lib/dtos.g.dart) in AppConfig.` | `req.validate<T>()` can not find `T`. | Do what the text says. |
| `Invalid argument(s): Storage disk "<name>" has unknown driver "<type>"` | A disk in `StorageConfig` has a `driver` other than `local`, `s3` or `memory`. | Fix the driver name. |
| `type 'Null' is not a subtype of type 'String' in type cast` | An `s3` disk without `bucket`, `key` or `secret`, on its first use. | Set `AWS_BUCKET`, `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`. |
| `Invalid argument(s): invalid file` | `Storage().put()` with no `extension:`, and Dox can not find the type from the bytes. | Pass `extension: 'pdf'`. |
| `403` `invalid or expired signature` | A `Route.files()` URL without a valid `signature`, or after `expires`. | Make a new link with `Storage().signedUrl()`. |
| `404` `file not found` | `Storage().stream()` or `download()` of a missing file. | Check the path. |
| `Invalid argument (trustedProxies): not an ip or cidr: "<value>"` | A bad entry in `AppConfig.trustedProxies`. | Use an IP, a CIDR like `10.0.0.0/8`, or `*`. |
| `Invalid argument (type): must be asc or desc: "<value>"` | `orderBy(column, type)` with another direction. | Use `asc` or `desc`. |
| `400` `decrypt_failed` | `AESEncryptor.decode` got changed text or a wrong key. It throws `DecryptException`. `req.cookie()` catches it and returns `null`. | Check the key. For a cookie, ask the user to log in again. |

## dox_auth

| Text | When | What to do |
| --- | --- | --- |
| `401` `Authentication failed` | `AuthMiddleware` finds no token, a bad or expired token, or the user is deleted. | Send `Authorization: Bearer <token>`. Log in again. |
| `Invalid argument(s) (salt): Invalid salt length ...` | `Hash.verify()` with a value that is not a bcrypt hash. | See [Troubleshooting](troubleshooting.md#hashverify-throws-on-a-bad-hash). |
| `Invalid argument(s) (password): Password is too long ...` | bcrypt with a password over 72 bytes. | Limit the length in the DTO. |

`Auth().attempt()` returns `null` for a wrong password. It does not throw. See [Authentication](../security/authentication.md).

## dox_orm

| Text | When | What to do |
| --- | --- | --- |
| `[dox] warning: dox_postgres_native did not load, using the Dart postgres driver (<reason>)` | The native Postgres library did not load. | See [Postgres native](../database/postgres-native.md). Or set `DOX_DB_DRIVER=dart`. |
| `[dox] warning: dox_mysql_native did not load, using the Dart mysql driver (<reason>)` | The native MySQL library did not load. | See [MySQL native](../database/mysql-native.md). |
| `Exception: <name> not found` | `DatabaseConfig.connection` (or `withConnection()`) names a connection that is not in `connections`. | Fix `DB_CONNECTION` or the map. |
| `Exception: Invalid driver or not supported` | A `ConnectionConfig.driver` Dox can not open. | Use `Driver.postgres`, `Driver.mysql` or `Driver.sqlite`. |
| `Invalid argument(s): dox_postgres_native: bad connection config` | The native driver can not read the connection values. | Check `host`, `port`, `user`, `database`. |
| `Invalid argument(s): dox_mysql_native: bad connection config` | Same, for MySQL. | Same. |
| `SqliteException` with `unable to open database file` | The SQLite folder does not exist. | See [Troubleshooting](troubleshooting.md#sqlite-the-database-file). |

## dox_orm: schema builder

| Text | When | What to do |
| --- | --- | --- |
| `Bad state: foreign key <name>: call on(table)` | `table.foreign('x').references('id')` with no `.on('table')`. | Add `.on('table')`, or use `foreignId('x').constrained()`. |
| `Unsupported operation: postgres: change() of an auto increment column is not supported` | `change()` on an `id()` or `increments()` column. | Write the `ALTER` by hand with `schema.driver.execute()`. |
| `Unsupported operation: sqlite: can not add a primary key to an existing table` | `primary(...)` in `schema.table()` on SQLite. | Make the table again with the key in `schema.create()`. |
| `Unsupported operation: sqlite: can not rebuild <table>, it has CHECK constraints` | A SQLite rebuild (`change()`, `foreign()`, `dropForeign()`) on a table with other `CHECK`s. | Make the new table by hand in the migration. |
| `Unsupported operation: sqlite: can not rebuild <table>, it has generated columns` | Same, on a table with generated columns. | Same. |
| `Bad state: sqlite: table <table> not found` | A SQLite rebuild of a missing table. | Check the table name. |
| `Bad state: sqlite: column <table>.<column> not found` | `change()` or `renameColumn()` of a missing column on SQLite. | Check the column name. |
| `Bad state: sqlite: foreign key <names> not found` | `dropForeign()` of a key the table does not have. | Check the key name or columns. |
| `Bad state: sqlite: rebuild of <table> breaks foreign keys` | After the rebuild, rows point to missing parent rows. | Fix the data first. |
| `Unsupported operation: sqlite: change() rebuilds the table, it only runs on a database` | `table.toSql(SqliteGrammar())` with `change()`. | Run it on a database, not as text. |

## dox_migration

| Text | When | What to do |
| --- | --- | --- |
| `Exception: Could not connect to database: <error>` | The migrator can not open the database. | Check `DATABASE_URL` or the `DB_*` values. A real env var wins over `.env`. |
| `Unknown migration command: <cmd> (use run, rollback, reset, refresh or status)` | `dart run bin/migrate.dart <cmd>` with another command. | Use one of the five. |
| `Invalid argument(s): Invalid option <x>, use --step=<count>` | `rollback` with a bad option. | Use `--step=2`. |
| `Bad state: Migration <name> is both a Dart and a .sql migration` | Two files with the same name in `db/migration`. | Rename or delete one. |
| `Bad state: foreign key check failed: <table> points to a missing <parent> row` | SQLite: a migration left a broken foreign key. | Fix the data in the migration. |
| `Migrating: <name>` / `Migrated: <name>` | Normal progress. | Nothing. |
| `Migrations are already up to date!` | Nothing to run. | Nothing. |
| `Nothing to rollback!` | No batch to undo. | Nothing. |
| `No migrations found.` | `status` with no migrations. | Check `db/migration`. |

See [Migration](../database/migration.md).

## dox_cache

| Text | When | What to do |
| --- | --- | --- |
| `Invalid argument(s): Cache store "<name>" is not configured` | `Cache().store('<name>')` or `defaultStore` names a missing store. | Add the store to `CacheConfig.stores`, or fix `CACHE_STORE`. |
| `Invalid argument(s): Cache driver "<driver>" of store "<name>" is not supported` | A store has a `driver` other than `file`, `memory`, `redis` or `null`. | Fix the driver name. |
| `Unsupported operation: <Driver> does not support locks` | `lock()` on the `file` or `null` store. | Use the `memory` or `redis` store. |
| `Bad state: Cache value of "<key>" is not an integer` | `increment()` or `decrement()` on a value that is not an `int`. | Store an `int`, or `forget()` the key. |
| `Invalid argument(s): Cache value of "<key>" is bigger than <limit> bytes` | A Redis value is too big. | Store less, or use files or a database. |
| `Bad state: RedisDriver.flush needs a prefix. It will not delete the whole database.` | `flush()` on a Redis store with an empty `prefix`. | Set a `prefix`. |

See [Cache](../digging-deeper/cache.md).

## dox_storage

The text has the form `<Exception>: <message> (key: "<key>")`.

| Text | When | What to do |
| --- | --- | --- |
| `FileNotFoundException: File not found` | The file is not on the disk. | Check the path. `Storage()` paths start with `/`, `Disk` keys do not. |
| `PermissionDeniedException: Permission denied` | The OS (local) or S3 (`403`) refused it. | Check file rights, or the S3 key and bucket policy. |
| `InvalidKeyException: Invalid key: path traversal is not allowed` | A key with `..`. | Do not build keys from user input. |
| `InvalidKeyException: Invalid key: absolute paths are not allowed` | A `Disk` key that starts with `/` or a drive letter. | Remove the first `/`. |
| `InvalidKeyException: Invalid key: key is empty` | An empty key. | Pass a file name. |
| `UnsupportedOperationException: urlBase is not configured` | `Storage().url()` on a local disk with no `url` option. | Set `url` on the disk. |
| `UnsupportedOperationException: urlBase and appKey are needed for signed URLs` | `signedUrl()` on a local disk with no `url`, or no `APP_KEY`. | Set both. |
| `UnsupportedOperationException: S3 signed URLs must expire within 1 second and 7 days` | `signedUrl()` on S3 with a bad `expiresIn`. | Use a time up to 7 days. |
| `UnsupportedOperationException: Disk "<name>" is not registered` | `Storage().disk('<name>')` with a missing disk. | Add the disk to `StorageConfig.disks`. |
| `DriverException: <S3 error>` | Any other S3 error (network, `500`, wrong bucket). | Read the S3 code in the text. |

See [File storage](../digging-deeper/file-storage.md).

## dox_validation

| Text | When | What to do |
| --- | --- | --- |
| `Bad state: Schema has async rules. Use parseAsync() instead.` | `schema.parse()` on a schema with an async rule. | Use `await schema.parseAsync()`. |
| `Bad state: Rule "<name>" is async. Use parseAsync() instead.` | Same, for one `AsyncRule`. | Same. |
| `Bad state: This refine is async. Use parseAsync() instead.` | `refine()` with an async function and sync parse. | Same. |
| `Bad state: DTO <name> has an async validate(). Use parseAsync() instead.` | A DTO with `Future<void> validate()` checked with a sync call. | Use the async call, like `req.validate<T>()`. |
| `Bad state: No value: the key was missing. Check isPresent.` | `maybe.value` on a `Maybe<T>` that is missing. | Check `isPresent` first. |

See [dox_validation](../packages/validation.md).

## dox_builder (`build_runner`)

These stop `dart run build_runner build`.

| Text | When | What to do |
| --- | --- | --- |
| `The @Dto class <Name> has problems:` then a `- ...` list | One or more lines below. | Fix each line. |
| `- The field <Class.field> must be final.` | A DTO field is not `final`. | Add `final`. |
| `- The field <Class.field> must be a `this.<field>` parameter of the unnamed constructor.` | The field is not set by the constructor. | Add `this.<field>` to the constructor. |
| `- A @Dto class needs an unnamed constructor.` | Only named constructors. | Add `const Name({...})`. |
| `- A @Dto class can not extend another class (<Parent>).` | The DTO extends a class. | Copy the fields in. |
| `- A @Dto class can not be generic.` | The DTO has type parameters. | Remove them. |
| `- The type <T> of <where> is not supported. Use a basic type, an enum, DateTime, RequestFile, a @Dto class, or a List or Map of them.` | Field type not supported. | Change the type. |
| `- @<Rule> does not fit the type <T> of <where>.` | A rule on the wrong type, like `@Email()` on an `int`. | Move the rule, or change the type. |
| `- @Length on <where> needs min:, max: or both.` | `@Length()` with no limit. | Add `min:` or `max:`. |
| `- The @Regex on <where> is not a valid regex: <reason>` | The pattern does not compile. | Fix the pattern. |
| `- @MaxSize on <where> needs a size like '2MB' (units B, KB, MB, GB), not "<text>".` | Bad size text. | Use `'2MB'`. |
| `- The Maybe field <where> needs the default `const Maybe.missing()`.` | A `Maybe<T>` field without that default. | Add it. |
| `- <where> can not have both @Lowercase and @Uppercase.` | Both on one field. | Keep one. |
| `- The validate method of <Name> must take one DtoErrors: `void validate(DtoErrors errors)`.` | Wrong `validate` signature. | Use that signature. |
| `Two @Dto classes are named <Name>: in <a> and <b>. Dox finds DTOs by name, so rename one.` | Two DTOs with the same class name. | Rename one. |
| `Env getter "<name>" has type <T>. Use String, int, double, num, bool, Uri, Duration, an enum or List<String>.` | A `@DoxEnv` getter with another type. | Change the type. |
| `@DoxModel can only be used on a class.` / `@DoxEnv can only be used on a class.` | The annotation is on something else. | Put it on a class. |
| `Conflicting outputs were detected ...` | `build_runner` cache is out of date. | See [Troubleshooting](troubleshooting.md#build_runner-conflicting-outputs). |

## Native libraries (build hooks)

Printed during `dart pub get`, `dox serve` or `dox build`. `<pkg>` is `dox_http_native`, `dox_postgres_native` or `dox_mysql_native`. The app still runs, on the Dart fallback.

| Text | When | What to do |
| --- | --- | --- |
| `<pkg>: no native library for <os>-<arch>.` | No ready build for this OS and CPU. | Install Rust, or accept the fallback. |
| `<pkg>: download <file>: <status>` / `<pkg>: download <file> failed: <error>` | The GitHub download failed. | Check the network, then `dart pub get` again. |
| `<pkg>: sha256 of <file> does not match` | The downloaded file is not the expected one. | Delete `.dart_tool` and try again. |
| `<pkg>: cargo build failed` | The build from source failed. | Read the cargo output below it. |
| `Bad state: <pkg>: <path> does not exist` | The `lib_path` user define points to a missing file. | Fix the path in `pubspec.yaml`. |
| `Unsupported operation: dox_http_native can not detach the socket` | `DOX_SERVER=native` with a WebSocket route. The upgrade fails with `500`. | Do not force native for WebSocket apps. |

See [Native server](../digging-deeper/native-server.md).

## dox_socketio

Printed to stderr. The connection or the request fails, the app keeps running.

| Text | When | What to do |
| --- | --- | --- |
| `dox_socketio: handler error: <error>` | Your namespace handler threw. The stack follows. | Fix the handler. |
| `dox_socketio: request error: <error>` | A Socket.IO HTTP request failed. The client gets `500`. | Check the client version and transport. |
| `dox_socketio: redis publish failed: <error>` | The Redis adapter could not publish. | Check Redis. |
| `dox_socketio: bad redis message: <error>` | The Redis adapter got a message it can not read. | Check that every app on the channel runs the same version. |

## CLI

| Text | When | What to do |
| --- | --- | --- |
| `Could not find a command. Run `dox help` for more information.` | `dox` with no command. | Run `dox help`. |
| `Could not find a command named "<name>". Run `dox help` for more information.` | Unknown command. | Check the spelling. |
| `Invalid number of arguments for command "<name>".` | Too few or too many arguments. | Run `dox help <name>`. |
| `Command "<name>" not found.` | `dox help <name>` with an unknown command. | Run `dox help`. |
| `<name> already exists` | A `create:*` file is already there. | Pick another name, or delete the file. |
| `Folder name "<name>" already exist` | `dox create` into a folder that exists. | Pick another name. |
| `RangeError (index): Invalid value: Only valid value is 0: 1` | `dox create <name>` without `--version`, in `3.0.0-alpha.4`. | Pass `--version 3.0.0-alpha.4`. |
| `Invalid option <x>, use -m or --migration` | `dox create:model` with another option. | Use `-m`. |
| `Invalid option <x>, use --step=<count>` | `dox migration:rollback` with another option. | Use `--step=2`. |
| `db/migration has Dart migrations, but bin/migrate.dart is missing. ...` | Dart migrations but no entry file. | Run `dox make:migration <name>` once. |
| `Skip <file>: no class that extends Migration.` | A Dart file in `db/migration` has no migration class. | Add `class X extends Migration`, or move the file. |
| `.env.example is missing.` | `dox env:generate` with no example file. | Make `.env.example`. |
| `lib/config/env.dart is already there. Delete it to make it again.` | `dox env:generate` again. | Delete the file, or edit it by hand. |
| `lib/config/env.dart is missing. Run `dox env:generate` first.` | `dox env:check` with no env class. | Run `dox env:generate`. |
| `pubspec.yaml has no name.` | `dox env:check` can not find the package name. | Add `name:` to `pubspec.yaml`. |
| `bin/openapi.dart is missing. Make it with: ...` | `dox openapi:generate` with no entry file. | Make `bin/openapi.dart`. See [OpenAPI](../packages/openapi.md). |
| `zsh: command not found: dox` | `$HOME/.pub-cache/bin` is not in `PATH`. | See [Troubleshooting](troubleshooting.md#dox-command-not-found-after-dart-pub-global-activate). |

See [CLI](cli.md).
