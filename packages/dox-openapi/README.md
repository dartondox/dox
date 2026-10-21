# dox_openapi

Make an OpenAPI 3.1 document for a Dox app. Output it as JSON and YAML, and
show it in a Swagger UI page.

In a Dox app you write no docs code: `dox_builder` reads your routes,
request classes and controllers, and `dox_core` serves `/docs`.
See the [OpenAPI docs](https://dartondox.dev/packages/openapi/).
The API below is for describing routes by hand.

## Describe your API

```dart
import 'package:dox_openapi/dox_openapi.dart';

ApiDoc docs = ApiDoc();
Map<String, dynamic> user = docs.schema('User', userSchema); // returns a $ref

docs.route('GET', '/users/{id}',
    summary: 'Get one user',
    tags: <String>['users'],
    params: <String, Object>{'id': <String, dynamic>{'type': 'integer'}},
    query: pageSchema, // object schema, each property becomes a query param
    responses: <int, ResponseDoc>{200: ResponseDoc(schema: user, description: 'The user')},
    security: <Map<String, List<String>>>[<String, List<String>>{'bearerAuth': <String>[]}]);

OpenApi api = OpenApi(
  info: const Info(title: 'My API', version: '1.0.0'),
  servers: const <Server>[Server('https://api.example.com')],
  securitySchemes: <String, SecurityScheme>{'bearerAuth': SecurityScheme.bearer()},
  docs: docs,
);
```

A schema can be:

- a raw `Map<String, dynamic>` (JSON Schema),
- a `JsonSchemaSource`,
- any object with a `toJsonSchema()` method, for example a `dox_validation` schema.

Paths can use `{id}` or `:id`. Both become `{id}`.

## Add the routes you did not document

```dart
DoxRouteAdapter(securityByMiddleware: <String, List<Map<String, List<String>>>>{
  'AuthMiddleware': <Map<String, List<String>>>[<String, List<String>>{'bearerAuth': <String>[]}],
}).addTo(docs, Route().routes);
```

Each new route gets a basic entry. Routes with docs are not changed.
Methods OpenAPI does not support (`PURGE`, `COPY`, ...) are skipped.

## Output

```dart
api.toJson();            // Map
api.toJsonString();      // pretty JSON
api.toYaml();            // YAML
await api.writeFiles('storage/openapi'); // openapi.json + openapi.yaml
```

## Serve it

`OpenApiServer` does not depend on a router. It returns body text and a
content type for `/openapi.json`, `/openapi.yaml` and `/docs`.

```dart
OpenApiServer server = OpenApiServer(api);
OpenApiResponse? res = server.handle('/docs'); // res.body, res.contentType
```

## CLI

`generateOpenApi(api, outputDir, routes: Route().routes)` adds the routes
and writes both files. The `dox openapi:generate` command can call it.
