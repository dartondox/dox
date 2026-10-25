# Step 3: Routes and controller

This step adds a resource controller and the routes to list, create and show posts.

## 1. Make the controller

```bash
dox make:controller Post -r
```

`-r` makes a resource controller with the seven CRUD methods.
Replace the file with this. It keeps only `index`, `store` and `show`:

```dart title="lib/app/http/controllers/post.controller.dart"
import 'package:blog/app/models/post/post.model.dart';
import 'package:dox_core/dox_core.dart';

@Inject()
class PostController {
  /// GET /api/posts
  Future<List<Post>> index(DoxRequest req) async {
    return Post().all();
  }

  /// POST /api/posts
  Future<DoxResponse> store(DoxRequest req) async {
    Post post = Post()
      ..title = req.input('title')
      ..body = req.input('body');
    await post.save();
    return response(post).statusCode(201);
  }

  /// GET /api/posts/{id}
  Future<Post> show(int id) async {
    Post? post = await Post().find(id);
    if (post == null) {
      throw NotFoundHttpException();
    }
    return post;
  }
}
```

How it works:

- `@Inject()` puts the controller in the container. Dox makes it for you. `dox s` runs `build_runner`, which adds it to `lib/container.g.dart`.
  A new project already has `container: registerContainer` in `lib/config/app.dart`, so you change nothing there.
- A controller returns a model or a list of models. Dox sends it as JSON.
- `response(post).statusCode(201)` sets the status code.
- `show(int id)` gets the `{id}` from the URL. `/api/posts/abc` answers `404`, because `abc` is not an `int`.
- `req.input('title')` reads the body as it is. It is not checked yet. [Step 4](04-validation.md) fixes that.

## 2. Add the routes

```dart title="lib/routes/api.dart"
import 'package:blog/app/http/controllers/api.controller.dart';
import 'package:blog/app/http/controllers/post.controller.dart';
import 'package:dox_core/dox_core.dart';

class ApiRouter extends Router {
  @override
  String get prefix => 'api';

  @override
  List<dynamic> get middleware => <dynamic>[];

  @override
  void register() {
    Route.get<ApiController>('/ping', (ApiController c) => c.pong);

    Route.resource('posts', PostController);
  }
}
```

`PostController` is the class. Dox gets the controller from the container.
You do not add the router to a list. Dox finds every `Router` class by itself.

`Route.resource` makes one route for each method the controller has:

| Method | Path | Controller method |
| --- | --- | --- |
| `GET` | `/api/posts` | `index` |
| `POST` | `/api/posts` | `store` |
| `GET` | `/api/posts/{id}` | `show` |

The controller has no `update` or `destroy`, so those routes are not made.

## 3. Start the server

```bash
dox s
```

If it is still running from step 1, it restarts by itself.

## Check it

Make a post:

```bash
curl -i -X POST http://localhost:3000/api/posts \
  -H 'Content-Type: application/json' \
  -d '{"title":"Hello Dox","body":"My first post."}'
```

```text
HTTP/1.1 201 Created
content-type: application/json; charset=utf-8
...

{"id":1,"title":"Hello Dox","body":"My first post.","created_at":"2026-10-22T13:58:14.062215Z","updated_at":"2026-10-22T13:58:14.062215Z"}
```

List the posts:

```bash
curl http://localhost:3000/api/posts
```

```json
[{"id":1,"title":"Hello Dox","body":"My first post.","created_at":"2026-10-22T13:58:14.062215Z","updated_at":"2026-10-22T13:58:14.062215Z"}]
```

Show one post:

```bash
curl http://localhost:3000/api/posts/1
```

```json
{"id":1,"title":"Hello Dox","body":"My first post.","created_at":"2026-10-22T13:58:14.062215Z","updated_at":"2026-10-22T13:58:14.062215Z"}
```

A post that does not exist:

```bash
curl -i http://localhost:3000/api/posts/99
```

```text
HTTP/1.1 404 Not Found
...

{"code":"not_found","message":"Not Found"}
```

## Next

[Step 4: Validation](04-validation.md)
