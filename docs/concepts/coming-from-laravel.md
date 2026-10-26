---
icon: lucide/arrow-right-left
---

# Coming from Laravel

This page is for Laravel developers: it shows the Laravel way and the Dox way side by side.

The Laravel code is Laravel 11. The biggest changes are in [What is different](#what-is-different).

## Routing

| Laravel | Dox |
| --- | --- |
| `Route::get('/ping', fn () => 'pong');` | `Route.get('/ping', (DoxRequest req) => 'pong');` |
| `Route::post('/blogs', [BlogController::class, 'store']);` | `Route.post('/blogs', (BlogController c) => c.store);` |
| `Route::get('/blogs/{id}', ...)` and `function show(int $id)` | `Route.get('/blogs/{id}', ...)` and `show(int id)` |
| `Route::get('/posts/{page?}', ...)` | `Route.get('/posts/{page?}', (int? page) => ...)` |
| `->where('path', '.*')` | `Route.get('/docs/{page*}', (String page) => ...)` |
| `Route::prefix('blogs')->group(function () { ... });` | `Route.group('/blogs', () { ... });` |
| `Route::middleware('auth')->group(...)` | `Route.middleware(<dynamic>[AuthMiddleware()], () { ... });` |
| `Route::domain('admin.app.test')->group(...)` | `Route.domain('admin.app.test', () { ... });` |
| `Route::resource('blogs', BlogController::class);` | `Route.resource('blogs', BlogController);` |
| `routes/api.php` with the `api` prefix | `lib/routes/api.dart`, a `Router` class with `prefix => 'api'` |

In Dox, the container makes the controller. Put `@Inject()` above the class. The route picks the method with a typed function.

```dart title="lib/routes/api.dart"
class ApiRouter extends Router {
  @override
  String get prefix => 'api';

  @override
  List<dynamic> get middleware => <dynamic>[];

  @override
  void register() {
    Route.get('/blogs', (BlogController c) => c.index);
    Route.resource('users', UserController);
  }
}
```

## Controllers

| Laravel | Dox |
| --- | --- |
| `php artisan make:controller BlogController` | `dox make:controller Blog` |
| `php artisan make:controller BlogController --resource` | `dox make:controller Blog -r` |
| `public function show(Request $request, int $id)` | `Future<Blog?> show(DoxRequest req, int id)` |
| `public function store(StoreBlogRequest $request)` | `Future<Blog> store(CreateBlog body)` |
| constructor injection by the service container | constructor injection by the container: `@Inject()` above the class |
| method injection | filled by type: `DoxRequest`, one `@Dto` class, path params, models, container classes |
| implicit route model binding | the same: a `User user` parameter loads `{user}` by its key |

Dox fills a parameter by its type, not by its name. Path params go by position.
The container is generated code, not reflection. See [Dependency injection](../the-basic/dependency-injection.md).
A controller can be a class method, a static method or a plain function.

## Middleware

| Laravel | Dox |
| --- | --- |
| `php artisan make:middleware Logger` | `dox make:middleware Logger` |
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
| `php artisan make:request StoreBlogRequest` | `dox make:dto CreateBlog` |
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

```dart title="lib/app/dtos/create_blog/create_blog.dto.dart"
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
See [Validation](../the-basic/validation.md).

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
| `php artisan make:model Blog -m` | `dox make:model Blog -m` |
| `class Blog extends Model` | `@DoxModel() class Blog extends BlogGenerator` |
| `protected $table = 'blogs';` | `@DoxModel(table: 'blogs')` |
| `protected $primaryKey = 'uid';` | `@DoxModel(primaryKey: 'uid')` |
| `use SoftDeletes;` | `@DoxModel(softDelete: true)` |
| `public $timestamps = false;` | `@DoxModel(timestamps: false)` |
| `protected $hidden = ['password'];` | `List<String> get hidden => <String>['password'];` |
| `protected $fillable = [...]` | `List<String> get fillable => <String>[...];` |
| `protected $casts = ['meta' => 'array'];` | the field type: `Map<String, dynamic>? meta;` |
| mutator `setSlugAttribute()` | `@Column(beforeSave: makeSlug)` |
| accessor `getStatusAttribute()` | `@Column(beforeGet: readStatus)` |
| `$appends` with an accessor | `@Computed() String get fullName => ...;` |
| `Blog::find(1)` | `await Blog().find(1)` |
| `Blog::findOrFail(1)` | `await Blog().findOrFail(1)` (throws `ModelNotFoundException`) |
| `->firstOrFail()` | `.firstOrFail()` |
| `Blog::where('age', '>', 18)->get()` | `await Blog().where('age', '>', 18).get()` |
| `Blog::create([...])` | `await Blog().create(<String, dynamic>{...})` |
| `Blog::firstOrCreate([...], [...])` | `await Blog().firstOrCreate(<String, dynamic>{...}, <String, dynamic>{...})` |
| `Blog::firstOrNew([...])` | `await Blog().firstOrNew(<String, dynamic>{...})` |
| `Blog::updateOrCreate([...], [...])` | `await Blog().updateOrCreate(<String, dynamic>{...}, <String, dynamic>{...})` |
| `$blog->save()` | `await blog.save()` |
| `$blog->delete()` | `await blog.delete()` (returns the deleted rows as an `int`) |
| `$blog->increment('views')` | `await blog.increment('views')` |
| `Blog::withTrashed()` | `Blog().withTrash()` |
| `$blog->restore()` | `await blog.restore()` |
| `Blog::with('posts')->get()` | `await Blog().preload('posts').get()` |
| `$blog->load('posts')` | `await blog.$getRelation('posts')` |
| `$user->posts()->where(...)->get()` | `user.related<Post>('posts')?.where(...).get()` |
| `User::whereHas('posts', fn ($q) => ...)` | `User().whereHas('posts', (QueryBuilder<dynamic> q) { ... })` |
| `orWhereHas`, `whereDoesntHave`, `orWhereDoesntHave` | the same names |
| `User::has('posts', '>=', 3)` | `User().has('posts', '>=', 3)` |
| `whereHas('posts.comments')` | `whereHas('posts.comments')` |
| `$with = ['posts']` | `@HasMany(Post, eager: true)` |
| `hasOne`, `hasMany`, `belongsTo`, `belongsToMany` | `@HasOne`, `@HasMany`, `@BelongsTo`, `@ManyToMany` |
| local scope `scopeActive()` | a static method with `@Scope()`, then `Blog().active()` |
| global scope | `@Scope(global: true)` |
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
Dox has no `$casts` list. Use the field type, a [cast](../database/model/casts.md), `beforeSave` or `beforeGet`.
For scopes, see [Scopes](../database/model/scopes.md).
See [Model](../database/model/index.md).

## Query builder

| Laravel | Dox |
| --- | --- |
| `DB::table('users')->get()` | `await QueryBuilder.table('users').get()` |
| `->where('a', 1)->orWhere('b', 2)` | `.where('a', 1).orWhere('b', 2)` |
| `->whereIn('id', [1, 2])` | `.whereIn('id', <int>[1, 2])` |
| `->whereNull('deleted_at')` | `.whereNull('deleted_at')` |
| `->where(fn ($q) => $q->where(...)->orWhere(...))` | `.whereGroup((QueryBuilder<Blog> q) { q.where(...).orWhere(...); })` |
| `->orWhere(fn ($q) => ...)` | `.orWhereGroup((QueryBuilder<Blog> q) { ... })` |
| `->whereNot(fn ($q) => ...)` | `.whereNot((QueryBuilder<Blog> q) { ... })` |
| `->whereBetween('age', [18, 60])` | `.whereBetween('age', <int>[18, 60])` |
| `->whereColumn('a', '>', 'b')` | `.whereColumn('a', '>', 'b')` |
| `->whereLike('name', '%a%')` | `.whereLike('name', '%a%')` |
| `->whereExists(fn ($q) => $q->from('post')->...)` | `.whereExists('post', (QueryBuilder<Map<String, dynamic>> q) { ... })` |
| `->when($cond, fn ($q) => ...)` | `.when(cond, (QueryBuilder<Blog> q) { ... })` |
| `->whereRaw('lower(name) = ?', [$n])` | `.whereRaw('lower(name) = @n', <String, dynamic>{'n': n})` |
| `->select('id', 'name')` | `.select(<String>['id', 'name'])` |
| `->orderBy('name', 'desc')->limit(10)->offset(20)` | `.orderBy('name', 'desc').limit(10).offset(20)` |
| `->latest()`, `->oldest()`, `->inRandomOrder()` | `.latest()`, `.oldest()`, `.inRandomOrder()` |
| `->distinct()` | `.distinct()` |
| `->having('a', '>', 1)`, `->havingRaw(...)` | `.having('a', '>', 1)`, `.havingRaw(...)` |
| `->join('posts', 'posts.user_id', '=', 'users.id')` | `.join('posts', 'posts.user_id', 'users.id')` |
| `->groupBy('age')` | `.groupBy('age')` on `QueryBuilder.table()` (returns maps) |
| `->count()` | `await ....count()` |
| `->sum('a')`, `->avg('a')`, `->min('a')`, `->max('a')` | `.sum('a')`, `.avg('a')`, `.min('a')`, `.max('a')` |
| `->exists()`, `->doesntExist()` | `.hasRows()`, `.hasNoRows()` |
| `->pluck('name')` | `.pluck('name')` |
| `->pluck('name', 'id')` | `.pluckMap('name', 'id')` |
| `->value('email')` | `.valueOf('email')` |
| `->chunk(100, fn)`, `->chunkById(100, fn)` | `.chunk(100, (rows) { ... })`, `.chunkById(100, (rows) { ... })` |
| `->paginate(10)` | `.paginate(currentPage: 1, perPage: 10)` |
| `->insert([...])` | `.insertMultiple(<Map<String, dynamic>>[...])` |
| `->update([...])` | `.update(<String, dynamic>{...})` (returns the changed rows as an `int`) |
| `->increment('views', 5)`, `->decrement(...)` | `.increment('views', 5)`, `.decrement(...)` |
| `->upsert([...], ['email'], ['name'])` | `.upsert(<Map<String, dynamic>>[...], <String>['email'], <String>['name'])` |
| `->delete()` | `.delete()` (returns the deleted rows as an `int`) |
| `->lockForUpdate()`, `->sharedLock()` | `.lockForUpdate()`, `.sharedLock()` |
| `DB::select('select ...', [$id])` | `QueryBuilder.query('select ... @id', substitutionValues: {'id': id})` |
| `DB::transaction(fn)` | `QueryBuilder.transaction(() async { ... })` |
| `->toSql()` | `.toSql()` |
| `DB::connection('mysql')` | `.withConnection('mysql')` |

Values are always bound parameters. Names you pass are quoted. Do not pass user input as a column name or an operator.

`exists` and `value` are other names in Dox, because a model already has an `exists` getter, and `value` is a common column name.

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
| `php artisan migrate:fresh --seed` | `dox migrate:fresh --seed` |
| `php artisan db:seed --class=UserSeeder` | `dox db:seed --class=UserSeeder` |
| `php artisan make:factory`, `make:seeder` | `dox make:factory`, `dox make:seeder` |

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
| `php artisan make:resource` | `dox make:serializer` |
| `php artisan key:generate` | `dox key:generate` |
| `php artisan route:list` | not there. Use the OpenAPI docs page at `/docs`. |
| `php artisan tinker` | not there |
| `php artisan optimize` | `dox build` (one native binary in `build/bundle`) |

The `make:*` and `migrate` commands are in the tables above. Two commands have no Laravel twin: `dox build_runner:build` makes the generated code, and `dox env:generate` makes the typed env class.
See [Dox CLI](../digging-deeper/dox-cli.md).

## Auth

| Laravel | Dox |
| --- | --- |
| `config/auth.php` guards and providers | `Auth.initialize(AuthConfig(guards: ...))` in a provider |
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
| `config/filesystems.php` disks | `lib/config/storage.dart`, `StorageConfig(defaultDisk:, disks:)`, passed to a `StorageProvider` (`dox_storage`) |
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
| `env('APP_KEY')` | `env.appKey` (a getter in `lib/config/env.dart`) |
| `env('APP_PORT', 3000)` | `env.appPort` (the default is in the getter: `int get appPort => 3000;`) |
| `config('app.name')` | `env.appName` from the typed env class (`@DoxEnv()`) |
| `php artisan config:cache` | not needed. The typed env is read once, at start. |

The typed env class gives you an `int` for `APP_PORT` and a build error for a bad type.
A missing key stops the app at start, with a list of every missing key. See [Environment Variables](../digging-deeper/env.md).

## Testing

| Laravel | Dox |
| --- | --- |
| `php artisan test` | `dart test` |
| `$this->get('/api/ping')->assertStatus(200)` | `(await client.get('/api/ping')).expectStatus(200)` with `DoxTestClient` |
| `RefreshDatabase` | run the migrations in `setUpAll`, then `setUp(refreshDatabase)` from `package:dox_orm/testing.dart` |
| `Storage::fake('s3')` | `Storage.manager.fake('s3')` |
| `Cache::fake()` | `Dox().cache = CacheManager(CacheConfig(...))` with a `memory` store |
| `$this->actingAs($user)` | `client.withToken(token)` with the JWT from `Auth().login(user)` |

Dox has no fake HTTP kernel. `DoxTestClient.start(appConfig)` starts the real server inside the test, on a free port, and sends real requests.
See [Testing](../digging-deeper/testing.md).

## What is different

- **A generated container.** Like Laravel, Dox makes your controllers and injects what the constructor asks for.
  You add `@Inject()` to the class. `build_runner` writes `lib/generated/container.g.dart` with every registration. You do not register classes by hand in a provider.
  A singleton is one instance per isolate, not one per request.
- **Isolates, not PHP-FPM workers.** One process runs one isolate per CPU core. Each isolate runs your whole app and has its own memory.
  A static value or a singleton lives once per isolate. A PHP worker starts from zero on each request. A Dox isolate keeps its state between requests, so a memory leak stays.
  Anything that must be shared goes to the database, Redis or files. See [How Dox works](how-dox-works.md#isolates).
- **Code generation, not reflection.** Laravel reads your classes at run time. Dart has no usable reflection in a compiled app.
  So `build_runner` with `dox_builder` writes the model code, the DTO checks, the env class and the OpenAPI docs into `.g.dart` files.
  Run `dox build_runner:build` after a change, or let `dox serve` watch for you.
- **One native binary.** `dox build` makes an AOT binary in `build/bundle`. There is no interpreter, no `vendor/` folder and no `composer install` on the server.
  The Docker image is about 11 MB.
- **A native HTTP server and native database drivers.** Rust parses HTTP and talks to Postgres and MySQL. Your code stays in Dart. They come ready-built, so you do not need Rust.
- **Types everywhere.** A DTO is a class with typed fields. A path param is an `int`. A model field is a `String?`. The compiler finds many mistakes before you run the app.
- **Async is explicit.** Database calls return a `Future`. You write `await`. One isolate serves many requests at the same time while it waits for the database.
- **JSON API first.** Dox returns text, JSON, files and streams. It has no view layer.

## What is missing today

Dox does not have these Laravel features yet:

- queues and jobs, and the task scheduler
- events and listeners (model events are there)
- Blade views, mail and notifications
- sessions (auth uses a JWT; encrypted cookies are there)
- policies and gates

See [What Dox does not have yet](status-and-roadmap.md#what-dox-does-not-have-yet) for what to use today.

What is there, as separate packages: [validation](../packages/validation.md), [OpenAPI docs](../packages/openapi.md),
[storage](../packages/storage.md), [cache](../packages/cache.md), [Socket.IO](../packages/socketio.md)
and [auth](../security/authentication.md).
