---
icon: lucide/book-open
---

# OpenAPI

Dox makes OpenAPI 3.1 docs for your API from your routes, controllers and request classes.

You get three URLs: `/docs`, a [Scalar](https://github.com/scalar/scalar) page with every route and "Try it" buttons, `/openapi.json` and `/openapi.yaml`. The docs come from the routes, the `@Dto` request classes and the controller methods, so you write little by hand.

## Setup

A new app already serves `/docs` in development, but each route shows only its path and method. Do these steps to get the full docs:

1. Write the config, with the generated `openApiRegistry`:

    ```dart title="lib/config/openapi.dart"
    import 'package:dox_core/dox_core.dart';
    import 'package:my_app/generated/openapi.g.dart';

    OpenApiConfig openApi = OpenApiConfig(
      info: Info(title: 'Blog API', version: '1.0.0'),
      registry: openApiRegistry,
    );
    ```

    The import shows an error until the builder runs in step 3.

2. Add it to `AppConfig`:

    ```dart title="lib/config/app.dart"
    import 'package:my_app/config/openapi.dart';

    AppConfig appConfig = AppConfig(
      openApi: openApi,
      // ...
    );
    ```

3. Run the builder. It writes `lib/generated/openapi.g.dart`. Run it again after you change routes, controllers, request classes or models, or use `dox build_runner:watch`:

    ```bash
    dart run build_runner build      # or: dox build_runner:build
    ```

4. Start the app with `APP_ENV=development` in `.env`, and open `http://localhost:3000/docs`.

The docs are on only when `APP_ENV` is `development` or `local`. With no `APP_ENV`, the app is in production, and `/docs` gives 404.

### Configuration

| Option | Default | What it does |
| --- | --- | --- |
| `enabled` | none | true or false turns the docs on or off. With none, they are on only when `APP_ENV` is `development` or `local` |
| `info` | `Info(title: 'Dox API', version: '1.0.0')` | title and version of the API |
| `servers` | `[]` | base URLs, like `[Server('https://api.my.app')]` |
| `registry` | empty | `openApiRegistry` from `lib/generated/openapi.g.dart` |
| `securitySchemes`, `securityByMiddleware` | `{}` | see [Login schemes](#login-schemes) |
| `ui` | `DocsUi.scalar` | the docs page: `DocsUi.scalar` or `DocsUi.swagger` |
| `scalar` | `ScalarOptions()` | see [Changing the docs page](#changing-the-docs-page) |
| `pageTitle` | `info.title` | title of the `/docs` page |
| `include` | `[]` (all routes) | only these paths go in the docs, like `['/api/*']` |
| `exclude` | `[]` | these paths are left out, like `['/api/internal/*']` |

`openApi.isEnabled` tells you if the live docs are on.

## Describe a route

A normal controller already gets docs, see [What Dox fills in for you](#what-dox-fills-in-for-you). For better text, put annotations from `dox_core` on the controller method. Each annotation also has a lower case name, like `@summary('Log in')`, except `@Response`.

### Adding a summary and tags

`@Summary` is the short title, `@Description` is the longer text, and `@Tags` puts the route in a group. `@Tags` also works on the class:

```dart
class BlogController {
  @Summary('Get one blog')
  @Description('Deleted blogs are not found.')
  @Tags(<String>['Blogs'])
  Future<Blog?> show(DoxRequest req, String id) async {
    return Blog().find(id);
  }
}
```

For `GET /blogs/{id}` with `AuthMiddleware` on the route, you get:

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

For a class that is not in a `Route.get(...)` call, set its tag with `@DoxController(tag: 'Users')`.

### Using doc comments

A `///` comment on a method also sets the summary (the first line) and the description (the rest). An annotation wins over the comment:

```dart
/// Get one blog
///
/// Deleted blogs are not found.
Future<Blog?> show(DoxRequest req, String id) async {
  return Blog().find(id);
}
```

### Adding responses

`@Response` describes one answer. Add one for each status code:

```dart
@Summary('Log in')
@Request(LoginUser)
@Response(200, LoginResult)
@Response(401, null, description: 'Wrong email or password')
Future<dynamic> login(DoxRequest req) async { ... }
```

The type can be a model, `List<User>`, a `@Dto`, a `Serializer` or a basic type like `String`. With a 2xx `@Response`, the return type of the method is not used.

### Hiding a route

`@ApiIgnore()` leaves a method, or a full class, out of the docs. To leave out routes by path, use `include` and `exclude` in the [config](#configuration):

```dart
@ApiIgnore()
Future<void> internal(DoxRequest req) async { ... }
```

### Marking a route as deprecated

Use `@ApiDeprecated()` or the Dart `@Deprecated`:

```dart
@ApiDeprecated()
Future<List<Blog>> oldIndex() async { ... }
```

## Describing the request

The builder finds the request class of a method in this order:

1. `@Body(T)`, `@Query(T)` or `@Request(T)` on the method.
2. An argument whose type is a `@Dto` class, like `store(CreateBlog body)`.
3. A `req.validate<T>()` call in the method, where `T` is a `@Dto` class.

For POST, PUT and PATCH, the request is the JSON body. For other methods, each field is a query param. `@Body`, `@Query` and `@Dto(source: Source.query)` set the place. The route `body` option wins over all of them.

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

The keys are the keys the DTO reads: snake_case, or `@Name('key')`. `@Dto(keyCase: KeyCase.field)` keeps the field names. Each rule adds its JSON Schema keys, see the [rules reference](../the-basic/validation-rules.md).

## Describing the response

The return type of the method gives the 200 answer. `Future<T>` counts as `T`.

| Return type | Schema |
| --- | --- |
| a model (`@DoxModel`) | `$ref` to the model. Keys in `hidden` are left out |
| `List<Model>` | an array of the model |
| a `@Dto` class | `$ref` to the class |
| a `Serializer<Model>` | the map that `convert()` returns, else the model |
| `Pagination` | `total`, `per_page`, `last_page`, `current_page`, `data` |
| `String`, `int`, `bool`, `Map`, `List` | the basic JSON type |
| `dynamic` | the types of the `return` values. A map literal gives its keys |
| `DoxResponse`, `void` | no schema |

A model schema has the primary key, the `@Column` fields, `created_at`, `updated_at`, the relations (only when they are loaded) and the `@Computed` getters. It goes in `components/schemas`:

```yaml
Blog:
  type: object
  properties:
    id: {type: integer}
    title: {type: [string, "null"]}
    user: {anyOf: [{$ref: "#/components/schemas/User"}, {type: "null"}]}
    created_at: {type: [string, "null"], format: date-time}
```

## Login schemes

"Try it" must know how a route is protected to send a token. Put `@Security` on a middleware class, and every route with this middleware gets the scheme:

```dart
/// `Authorization: Bearer <api key>`. Not a JWT.
@Security.bearer(format: 'API key')
class ApiKeyAuthMiddleware implements IDoxMiddleware { ... }
```

`@Security.bearer()` gives `type: http, scheme: bearer`, and `format` becomes `bearerFormat`. For a key in a header, use `@Security.apiKey`. The default header is `X-API-Key`:

```dart
@Security.apiKey(header: 'X-API-Key')
class HeaderKeyMiddleware implements IDoxMiddleware { ... }
```

Run `dart run build_runner build` after you add it. The scheme name is the class name without `Middleware`, with a small first letter: `ApiKeyAuthMiddleware` gives `apiKeyAuth`. Give `scheme: 'myName'` for another name.

A middleware with no `@Security` whose class name ends with `AuthMiddleware` gets `bearerAuth`.

### Setting schemes in the config

For a key in the query or a cookie, set the scheme in the config. The config wins over `@Security`:

```dart
OpenApiConfig(
  registry: openApiRegistry,
  securitySchemes: <String, SecurityScheme>{
    'apiKey': SecurityScheme.apiKey(name: 'key', location: 'query'),
  },
  securityByMiddleware: <String, List<Map<String, List<String>>>>{
    'ApiKeyMiddleware': <Map<String, List<String>>>[
      <String, List<String>>{'apiKey': <String>[]},
    ],
  },
);
```

`SecurityScheme.bearer(bearerFormat: 'JWT')` makes a bearer scheme, and `SecurityScheme.raw(map)` takes a raw OpenAPI map.

## What Dox fills in for you

A controller with no annotations gets docs. Annotations only change the result.

| Part of the docs | Where it comes from |
| --- | --- |
| path, method | the route table |
| path param types | the controller arguments after the first one, in order. `int id` gives `integer` |
| tags | the class name without `Controller` (`BlogController` gives `Blog`) |
| operationId | `Class.method`, like `BlogController.show` |
| summary, description | the annotations, else the `///` comment |
| request | see [Describing the request](#describing-the-request) |
| 200 answer | the return type, see [Describing the response](#describing-the-response) |
| 401 and a login scheme | see [Login schemes](#login-schemes) |
| 401 and 403 | the `Can` middleware, or a `req.authorize(...)` call in the method |
| 403 | the `GuestMiddleware` or `ValidateSignature` middleware, or a `Gate.authorize(...)` call in the method |
| 404 | the path has a `{param}` |
| 422 | the route has a request class, or the method calls `req.validate<T>()` or `req.validateSchema(...)` |
| 500 | every route |

- A `@Response` with the same status wins over an automatic answer. `GuestMiddleware(redirectTo: ...)` shows 403, but the app sends a redirect, so add a `@Response(403, ...)`.
- An optional param gives two paths: `/blog/{id?}` gives `/blog/{id}` and `/blog`. The short path gets no 404.
- Dox matches a route to its docs by method name, HTTP method and the end of the path. When two controllers have a method with the same name, name the class in the route, like `(LinkController c) => c.index`.

## Changing the docs page

Change the look of the Scalar page with `scalar`:

```dart
OpenApiConfig(
  registry: openApiRegistry,
  pageTitle: 'Blog API docs',
  scalar: ScalarOptions(theme: ScalarTheme.purple, darkMode: true),
);
```

| Option | Default | What it does |
| --- | --- | --- |
| `theme` | `ScalarTheme.default_` | color theme, like `moon`, `purple`, `deepSpace`, `saturn`, `kepler` or `mars` |
| `darkMode` | false | start in dark mode |
| `showDownloadButton` | true | show the button that downloads the document |
| `proxyUrl` | none | send "Try it" requests through this proxy. Without it, requests go from the browser to your API |

To use Swagger UI, set `ui`:

```dart
OpenApiConfig(registry: openApiRegistry, ui: DocsUi.swagger);
```

## Turn the docs on in production

Set `enabled: true` to show the docs in production. `enabled: false` turns them off everywhere:

```dart title="lib/config/openapi.dart"
OpenApiConfig openApi = OpenApiConfig(
  enabled: true,
  info: Info(title: 'Blog API', version: '1.0.0'),
  registry: openApiRegistry,
);
```

!!! warning
    `/docs` has no login, so anyone can see every route of your API. Do this only for a public API.

## Write the files

To get the document as files, for example for a client generator, run `dox openapi:generate`:

```bash
dox openapi:generate              # storage/openapi/openapi.json and .yaml
dox openapi:generate docs/api     # another folder
```

It runs `bin/openapi.dart` of your app. A new app does not have this file, so make it. `writeOpenApi` runs your providers and registers the routes:

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

## Production setup

You can also make the document at build time, put the files in the image, and serve them. The URLs stay the same. You need `lib/config/openapi.dart` (see [Setup](#setup)) and `bin/openapi.dart` (see [Write the files](#write-the-files)).

1. Make both files, if you do not have them.

2. Add a controller that serves the files. If your `pubspec.yaml` has no `dox_openapi`, run `dart pub add dox_openapi`:

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
        return response(_page).contentType(
            ContentType.parse(OpenApiConstants.htmlContentType));
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

3. Add the routes only when the live docs are off, so they do not clash in development. Import `openApi` and the controller in this file:

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

4. Make the files in the Docker build. In the build stage, right after `RUN /root/.pub-cache/bin/dox build`, add:

    ```dockerfile title="Dockerfile"
    RUN APP_KEY=only-for-the-build-not-a-key \
        /root/.pub-cache/bin/dox openapi:generate docs/openapi
    ```

    Then, in the `RUN` step that lays out `/out`, add `/out/app/docs` to `mkdir -p` and copy the files after the `cp -r build/bundle/. /out/app/` line:

    ```dockerfile title="Dockerfile"
    RUN mkdir -p /out/app/storage /out/app/docs /out/tmp \
      && chmod 1777 /out/tmp \
      && cp -r build/bundle/. /out/app/ \
      && cp -r docs/openapi /out/app/docs/openapi \
      # ... the lines that follow stay as they are
    ```

    `bin/openapi.dart` loads your app config, so it needs an `APP_KEY`. The dummy key is only for this step. If a provider connects to a database in `setup()`, the build step must reach that database.

5. Start the image with `APP_ENV=production` and open `/docs`.

To test it on your machine, run `dox openapi:generate docs/openapi`, then start the app with `APP_ENV=production`.

!!! warning
    These routes have no login, so anyone can see every route of your API. To protect them, put a middleware on the three routes.

## Without Dox

`dox_openapi` also works on its own. Describe each route with `ApiDoc`:

```dart
import 'package:dox_openapi/dox_openapi.dart';

ApiDoc docs = ApiDoc();
Map<String, dynamic> user = docs.schema('User', userSchema); // a $ref

docs.route('GET', '/users/{id}',
    summary: 'Get one user',
    tags: <String>['users'],
    params: <String, Object>{'id': <String, dynamic>{'type': 'integer'}},
    responses: <int, ResponseDoc>{
      200: ResponseDoc(schema: user, description: 'The user'),
      404: const ResponseDoc(description: 'Not found'),
    });

OpenApi api = OpenApi(
    info: const Info(title: 'My API', version: '1.0.0'), docs: docs);
```

A schema can be a JSON Schema map, a [`dox_validation`](validation.md) schema, or any object with `toJsonSchema()`. Paths can use `{id}` or `:id`. `route` also takes `query`, `body`, `security`, `deprecated` and `operationId`. `OpenApi` also takes `servers`, `securitySchemes` and `security`.

### Reading the docs back

`docs.ref('User')` gives a `$ref` to a schema you added. `docs.has('GET', '/users/{id}')` tells you if a route has docs. `docs.add(routeDoc)` adds or replaces a `RouteDoc`.

### Getting the document

```dart
api.toJson();                              // Map
api.toJsonString();                        // pretty JSON
api.toYaml();                              // YAML
await api.writeFiles('storage/openapi');   // openapi.json + openapi.yaml
```

### Serving the docs from your own server

`OpenApiServer` gives the page and the document for a path. `docsPage()`, `json()` and `yaml()` give each one directly:

```dart
OpenApiServer server = OpenApiServer(api); // or ui: DocsUi.swagger
OpenApiResponse? page = server.handle('/docs'); // or '/openapi.json'
if (page != null) {
  // send page.body with the header Content-Type: page.contentType
}
```

### Text response keys

`responses` takes status codes as integer keys. For a text key like `default` or `2XX`, use `namedResponses`. It wins when the same key is in both:

```dart
docs.route('GET', '/users/{id}',
    responses: <int, ResponseDoc>{
      200: ResponseDoc(schema: user, description: 'The user'),
    },
    namedResponses: <String, ResponseDoc>{
      'default': const ResponseDoc(description: 'Any other error'),
    });
```

`DoxRouteAdapter().addTo(docs, routes)` adds a basic entry for each route with no docs.

## Next steps

- [API docs with OpenAPI](../guides/api-docs-with-openapi.md): a docs page for your API, step by step.
- [DTOs](../the-basic/dto.md): the classes that become schemas.
