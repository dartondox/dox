# OpenAPI

Dox makes OpenAPI 3.1 docs for your API by itself.
You write no docs code. You get a Swagger UI page at `/docs`, plus `/openapi.json` and `/openapi.yaml`.

The docs come from three places:

- **the routes**: method, path, path params, middleware (login),
- **the request classes**: a `@Dto` class,
- **the controllers**: the `///` comment, the arguments and the return type of each method.

## In a Dox app

### 1. Run the builder

```bash
dart run build_runner build      # or: dox build_runner:build
```

`dox_builder` reads your code and writes `lib/openapi.g.dart`.
Run it again after you change routes, controllers, request classes or models.
`dox build_runner:watch` does it for you while you work.

### 2. Pass the result to the config

```dart
// lib/config/openapi.dart
import 'package:my_app/openapi.g.dart';
import 'package:dox_core/dox_core.dart';

OpenApiConfig openApi = OpenApiConfig(
  info: Info(title: 'Blog API', version: '1.0.0'),
  registry: openApiRegistry,
);

AppConfig(openApi: openApi, ...);
```

### 3. Open `/docs`

Start the app and open `http://localhost:3000/docs`.

- `enabled` is `null` by default. The docs are on only when `APP_ENV` is `development` or `local`.
  So production is off unless you set `enabled: true`.
- When the docs are off, there is no extra work per request.
- The document is built and encoded on the first `/docs` request, then kept. It is built again only when routes are added.

## What you write, what you get

A normal controller. There are no docs annotations here:

```dart
class BlogController {
  /// Get one blog
  ///
  /// Deleted blogs are not found.
  Future<Blog?> show(DoxRequest req, String id) async {
    return Blog().find(id);
  }

  /// Create a blog
  Future<Blog> store(CreateBlog body) async { ... }
}

// routes
Route.get('/blogs/{id}', [AuthMiddleware(), blogController.show]);
```

The generated docs for `GET /blogs/{id}`:

```yaml
get:
  tags: [Blog]
  summary: Get one blog
  description: Deleted blogs are not found.
  operationId: BlogController.show
  parameters:
    - {name: id, in: path, required: true, schema: {type: string}}
  responses:
    "200":
      content:
        application/json:
          schema: {$ref: "#/components/schemas/Blog"}
    "401": {description: Not logged in}
    "404": {description: Not found}
    "500": {description: Server error}
  security:
    - bearerAuth: []
```

`Blog` is in `components/schemas`, made from the model:

```yaml
Blog:
  type: object
  properties:
    id: {type: integer}
    title: {type: [string, "null"]}
    user: {anyOf: [{$ref: "#/components/schemas/User"}, {type: "null"}]}
    created_at: {type: [string, "null"], format: date-time}
```

## How each part is found

| Part of the docs | Where it comes from |
| --- | --- |
| path, method | the live route table |
| path param types | the controller arguments after the first one, in order. `int id` gives `integer` |
| tags | the controller class name without `Controller` (`BlogController` gives `Blog`) |
| operationId | `Class.method`, for example `BlogController.show` |
| summary | the first line of the `///` comment |
| description | the rest of the `///` comment |
| request | see [Request](#request) below |
| 200 answer | the return type, see [Response](#response) below |
| `401` and `bearerAuth` | a middleware whose class name ends with `AuthMiddleware` |
| `404` | the path has a `{param}` |
| `422` | the route has a request class. The body is `{field: message}` |
| `500` | every route |

Routes that the builder does not know (for example inline closures) still get a basic entry.

### Request

The builder looks in this order. The first one wins.

1. `@Body(T)`, `@Query(T)` or `@Request(T)` on the method.
2. An argument whose type is a `@Dto` class: `store(CreateBlog body)`.
3. A `req.validate<T>()` call in the method, where `T` is a `@Dto` class.

For `POST`, `PUT` and `PATCH` the request is the JSON body.
For other methods each field is one query parameter.
`@Dto(source: Source.query)` or `Source.body` chooses the place by hand.
The route `body:` option still works, and it wins over all of these.

A `@Dto` class:

```dart
@Dto()
class CreateBlog {
  @Length(min: 3, max: 200)
  final String title;

  /// Text of the blog.
  final String? description;   // nullable: optional

  final int views;             // default: optional, `default: 0`

  final Status status;         // enum: only `draft` or `published`

  final List<Tag> tags;        // a list of another @Dto class

  const CreateBlog({required this.title, this.description, this.views = 0,
      required this.status, required this.tags});
}
```

The keys are the same as the keys the DTO reads: snake_case by default (`postCode` is `post_code`),
or `@Name('key')`, or `@Dto(keyCase: KeyCase.field)`.
Each rule annotation adds its JSON Schema keys. See the [rules reference](../the-basic/validation-rules.md).

### Response

The return type of the method gives the `200` answer. `Future<T>` counts as `T`.

| Return type | Schema |
| --- | --- |
| a model (`@DoxModel`) | `$ref` to the model. Keys in `hidden` are left out |
| `List<Model>` | an array of the model |
| a `@Dto` class | `$ref` to the class |
| a `Serializer<Model>` | the map that `convert()` returns, else the model |
| `Pagination` | `total`, `per_page`, `last_page`, `current_page`, `data` |
| `String`, `int`, `bool`, `Map`, `List` | the basic JSON type |
| `dynamic` | the types of the `return` values. A map literal gives its keys. Exceptions are left out |
| `DoxResponse`, `void` | no schema |

A model schema has the primary key, the `@Column` fields, `created_at`, `updated_at`,
the relations (only there when loaded) and the `@Computed` getters.

## Change the docs (optional)

Add these to a controller method when the automatic result is not what you want.
They are all in `dox_core`.

```dart
@Summary('Log in')
@Description('Gives a bearer token for the Authorization header.')
@Tags(<String>['Auth'])
@Request(LoginUser)
@Response(200, LoginResult)
@Response(401, null, description: 'Wrong email or password')
Future<dynamic> login(DoxRequest req) async { ... }
```

| Annotation | What it does |
| --- | --- |
| `@Summary('text')` | short title. Default: the first line of the `///` comment |
| `@Description('text')` | longer text. Default: the rest of the `///` comment |
| `@Tags(['Users'])` | groups. On a method or on the class |
| `@Request(T)` | the request class. Body or query by the HTTP method |
| `@Body(T)` | the request class, always the body |
| `@Query(T)` | the request class, always the query |
| `@Response(status, Type, description: '')` | one answer. Add more than one for more codes. With a `2xx` one, the return type is not used |
| `@ApiDeprecated()` | marks the route as deprecated. Dart `@Deprecated` works too |
| `@ApiIgnore()` | leaves the method (or the whole class) out of the docs |
| `@DoxController(tag: 'Users')` | for a class that the builder can not see in a `Route.get(...)` call |

The `Type` of `@Response` can be a model, `List<User>`, a `@Dto`, a `Serializer` or a basic type like `String`.

Lower case names work too: `@summary('Log in')`, `@description(...)`, `@tags(...)`,
`@request(...)`, `@body(...)`, `@query(...)`, `@apiDeprecated()`, `@apiIgnore()`, `@doxController()`.
The capital form is the normal Dart style. `@Response` has no lower case name,
because `response()` is already the response helper of `dox_core`.

### Login schemes

A middleware whose class name ends with `AuthMiddleware` adds `bearerAuth` (a JWT bearer token) by itself.
For other middleware, or another scheme, set it in the config:

```dart
OpenApiConfig(
  registry: openApiRegistry,
  securitySchemes: <String, SecurityScheme>{
    'apiKey': SecurityScheme.apiKey(name: 'X-API-Key'),
  },
  securityByMiddleware: <String, List<Map<String, List<String>>>>{
    'ApiKeyMiddleware': <Map<String, List<String>>>[
      <String, List<String>>{'apiKey': <String>[]},
    ],
  },
);
```

## How a route finds its docs

Routes are added when the app starts, so the builder can not see the final route table.
It writes two lists into `openapi.g.dart`:

- the docs of each controller method, by `Class.method`,
- each `Route.get(...)` / `Route.resource(...)` call it found, with its path and `Class.method`.

At runtime, Dox reads the method name of each route handler.
It picks the route call with the same HTTP method and the same end of path.
If there is none, it picks the only method with that name and the same argument types.
Group prefixes (like `api/`) do not matter.

!!! tip
    If two controllers have a method with the same name, register the routes with
    `Route.get('path', controller.method)` so the builder can see them.

### Write the files: `dox openapi:generate`

```bash
dox openapi:generate              # storage/openapi/openapi.json and openapi.yaml
dox openapi:generate docs/api     # another folder
```

It runs `bin/openapi.dart` of your app:

```dart
// bin/openapi.dart
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:my_app/config/app.dart';

Future<void> main(List<String> args) async {
  Dox().initialize(appConfig);
  await Dox().writeOpenApi(args.isEmpty ? 'storage/openapi' : args.first);
  exit(0);
}
```

`writeOpenApi` runs your services and registers the routes. It does not start the server.

## Without Dox

`dox_openapi` also works on its own. Describe routes by hand with `ApiDoc`:

```dart
import 'package:dox_openapi/dox_openapi.dart';

ApiDoc docs = ApiDoc();
Map<String, dynamic> user = docs.schema('User', userSchema); // returns a $ref

docs.route('GET', '/users/{id}',
    summary: 'Get one user',
    tags: <String>['users'],
    params: <String, Object>{'id': <String, dynamic>{'type': 'integer'}},
    responses: <int, ResponseDoc>{
      200: ResponseDoc(schema: user, description: 'The user'),
      404: const ResponseDoc(description: 'Not found'),
    });

OpenApi api = OpenApi(info: const Info(title: 'My API', version: '1.0.0'), docs: docs);

api.toJson();                              // Map
api.toJsonString();                        // pretty JSON
api.toYaml();                              // YAML
await api.writeFiles('storage/openapi');   // openapi.json + openapi.yaml

OpenApiServer server = OpenApiServer(api); // body + content type for /openapi.json, /openapi.yaml, /docs
```

A schema can be a JSON Schema `Map`, a [`dox_validation`](validation.md) schema, or any object with `toJsonSchema()`.
Paths can use `{id}` or `:id`. Both become `{id}`.
`DoxRouteAdapter().addTo(docs, routes)` adds a basic entry for each route you did not describe.

!!! tip
    Do not serve `/docs` in production if your API is private.
