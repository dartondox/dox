# Coming from Laravel

This page is for developers who know Laravel. It shows the Laravel way and the Dox way side by side.
The Dox code is real 3.x code. The Laravel code is Laravel 11.

Dox follows the ideas of Laravel: routers, controllers, middleware, an ORM with models and relations, migrations, a CLI.
But Dox is Dart. It has static types, no reflection at run time, and it compiles to one native binary.

## Routing

| Laravel | Dox |
| --- | --- |
| `Route::get('/ping', fn () => 'pong');` | `Route.get('/ping', (DoxRequest req) => 'pong');` |
| `Route::post('/blogs', [BlogController::class, 'store']);` | `Route.post('/blogs', blogController.store);` |
| `Route::get('/blogs/{id}', ...)` and `function show(int $id)` | `Route.get('/blogs/{id}', ...)` and `show(int id)` |
| `Route::get('/posts/{page?}', ...)` | `Route.get('/posts/{page?}', (int? page) => ...)` |
| `->where('path', '.*')` | `Route.get('/docs/{page*}', (String page) => ...)` |
| `Route::prefix('blogs')->group(function () { ... });` | `Route.group('/blogs', () { ... });` |
| `Route::middleware('auth')->group(...)` | `Route.middleware(<dynamic>[AuthMiddleware()], () { ... });` |
| `Route::domain('admin.app.test')->group(...)` | `Route.domain('admin.app.test', () { ... });` |
| `Route::resource('blogs', BlogController::class);` | `Route.resource('blogs', BlogController());` |
| `routes/api.php` with the `api` prefix | `lib/routes/api.dart`, a `Router` class with `prefix => 'api'` |

In Dox, a controller is an object you make yourself. There is no `BlogController::class` string.

```dart title="lib/routes/api.dart"
class ApiRouter extends Router {
  @override
  String get prefix => 'api';

  @override
  List<dynamic> get middleware => <dynamic>[];

  @override
  void register() {
    BlogController blogController = BlogController();
    Route.get('/blogs', blogController.index);
    Route.resource('users', UserController());
  }
}
```

## Controllers

| Laravel | Dox |
| --- | --- |
| `php artisan make:controller BlogController` | `dox create:controller Blog` |
| `php artisan make:controller BlogController --resource` | `dox create:controller Blog -r` |
| `public function show(Request $request, int $id)` | `Future<Blog?> show(DoxRequest req, int id)` |
| `public function store(StoreBlogRequest $request)` | `Future<Blog> store(CreateBlog body)` |
| injected by the service container | filled by type: `DoxRequest`, one `@Dto` class, path params |

Dox fills a parameter by its type, not by its name. Path params go by position.
A controller can be a class method, a static method or a plain function.

## Middleware

| Laravel | Dox |
| --- | --- |
| `php artisan make:middleware Logger` | `dox create:middleware Logger` |
| `public function handle(Request $request, Closure $next)` | `dynamic handle(IDoxRequest req)` |
| `return $next($request);` | `return req;` |
| `return response('no', 401);` | `return response('no').statusCode(401);` |
| `abort(404);` | `throw NotFoundHttpException();` |
| `$middleware->append(LogMiddleware::class)` in `bootstrap/app.php` | `AppConfig(globalMiddleware: <dynamic>[LogMiddleware()])` |

```dart title="lib/app/http/middleware/logger.middleware.dart"
class LoggerMiddleware implements IDoxMiddleware {
  @override
  dynamic handle(IDoxRequest req) {
    print('${req.method} ${req.uri.path}');
    return req; // go on. anything else is the response.
  }
}
```

A plain function `dynamic apiKey(DoxRequest req)` also works as middleware.
Dox middleware runs before the controller only. There is no "after" step; use a `responseHandler` for that.

## Requests and validation

| Laravel | Dox |
| --- | --- |
| `php artisan make:request StoreBlogRequest` | `dox create:dto CreateBlog` |
| `class StoreBlogRequest extends FormRequest` with `rules()` | `@Dto() class CreateBlog` with annotations on `final` fields |
| `'title' => ['required', 'string', 'max:50']` | `@MaxLength(50) final String title;` |
| `'age' => ['nullable', 'integer', 'min:18']` | `@Min(18) final int? age;` |
| `'email' => ['required', 'email', 'unique:users']` | `@Email() @Unique('users') final String email;` |
| `'role' => Rule::in(['admin', 'user'])` | `final Role role;` (a Dart enum) |
| `'tags' => ['array', 'max:5']`, `'tags.*' => 'string'` | `@MaxItems(5) final List<String> tags;` |
| `$request->validated()` | the DTO object itself, already typed |
| `$request->validate([...])` inside a method | `await req.validate<CreateBlog>()` |
| `$request->input('name')` | `req.input('name')` |
| `$request->file('avatar')` | a `RequestFile` field in the DTO, or `req.input('avatar')` |
| `$request->user()` | `req.auth?.user<User>()` |
| `422` with `{"errors": {...}}` | `422` with a flat map `{"email": "...", "items.1.quantity": "..."}` |

```dart title="lib/app/http/dtos/create_blog.dto.dart"
@Dto()
class CreateBlog {
  @Length(min: 3, max: 50)
  final String title;

  @Min(18)
  final int? age; // nullable = optional

  const CreateBlog({required this.title, this.age});

  static const DtoSchema<CreateBlog> schema = $CreateBlogDto;
}
```

The rules are checked by generated Dart code, not by rule strings at run time.
Run `dox build_runner:build` after you change a DTO. See [Validation](../the-basic/validation.md).

## Responses

| Laravel | Dox |
| --- | --- |
| `return 'pong';` | `return 'pong';` |
| `return ['a' => 1];` | `return <String, int>{'a': 1};` |
| `return $blog;` (JSON) | `return blog;` (JSON from `toJson()`) |
| `return response($data, 201)->header('X-A', 'b');` | `return response(data).statusCode(201).header('X-A', 'b');` |
| `return response()->json($data);` | `return data;` (a `Map` or `List` is JSON) |
| `return response()->file($path);` | `return File(path);` |
| `return response()->download($path);` | `return Storage().download(path);` |
| `->cookie('theme', 'dark')` | `.cookie(DoxCookie('theme', 'dark'))` |
| `abort(404, 'Not found');` | `throw NotFoundHttpException(message: 'Not found');` |
| `new BlogResource($blog)` | `BlogSerializer(blog)` |

## Eloquent vs Dox Model

| Laravel | Dox |
| --- | --- |
| `php artisan make:model Blog -m` | `dox create:model Blog -m` |
| `class Blog extends Model` | `@DoxModel() class Blog extends BlogGenerator` |
| `protected $table = 'blogs';` | `@DoxModel(table: 'blogs')` |
| `protected $primaryKey = 'uid';` | `@DoxModel(primaryKey: 'uid')` |
| `use SoftDeletes;` | `@DoxModel(softDelete: true)` |
| `protected $hidden = ['password'];` | `List<String> get hidden => <String>['password'];` |
| `protected $fillable = [...]` | not needed. Only `@Column()` fields are saved. |
| `protected $casts = ['meta' => 'array'];` | the field type: `Map<String, dynamic>? meta;` |
| mutator `setSlugAttribute()` | `@Column(beforeSave: makeSlug)` |
| accessor `getStatusAttribute()` | `@Column(beforeGet: readStatus)` |
| `$appends` with an accessor | `@Computed() String get fullName => ...;` |
| `Blog::find(1)` | `await Blog().find(1)` |
| `Blog::where('age', '>', 18)->get()` | `await Blog().where('age', '>', 18).get()` |
| `Blog::create([...])` | `await Blog().create(<String, dynamic>{...})` |
| `$blog->save()` | `await blog.save()` |
| `$blog->delete()` | `await blog.delete()` |
| `Blog::withTrashed()` | `Blog().withTrash()` |
| `$blog->restore()` | `await blog.restore()` |
| `Blog::with('posts')->get()` | `await Blog().preload('posts').get()` |
| `$blog->load('posts')` | `await blog.$getRelation('posts')` |
| `$user->posts()->where(...)->get()` | `user.related<Post>('posts')?.where(...).get()` |
| `$with = ['posts']` | `@HasMany(Post, eager: true)` |
| `hasOne`, `hasMany`, `belongsTo`, `belongsToMany` | `@HasOne`, `@HasMany`, `@BelongsTo`, `@ManyToMany` |
| local scope `scopeActive()` | `onQuery: onlyActive` on a relation, or a static method that returns a query |
| `creating`, `saved`, `deleting` events | `onCreating()`, `onSaved()`, `onDeleting()` hooks in the model |
| `Blog::observe(BlogObserver::class)` | `Model.observe<Blog>(BlogObserver())` |
| `$blog->saveQuietly()` | `await blog.saveQuietly()` |
| `Model::withoutEvents(fn)` | `Model.withoutEvents(() async { ... })` |

```dart title="lib/app/models/blog/blog.model.dart"
@DoxModel(table: 'blogs', softDelete: true)
class Blog extends BlogGenerator {
  @Column()
  String? title;

  @Column(name: 'user_id')
  int? userId;

  @BelongsTo(User)
  User? user;

  @override
  Future<void> onCreating() async {
    title = title?.trim();
  }
}
```

Every column field is nullable, because a new model has no values yet.
Dox has no global scopes and no `$casts` list. Use the field type, `beforeSave` and `beforeGet`.
Run `dox build_runner:build` after you change a model. See [Model](../database/model/index.md).

## Query builder

| Laravel | Dox |
| --- | --- |
| `DB::table('users')->get()` | `await QueryBuilder.table('users').get()` |
| `->where('a', 1)->orWhere('b', 2)` | `.where('a', 1).orWhere('b', 2)` |
| `->whereIn('id', [1, 2])` | `.whereIn('id', <int>[1, 2])` |
| `->whereNull('deleted_at')` | `.whereNull('deleted_at')` |
| `->whereRaw('lower(name) = ?', [$n])` | `.whereRaw('lower(name) = @n', <String, dynamic>{'n': n})` |
| `->select('id', 'name')` | `.select(<String>['id', 'name'])` |
| `->orderBy('name', 'desc')->limit(10)->offset(20)` | `.orderBy('name', 'desc').limit(10).offset(20)` |
| `->join('posts', 'posts.user_id', '=', 'users.id')` | `.join('posts', 'posts.user_id', 'users.id')` |
| `->groupBy('age')` | `.groupBy('age')` (returns maps) |
| `->count()` | `await ....count()` |
| `->paginate(10)` | `.paginate(currentPage: 1, perPage: 10)` |
| `->insert([...])` | `.insertMultiple(<Map<String, dynamic>>[...])` |
| `->update([...])` | `.update(<String, dynamic>{...})` |
| `->delete()` | `.delete()` |
| `DB::select('select ...', [$id])` | `QueryBuilder.query('select ... @id', substitutionValues: {'id': id})` |
| `DB::transaction(fn)` | `QueryBuilder.transaction(() async { ... })` |
| `->toSql()` | `.toSql()` |
| `DB::connection('mysql')` | `.withConnection('mysql')` |

Values are always bound parameters. Names you pass are quoted. Do not pass user input as a column name or an operator.

## Migrations and schema

| Laravel | Dox |
| --- | --- |
| `php artisan make:migration create_users_table` | `dox make:migration create_users_table` |
| `database/migrations/` | `db/migration/` |
| `Schema::create('users', function (Blueprint $table) {...})` | `await schema.create('users', (Table table) {...})` |
| `$table->id();` | `table.id();` |
| `$table->string('email')->unique();` | `table.string('email').unique();` |
| `$table->foreignId('user_id')->constrained()->cascadeOnDelete();` | `table.foreignId('user_id').constrained().cascadeOnDelete();` |
| `$table->timestamps();` | `table.timestamps();` |
| `$table->softDeletes();` | `table.softDeletes();` |
| `$table->string('name', 100)->nullable()->change();` | `table.string('name', 100).nullable().change();` |
| `Schema::dropIfExists('users');` | `await schema.dropIfExists('users');` |
| `php artisan migrate` | `dox migrate` (or `dox migration:run`) |
| `php artisan migrate:rollback --step=2` | `dox migration:rollback --step=2` |
| `php artisan migrate:reset`, `migrate:refresh`, `migrate:status` | `dox migration:reset`, `migration:refresh`, `migration:status` |

```dart title="db/migration/2026_10_21_120000_create_users_table.dart"
class CreateUsersTable extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await schema.create('users', (Table table) {
      table.id();
      table.string('email').unique();
      table.timestamps();
    });
  }

  @override
  Future<void> down(Schema schema) async {
    await schema.dropIfExists('users');
  }
}
```

Dart can not load files at run time in an AOT binary. So the CLI keeps a list of your migrations in `db/migration/migrations.dart`. You do not edit it.
The server can run the migrations at start. See [Migration](../database/migration.md).

## Artisan vs the dox CLI

| Laravel | Dox |
| --- | --- |
| `laravel new blog` | `dox create blog` |
| `php artisan serve` | `dox serve` (or `dox s`), with hot restart and `build_runner watch` |
| `php artisan make:controller` | `dox create:controller` |
| `php artisan make:model Blog -m` | `dox create:model Blog -m` |
| `php artisan make:request` | `dox create:dto` |
| `php artisan make:middleware` | `dox create:middleware` |
| `php artisan make:resource` | `dox create:serializer` |
| `php artisan make:migration` | `dox make:migration` |
| `php artisan migrate` | `dox migrate` |
| `php artisan key:generate` | `dox key:generate` |
| `php artisan route:list` | not there. Use the OpenAPI docs page at `/docs`. |
| `php artisan tinker` | not there |
| `php artisan optimize` | `dox build` (one native binary in `build/bundle`) |

Two commands have no Laravel twin: `dox build_runner:build` makes the generated code, and `dox env:generate` makes the typed env class.
See [Dox CLI](../digging-deeper/dox-cli.md).

## Auth

| Laravel | Dox |
| --- | --- |
| `config/auth.php` guards and providers | `Auth.initialize(AuthConfig(guards: ...))` in a service |
| `Auth::attempt(['email' => $e, 'password' => $p])` | `await Auth().attempt(<String, dynamic>{'email': e, 'password': p})` gives a JWT, or `null` |
| `Auth::login($user)` | `Auth().login(user)` gives a JWT |
| `Auth::user()` | `req.auth?.user<User>()` |
| `->middleware('auth:sanctum')` | `AuthMiddleware()` from `dox_auth` |
| `Hash::make($p)`, `Hash::check($p, $hash)` | `Hash.make(p)`, `Hash.verify(p, hash)` |

Dox auth is a JWT in the `Authorization` header. There are no sessions, no cookies and no Sanctum tokens table.
See [Authentication](../security/authentication.md).

## Cache

| Laravel | Dox |
| --- | --- |
| `config/cache.php` | `lib/config/cache.dart`, `CacheConfig(defaultStore:, stores:)` |
| `Cache::put('k', $v, 600)` | `await Cache().put('k', v, duration: Duration(minutes: 10))` |
| `Cache::get('k', 'default')` | `await Cache().get('k', 'default')` |
| `Cache::remember('k', 600, fn)` | `await Cache().remember('k', Duration(minutes: 10), fn)` |
| `Cache::forget('k')` | `await Cache().forget('k')` |
| `Cache::store('redis')` | `Cache().store('redis')` |
| `Cache::tags(['a'])` | `Cache().tags(<String>['a'])` |
| `Cache::lock('k', 10)` | `Cache().lock('k', Duration(seconds: 10))` |
| drivers: file, redis, memcached, database, array | drivers: `file`, `redis`, `memory`, `null` |

A value must be a JSON type. The `memory` store is per isolate. See [Cache](../digging-deeper/cache.md).

## Storage

| Laravel | Dox |
| --- | --- |
| `config/filesystems.php` disks | `lib/config/storage.dart`, `StorageConfig(defaultDisk:, disks:)` |
| `Storage::put('a.txt', $bytes)` | `await Storage().put('files', bytes, extension: 'txt')` (a uuid file name) |
| `$request->file('f')->store('avatars')` | `await file.store('avatars')` or `Storage().putRequestFile('avatars', file)` |
| `Storage::get($path)` | `await Storage().get(path)` |
| `Storage::exists($path)` | `await Storage().exists(path)` |
| `Storage::delete($path)` | `await Storage().delete(path)` |
| `Storage::url($path)` | `await Storage().url(path)` |
| `Storage::temporaryUrl($path, now()->addMinutes(10))` | `await Storage().signedUrl(path, expiresIn: Duration(minutes: 10))` |
| `Storage::disk('s3')` | `Storage().disk('s3')` |
| `Storage::download($path)` | `return Storage().download(path);` |
| drivers: local, s3, ftp, sftp | drivers: `local`, `s3` (also R2, MinIO, Spaces), `memory` |

See [File Storage](../digging-deeper/file-storage.md).

## Config and `.env`

| Laravel | Dox |
| --- | --- |
| `config/*.php` files | `lib/config/*.dart` files, put together in `AppConfig` |
| `env('APP_KEY')` | `Env.get<String>('APP_KEY')` |
| `env('APP_PORT', 3000)` | `Env.get<int>('APP_PORT', 3000)` |
| `config('app.name')` | `env.appName` from the typed env class (`@DoxEnv()`) |
| `php artisan config:cache` | not needed. The typed env is read once, at start. |

The typed env class gives you an `int` for `APP_PORT` and a build error for a bad type.
A missing key stops the app at start, with a list of every missing key. See [Environment Variables](../digging-deeper/env.md).

## Testing

| Laravel | Dox |
| --- | --- |
| `php artisan test` | `dart test` |
| `$this->get('/api/ping')->assertStatus(200)` | start the server once, then `http.get(Uri.parse('$baseUrl/api/ping'))` |
| `RefreshDatabase` | run the migrations in `setUpAll`, or use SQLite `:memory:` |
| `Storage::fake('s3')` | `Dox().storage.fake('s3')` |
| `Cache::fake()` | `Dox().cache = CacheManager(CacheConfig(...))` with a `memory` store |
| `$this->actingAs($user)` | send the JWT from `Auth().login(user)` in the `Authorization` header |

Dox has no fake HTTP kernel. A test starts the real server with `Dox().totalIsolate(1)` and sends real requests.
See [Testing](../digging-deeper/testing.md).

## What is different

- **No service container in the controller.** Laravel makes your controllers and injects what the constructor asks for.
  In Dox you make the controller yourself (`BlogController()`) and pass what it needs. Dox fills only the method parameters: the request, one DTO and the path params.
  `Dox().ioc` is a small registry (`register`, `registerSingleton`, `get`), but nothing is injected for you.
- **Isolates, not PHP-FPM workers.** One process runs one isolate per CPU core. Each isolate runs your whole app and has its own memory.
  A static value or a singleton lives once per isolate. A PHP worker starts from zero on each request. A Dox isolate keeps its state between requests, so a memory leak stays.
  Anything that must be shared goes to the database, Redis or files. See [How Dox works](how-dox-works.md#isolates).
- **Code generation, not reflection.** Laravel reads your classes at run time. Dart has no usable reflection in a compiled app.
  So `build_runner` with `dox_builder` writes the model code, the DTO checks, the env class and the OpenAPI docs into `.g.dart` files.
  Run `dox build_runner:build` after a change, or let `dox serve` watch for you.
- **One native binary.** `dox build` makes an AOT binary in `build/bundle`. There is no interpreter, no `vendor/` folder and no `composer install` on the server.
  The Docker image is about 11 MB.
- **A native HTTP server and native database drivers.** Rust parses HTTP and talks to Postgres and MySQL. Your code stays in Dart. You do not need Rust installed.
- **Types everywhere.** A DTO is a class with typed fields. A path param is an `int`. A model field is a `String?`. The compiler finds many mistakes before you run the app.
- **Async is explicit.** Database calls return a `Future`. You write `await`. One isolate serves many requests at the same time while it waits for the database.
- **JSON API first.** Dox returns text, JSON, files and streams. It has no view layer.

## What is missing today

Dox 3.0 does not have these Laravel features. Check the [packages](../packages/validation.md) list for what is there.

| Laravel | Dox 3.0 |
| --- | --- |
| Queues and jobs (`dispatch(new Job)`) | not there. Use a database table, Redis or a separate worker process. |
| Task scheduler (`schedule()->daily()`) | not there. Use cron or systemd timers to call a route or a Dart script. |
| Events and listeners (`Event::dispatch`, `$listen`) | not there. Model events (hooks and observers) are there. |
| Blade views, `view()` | not there. Dox is for APIs. Serve a front end from a CDN or a proxy. |
| Mail (`Mail::to()`) | not there. Use a Dart mail package or an HTTP mail API. |
| Notifications | not there |
| Sessions and session cookies | not there. Auth uses a JWT. Encrypted cookies are there. |
| Policies and gates | not there. Check the user in a middleware or in the controller. |
| Global scopes, `$casts`, `$fillable` | not there. See [Eloquent vs Dox Model](#eloquent-vs-dox-model). |
| Database seeders and factories | not there. Write a Dart script, or a migration with data. |
| Rate limiting middleware | not there. Write a middleware with the cache, or use a proxy. |
| `php artisan route:list`, `tinker` | not there |
| Savepoints in nested transactions | not there. A nested `transaction()` joins the outer one. |
| WebSocket on the native server | not there yet. An app with WebSocket routes uses the `dart:io` server. |

What is there, as separate packages: [validation](../packages/validation.md), [OpenAPI docs](../packages/openapi.md),
[storage](../packages/storage.md), [cache](../packages/cache.md), [Socket.IO](../packages/socketio.md),
[WebSocket](../digging-deeper/websocket.md) and [auth](../security/authentication.md).
