# Upgrade from 2.x to 3.x

!!! warning "3.x is alpha"
    `3.0.0-alpha.1` can still change before the stable release. The 2.x docs stay online: pick **2.x** in the version menu at the top.

## Do these first

1. Use Dart **3.13** or newer.
2. Set every Dox package to the same version, `^3.0.0-alpha.1`. All Dox packages now share one version.
3. Replace `dox_query_builder` with `dox_orm`.
4. If you use `ioredis` in your app, update it to `^2.0.0-alpha.1`.
5. Run `dart pub upgrade`, then `dox build_runner:build`.
6. Replace rule strings and form requests with DTOs. See [Validation](#validation).
7. Read the list below. Each item says what breaks and how to fix it.

```yaml
environment:
  sdk: ^3.13.0

dependencies:
  dox_core: ^3.0.0-alpha.1
  dox_orm: ^3.0.0-alpha.1        # was dox_query_builder
  dox_migration: ^3.0.0-alpha.1
  dox_auth: ^3.0.0-alpha.1
  dox_websocket: ^3.0.0-alpha.1
  ioredis: ^2.0.0-alpha.1        # only if you use redis

dev_dependencies:
  dox_builder: ^3.0.0-alpha.1
  build_runner: ^2.17.1
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

**`save()`, `delete()` and `forceDelete()` return `Future<bool>`.**
They return `false` when a model event cancels them. Code that overrides these methods in a model must use `Future<bool>`.

**A model can not have a field or method named like a model hook.**
The `Model` class now has `onSaving()`, `onCreated()`, `onDeleted()` and the other [event hooks](../database/model/events.md), plus `restore()`, `saveQuietly()`, `hasModelHooks` and `setComputedValues()`.
Fix: rename a field with one of these names.

**`dox_builder` needs the new analyzer.**
It uses `analyzer` 14, `source_gen` 4 and `build` 5, so it needs Dart **3.13** or newer.
Set `build_runner: ^2.17.1` in `dev_dependencies`.
Other builders in your app (for example `json_serializable`) must also support `analyzer` 14.

**New:** [computed values](../database/model/index.md#computed-values) with `@Computed()`, [model events and observers](../database/model/events.md), and `restore()` for soft deleted models.

**New:** SQLite, `whereNull`, `whereNotNull`, `whereNotIn`, `orWhereIn`, `orWhereNotIn`, `selectRaw`, `boolean()` column, transactions.
See [Database](../database/index.md).

## Migrations

**Migrations are Dart files now.**
`dox make:migration create_users_table` makes a Dart class in `db/migration`.
It also makes the registry `db/migration/migrations.dart` and, once, `bin/migrate.dart`.
The `dox migration:*` commands run `bin/migrate.dart` in your app.
Old `.sql` migrations still run. Use `make:migration <name> --sql` for a new `.sql` file.
`dox migration:status` shows which migrations ran.

**The runner is renamed.**
`Migration()` is now `Migrator()`. `Migration` is now the base class of a Dart migration.
`migrate(conn)` is now `Migrator(connection: conn).migrate()`.
`rollback(null, 2)` is now `rollback(step: 2)`.

**The schema builder changed.** See [Schema builder](../database/schema.md).

- `Schema.create(...)` is now `Schema().create(...)`, or the `schema` given to `up`.
- In `schema.table(...)` a column is added. Add `.change()` to change a column that exists.
- `string()` is `VARCHAR(255)` by default. It was 100.
- `id()` is `BIGSERIAL` on Postgres. It was `SERIAL`.
- `money()`, `float4()` and `float8()` are removed. Use `decimal()`, `float()` or `double()`.
- `foreignId('user_id').constrained()` guesses a plural table: `users`, `categories`.
- `CREATE TABLE` and `CREATE UNIQUE INDEX` no longer add `IF NOT EXISTS`. Check with `schema.hasTable()` first if you need it.

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

**`dox build` makes an AOT bundle in `build/bundle`.** The binary is `build/bundle/bin/server`.
It uses `dart build cli`, not `dart compile exe`. `dox_orm` uses `sqlite3` v3, which bundles SQLite
with a build hook, and `dart compile exe` stops with "does not support build hooks".
If your own Dockerfile or CI runs `dart compile exe`, change it to
`dart build cli --target bin/server.dart --output build` and copy all of `build/bundle`.
See [Deployment](../digging-deeper/deployment.md).

## Validation

**Rule strings are gone. Input is a typed class (a DTO).**
`req.validate({'title': 'required|string'})`, `v.fromRules()` and `FormRequest` are removed.
Fix: write a `@Dto` class for each input, and ask for it in the controller. See [Validation](validation.md).

```dart
// 2.x
class BlogController {
  store(DoxRequest req) async {
    req.validate({
      'title': 'required|string|max_length:100',
      'status': 'required|in:active,draft',
      'tags': 'array',
    });
    String title = req.input('title');
    // ...
  }
}

// 3.x
enum Status { active, draft }

@Dto()
class CreateBlog {
  @MaxLength(100)
  final String title;
  final Status status;
  final List<String>? tags;

  const CreateBlog({required this.title, required this.status, this.tags});

  static const DtoSchema<CreateBlog> schema = $CreateBlogDto;
}

class BlogController {
  Future<Blog> store(CreateBlog body) async {
    String title = body.title;
    // ...
  }
}
```

Steps:

1. Make each DTO with `dox create:dto <Name>`.
2. Run `dart run build_runner build`.
3. Add `dtos: dtos` (from `lib/dtos.g.dart`) to `AppConfig`.
4. Remove `formRequests:` from `AppConfig`.

### APIs

| 2.x | 3.x |
| --- | --- |
| `req.validate({...})` | a DTO controller parameter, or `await req.validate<T>()` |
| `req.validateAsync({...})` | removed. `req.validate<T>()` is always async. |
| `req.validateSchema(schema)` | the same. Only for [dynamic input](validation.md#dynamic-input-fluent-schemas). |
| `class BlogRequest extends FormRequest` | `@Dto() class CreateBlog` |
| `rules()` | annotations on the fields |
| `messages()` | `@Dto(messages: {...})` or `message:` on an annotation |
| `setUp()`, `mapInputs()`, `validated` | fields of the DTO. Rename a key with `@Name('key')`. |
| `AppConfig(formRequests: {...})` | `AppConfig(dtos: dtos)` |
| `dox create:request` | `dox create:dto` |
| `v.fromRules()`, `v.registerRule()`, `DoxValidator.addCustomRule()` | a `Rule<T>` class used as an annotation. See [Custom rules](validation.md#custom-rules). |
| `show(DoxRequest req, String id)` | still works. New: `show(int id)`. See [Controller: parameters](controller.md#parameters). |

### Rules

| 2.x rule | 3.x |
| --- | --- |
| `required` | a non-nullable field with no default: `final String name;` |
| `nullable` | a nullable field: `final int? age;` |
| `sometimes` | a nullable field, or `Maybe<T>` to know "missing" from `null` |
| `required_if`, `required_if_not` | a nullable field, plus a check in [`validate()`](validation.md#checks-across-fields-validate) |
| `string` | `String` |
| `integer` | `int` |
| `numeric`, `double` | `num`, `double` |
| `boolean` | `bool` |
| `array` | `List<T>` |
| `json` | `Map<String, dynamic>` (send an object, not a JSON text) |
| `date` | `DateTime` |
| `email`, `url`, `uuid`, `ip` | `@Email()`, `@Url()`, `@Uuid()`, `@Ip()` |
| `alpha`, `alpha_dash`, `alpha_numeric` | `@Alpha()`, `@AlphaDash()`, `@AlphaNumeric()` |
| `in:a,b` | a Dart `enum`, or `@In(['a', 'b'])` |
| `not_in:a,b` | `@NotIn(['a', 'b'])` |
| `start_with:x`, `end_with:x` | `@StartsWith('x')`, `@EndsWith('x')` |
| `min_length:3`, `max_length:50` | `@MinLength(3)`, `@MaxLength(50)` |
| `length_between:3,50` | `@Length(min: 3, max: 50)` |
| `min:18`, `max:100` | `@Min(18)`, `@Max(100)` |
| `between:1,10` | `@Range(1, 10)` |
| `greater_than:0`, `less_than:100` | `@GreaterThan(0)`, `@LessThan(100)` |
| `confirmed` | a `password_confirmation` field, plus a check in `validate()` |
| `unique:users,email,5` | `@Unique('users', 'email', ignoreParam: 'id')` |
| `exists:teams,id` | `@Exists('teams', 'id')` |
| `file:pdf,docx` | a `RequestFile` field with `@Mimes(['pdf', 'docx'])` |
| `image`, `image:png,jpg` | a `RequestFile` field with `@Image()`, or `@Mimes(['png', 'jpg'])` |
| `address.city` | a nested `@Dto` field: `final Address address;` |
| `products.*.name` | a list of DTOs: `final List<Product> products;` |

### Behaviour changes

- **JSON types are strict.** `"18"` in a JSON body is not an `int`. Query and form data are still converted.
- **Keys are snake_case by default.** A field `postCode` reads `post_code`. Use `@Name()` or `@Dto(keyCase: KeyCase.field)` to change it.
- **Unknown keys are dropped** from the DTO. `req.body` still has the raw input.
- **`""` counts as missing.** A required `String` rejects `""`. Add `@AllowEmpty()` to accept it.
- **Database rules run last**, and only when all other checks passed.
- **The 422 body is the same shape:** `{"field": "message"}`. Nested keys use dots, list items use the index: `items.0.name`.
- `dox_core` exports the `dox_validation` names (`v`, `Schema`, `Rule`, `Dto`, `Min`, ...). `dox_orm` also has a `Schema` class.
  A file that imports both and uses `Schema` gets an "ambiguous import" error. Fix: `import 'package:dox_orm/dox_orm.dart' as orm;` or `hide Schema`.
- A class of yours named like a `dox_validation` class (for example `Rule`, `Name` or `Range`) wins in its own file. In other files, hide the `dox_core` one.
- `Rule` has a `const` constructor now, and `message` is `final`.

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

**`create:migration` is now `make:migration`.** The old name still works.
It makes a Dart file by default. `--dart` is gone, use `--sql` for a `.sql` file.

**`create:model Blog -m` makes a Dart migration.**
The migration is `create_blogs_table`, and the model gets `@DoxModel(table: 'blogs')`.

## Cache

**`Cache()` runs on `dox_cache`.** The config changed:

```dart
// old
CacheConfig(
  defaultDriver: 'file',
  drivers: <String, CacheDriverInterface>{'file': FileCacheDriver()},
);

// new
CacheConfig(
  defaultStore: 'file',
  stores: <String, Map<String, dynamic>>{
    'file': <String, dynamic>{'driver': 'file', 'path': 'storage/cache'},
    'redis': <String, dynamic>{'driver': 'redis', 'host': '127.0.0.1'},
  },
);
```

- `CacheDriverInterface` and `FileCacheDriver` are gone. For your own driver, see [dox_cache](../packages/cache.md#your-own-driver).
- **Values must be JSON types** (`Map`, `List`, `String`, `num`, `bool`). Other types throw.
- **`put` with no `duration` keeps the value forever.** Before, it kept it 1 hour. Pass `duration:` where you need a limit.
- `Cache().flush()` with no tag empties the whole store.
- Old cache files are not read. The new files are plain JSON, not encrypted. Delete `storage/cache` once.

See [Cache](../digging-deeper/cache.md).

## File storage

**`Storage()` runs on `dox_storage`.** `AppConfig(fileStorage:)` is now `AppConfig(storage:)`:

```dart
// old
FileStorageConfig(
  defaultDriver: 'local',
  drivers: <String, StorageDriverInterface>{'local': LocalStorageDriver()},
);

// new
StorageConfig(
  defaultDisk: 'local',
  disks: <String, Map<String, dynamic>>{
    'local': <String, dynamic>{'driver': 'local', 'root': 'storage'},
  },
);
```

- `StorageDriverInterface` and `LocalStorageDriver` are gone. Implement `DriverContract` from `dox_storage` and call `Dox().storage.register(name, driver)`.
- `Storage().disk('name')` with a name that is not in the config throws. Before, it used the default disk.
- `put`, `putRequestFile`, `get`, `exists`, `delete`, `stream` and `download` work as before. Paths still look like `/images/<uuid>.png`.
- `stream()` now gets the content type from the file extension, not from the first bytes.

See [File Storage](../digging-deeper/file-storage.md).

## Environment

**A missing key is never the text `"null"`.**
Before, `Env.get('APP_KEY')` with no `APP_KEY` gave `"null"`, so the app used a key anyone can guess.
Now a `String` gives `''`, `String?` gives `null`, and `int`, `num`, `double`, `bool` throw an `ArgumentError`.
Fix: give a default where a key is optional, for example `Env.get<int>('APP_PORT', 3000)`.

**An empty `APP_KEY` stops the server in production** (`APP_ENV=production`). Run `dox key:generate`.

## New built-in features

- [OpenAPI docs](../packages/openapi.md#in-a-dox-app) at `/docs`, on by default only when `APP_ENV` is `development` or `local`. `dox openapi:generate` writes the files.
- [Socket.IO](../packages/socketio.md#in-a-dox-app-same-port-as-http) on the app port, off by default.
- [Typed DTOs](validation.md) with `@Dto()`, typed [controller parameters](controller.md#parameters), and [`@Unique` / `@Exists`](validation.md#database-rules-unique-and-exists).
- `Route.files()` for local signed URLs, and the catch-all route param `{path*}`.
