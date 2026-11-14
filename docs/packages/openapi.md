---
icon: lucide/book-open
---

# OpenAPI

This page shows how to make OpenAPI 3.1 docs for your Dox API, how to describe each route, and how to change the result.

You get three things:

- `/docs`: a [Scalar](https://github.com/scalar/scalar) page with every route and "Try it" buttons.
- `/openapi.json`: the OpenAPI document as JSON.
- `/openapi.yaml`: the same document as YAML.

The docs come from three places:

- **the routes**: method, path, path params, middleware (login),
- **the request classes**: a `@Dto` class,
- **the controllers**: the annotations (`@Summary`, `@Response` and more), the arguments and the return type of each method.

## Setup (optional)

!!! note "Made with `dox create`?"
    Your app already serves `/docs`, `/openapi.json` and `/openapi.yaml` while `APP_ENV` is `development`. The template `.env` sets this. You need no setup for that.
    But the config does not have `openApiRegistry` yet. So each route shows only its path and method.
    Do the steps below when you want the full docs from your code (annotations, request and response schemas), or when you want to change the title or other options.

1. Write the config. Pass the generated `openApiRegistry` to it:

    ```dart title="lib/config/openapi.dart"
    import 'package:dox_core/dox_core.dart';
    import 'package:my_app/generated/openapi.g.dart';

    OpenApiConfig openApi = OpenApiConfig(
      info: Info(title: 'Blog API', version: '1.0.0'),
      registry: openApiRegistry,
    );
    ```

    The import of `generated/openapi.g.dart` shows an error until the builder runs in step 3.

2. Add it to `AppConfig`:

    ```dart title="lib/config/app.dart"
    import 'package:my_app/config/openapi.dart';

    AppConfig appConfig = AppConfig(
      openApi: openApi,
      // ...
    );
    ```

3. Run the builder:

    ```bash
    dart run build_runner build      # or: dox build_runner:build
    ```

    `dox_builder` reads your code and writes `lib/generated/openapi.g.dart`.
    Run it again after you change routes, controllers, request classes or models.
    `dox build_runner:watch` does it for you while you work.

4. Make sure `.env` has `APP_ENV=development`. Then start the app and open `http://localhost:3000/docs`.
    Without `APP_ENV=development`, `/docs` gives 404.
    The document is built on the first `/docs` request, then kept.

!!! note
    The docs are on only when `APP_ENV` is `development` or `local`.
    If `APP_ENV` is not set, Dox treats the app as production: `/docs` is off and error details are hidden.
    Set `APP_ENV=development` in your `.env` and in CI.
    To turn the docs on in production, see [Turn the docs on in production](#turn-the-docs-on-in-production).

## Describe a route

Put annotations on a controller method. They are all in `dox_core`.

```dart
class BlogController {
  @Summary('Get one blog')
  @Description('Deleted blogs are not found.')
  @Tags(<String>['Blogs'])
  Future<Blog?> show(DoxRequest req, String id) async {
    return Blog().find(id);
  }

  @Summary('Create a blog')
  @Response(201, Blog, description: 'The new blog')
  Future<DoxResponse> store(CreateBlog body) async { ... }
}

// routes
Route.get('/blogs/{id}', <dynamic>[AuthMiddleware(), (BlogController c) => c.show]);
```

Here is what you get. The generated docs for `GET /blogs/{id}`:

```yaml
get:
  tags: [Blogs]
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

Annotations are all optional. Without them, Dox fills in the docs for you, see [What Dox fills in for you](#what-dox-fills-in-for-you).

Another example, with a request and more than one answer:

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
| `@ApiIgnore()` | leaves the method (or the whole class) out of the docs. To leave out routes by path, use `include` and `exclude` in `OpenApiConfig` |
| `@DoxController(tag: 'Users')` | for a class that the builder can not see in a `Route.get(...)` call |

The `Type` of `@Response` can be a model, `List<User>`, a `@Dto`, a `Serializer` or a basic type like `String`.

Each annotation also has a lower case name, like `@summary('Log in')`.
Only `@Response` has none, because `response()` is already a `dox_core` helper.

## Request

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

## Response

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

## Login schemes

Put `@Security` above a middleware class. Every route with this middleware gets the scheme in the docs.
Run `dart run build_runner build` after you add it.

```dart
/// `Authorization: Bearer <api key>`. Not a JWT.
@Security.bearer(format: 'API key')
class ApiKeyAuthMiddleware implements IDoxMiddleware { ... }

/// `X-API-Key: <key>`
@Security.apiKey(header: 'X-API-Key')
class HeaderKeyMiddleware implements IDoxMiddleware { ... }
```

| Annotation | Scheme in the docs |
| --- | --- |
| `@Security.bearer()` | `type: http`, `scheme: bearer`, no format |
| `@Security.bearer(format: 'JWT')` | the same, with `bearerFormat: JWT` |
| `@Security.apiKey(header: 'X-API-Key')` | `type: apiKey`, `in: header`, `name: X-API-Key`. The default header is `X-API-Key` |

The scheme name is the class name without `Middleware`, with a small first letter: `ApiKeyAuthMiddleware` gives `apiKeyAuth`.
Use `scheme: 'myName'` to pick another name.

A middleware without `@Security` whose class name ends with `AuthMiddleware` gets `bearerAuth`: a bearer token with no format, because Dox can not know if it is a JWT.

For a key in the query or a cookie, or to change a scheme without the builder, set it in the config.
The config wins over `@Security`:

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

## What Dox fills in for you

You do not have to write all of the above. A normal controller already gets docs. Annotations only change the result.

| Part of the docs | Where it comes from |
| --- | --- |
| path, method | the live route table |
| path param types | the controller arguments after the first one, in order. `int id` gives `integer` |
| tags | the controller class name without `Controller` (`BlogController` gives `Blog`) |
| operationId | `Class.method`, for example `BlogController.show` |
| summary | `@Summary`. Else the first line of the `///` comment |
| description | `@Description`. Else the rest of the `///` comment |
| request | see [Request](#request) |
| 200 answer | the return type, see [Response](#response) |
| `401` and a login scheme | `@Security` on a middleware class, or a middleware whose class name ends with `AuthMiddleware`. See [Login schemes](#login-schemes) |
| `401` and `403` | the `Can` middleware on the route, or a `req.authorize(...)` call in the controller method |
| `403` | the `GuestMiddleware` or `ValidateSignature` middleware on the route, or a `Gate.authorize(...)` call in the controller method |
| `404` | the path has a `{param}`. The short path of an optional param, like `/blog`, has no `404` |
| `422` | the route has a request class, or the controller method calls `req.validate<T>()` or `req.validateSchema(...)`. The body is `{field: message}` |
| `500` | every route |

`Can`, `GuestMiddleware` and `ValidateSignature` are found by their class name. `req.authorize(...)` is found when it is called on the request (`DoxRequest` or `IDoxRequest`) in the controller method. `Gate.authorize(...)` is found when `Gate` is the class of `dox_auth`. A `@Response` with the same status wins over an automatic answer.

`GuestMiddleware(redirectTo: ...)` also shows a `403`, but the app sends a redirect. Put `@Response(403, ...)` on the method to replace it.

Routes that the builder does not know (for example inline closures) still get a basic entry.

An optional param shows as two paths. The route `/blog/{id?}` gives `/blog/{id}` and `/blog`. OpenAPI path params must always be required.
An optional param in the middle, like `/a/{x?}/b`, also gives the path without it: `/a/{x}/b` and `/a/b`.
Optional params next to each other are dropped from the right, the same way the Dox router matches them.
When the summary and operation id are made from the path, the short path gets its own, like `GET /blog` and `getBlog`.

### `///` comments (optional)

A `///` comment on a method also sets the summary and the description.
The first line is the summary. The rest is the description.

```dart
/// Get one blog
///
/// Deleted blogs are not found.
Future<Blog?> show(DoxRequest req, String id) async {
  return Blog().find(id);
}
```

When a method has both, the annotation wins. `@Summary` replaces the first line of the comment, and `@Description` replaces the rest.

## Config options

| Option | Default | What it does |
| --- | --- | --- |
| `enabled` | `null` | `true` or `false` turns the docs routes on or off. `null`: on only when `APP_ENV` is `development` or `local`. See [Turn the docs on in production](#turn-the-docs-on-in-production) |
| `info` | `Info(title: 'Dox API', version: '1.0.0')` | title and version of the API |
| `servers` | `[]` | base URLs, like `[Server('https://api.my.app')]` |
| `registry` | empty | `openApiRegistry` from `lib/generated/openapi.g.dart` |
| `securitySchemes`, `securityByMiddleware` | `{}` | see [Login schemes](#login-schemes) |
| `ui` | `DocsUi.scalar` | the docs page: `DocsUi.scalar` or `DocsUi.swagger` |
| `scalar` | `ScalarOptions()` | see [The docs page](#the-docs-page) |
| `pageTitle` | `info.title` | title of the `/docs` page |
| `include` | `[]` (all routes) | only these paths go in the docs, like `['/api/*']` |
| `exclude` | `[]` | these paths are left out, like `['/api/internal/*']` |

In production the docs are off, unless you set `enabled: true`. See [Turn the docs on in production](#turn-the-docs-on-in-production).

### Turn the docs on in production

By default `enabled` is `null`. Then Dox looks at `APP_ENV`:

| `APP_ENV` value | Are the docs on? |
| --- | --- |
| `development` | yes |
| `local` | yes |
| `production` | no. `/docs`, `/openapi.json` and `/openapi.yaml` give 404 |
| not set | no. Dox treats the app as production |

To turn the docs on in every environment, also production, set `enabled: true`:

```dart title="lib/config/openapi.dart"
OpenApiConfig openApi = OpenApiConfig(
  enabled: true,
  info: Info(title: 'Blog API', version: '1.0.0'),
  registry: openApiRegistry,
);
```

!!! warning
    `/docs` has no login. In production, anyone can see every route of your API.
    Only do this for a public API.

`enabled: false` turns the docs off in every environment.

### The docs page

The page loads Scalar from the jsDelivr CDN, at a fixed version, and reads `/openapi.json`.
Change the look with `scalar:`:

```dart
OpenApiConfig(
  registry: openApiRegistry,
  pageTitle: 'Blog API docs',
  scalar: ScalarOptions(theme: ScalarTheme.purple, darkMode: true),
);
```

| Option | Default | What it does |
| --- | --- | --- |
| `theme` | `ScalarTheme.default_` | Color theme. Same names as Scalar: `moon`, `purple`, `deepSpace`, `saturn`, `kepler`, `mars` and more. |
| `darkMode` | `false` | Start in dark mode. The user can still switch. |
| `showDownloadButton` | `true` | Show the button that downloads the document. |
| `proxyUrl` | `null` | Send "Try it" requests through this proxy. Off by default, so requests go from the browser straight to your API. |

`pageTitle` and all options are escaped, so a value can not break the page.

To use Swagger UI instead, set `ui:`:

```dart
OpenApiConfig(registry: openApiRegistry, ui: DocsUi.swagger);
```

## Write the files

Use `dox openapi:generate` to write the document to files.

```bash
dox openapi:generate              # storage/openapi/openapi.json and openapi.yaml
dox openapi:generate docs/api     # another folder
```

It runs `bin/openapi.dart` of your app.
A new app does not have this file. Make it with this code:

```dart title="bin/openapi.dart"
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:my_app/config/app.dart';

Future<void> main(List<String> args) async {
  Dox().initialize(appConfig);
  await Dox().writeOpenApi(args.isEmpty ? 'storage/openapi' : args.first);
  exit(0);
}
```

`writeOpenApi` runs your providers and registers the routes. It does not start the server.

To serve these files in production, see [Production setup](#production-setup).

## Production setup

By default the docs are off in production. `enabled: true` is the quick way to turn them on, see [Turn the docs on in production](#turn-the-docs-on-in-production).
This section is the other way: make the document at build time, put the files in the image, and serve the files.
The URLs stay the same: `/docs`, `/openapi.json` and `/openapi.yaml`.

You need two files first: `lib/config/openapi.dart` (see [Setup](#setup-optional)) and `bin/openapi.dart` (see [Write the files](#write-the-files)). An app made with `dox create` has neither file.

1. Make both files, if you do not have them yet.

2. Add a controller that serves the files:

    ```dart title="lib/app/http/controllers/docs.controller.dart"
    import 'dart:io';

    import 'package:dox_core/dox_core.dart';
    import 'package:dox_openapi/dox_openapi.dart'
        show OpenApiConstants, OpenApiServer;
    import 'package:my_app/config/openapi.dart';

    @Inject()
    class DocsController {
      /// The same Scalar page as the live docs. It loads `/openapi.json`.
      final String _page = OpenApiServer(
        OpenApi(info: openApi.info),
        pageTitle: openApi.pageTitle,
        ui: openApi.ui,
        scalar: openApi.scalar,
      ).docsPage().body;

      DoxResponse page() {
        return response(_page)
            .contentType(ContentType.parse(OpenApiConstants.htmlContentType));
      }

      DoxResponse json() {
        return _file('openapi.json', OpenApiConstants.jsonContentType);
      }

      DoxResponse yaml() {
        return _file('openapi.yaml', OpenApiConstants.yamlContentType);
      }

      DoxResponse _file(String name, String contentType) {
        File file = File('docs/openapi/$name');
        if (!file.existsSync()) throw NotFoundHttpException();
        return response(file.readAsStringSync())
            .contentType(ContentType.parse(contentType));
      }
    }
    ```

    A new app has `dox_openapi` in its `pubspec.yaml`. If yours does not, run `dart pub add dox_openapi`.
    Run the builder again after you add the controller.

3. Add the routes. Add them only when the live docs are off, so the routes do not clash in development:

    ```dart title="lib/routes/web.dart"
    @override
    void register() {
      if (!openApi.isEnabled) {
        Route.get('/docs', (DocsController c) => c.page);
        Route.get('/openapi.json', (DocsController c) => c.json);
        Route.get('/openapi.yaml', (DocsController c) => c.yaml);
      }
      // ...
    }
    ```

    `openApi` is the config of `lib/config/openapi.dart`. Import it, and the controller, in this file.

4. Make the files in the Docker build, and copy them into the image. Change the `Dockerfile` in two places.
    First, in the build stage, right after `RUN /root/.pub-cache/bin/dox build`, add:

    ```dockerfile title="Dockerfile"
    RUN APP_KEY=only-for-the-build-not-a-key /root/.pub-cache/bin/dox openapi:generate docs/openapi
    ```

    Second, in the `RUN` step that lays out `/out`, add `/out/app/docs` to the `mkdir -p` list. Add one line to the `&&` chain after the `cp -r build/bundle/. /out/app/` line:

    ```dockerfile title="Dockerfile"
    RUN mkdir -p /out/app/storage /out/app/docs /out/tmp \
      && chmod 1777 /out/tmp \
      && cp -r build/bundle/. /out/app/ \
      && cp -r docs/openapi /out/app/docs/openapi \
      # ... the lines that follow stay as they are
    ```

    `bin/openapi.dart` starts your app config, so it needs `APP_KEY`. The dummy key is only for this step. It is not in the image.
    If a provider of your app connects to a database in `setup()`, that database must be reachable in the build step.
    The server runs in `/app`, so the controller reads `/app/docs/openapi/`.

5. Start the image with `APP_ENV=production` and open `/docs`.

!!! warning
    The route has no login. Anyone can open `/docs` and see every route of your API.
    To protect it, put a middleware on the three routes.

To test it on your machine, run `dox openapi:generate docs/openapi`, then start the app with `APP_ENV=production`.

## How a route finds its docs

The builder saves the docs of each controller method, and each `Route.get(...)` / `Route.resource(...)` call it finds.
At runtime, Dox matches each route handler by its method name, HTTP method and the end of its path.
If there is no match, it picks the only method with that name and the same argument types.
Group prefixes (like `api/`) do not matter.

!!! tip
    Two controllers can have a method with the same name, like `index`.
    When the route names the class, like `(LinkController c) => c.index` or `Route.get<LinkController>(...)`,
    only methods of that class match. With a plain `links.index`, the path of the route call decides.

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

// Serve the docs from your own server
OpenApiServer server = OpenApiServer(api); // Swagger UI: OpenApiServer(api, ui: DocsUi.swagger)
OpenApiResponse? page = server.handle('/docs'); // also '/openapi.json' and '/openapi.yaml'
if (page != null) {
  // send page.body with the header Content-Type: page.contentType
}
```

A schema can be a JSON Schema `Map`, a [`dox_validation`](validation.md) schema, or any object with `toJsonSchema()`.
Paths can use `{id}` or `:id`. Both become `{id}`.
`responses` takes status codes as `int` keys. To use a text key like `default` or `2XX`, pass `namedResponses`:

```dart
docs.route('GET', '/users/{id}',
    responses: <int, ResponseDoc>{
      200: ResponseDoc(schema: user, description: 'The user'),
    },
    namedResponses: <String, ResponseDoc>{
      'default': const ResponseDoc(description: 'Any other error'),
    });
```

`namedResponses` come after `responses`. When the same key is in both, the one in `namedResponses` wins.
`DoxRouteAdapter().addTo(docs, routes)` adds a basic entry for each route you did not describe.
