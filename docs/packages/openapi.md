# OpenAPI

`dox_openapi` makes an OpenAPI 3.1 document for your Dox app.
You get `openapi.json`, `openapi.yaml` and a Swagger UI page at `/docs`.

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
