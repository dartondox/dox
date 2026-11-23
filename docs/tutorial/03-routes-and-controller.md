---
icon: lucide/route
---

# Step 3: Routes and controller

In this step you add a controller and the routes to list, create and show posts.

## 1. Make the controller

A controller holds the code that answers a request. Make one for posts:

```bash
dox make:controller Post -r
```

The `-r` flag makes a resource controller with seven methods. You need three now, so replace the file with this:

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

What the code does:

- `@Inject()` puts the controller in the container. The code generator adds it to `lib/generated/container.g.dart`, and a new project uses that file.
- A model or a list of models goes back as JSON.
- `statusCode` sets the status code.
- `show(int id)` gets the id from the URL. A path like `/api/posts/abc` gets 404, because abc is not an integer.
- `input` reads the input with no check. You add checks in [step 4](04-validation.md).

## 2. Add the routes

Open `lib/routes/api.dart` and add `Route.resource`:

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
    Route.get('/ping', (ApiController c) => c.pong);

    Route.resource('posts', PostController);
  }
}
```

It makes one route for each method of the controller:

| Method | Path | Controller method |
| --- | --- | --- |
| `GET` | `/api/posts` | `index` |
| `POST` | `/api/posts` | `store` |
| `GET` | `/api/posts/{id}` | `show` |

Dox finds each router class, so you do not register it.

## 3. Start the server

If the server is off, start it:

```bash
dox s
```

If it is on, it restarts when you save a file.

## Check it

Make a post:

```bash
curl -i -X POST http://localhost:3000/api/posts \
  -H 'Content-Type: application/json' \
  -d '{"title":"Hello Dox","body":"My first post."}'
```

You get 201 and the new post:

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

Ask for a post that does not exist. You get 404:

```bash
curl -i http://localhost:3000/api/posts/99
```

```text
HTTP/1.1 404 Not Found
...

{"code":"not_found","message":"Not Found"}
```

## Next steps

- [Step 4: Validation](04-validation.md): check the input of a post.
