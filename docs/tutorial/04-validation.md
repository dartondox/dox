# Step 4: Validation

This step checks the input of create and update with a `@Dto` class. Bad input gets a `422` answer, and the controller does not run.

## 1. Make the DTO

```bash
dox make:dto SavePost
```

One class is enough for create and update, because both need the same fields.
Replace the file with this:

```dart title="lib/app/http/dtos/save_post.dto.dart"
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

- A field that is not nullable and has no default is required.
- The rules run from top to bottom. `@Trim()` removes spaces first. An empty string then counts as missing.
- See [Validation](../the-basic/validation.md) for all rules.

## 2. Give the DTO list to the app

The generator writes a list of all DTOs to `lib/generated/dtos.g.dart`.
Dox needs this list, because it does not use reflection.
Add two lines to `lib/config/app.dart`:

```dart title="lib/config/app.dart"
import 'package:blog/generated/dtos.g.dart';

AppConfig appConfig = AppConfig(
  /// DTOs (generated list in lib/generated/dtos.g.dart)
  dtos: dtos,

  // ... the rest stays the same
);
```

## 3. Use the DTO in the controller

Ask for `SavePost` as a parameter. Dox checks the body and gives you a typed object.
This also adds `update`, so `PUT /api/posts/{id}` works:

```dart title="lib/app/http/controllers/post.controller.dart"
import 'package:blog/app/http/dtos/save_post.dto.dart';
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

`Route.resource` in `lib/routes/api.dart` sees the new `update` method and adds `PUT` and `PATCH /api/posts/{id}`. You change nothing there.

## 4. Run the generator

`dox s` runs it for you. Without `dox s`:

```bash
dart run build_runner build --delete-conflicting-outputs
```

It writes `lib/app/http/dtos/save_post.dto.g.dart` and `lib/generated/dtos.g.dart`.

## Check it

A title that is too short, and a body that is too short:

```bash
curl -i -X POST http://localhost:3000/api/posts \
  -H 'Content-Type: application/json' \
  -d '{"title":"Hi","body":"Short"}'
```

```text
HTTP/1.1 422 Unprocessable Entity
content-type: application/json; charset=utf-8
...

{"title":"The title must be between 3 and 100 characters","body":"The body must be at least 10 characters"}
```

An empty body:

```bash
curl -X POST http://localhost:3000/api/posts \
  -H 'Content-Type: application/json' -d '{}'
```

```json
{"title":"The title is required","body":"The body is required"}
```

Good input still gives `201`:

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

## Next

[Step 5: Login with dox_auth](05-auth.md)
