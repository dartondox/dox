---
icon: lucide/circle-check
---

# Step 4: Validation

In this step you check the input of create and update with a DTO class, so bad input gets a 422 answer.

## 1. Make the DTO

A [DTO](../the-basic/dto.md) is a class for the input that you expect, with a rule on each field. Make one:

```bash
dox make:dto SavePost
```

Create and update use the same fields, so one class is sufficient. Replace the file with this:

```dart title="lib/app/dtos/save_post/save_post.dto.dart"
import 'package:dox_core/dox_core.dart';

part 'save_post.dto.g.dart';

/// Typed, checked input. Run `dox build_runner:build` after a change.
@Dto()
class SavePost {
  @Trim()
  @Length(min: 3, max: 100)
  final String title;

  @Trim()
  @MinLength(10)
  final String body;

  const SavePost({required this.title, required this.body});

  static const DtoSchema<SavePost> schema = $SavePostDto;
}
```

A field that is not nullable and has no default is required. The rules run from top to bottom, so after `@Trim()` an empty string counts as missing. See [Validation](../the-basic/validation.md) for all rules.

## 2. Give the DTO list to the app

The code generator writes a list of all DTOs to `lib/generated/dtos.g.dart`. Add two lines to `lib/config/app.dart`:

```dart title="lib/config/app.dart"
import 'package:blog/generated/dtos.g.dart';

AppConfig appConfig = AppConfig(
  /// DTOs (generated list in lib/generated/dtos.g.dart)
  dtos: dtos,

  // ... the rest stays the same
);
```

## 3. Use the DTO in the controller

Ask for `SavePost` as a parameter of the controller method. Dox checks the body and gives you a typed object. This version also adds `update`:

```dart title="lib/app/http/controllers/post.controller.dart"
import 'package:blog/app/dtos/save_post/save_post.dto.dart';
import 'package:blog/app/models/post/post.model.dart';
import 'package:dox_core/dox_core.dart';

@Inject()
class PostController {
  /// GET /api/posts
  Future<List<Post>> index(DoxRequest req) async {
    return Post().all();
  }

  /// POST /api/posts
  Future<DoxResponse> store(SavePost body) async {
    Post post = Post()
      ..title = body.title
      ..body = body.body;
    await post.save();
    return response(post).statusCode(201);
  }

  /// GET /api/posts/{id}
  Future<Post> show(int id) async {
    return _find(id);
  }

  /// PUT /api/posts/{id}
  Future<Post> update(int id, SavePost body) async {
    Post post = await _find(id);
    post
      ..title = body.title
      ..body = body.body;
    await post.save();
    return post;
  }

  Future<Post> _find(int id) async {
    Post? post = await Post().find(id);
    if (post == null) {
      throw NotFoundHttpException();
    }
    return post;
  }
}
```

The routes stay the same. The resource route finds the new method and adds PUT and PATCH for `/api/posts/{id}`.

## 4. Run the generator

`dox s` runs the generator. If the server is off, run it one time:

```bash
dart run build_runner build
```

It writes `save_post.dto.g.dart` and `lib/generated/dtos.g.dart`.

## Check it

Send a title and a body that are too short:

```bash
curl -i -X POST http://localhost:3000/api/posts \
  -H 'Content-Type: application/json' \
  -d '{"title":"Hi","body":"Short"}'
```

You get 422 with one message for each field:

```text
HTTP/1.1 422 Unprocessable Entity
content-type: application/json; charset=utf-8
...

{"title":"The title must be between 3 and 100 characters","body":"The body must be at least 10 characters"}
```

Send an empty body:

```bash
curl -X POST http://localhost:3000/api/posts \
  -H 'Content-Type: application/json' -d '{}'
```

```json
{"title":"The title is required","body":"The body is required"}
```

Good input gives 201:

```bash
curl -i -X POST http://localhost:3000/api/posts \
  -H 'Content-Type: application/json' \
  -d '{"title":"Second post","body":"Validation works now."}'
```

```text
HTTP/1.1 201 Created
```

Update the first post:

```bash
curl -X PUT http://localhost:3000/api/posts/1 \
  -H 'Content-Type: application/json' \
  -d '{"title":"Hello Dox (edited)","body":"My first post, edited."}'
```

```json
{"id":1,"title":"Hello Dox (edited)","body":"My first post, edited.","created_at":"2026-10-22T13:58:14.062215Z","updated_at":"2026-10-22T13:59:13.539886Z"}
```

## Next steps

- [Step 5: Login with dox_auth](05-auth.md): protect the write routes.
