---
icon: lucide/signpost
---

# Routing

A route connects a URL and an HTTP method to the code that answers it.

The **router** finds the route of a request by its method, host and path. Then it calls the **handler** of the route: a function or a controller method.

## Where routes live

Routes are in the `lib/routes` folder. Each file has one router class:

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

The prefix goes in front of every route of the router. Run `dart run build_runner build`, and Dox finds the router by itself. To set the order of the routers, see [Dependency injection](dependency-injection.md#routers-and-providers).

To see every route of your app, run `dox route:list`. See the [CLI reference](../reference/cli.md#dox-routelist).

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

A HEAD request runs the GET route of the same path. There are also methods for the less common verbs: `Route.options`, `Route.copy`, `Route.link`, `Route.unlink`, `Route.purge`, `Route.lock`, `Route.unlock`, `Route.propfind` and `Route.view`.

### More than one method

Answer a list of methods with one handler:

```dart
Route.match(<String>['GET', 'POST'], '/contact',
    (ContactController c) => c.handle);
```

Answer GET, POST, PUT, PATCH and DELETE:

```dart
Route.any('/webhook', (WebhookController c) => c.handle);
```

### The handler

The handler can be a function:

```dart
Route.get('/ping', (DoxRequest req) => 'pong');
```

Or a [controller](controller.md) method:

```dart
Route.get('/ping', (WebController c) => c.pong);

@Inject()
class WebController {
  String pong(DoxRequest req) {
    return 'pong';
  }
}
```

Or a list, with [middleware](middleware.md) before the controller:

```dart
Route.get('/ping', <dynamic>[
  LoggerMiddleware(),
  (WebController c) => c.pong,
]);
```

### Health check route

Add a route for your load balancer or uptime check:

```dart
Route.health('/health');
```

Add checks and a timeout:

```dart
Route.health(
  '/health',
  timeout: Duration(seconds: 2),
  checks: <String, HealthCheckFunction>{
    'database': () => QueryBuilder.query('select 1'),
    'cache': HealthCheck.cache(),
  },
);
```

A failed check answers 503. See [Health check](../digging-deeper/health-check.md).

## Redirect routes

Send an old path to a new URL. The status is 302 by default:

```dart
Route.redirect('/home', '/');
Route.redirect('/old-blog', '/blog', status: 301);
```

Or send a 301:

```dart
Route.permanentRedirect('/old-pricing', '/pricing'); // 301
```

## Route params

A **route param** is a name in braces in the path. Ask for it as a typed parameter:

```dart
Route.get('/blogs/{id}', (BlogController c) => c.show);

@Inject()
class BlogController {
  Future<Blog?> show(int id) async {
    return Blog().find(id);
  }
}
```

A request to `/blogs/abc` gets a 404, because the text is not an integer. See [Controller](controller.md#parameters).

### Param in a part with text

Mix text and params in one part of the path:

```dart
Route.get('/v{version}/users/{id}', (DoxRequest req) {
  return req.param['version']; // GET /v2/users/5 gives '2'
});

Route.get('/files/{name}-{size}', (DoxRequest req) {
  return req.param['size']; // GET /files/logo-small gives 'small'
});
```

### Optional param

Add `?` to a param that can be missing:

```dart
Route.get('/posts/{page?}', (int? page) {
  return 'page ${page ?? 1}'; // GET /posts and GET /posts/2 both match
});
```

### Catch-all param

Add `*` to match the rest of the path, with slashes:

```dart
Route.get('/docs/{page*}', (String page) {
  return page; // GET /docs/a/b/c gives 'a/b/c'
});
```

### Param rules

Match only some values with `where` and a regex. When it does not match, the router tries the next route:

```dart
Route.get('/users/{id}', (UserController c) => c.show)
    .where('id', '[0-9]+');
Route.get('/users/{name}', (UserController c) => c.byName); // gets the rest
```

The regex must match the whole param. For a group, use `(?:...)`.

## Group routes

A **group** gives many routes the same prefix, domain or middleware.

### Prefix

Add a path in front of every route:

```dart
Route.group('/blogs', () {
  Route.get('/', (BlogController c) => c.index); // GET /blogs
  Route.get('/{id}', (BlogController c) => c.show); // GET /blogs/{id}
});
```

### Domain

Match only requests for one host:

```dart
Route.domain('dartondox.com', () {
  Route.get('/ping', (WebController c) => c.pong);
});
```

### Middleware

Run the same middleware for every route:

```dart
Route.middleware(<dynamic>[AuthMiddleware()], () {
  Route.get('/me', (AuthController c) => c.me);
  Route.post('/logout', (AuthController c) => c.logout);
});
```

### CORS

Turn the CORS headers on or off for some routes:

```dart
Route.enabledCors(() {
  Route.get('/public/posts', (PostController c) => c.index);
});

Route.disabledCors(() {
  Route.post('/webhooks/stripe', (WebhookController c) => c.handle);
});
```

See [CORS](../security/cors.md#cors-for-some-routes).

## Route options

Add these after a route. They change only that route.

### Timeout

Answer 503 when the route takes too long:

```dart
Route.get('/report', (ReportController c) => c.show)
    .timeout(Duration(seconds: 30));
```

See [Request timeout](middleware.md#request-timeout).

### Skip a middleware

Take one middleware out of the route, also a global one:

```dart
Route.post('/events', (EventController c) => c.stream)
    .withoutMiddleware<RequestTimeout>();
```

See [Middleware](middleware.md#skip-a-middleware-on-one-route).

### Errors of one route

Send the errors of the route to your own function:

```dart
DoxResponse? rpcError(Object error, DoxRequest req) {
  return response(<String, String>{'error': 'failed'}).statusCode(500);
}

Route.post('/rpc', (RpcController c) => c.call)
    .renderErrorsWith(rpcError);
```

See [Error handling](errors.md#errors-of-one-route).

### Name and param rules

The other options are `name` and `where`. See [Named routes](#named-routes) and [Param rules](#param-rules).

## Resource routes

A **resource route** makes the routes to list, show, create, change and delete, in one line:

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

A method that the controller does not have gets no route. To make the controller, see [Resource controllers](controller.md#resource-controllers).

Pass `name` to change the first part of the route names:

```dart
Route.resource('blogs', BlogController, name: 'posts'); // posts.index, ...
```

### Naming the param

Pass `parameter` to change `{id}` to another name:

```dart
Route.resource('photos', PhotoController, parameter: 'photo');
// GET /photos/{photo}, PUT /photos/{photo}, ...
```

## Forms with PUT, PATCH and DELETE

An HTML form can only send GET or POST. Add `MethodOverride` to the global middleware:

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

For a client that sends the `X-HTTP-Method-Override` header, turn it on with `header: true`:

```dart
AppConfig(
  globalMiddleware: <dynamic>[const MethodOverride(header: true)],
);
```

## Named routes

A **named route** lets you build URLs from a name, so the path lives in one place:

```dart
Route.get('/users/{id}', (UserController c) => c.show).name('users.show');
```

### Generating URLs

Build the path with `route()`. `Route.url()` does the same:

```dart
route('users.show', params: <String, Object>{'id': 5});
// /users/5
```

Add a query string with `query`:

```dart
route('users.show', params: <String, Object>{'id': 5},
    query: <String, Object>{'tab': 'posts'});
// /users/5?tab=posts
```

### Full URL

Pass `absolute: true` to put `APP_URL` in front:

```dart
route('users.show', params: <String, Object>{'id': 5}, absolute: true);
// https://example.com/users/5   (APP_URL=https://example.com)
```

Or pass your own `baseUrl`:

```dart
route('users.show', params: <String, Object>{'id': 5},
    absolute: true, baseUrl: 'https://admin.example.com');
// https://admin.example.com/users/5
```

### Name prefix in a group

Put a prefix in front of the names in a group:

```dart
Route.group('admin', () {
  Route.get('users', (UserController c) => c.index)
      .name('users'); // admin.users
}, name: 'admin.');
```

### Signed routes

A **signed URL** is a link that nobody can change, like an unsubscribe link in an email. Protect the route with `ValidateSignature`, and make the URL with `Route.signedUrl`:

```dart
Route.get('/unsubscribe/{user}', <dynamic>[
  const ValidateSignature(),
  (UserController c) => c.unsubscribe,
]).name('unsubscribe');

Route.signedUrl('unsubscribe',
    params: <String, Object>{'user': 5}, expires: Duration(days: 7));
// https://example.com/unsubscribe/5?expires=...&signature=...
```

A changed or expired URL gets 403. See [Signed URLs](../security/signed-urls.md).

## Route model binding

A **binder** turns a route param into a model before the controller runs. Add it before the routes that use it:

```dart
Route.bind<User>('user', (String id) => User().find(id));

Route.get('/users/{user}', (DoxRequest req, User user) {
  return user;
});
```

When the binder returns null, the client gets a 404. Other params still work next to it:

```dart
Route.get('/users/{user}/posts/{page}', (User user, int page) {
  return user.posts(page);
});
```

You can also read the model with `req.bound<User>('user')`. A model class needs no `Route.bind`. See [Dependency injection](dependency-injection.md#route-model-binding).

## Serve static files

Serve the files of a folder, like CSS, JavaScript and images:

```dart
Route.staticFiles('/', 'public');
```

Let the browser keep files that never change, with `maxAge`:

```dart
Route.staticFiles('build', 'public/build', maxAge: Duration(days: 365));
```

No middleware runs for a file, so a login check does not protect this folder.

!!! warning
    Never save user uploads in this folder. An uploaded html or svg file would run its script on your site.
    Use [File Storage](../digging-deeper/file-storage.md) for uploads. It sends such files as downloads.

## Fallback route

A **fallback** answers a GET or HEAD request that matches no route and no static file:

```dart title="lib/routes/web.dart"
class WebRouter extends Router {
  @override
  void register() {
    Route.get('/', (WebController c) => c.home);

    Route.fallback((DoxRequest req) {
      return response(<String, String>{'message': 'Page not found'})
          .statusCode(404);
    });
  }
}
```

Set the status yourself. Without `statusCode(404)`, the client gets 200.

### Fallback for other methods

Give `when` a check to answer other methods too, for example for gRPC clients:

```dart
bool isGrpc(HttpRequest req) {
  String type = req.headers.value('content-type') ?? '';
  return req.method == 'POST' && type.startsWith('application/grpc');
}

Route.fallback(grpcNotFound, when: isGrpc);
```

The check must be a top-level or static function.

## Serve storage files

Serve the files of a [storage](../digging-deeper/file-storage.md) disk. By default only signed URLs work:

```dart
Storage.route('files');
Storage.route('public', disk: 'local', signed: false);
```

For user uploads, send every file as a download:

```dart
Storage.route('uploads', download: true);
```

See [File Storage](../digging-deeper/file-storage.md#serving-local-files).

## WebSocket routes

Add a raw WebSocket route:

```dart
Route.websocket('chat', handler, maxMessageSize: 64 * 1024);
```

!!! warning
    By default any website can open the socket from a browser, with the cookies of the user.
    Pass `allowedOrigins` to the route, or set `webSocketAllowedOrigins` in `AppConfig`.

## Request body for the docs

Give a post, put or patch route a `body` schema to show the body in the [OpenAPI docs](../packages/openapi.md). It does not check the request. To check input, use a [DTO](validation.md).

```dart
Route.post('/posts', (PostController c) => c.store,
    body: v.object(<String, Schema<Object?>>{
      'title': v.string().min(3),
    }));
```

## Mount a raw handler

A **mount** sends every request under a path prefix to a raw `HttpRequest` handler. [Socket.IO](../packages/socketio.md) uses it:

```dart
Route.mount('/socket.io/', io.handle);
```

!!! warning
    By default a mount skips all middleware, also the global middleware (security headers, CSRF, rate limit).
    Set `middleware: true` to run the global middleware before the handler.
    The global CORS config never applies to a mount. The handler must send its own CORS headers.

```dart
Route.mount('/admin', admin.handle, middleware: true);
```

Remove a mount with the same prefix:

```dart
Route.unmount('/admin');
```

## Next steps

- [Controller](controller.md): put the route code in a class.
- [Middleware](middleware.md): run code before and after a route.
- [Request](request.md): read the input of a request.
