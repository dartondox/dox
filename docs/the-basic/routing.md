---
icon: lucide/signpost
---

# Routing

A route connects a URL and an HTTP method to the code that answers it.

Routing is the first step in [the life of a request](../concepts/how-dox-works.md#the-life-of-a-request). When a request comes in, the router finds the route by its method, host and path, and calls its controller.

## Where routes live

Routes are in the `lib/routes` folder. Each file has one `Router` class. The `prefix` of the router is added in front of all its routes:

```dart title="lib/routes/api.dart"
import 'package:dox_core/dox_core.dart';

class ApiRouter extends Router {
  @override
  String get prefix => 'api';

  @override
  List<dynamic> get middleware => <dynamic>[];

  @override
  void register() {
    Route.get('/ping', (DoxRequest req) => 'pong'); // GET /api/ping
  }
}
```

Dox finds every `Router` class by itself after `dart run build_runner build`. If you want to pick the order of routers, list them in `routers:` of `AppConfig`. See [Dependency injection: routers and providers](dependency-injection.md#routers-and-providers).

Some routes need an exact path, like gRPC routes (`/pkg.Service/Method`). Register them in a router with no prefix. A router without a `prefix` getter has none.

To see every route of your app, run `dox route:list`. It does not start the server. See [`dox route:list`](../reference/cli.md#dox-routelist).

## Defining routes

### Route methods

There is one method for each HTTP verb:

```dart
Route.get('/blogs', (BlogController c) => c.index);
Route.post('/blogs', (BlogController c) => c.store);
Route.put('/blogs/{id}', (BlogController c) => c.update);
Route.patch('/blogs/{id}', (BlogController c) => c.update);
Route.delete('/blogs/{id}', (BlogController c) => c.destroy);
```

The leading `/` is optional, so `'ping'` and `'/ping'` are the same route. A `HEAD` request runs the `GET` route of the same path, and the answer has no body.

### More than one method

Sometimes one handler should answer more than one method. `Route.match` adds it for a list of methods:

```dart
Route.match(<String>['GET', 'POST'], '/contact', (ContactController c) => c.handle);
```

`Route.any` adds it for `GET`, `POST`, `PUT`, `PATCH` and `DELETE`:

```dart
Route.any('/webhook', (WebhookController c) => c.handle);
```

`HEAD` comes with `GET`, so do not list it.

### The handler

The second argument is the code that answers the request. It can be a function:

```dart
Route.get('/ping', (DoxRequest req) => 'pong');
```

Or a controller method. The controller comes from the container. See [Controller](controller.md):

```dart
Route.get('/ping', (WebController c) => c.pong);

@Inject()
class WebController {
  String pong(DoxRequest req) {
    return 'pong';
  }
}
```

Or a list. The last item is the controller, and the items before it are [middleware](middleware.md):

```dart
Route.get('/ping', <dynamic>[
  LoggerMiddleware(),
  (WebController c) => c.pong,
]);
```

See [Controller: parameters](controller.md#parameters) for the parameters a handler can ask for.

### Health check route

`Route.health` adds a route for your load balancer or uptime check. It answers `200` with `{"status": "ok"}`:

```dart
Route.health('/health');
```

## Redirect routes

If a page moved, `Route.redirect` sends the old path to the new URL. The status is `302` by default:

```dart
Route.redirect('/home', '/');
Route.redirect('/old-blog', '/blog', status: 301);
```

For a `301`, you can also use `permanentRedirect`:

```dart
Route.permanentRedirect('/old-pricing', '/pricing'); // 301
```

The target is sent as it is. A param like `{id}` in the target is not filled in, and the query string is dropped. If you need these, use a normal route and return `redirect(...)` with the URL you build.

## Route params

Sometimes you need a part of the URL, like the id of a blog. Put the param in `{}`, and ask for it as a typed parameter in the controller:

```dart
Route.get('/blogs/{id}', (BlogController c) => c.show);

@Inject()
class BlogController {
  Future<Blog?> show(int id) async {
    return Blog().find(id);
  }
}
```

`/blogs/abc` answers `404`, because `abc` is not an `int`. See [Controller: parameters](controller.md#parameters) for all the rules.

### Param in a part with text

A part of the path can have text and params together. Each param gets its own value:

```dart
Route.get('/v{version}/users/{id}', (DoxRequest req) {
  return req.param['version']; // GET /v2/users/5 gives '2'
});

Route.get('/files/{name}-{size}', (DoxRequest req) {
  return req.param['size']; // GET /files/logo-small gives 'small'
});
```

A param takes as much text as it can. So for `/files/a-b-c`, `name` is `a-b` and `size` is `c`.

### Optional param

A param with `?` can be missing. Use a nullable type for it:

```dart
Route.get('/posts/{page?}', (int? page) {
  return 'page ${page ?? 1}'; // GET /posts and GET /posts/2 both match
});
```

### Catch-all param

A param with `*` matches the rest of the path, with slashes:

```dart
Route.get('/docs/{page*}', (String page) {
  return page; // GET /docs/a/b/c gives 'a/b/c'
});
```

### Param rules

If you want a route to match only some values, use `.where(param, regex)`. When the param does not match, the router tries the next route. When no route matches, the client gets `404`:

```dart
Route.get('/users/{id}', (UserController c) => c.show).where('id', '[0-9]+');
Route.get('/users/{name}', (UserController c) => c.byName); // gets the rest
```

The regex must match the whole param text, so you do not need `^` or `$`. Use `(?:...)` for a group, not `(...)`. Call `.where` more than once for more params.

## Group routes

### Prefix

If many routes start with the same path, put them in a group. The prefix goes in front of every path in the callback:

```dart
Route.group('/blogs', () {
  Route.get('/', (BlogController c) => c.index); // GET /blogs
  Route.get('/{id}', (BlogController c) => c.show); // GET /blogs/{id}
});
```

Groups can be nested. `Route.group('blogs', ...)` with `Route.get('all', ...)` makes `/blogs/all`.

### Domain

Routes in a domain group match only when the `Host` header is that domain. Other hosts get `404`:

```dart
Route.domain('dartondox.com', () {
  Route.get('/ping', (WebController c) => c.pong);
});
```

### Middleware

To run a middleware for many routes, use a middleware group. It runs after the global and router middleware:

```dart
Route.middleware(<dynamic>[AuthMiddleware()], () {
  Route.get('/me', (AuthController c) => c.me);
  Route.post('/logout', (AuthController c) => c.logout);
});
```

A group can also add a prefix to the [route names](#named-routes) inside it, with `name:`. To turn CORS on or off for some routes, see [CORS](../security/cors.md).

## Resource routes

Most models need the same CRUD routes. `Route.resource` makes all of them in one line:

```dart
Route.resource('blogs', BlogController);
```

These are the routes it makes:

| Method | Path | Controller method | Route name |
| --- | --- | --- | --- |
| `GET` | `/blogs` | `index` | `blogs.index` |
| `GET` | `/blogs/create` | `create` | `blogs.create` |
| `POST` | `/blogs` | `store` | `blogs.store` |
| `GET` | `/blogs/{id}` | `show` | `blogs.show` |
| `GET` | `/blogs/{id}/edit` | `edit` | `blogs.edit` |
| `PUT`, `PATCH` | `/blogs/{id}` | `update` | `blogs.update` |
| `DELETE` | `/blogs/{id}` | `destroy` | `blogs.destroy` |

If the controller does not have a method, no route is made for it. See [Resource controllers](controller.md#resource-controllers) to make one with the CLI.

The route names come from the path: `/` becomes `.`, and `{params}` are left out. So `Route.resource('users/{user}/posts', ...)` gives `users.posts.index`. Pass `name:` to pick another one: `Route.resource('blogs', BlogController, name: 'posts')`.

### Naming the param

The param of one item is `{id}`. Pass `parameter:` to give it another name:

```dart
Route.resource('photos', PhotoController, parameter: 'photo');
// GET /photos/{photo}, PUT /photos/{photo}, ...
```

Then `Route.bind('photo', ...)` and [model binding](#route-model-binding) work on these routes.

## Forms with PUT, PATCH and DELETE

An HTML form can only send GET or POST. To reach a `PUT`, `PATCH` or `DELETE` route, add `MethodOverride` to the global middleware:

```dart
AppConfig(
  globalMiddleware: <dynamic>[const MethodOverride()],
);
```

Then send the form as POST with a `_method` field:

```html
<form method="POST" action="/blogs/5">
  <input type="hidden" name="_method" value="DELETE">
</form>
```

`CsrfMiddleware` still checks the request, so send the `_token` field too. `MethodOverride` works only in `globalMiddleware`, not on a router or a route.

If a client can not send PUT, like an old proxy or JS client, it can send the `X-HTTP-Method-Override` header instead. Turn it on with `header: true`:

```dart
AppConfig(
  globalMiddleware: <dynamic>[const MethodOverride(header: true)],
);
```

## Named routes

You should give routes a name, so a path lives in one place. Then you build URLs from the name, and you can change the path later without breaking links:

```dart
Route.get('/users/{id}', (UserController c) => c.show).name('users.show');
```

### Generating URLs

Use `route()` to build the path of a named route. `Route.url()` does the same:

```dart
route('users.show', params: <String, Object>{'id': 5});
// /users/5
```

To add a query string, pass `query:`. A param that is not in the path also goes to the query string:

```dart
route('users.show', params: <String, Object>{'id': 5}, query: <String, Object>{'tab': 'posts'});
// /users/5?tab=posts
```

Dox stops with a clear error when two routes have the same name, when `route()` gets a name that no route has, or when a `{param}` of the path has no value.

### Full URL

Pass `absolute: true` to get the full URL, with `APP_URL` in front:

```dart
route('users.show', params: <String, Object>{'id': 5}, absolute: true);
// https://example.com/users/5   (APP_URL=https://example.com)
```

To use another base, also pass `baseUrl:`:

```dart
route('users.show', params: <String, Object>{'id': 5}, absolute: true, baseUrl: 'https://admin.example.com');
// https://admin.example.com/users/5
```

### Name prefix in a group

A group can put a prefix in front of the names inside it:

```dart
Route.group('admin', () {
  Route.get('users', (UserController c) => c.index).name('users'); // admin.users
}, name: 'admin.');
```

### Signed routes

Sometimes you send a link in an email, like "unsubscribe", and nobody should be able to change it. A signed URL has a `signature` in its query for this. Protect the route with `ValidateSignature`, and make the URL with `Route.signedUrl`:

```dart
Route.get('/unsubscribe/{user}', <dynamic>[
  const ValidateSignature(),
  (UserController c) => c.unsubscribe,
]).name('unsubscribe');

Route.signedUrl('unsubscribe',
    params: <String, Object>{'user': 5}, expires: Duration(days: 7));
// https://example.com/unsubscribe/5?expires=...&signature=...
```

A changed or expired URL gets `403`. See [Signed URLs](../security/signed-urls.md).

## Route model binding

Often a route param is the id of a model, and every controller loads the model first. A binder does this for you before the controller runs. Add it with `Route.bind`, before the routes that use it:

```dart
Route.bind<User>('user', (String id) => User().find(id));

Route.get('/users/{user}', (DoxRequest req, User user) {
  return user;
});
```

Every route with a `{user}` param now runs the binder first. The binder gets the raw text from the URL. If it returns `null`, the client gets `404`.

Ask for a parameter of the bound type, like `User user`, at any place in the parameter list. You can also read it from the request with `req.bound<User>('user')`. Other path params still work next to it:

```dart
Route.get('/users/{user}/posts/{page}', (User user, int page) {
  return user.posts(page);
});
```

The binder runs after the middleware, so an auth middleware can stop the request before any database call.

A `@DoxModel` class does not need `Route.bind`, because Dox makes a binder for it. See [Dependency injection: route model binding](dependency-injection.md#route-model-binding). `Route.bind` wins when both exist.

## Serve static files

Your app often has CSS, JavaScript and images. `Route.staticFiles(prefix, folder)` serves the files of a folder:

```dart
Route.staticFiles('/', 'public');
```

Build files with a hash in the name (like Vite's) never change, so give them a long `maxAge`. It sends `Cache-Control: public, max-age=...`:

```dart
Route.staticFiles('build', 'public/build', maxAge: Duration(days: 365));
```

Only `GET` and `HEAD` requests read files, and only when no route matches. `..`, dot files (like `.env`) and folders are never sent. No middleware runs for a file, but the global CORS config still applies.

!!! warning
    Never save user uploads in this folder. An uploaded html or svg file would run its script on your site.
    Use [`dox_storage`](../packages/storage.md) for uploads. It sends such files as downloads.

## Fallback route

`Route.fallback` answers a `GET` or `HEAD` request that matches no route and no static file. Use it for a custom 404 page, or to send `index.html` of a single page app:

```dart title="lib/routes/web.dart"
class WebRouter extends Router {
  @override
  void register() {
    Route.get('/', (WebController c) => c.home);

    Route.fallback((DoxRequest req) {
      return response(<String, String>{'message': 'Page not found'}).statusCode(404);
    });
  }
}
```

The handler decides the status. So return a `404` status for a "not found" page, or the client gets `200`.

Add the fallback in a `Router`, so the global middleware (like security headers) runs for it. The built-in `404` and `405` answers do not run the global middleware.

### Fallback for other methods

Some packages answer unknown paths in their own format. For example, a gRPC client wants a gRPC error, not a JSON `404`. Give `when:` a check. Then the fallback is tried for every method, and it answers only when the check gives `true`:

```dart
bool isGrpc(HttpRequest req) {
  String type = req.headers.value('content-type') ?? '';
  return req.method == 'POST' && type.startsWith('application/grpc');
}

Route.fallback(grpcNotFound, when: isGrpc);
```

Other requests still get the plain fallback, or `404` and `405`. A `when:` fallback never takes a request that a route matches. It does take a path that only has a route for another method: a gRPC `POST` to a path with only a `GET` route gets the fallback, not `405`.

Dox sends routes to every isolate. So `when` must be a top-level or static function, or one that captures nothing.

## Serve storage files

`Storage.route(path)` from the [`dox_storage`](../packages/storage.md) package serves the files of a storage disk at `GET <path>/{key*}`. By default only signed URLs work, and other requests get `403`:

```dart
Storage.route('files');
Storage.route('public', disk: 'local', signed: false);
```

An html, svg, xml or javascript file is sent as a download, so a script in an uploaded file does not run on your site. For user uploads, `download: true` sends every file as a download, also images and PDFs:

```dart
Storage.route('uploads', download: true);
```

See [File Storage](../digging-deeper/file-storage.md#serving-local-files).

## WebSocket routes

`Route.websocket` adds a raw WebSocket route:

```dart
Route.websocket('chat', handler, maxMessageSize: 64 * 1024);
```

By default any website can open it from a browser, with the cookies of the user. So you should check the `Origin`: pass `allowedOrigins: ['https://app.example.com']`, or set `AppConfig(webSocketAllowedOrigins: [...])` for every WebSocket route. Then only pages of the same host and the listed sites can open it, and other origins get `403`. `[]` means the same host only. When a WebSocket route has no check, Dox prints a warning at start.

A message over `maxMessageSize` bytes (default 16 MB) closes the socket with code `1009`.

## Request body for the docs

`post`, `put` and `patch` take a `body:` schema, so the body shows in the [OpenAPI docs](../packages/openapi.md). It does **not** check the request. To check input, use a [DTO](validation.md).

```dart
Route.post('/posts', (PostController c) => c.store, body: v.object(<String, Schema<Object?>>{
  'title': v.string().min(3),
}));
```

## Mount a raw handler

Some packages need the raw request, before Dox reads it. `Route.mount(prefix, handler)` sends every request under a path prefix straight to a raw `HttpRequest` handler. The handler writes and closes the response itself. [Socket.IO](../packages/socketio.md) uses it for `/socket.io/`:

```dart
Route.mount('/socket.io/', io.handle);
```

The prefix matches whole path parts. So `/admin` matches `/admin` and `/admin/users`, but not `/administrator`. When two prefixes match, the longest one wins.

!!! warning
    By default a mount skips all middleware, also the global middleware (security headers, CSRF, rate limit).
    Set `middleware: true` to run `AppConfig.globalMiddleware` before the handler.
    The global CORS config never applies to a mount. The handler must send its own CORS headers.

```dart
Route.mount('/admin', admin.handle, middleware: true);
```

## Details

This section is for special cases. Most apps do not need it.

### Route methods

- There are also `Route.options`, `Route.copy`, `Route.view`, `Route.link`, `Route.unlink`, `Route.purge`, `Route.lock`, `Route.unlock` and `Route.propfind`. `Route.view` is the WebDAV `VIEW` method. It does not render a template. To show a template, use a GET route with `view()` of `dox_view`: `Route.get('welcome', (DoxRequest req) => view(req, 'welcome'))`.
- `(WebController c) => c.pong` picks the method. Dox calls it once per isolate, at start.
- An unknown method in `Route.match` throws an `ArgumentError` at start.
- `Route.any` does not add `OPTIONS`, so Dox still answers the CORS preflight request for the path.
- `.where(...)` and `.timeout(...)` after `Route.match` or `Route.any` work on every route it added. `.name(...)` names the last one.
- `Route.redirect` works for the same methods as `Route.any`.
- In a group, Dox puts one `/` between the parts. `'blogs'` and `'/blogs/'` work the same.
- `Route.resource` also takes a controller object: `Route.resource('blogs', BlogController())`. An error from the controller, other than a missing method, stops the app at start.

### Param rules

- A leading `^` and a trailing `$` in a `.where` regex are dropped. A regex with a `(...)` group, or a param name that the path does not have, throws an `ArgumentError` at start.
- `.where('page', '.*')` also matches slashes.
- Routes without `.where` cost nothing extra.
- The regex checks the param text two times: as it is in the URL, and again after `%` codes are decoded. Both checks must pass. A `%` code for a letter, a digit or `-._~` is decoded before the router sees the path, so `/users/%31` matches `[0-9]+`. So `/files/x%2Fy` does not match `[^/]+`, because `%2F` is `/`. In the second check, `.` also matches a new line (`%0A`), so `.*` still matches it.

### Forms and named routes

- `MethodOverride` changes only a POST request, and only to `PUT`, `PATCH` or `DELETE`. Other values are ignored. `req.method` gives the new method. When both the header and `_method` are there, the header wins.
- In `route()`, param values are URL encoded. A missing `{name?}` param and a `null` value are left out. When `params` and `query` have the same key, `query` wins.
- `baseUrl:` works only with `absolute: true`. With `absolute: true` and no `APP_URL` and no `baseUrl:`, `route()` throws an `ArgumentError`.

### Static files

- The one dot folder that is sent is `.well-known` at the top of the folder. It holds ACME (Let's Encrypt) challenges, `security.txt` and `apple-app-site-association`. Dot files inside it still get `404`.
- A file gets a weak `ETag` (from its size and change time) and `Last-Modified`, so the browser gets `304` when it already has the file. `If-None-Match` wins over `If-Modified-Since`. Range requests work. With `If-Range`, the Range is used only when it is the file's `Last-Modified` date.
- The prefix follows `Route.group`, the router prefix and `Route.domain`.
- The folder path is relative to the folder the app starts in. Symlinks are followed.
- Behind a proxy, the proxy can serve the folder instead.
- Storage routes send html, svg, xml and javascript files with `Content-Security-Policy: sandbox`. Every file response has `X-Content-Type-Options: nosniff`.

### Fallback route

- Without `when:`, other methods still get the normal `404` or `405`. A `GET` to a path that only has a `POST` route gets the fallback, if one covers that path. If none does, the client gets `405`.
- Add the fallback before `startServer()`. A fallback added later only works in the isolate that added it.
- It follows `Route.group`, the router prefix and `Route.domain`. In a group, it only answers paths under the group prefix. A prefix can have params, like `{tenant}`. When two fallbacks match, the one with the longest prefix wins.
- The built-in `404` and `405` skip the global middleware because, for example, `CsrfMiddleware` would answer `419` to a `POST` to an unknown path, and `SessionMiddleware` would start a session for every bad link.

### Mounts

- A trailing `/` does not change the match, and the query string is not part of it. `//` counts as one `/`, so `/admin//secure/x` goes to a mount at `/admin/secure`.
- The match uses the raw path. `%2F` stays encoded, so `/admin/secure%2Fx` goes to a mount at `/admin`. To protect a nested path, set `middleware: true` on the outer mount too.
- With `middleware: true`, a middleware that gives a response (like `403`) stops the request. The body is not read for the middleware, so a CSRF token must come in a header.
- With `middleware: true`, the handler sends the answer itself. So the part of a middleware that runs after `next` cannot change it, and cookies it adds then (the session cookie, `XSRF-TOKEN`) are not sent. Get the CSRF token from a normal route. A `terminate` step still runs. `RequestTimeout` does not run for a mount.
