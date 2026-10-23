# dox_openapi

Make an OpenAPI 3.1 document (JSON and YAML) and serve it with a Scalar or Swagger UI docs page.

[![pub package](https://img.shields.io/pub/v/dox_openapi.svg)](https://pub.dev/packages/dox_openapi)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/dartondox/dox/blob/develop/LICENSE)

Part of [Dox](https://dartondox.dev), a web backend framework for Dart, like Laravel.
Source code: [github.com/dartondox/dox](https://github.com/dartondox/dox).

## Install

In a Dox app you do not add it and you write no docs code.
`dox_builder` reads your routes, DTOs and controllers, and `dox_core` serves `/docs`.
To use it on its own:

```bash
dart pub add dox_openapi
```

Dox 3.x is in alpha (`3.0.0-alpha.x`). The API can still change before the stable release.

## Use it

Describe routes by hand with `ApiDoc`:

```dart
import 'package:dox_openapi/dox_openapi.dart';

void main() async {
  ApiDoc docs = ApiDoc();
  docs.route('GET', '/users/{id}',
      summary: 'Get one user',
      tags: <String>['users'],
      params: <String, Object>{'id': <String, dynamic>{'type': 'integer'}},
      responses: <int, ResponseDoc>{
        404: const ResponseDoc(description: 'Not found'),
      });

  OpenApi api = OpenApi(info: const Info(title: 'My API', version: '1.0.0'), docs: docs);

  print(api.toYaml());
  await api.writeFiles('storage/openapi'); // openapi.json + openapi.yaml

  OpenApiServer server = OpenApiServer(api);
  OpenApiResponse? page = server.handle('/docs'); // page.body, page.contentType
}
```

## Features

- OpenAPI 3.1 output as a `Map`, JSON text or YAML.
- `OpenApiServer` answers `/docs`, `/openapi.json` and `/openapi.yaml`. It does not need a router.
- Scalar docs page by default. `DocsUi.swagger` gives Swagger UI.
- A schema can be a JSON Schema `Map`, a `dox_validation` schema, or any object with `toJsonSchema()`.
- `DoxRouteAdapter` adds a basic entry for each route you did not describe.
- Paths with `{id}` or `:id` both become `{id}`.

## Documentation

- [OpenAPI](https://dartondox.dev/latest/packages/openapi/)
- [API reference](https://pub.dev/documentation/dox_openapi/latest/)

## License

MIT. See [LICENSE](https://github.com/dartondox/dox/blob/develop/LICENSE).
