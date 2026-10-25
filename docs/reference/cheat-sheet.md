# Cheat sheet

One page to keep open while you work. Each section links to its full page.

## Project layout

| Path | What is in it |
| --- | --- |
| `bin/server.dart` | starts the app: `Dox().initialize()`, migrations, `startServer()` |
| `bin/migrate.dart` | runs migrations for `dox migration:*` |
| `bin/openapi.dart` | writes the OpenAPI files for `dox openapi:generate` |
| `lib/config/` | `app.dart` (`AppConfig`), `env.dart`, `database.dart`, `cors.dart`, `cache.dart`, `storage.dart`, `openapi.dart`, `logger.dart`, `socketio.dart` |
| `lib/routes/` | `api.dart`, `web.dart`, `websocket.dart`: one `Router` class each |
| `lib/app/http/controllers/` | `<name>.controller.dart` |
| `lib/app/http/dtos/` | `<name>.dto.dart` |
| `lib/app/http/middleware/` | `<name>.middleware.dart` |
| `lib/app/http/serializers/` | `<name>.serializer.dart` |
| `lib/app/models/<name>/` | `<name>.model.dart` |
| `lib/services/` | `DoxService` classes: ORM, auth, websocket |
| `lib/container.g.dart`, `lib/dtos.g.dart`, `lib/openapi.g.dart` | made by `build_runner`. Do not edit. |
| `db/migration/` | migrations and `migrations.dart` (the registry) |

See [CLI](cli.md) and [App config](app-config.md).

## CLI

```bash
dox create my_app                  # newest template
dox serve                          # dev server + build_runner watch
dox build                          # AOT bundle in build/bundle
dox build_runner:build             # make .g.dart files
dox key:generate                   # APP_KEY in .env
dox env:generate                   # lib/config/env.dart from .env.example
dox env:check                      # check the env, exit 1 when bad
dox make:controller Blog [-r]
dox make:middleware Auth
dox make:dto CreateBlog
dox make:serializer Blog
dox make:model Blog -m           # model + migration
dox make:migration create_blogs_table [--sql]
dox migrate                        # migration:run
dox migration:rollback --step=1
dox migration:status
dox openapi:generate [dir]
```

See [CLI](cli.md).

## Routes

```dart
class ApiRouter extends Router {
  @override
  String get prefix => 'api';

  @override
  List<dynamic> get middleware => <dynamic>[];

  @override
  void register() {
    Route.get('/ping', (DoxRequest req) => 'pong');
  }
}
```

| Code | Does |
| --- | --- |
| `Route.get<C>('/blogs', (C c) => c.index)` | controller `C` from the container. Also `post`, `put`, `patch`, `delete`, `options` |
| `Route.get('/blogs', listBlogs)` | a plain function |
| `Route.post('/blogs', c.store, body: schema)` | `body:` is for the docs only. It checks nothing. |
| `Route.get('/blogs/{id}', c.show)` | path param. `show(int id)` |
| `Route.get('/posts/{page?}', c.list)` | optional param. `list(int? page)` |
| `Route.get('/docs/{path*}', c.page)` | rest of the path, with `/` |
| `Route.get('/me', <dynamic>[AuthMiddleware(), c.me])` | middleware first, controller last |
| `Route.group('/blogs', () { ... })` | prefix. Dox adds the `/` between parts. |
| `Route.middleware(<dynamic>[M()], () { ... })` | middleware for a group |
| `Route.domain('api.app.com', () { ... })` | match by `Host` |
| `Route.resource('blogs', BlogController)` | `index`, `create`, `store`, `show`, `edit`, `update`, `destroy` |
| `Route.files('files')` | serve a storage disk, signed URLs only |
| `Route.enabledCors(() { ... })` / `Route.disabledCors(...)` | CORS for some routes |
| `Route.websocket('echo', (WebSocket s, DoxRequest req) { ... })` | a raw WebSocket. For rooms and acks, use Socket.IO. |

Controller parameters, by type: `DoxRequest`, one `@Dto` class, `String`/`int`/`double`/`num`/`bool` for path params (by position), a `@DoxModel` (loaded by its key), an `@Inject()` class. Only positional parameters.

In the examples, `c.index` and the like are methods of a controller `C` from the container.

## Dependency injection

```dart
@Inject()                       // one instance per isolate
class PostService {
  PostService(this.posts);      // from the container, by type
  final PostRepository posts;
}

@Inject(singleton: false)       // a new instance each time
class Clock {}

AppConfig(container: registerContainer); // from lib/container.g.dart

Dox().ioc.get<PostService>();
Dox().ioc.override<PostRepository>(FakePostRepository()); // tests
```

Routers and `DoxService` classes are found without `@Inject()`. Run `dart run build_runner build` after a change.
See [Dependency injection](../the-basic/dependency-injection.md).

Middleware order: `globalMiddleware`, router `middleware`, group, route.

See [Routing](../the-basic/routing.md), [Controller](../the-basic/controller.md), [Middleware](../the-basic/middleware.md).

## Middleware

```dart
class ApiKeyMiddleware implements IDoxMiddleware {
  @override
  dynamic handle(IDoxRequest req) {
    if (req.header('X-Api-Key') != 'secret') {
      return response('no').statusCode(401); // stop here
    }
    return req; // go on
  }
}
```

See [Middleware](../the-basic/middleware.md).

## Request

| Code | Gives |
| --- | --- |
| `await req.validate<CreateBlog>()` | checked DTO, or `422` |
| `req.input('name')` | one value, query or body (body wins) |
| `req.all()` / `req.only(<String>['a', 'b'])` | many values |
| `req.has('name')` | key is there and not empty |
| `req.body` / `req.query` / `req.param['id']` | one source only |
| `req.header('X-Token')` / `req.headers` | headers |
| `req.cookie('token')` | decrypted cookie |
| `req.ip()` / `req.scheme()` / `req.isSecure()` | client info. Needs `trustedProxies` behind a proxy. |
| `req.userAgent()` / `req.host()` / `req.origin()` / `req.locale` | more headers |
| `req.isJson()` / `req.isFormData()` | content type |
| `req.auth?.user<User>()` | logged in user (after `AuthMiddleware`) |
| `req.method` / `req.uri` | method and URI |

Files:

```dart
RequestFile file = req.input('avatar');
file.filename; file.extension; file.length;   // bytes
String path = await file.store('avatars');    // save before you return
```

See [Request](../the-basic/request.md) and [Request and response](request-and-response.md).

## Response

| Return | Client gets |
| --- | --- |
| `String` | text |
| `Map`, `List`, model, `Pagination`, serializer | JSON |
| `File` | streamed file, `Range` supported |
| `Storage().stream(path)` / `Storage().download(path)` | file / download |
| `Stream<List<int>>` | streamed bytes |
| `throw NotFoundHttpException()` | `404 Not Found` |
| `response(...)` | full control |

```dart
return response(<String, dynamic>{'id': 1})
    .statusCode(201)
    .header('X-Request-Id', 'abc')
    .contentType(ContentType.json)
    .cache(Duration(minutes: 5))
    .cookie(DoxCookie('theme', 'dark', httpOnly: true, secure: true));

response('ok').cookie(DoxCookie('token', ''), setExpire: true); // delete
```

| Exception | Status |
| --- | --- |
| `BadRequestException()` | `400` |
| `UnAuthorizedException()` (`dox_auth`) | `401` |
| `NotFoundHttpException()` | `404` |
| `PayloadTooLargeException()` | `413` |
| `UnsupportedMediaTypeException()` | `415` |
| `ValidationException()` | `422` |
| `InternalErrorException()` | `500` |

See [Response](../the-basic/response.md) and [HTTP exceptions](http-exceptions.md).

## DTO validation

```dart
@Dto()
class CreateBlog {
  @Length(min: 3, max: 200)
  @Trim()
  final String title;

  final String? body;            // nullable = optional
  final Status status;           // enum = only its names

  const CreateBlog({required this.title, this.body, this.status = Status.draft});

  static const DtoSchema<CreateBlog> schema = $CreateBlogDto;
}
```

Then `dox build_runner:build`, and `dtos: dtos` in `AppConfig`.

| Kind | Annotations |
| --- | --- |
| Text | `@Length(min:, max:)`, `@MinLength(3)`, `@MaxLength(50)`, `@Email()`, `@Url()`, `@Uuid()`, `@Ip()`, `@Regex(r'..')`, `@In([..])`, `@NotIn([..])`, `@StartsWith('a')`, `@EndsWith('b')`, `@Alpha()`, `@AlphaNumeric()`, `@AlphaDash()` |
| Change text | `@Trim()`, `@Lowercase()`, `@Uppercase()`, `@AllowEmpty()` |
| Numbers | `@Min(1)`, `@Max(9)`, `@Range(1, 9)`, `@Positive()`, `@GreaterThan(0)`, `@LessThan(9)`, `@In`, `@NotIn` |
| Lists | `@MinItems(1)`, `@MaxItems(5)`, `@UniqueItems()` |
| Dates | `@After('2000-01-01')`, `@Before('now')` |
| Files | `@MaxSize('2MB')`, `@Mimes(['pdf'])`, `@Image()` |
| Database (`dox_orm`) | `@Unique('users', column: 'email', ignoreParam: 'id')`, `@Exists('teams')` |
| Keys | `@Name('emailAddress')` |
| Class | `@Dto(source: Source.query, keyCase: KeyCase.field, strict: true, messages: {...})` |

Cross field check: add `void validate(DtoErrors errors)` to the DTO. PATCH "missing or null": `Maybe<T>` with `const Maybe.missing()`.

See [Validation](../the-basic/validation.md) and [Validation rules](../the-basic/validation-rules.md).

## Model

```dart
@DoxModel(table: 'blogs', softDelete: true)
class Blog extends BlogGenerator {
  @Column()
  String? title;

  @Column(name: 'user_id')
  int? userId;

  @BelongsTo(User)
  User? user;

  @HasMany(Comment)
  List<Comment> comments = <Comment>[];

  @override
  List<String> get hidden => <String>['secret'];
}
```

| Code | Does |
| --- | --- |
| `await Blog().find(1)` / `find('slug', 'a')` | one row or `null` |
| `await Blog().all()` | every row (ignores `where`) |
| `await Blog().where('status', 'live').get()` | rows that match |
| `await Blog().where('id', '>', 5).getFirst()` | first match or `null` |
| `await Blog().count()` | `int` |
| `await Blog().paginate(currentPage: 1, perPage: 20)` | `Pagination<Blog>`, rows in `data` |
| `await Blog().create(<String, dynamic>{'title': 'a'})` | insert and return the model |
| `blog.title = 'b'; await blog.save()` | insert or update |
| `await blog.delete()` | soft delete when `softDelete: true` |
| `await blog.forceDelete()` / `await blog.restore()` | real delete / undo soft delete |
| `Blog().withTrash()` | include soft deleted rows |
| `Blog().preload('comments').get()` | load a relation, one query |
| `await blog.$getRelation('user')` | load a relation on one model |
| `blog.related<Comment>('comments')?.where(...).get()` | relation query |
| `blog.toJson()` / `blog.toMap()` | map, `hidden` left out of `toJson()` |
| `Blog().query()` | a new, empty query |

Relations: `@HasOne(T)`, `@HasMany(T)`, `@BelongsTo(T)`, `@ManyToMany(T)`. Options: `foreignKey`, `localKey`, `onQuery`, `eager`.

Events: override `onCreating()`, `onCreated()`, `onSaving()`, `onUpdated()`, `onDeleting()`, ... or `Model.observe<Blog>(BlogObserver())`. `throw CancelModelEvent('why')` in a "before" event stops it. `saveQuietly()` skips events.

See [Model](../database/model/index.md), [Events](../database/model/events.md), [HasMany](../database/model/relationship/has-many.md).

## Query builder

```dart
List<Map<String, dynamic>> rows = await QueryBuilder.table('blogs')
    .select(<String>['id', 'title'])
    .where('status', 'live')
    .orWhere('views', '>', 100)
    .whereIn('id', <int>[1, 2, 3])
    .whereNull('deleted_at')
    .join('users', 'users.id', 'blogs.user_id')
    .orderBy('id', 'desc')
    .limit(10)
    .offset(20)
    .get();
```

| Code | Does |
| --- | --- |
| `whereNotIn`, `whereNotNull`, `orWhereIn`, `orWhereNull` | more filters |
| `whereRaw('lower(name) = @n', <String, dynamic>{'n': 'a'})` | raw SQL, bound values |
| `leftJoin`, `rightJoin`, `joinRaw` | joins |
| `groupBy('age')`, `selectRaw('DISTINCT name')` | groups, raw select |
| `insert({...})`, `insertMultiple([...])` | insert |
| `where(...).update({...})` | update, no events, no `updated_at` |
| `where(...).delete()`, `truncate()` | delete |
| `QueryBuilder.query('select 1', substitutionValues: {...})` | raw query |
| `withConnection('mysql')` | another connection |
| `toSql()`, `debug(true)` | see the SQL |

See [Query builder](../database/query-builder.md).

## Migrations and schema

```dart
class CreateBlogsTable extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await schema.create('blogs', (Table table) {
      table.id();
      table.foreignId('user_id').constrained('users').cascadeOnDelete();
      table.string('title');
      table.text('body').nullable();
      table.enumeration('status', <String>['draft', 'live']).defaultTo('draft');
      table.timestamps();
      table.softDeletes();
    });
  }

  @override
  Future<void> down(Schema schema) async {
    await schema.dropIfExists('blogs');
  }
}
```

| Column types |
| --- |
| `id()`, `increments`, `bigIncrements`, `string(c, [255])`, `char`, `text`, `mediumText`, `longText` |
| `integer`, `bigInteger`, `smallInteger`, `tinyInteger`, `unsignedInteger` (and `Big`, `Small`, `Tiny`) |
| `float`, `double`, `decimal(c, [8], [2])`, `boolean` |
| `date`, `dateTime`, `dateTimeTz`, `time`, `timestamp`, `timestampTz` |
| `json`, `jsonb`, `uuid`, `binary`, `enumeration(c, [...])`, `foreignId`, `foreignUuid` |
| `timestamps()`, `softDeletes()`, `rememberToken()`, `morphs('owner')` |

| Modifiers |
| --- |
| `nullable()`, `defaultTo(v)`, `defaultRaw('sql')`, `useCurrent()`, `useCurrentOnUpdate()` |
| `unique()`, `index()`, `primary()`, `unsigned()`, `comment('t')`, `after('c')`, `change()` |
| keys: `constrained([table])`, `references('id').on('t')`, `onDelete('cascade')`, `cascadeOnDelete()`, `nullOnDelete()` |

Change a table: `schema.table('t', (Table table) { table.string('a').nullable().change(); table.renameColumn('b', 'c'); table.dropColumn('d'); })`.

See [Migration](../database/migration.md) and [Schema](../database/schema.md).

## Transactions

```dart
int? id = await QueryBuilder.transaction(() async {
  Blog blog = await Blog().create(<String, dynamic>{'title': 'a'});
  await QueryBuilder.table('blog_info').insert(<String, dynamic>{'blog_id': blog.id});
  return blog.id;
}); // throw inside = rollback
```

See [Transactions](../database/transactions.md).

## Cache

```dart
await Cache().put('k', 'v', duration: Duration(minutes: 10));
await Cache().get('k', 'default');
await Cache().remember('posts', Duration(minutes: 5), () => Post().all());
await Cache().forget('k');
await Cache().store('redis').increment('hits');
await Cache().tag('users').flush();
CacheLock lock = Cache().store('redis').lock('report', Duration(seconds: 30));
```

Values must be JSON types. `memory` is per isolate. See [Cache](../digging-deeper/cache.md).

## Storage

```dart
String path = await Storage().putRequestFile('avatars', file); // '/avatars/<uuid>.png'
Uint8List? bytes = await Storage().get(path);
await Storage().exists(path);
await Storage().delete(path);
String url = await Storage().signedUrl(path, expiresIn: Duration(minutes: 10));
await Storage().disk('s3').put('reports', bytes, extension: 'pdf');
return Storage().download(path); // from a controller
```

See [File storage](../digging-deeper/file-storage.md).

## Env

```dart
@DoxEnv()
abstract class AppEnv {
  static AppEnv load([EnvReader? reader]) => _$AppEnv.load(reader);

  String get appKey;              // APP_KEY, required
  int get appPort => 3000;        // APP_PORT, default 3000
  String? get awsBucket;          // AWS_BUCKET, optional
}

final AppEnv env = AppEnv.load();
```

A new project has this class in `lib/config/env.dart`. Use `env.appPort` in code. After you add a getter, run `dart run build_runner build`.

`Env.get<int>('APP_PORT', 3000)` is the low-level way. It reads a key by name. A real env var wins over `.env`. In `.env`, a `#` after a space starts a comment.

See [Environment variables](../digging-deeper/env.md) and [Env reference](env.md).

## Auth

```dart
Auth.initialize(AuthConfig(
  defaultGuard: 'web',
  guards: <String, AuthGuard>{
    'web': AuthGuard(
      driver: JwtAuthDriver(secret: SecretKey(env.appKey), expiresIn: Duration(days: 7)),
      provider: AuthProvider(model: () => User()),
    ),
  },
));

String? token = await Auth().attempt(<String, dynamic>{'email': e, 'password': p});
String? token2 = Auth().login(user);
user.password = Hash.make(password);
bool ok = Hash.verify(password, hash);
```

Protect a route with `AuthMiddleware()`. Client sends `Authorization: Bearer <token>`.

See [Authentication](../security/authentication.md) and [Hashing](../security/hashing.md).

## Socket.IO

```dart
class ChatNamespace extends NamespaceHandler {
  @override
  String get path => '/chat';

  @override
  void onConnection(Socket socket) {
    socket.join('lobby');
    socket.on('chat', onChat);
  }

  void onChat(SocketEvent event) {
    event.socket.to('lobby').emit('chat', event.data);
    event.ack('ok');
  }
}
```

Turn it on with `SocketIoConfig` in `AppConfig`. Many isolates need the Redis adapter and `transports: ['websocket']` on the client.

See [Socket.IO](../packages/socketio.md).

## OpenAPI

```dart
OpenApiConfig openApi = OpenApiConfig(
  info: Info(title: 'Blog API', version: '1.0.0'),
  registry: openApiRegistry, // lib/openapi.g.dart
);
```

Docs at `/docs`, `/openapi.json`, `/openapi.yaml`. On only when `APP_ENV` is `development` or `local`, unless `enabled: true`. Change one route with `@Summary`, `@Tags`, `@Request(T)`, `@Response(200, T)`, `@ApiIgnore()`.

See [OpenAPI](../packages/openapi.md).

## Testing

```dart
import 'package:dox_core/testing.dart';
import 'package:dox_orm/testing.dart';

late DoxTestClient client;
setUpAll(() async => client = await DoxTestClient.start(appConfig));
setUp(refreshDatabase); // empty every table before each test
tearDownAll(() async => client.close());

test('ping', () async {
  (await client.get('/api/ping')).expectStatus(200).expectBody('pong');
  (await client.withToken(token).post('/api/posts', body: {...})).expectStatus(201);
});
```

| Fake | Code |
| --- | --- |
| cache | `Dox().cache = CacheManager(CacheConfig(defaultStore: 'memory', stores: {...}))` |
| storage | `Disk fake = Dox().storage.fake('s3');` then `Dox().storage.restore('s3')` |
| env | `AppEnv.load(EnvReader(environment: {...}, dotEnv: {...}))` |
| DTO | `await CreateBlog.schema.safeValidateMap(<String, dynamic>{...})` |

Run with `dart test --concurrency=1` when files share a port or tables.

See [Testing](../digging-deeper/testing.md).
