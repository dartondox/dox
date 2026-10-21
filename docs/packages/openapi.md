# OpenAPI

`dox_openapi` makes an OpenAPI 3.1 document for your Dox app.
You get `openapi.json`, `openapi.yaml` and a Swagger UI page at `/docs`.

## In a Dox app

`dox_core` has it built in. Add an `OpenApiConfig` to `AppConfig`:

```dart
// config/openapi.dart
OpenApiConfig openApi = OpenApiConfig(
  info: Info(title: 'Blog API', version: '1.0.0'),
  servers: <Server>[Server('https://api.example.com')],
  securitySchemes: <String, SecurityScheme>{'bearerAuth': SecurityScheme.bearer()},
  securityByMiddleware: <String, List<Map<String, List<String>>>>{
    'AuthMiddleware': <Map<String, List<String>>>[<String, List<String>>{'bearerAuth': <String>[]}],
  },
);

AppConfig(openApi: openApi, ...);
```

- `GET /docs` (Swagger UI), `GET /openapi.json` and `GET /openapi.yaml` are added after your routes.
- `enabled` is `null` by default: the docs are on only when `APP_ENV` is `development` or `local`.
  So production is off unless you set `enabled: true`. When it is off, there is no extra work per request.
- Every route is added. The document is built on the first `/docs` request, and again when routes change.
- Request bodies come from the route `body:` option, or from the form request of the controller
  (`schema()` first, then `rules()`):

```dart
Route.post('/posts', controller.store, body: v.object(<String, Schema<Object?>>{
  'title': v.string().min(3),
}));

// or: store(PostRequest req) where PostRequest has schema() or rules()
```

- Middleware names come from the route groups and router middleware (`preMiddleware`), so
  `securityByMiddleware` knows which routes need a login.

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

The rest of this page is for describing routes by hand, and for using `dox_openapi` outside Dox.

## Install

```bash
dart pub add dox_openapi
```

```dart
import 'package:dox_openapi/dox_openapi.dart';
```

## 1. Describe your routes

```dart
ApiDoc docs = ApiDoc();

// a named schema. It returns a $ref you can use below.
Map<String, dynamic> user = docs.schema('User', userSchema);

docs.route('GET', '/users/{id}',
    summary: 'Get one user',
    tags: <String>['users'],
    params: <String, Object>{'id': <String, dynamic>{'type': 'integer'}},
    responses: <int, ResponseDoc>{
      200: ResponseDoc(schema: user, description: 'The user'),
      404: const ResponseDoc(description: 'Not found'),
    },
    security: <Map<String, List<String>>>[
      <String, List<String>>{'bearerAuth': <String>[]},
    ]);
```

A schema can be:

- a JSON Schema `Map<String, dynamic>`,
- a [`dox_validation`](validation.md) schema (any object with `toJsonSchema()`),
- a `JsonSchemaSource`.

Paths can use `{id}` or `:id`. Both become `{id}`.

## 2. Make the document

```dart
OpenApi api = OpenApi(
  info: const Info(title: 'My API', version: '1.0.0'),
  servers: const <Server>[Server('https://api.example.com')],
  securitySchemes: <String, SecurityScheme>{'bearerAuth': SecurityScheme.bearer()},
  docs: docs,
);
```

## 3. Add the routes you did not describe

`DoxRouteAdapter` reads the Dox router and adds a basic entry for each route.
Routes you already described are not changed.

```dart
DoxRouteAdapter(securityByMiddleware: <String, List<Map<String, List<String>>>>{
  'AuthMiddleware': <Map<String, List<String>>>[
    <String, List<String>>{'bearerAuth': <String>[]},
  ],
}).addTo(docs, Route().routes);
```

Methods that OpenAPI does not know (`PURGE`, `COPY`, ...) are skipped.

## 4. Output

```dart
api.toJson();          // Map
api.toJsonString();    // pretty JSON
api.toYaml();          // YAML
await api.writeFiles('storage/openapi'); // openapi.json + openapi.yaml

// adds the router routes and writes both files
await generateOpenApi(api, 'storage/openapi', routes: Route().routes);
```

## 5. Serve it

`OpenApiServer` returns the body and the content type for `/openapi.json`, `/openapi.yaml` and `/docs`.

```dart
OpenApiServer server = OpenApiServer(api);

for (String path in <String>['/openapi.json', '/openapi.yaml', '/docs']) {
  Route.get(path, (DoxRequest req) {
    OpenApiResponse res = server.handle(path)!;
    return response(res.body).contentType(ContentType.parse(res.contentType));
  });
}
```

!!! tip
    Call `DoxRouteAdapter().addTo()` after all routes are registered, so it sees every route.
    Do not serve `/docs` in production if your API is private.
