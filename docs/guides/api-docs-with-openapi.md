---
icon: lucide/file-code
---

# API docs with OpenAPI

Turn on OpenAPI docs for the blog API, open the docs page, and make the docs better with comments and annotations.

## What you need

- The blog API from the [tutorial](../tutorial/01-create-project.md), or any Dox app.
- `build_runner` and `dox_builder`. A new app has both. `dox_core` already has `dox_openapi`, so you add no package.

## 1. Write the config

`build_runner` writes `lib/generated/openapi.g.dart`. Its `openApiRegistry` holds what the builder found in your routes, controllers, DTOs and models. Pass it to an `OpenApiConfig`:

```dart title="lib/config/openapi.dart"
import 'package:dox_core/dox_core.dart';
import 'package:blog/generated/openapi.g.dart';

OpenApiConfig openApi = OpenApiConfig(
  info: Info(title: 'Blog API', version: '1.0.0'),
  registry: openApiRegistry,
);
```

Add it to `AppConfig`:

```dart title="lib/config/app.dart"
import 'package:blog/config/openapi.dart';

AppConfig appConfig = AppConfig(
  // ...
  /// OpenAPI docs (config/openapi.dart)
  openApi: openApi,
);
```

## 2. Build and start

```bash
dart run build_runner build --delete-conflicting-outputs
dox serve
```

`.env` has `APP_ENV=development`, so the docs routes are on.

## 3. Open the docs page

Open `http://localhost:3000/docs`. It is a [Scalar](https://github.com/scalar/scalar) page with every route and "Try it" buttons. It loads Scalar from the jsDelivr CDN.

The app now has three new routes:

| Route | What it gives |
| --- | --- |
| `GET /docs` | the Scalar docs page (HTML) |
| `GET /openapi.json` | the OpenAPI 3.1 document as JSON |
| `GET /openapi.yaml` | the same document as YAML |

## 4. Read the JSON

```bash
curl http://localhost:3000/openapi.json
```

This is the real output for the blog API, shortened. The top level:

```json
{
  "openapi": "3.1.0",
  "info": {"title": "Blog API", "version": "1.0.0"},
  "paths": {
    "/api/ping": {},
    "/api/posts": {},
    "/api/posts/{id}": {},
    "/api/auth/register": {},
    "/api/auth/login": {},
    "/api/auth/user": {},
    "/ping": {}
  },
  "components": {
    "schemas": {"Post": {}, "SavePost": {}, "RegisterUser": {}, "LoginUser": {}, "User": {}, "ValidationError": {}},
    "securitySchemes": {
      "bearerAuth": {"type": "http", "scheme": "bearer"}
    }
  }
}
```

`POST /api/posts`, as the builder found it. You wrote no docs code for it:

```json
{
  "tags": ["Post"],
  "summary": "POST /api/posts",
  "operationId": "PostController.store",
  "requestBody": {
    "required": true,
    "content": {"application/json": {"schema": {"$ref": "#/components/schemas/SavePost"}}}
  },
  "responses": {
    "200": {"description": "Successful response"},
    "401": {
      "description": "Not logged in",
      "content": {"application/json": {"schema": {"type": "object", "properties": {"code": {"type": "string"}, "message": {"type": "string"}}}}}
    },
    "422": {
      "description": "Validation failed",
      "content": {"application/json": {"schema": {"$ref": "#/components/schemas/ValidationError"}}}
    },
    "500": {"description": "Server error"}
  },
  "security": [{"bearerAuth": []}],
  "x-dox-middleware": ["LogMiddleware", "AuthMiddleware"]
}
```

Where each part comes from:

| Part | Comes from |
| --- | --- |
| `tags: ["Post"]` | the class name `PostController`, without `Controller` |
| `summary` | the first line of the `///` comment: `/// POST /api/posts` |
| `requestBody` | the argument `SavePost body` of `store` |
| `401` and `bearerAuth` | `AuthMiddleware` on the route |
| `422` | the route has a request class |
| `200` with no body | `store` returns `DoxResponse`, so the builder can not see the body. Step 6 fixes this |
| `x-dox-middleware` | the middleware of the route: the global `LogMiddleware` and `AuthMiddleware` |

## 5. See how a DTO becomes a schema

This is the `SavePost` DTO of the tutorial:

```dart title="lib/app/dtos/save_post/save_post.dto.dart"
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

And this is its schema in `/openapi.json`:

```json
"SavePost": {
  "type": "object",
  "title": "SavePost",
  "properties": {
    "title": {"type": "string", "minLength": 3, "maxLength": 100},
    "body": {"type": "string", "minLength": 10}
  },
  "required": ["title", "body"]
}
```

| In the DTO | In the schema |
| --- | --- |
| `String title` (not nullable) | `"type": "string"` and `title` in `required` |
| `@Length(min: 3, max: 100)` | `"minLength": 3, "maxLength": 100` |
| `@MinLength(10)` | `"minLength": 10` |
| `@Email()` (in `RegisterUser`) | `"format": "email"` |
| `@Trim()`, `@Lowercase()`, `@Unique(...)` | nothing. They change or check the value on the server only |

A model becomes a schema too. `Post` has `id`, the `@Column` fields `title` and `body`, and `created_at` and `updated_at`.
Keys in `hidden` are left out. That is why `User` has no `password`.

When you change a rule, run `build_runner` again, and the docs change with it.

## 6. Make the docs better

Write a `///` comment on a controller method. The first line is the summary. The rest is the description.
Add `@Tags` and `@Response` (from `dox_core`) when the automatic result is not what you want.

```dart title="lib/app/http/controllers/post.controller.dart"
@Inject()
class PostController {
  /// List all posts
  ///
  /// Newest posts are not first. There is no paging yet.
  Future<List<Post>> index(DoxRequest req) async {
    return Post().all();
  }

  /// Create a post
  @Tags(<String>['Posts'])
  @Response(201, Post, description: 'The new post')
  Future<DoxResponse> store(SavePost body) async {
    Post post = Post()
      ..title = body.title
      ..body = body.body;
    await post.save();
    return response(post).statusCode(201);
  }

  // ...
}
```

Run `dart run build_runner build` again and restart the app. The real result:

```json
"get": {
  "tags": ["Post"],
  "summary": "List all posts",
  "description": "Newest posts are not first. There is no paging yet.",
  "operationId": "PostController.index",
  "responses": {
    "200": {
      "description": "Successful response",
      "content": {"application/json": {"schema": {"type": "array", "items": {"$ref": "#/components/schemas/Post"}}}}
    },
    "500": {}
  }
},
"post": {
  "tags": ["Posts"],
  "summary": "Create a post",
  "operationId": "PostController.store",
  "responses": {
    "201": {
      "description": "The new post",
      "content": {"application/json": {"schema": {"$ref": "#/components/schemas/Post"}}}
    },
    "401": {},
    "422": {},
    "500": {}
  }
}
```

- `@Response(201, Post)` replaces the empty `200`. The docs now match the real status code.
- `@Tags(['Posts'])` moves the route to the group "Posts" in the docs page.
- `@Summary('...')` and `@Description('...')` set the text without a `///` comment.
- `@ApiIgnore()` leaves a method (or a whole controller) out of the docs.

See [OpenAPI: change the docs](../packages/openapi.md#change-the-docs-optional) for all annotations.

## 7. Turn it off in production

This is the default. `enabled` is `null`, so the docs routes are on only when `APP_ENV` is `development` or `local`. With `APP_ENV=production` all three routes give `404`:

```bash
curl -o /dev/null -w '%{http_code}\n' http://localhost:3000/docs           # 404
curl -o /dev/null -w '%{http_code}\n' http://localhost:3000/openapi.json   # 404
```

To show the docs on staging too, but never in production, set `enabled` yourself:

```dart title="lib/config/openapi.dart"
import 'package:blog/config/env.dart';

OpenApiConfig openApi = OpenApiConfig(
  enabled: env.appEnv != 'production',
  info: Info(title: 'Blog API', version: '1.0.0'),
  registry: openApiRegistry,
);
```

!!! warning
    `enabled: true` in production shows every route of your API to anyone. Only do it for a public API.

To give the document to a front-end team without a running server, write it to files with `dox openapi:generate`.
See [OpenAPI: write the files](../packages/openapi.md#write-the-files-dox-openapigenerate).

## Check it

```bash
curl -s http://localhost:3000/openapi.json | head -n 5
```

```text
{
  "openapi": "3.1.0",
  "info": {
    "title": "Blog API",
    "version": "1.0.0"
```

Open `http://localhost:3000/docs`, find "Create a post" under "Posts", and send a request with "Try it".

## See also

- [OpenAPI](../packages/openapi.md) for all options, the Scalar look, Swagger UI and login schemes
- [Validation rules](../the-basic/validation-rules.md) for the rules and their JSON Schema keys
- [Environments](environments.md) for `APP_ENV`
