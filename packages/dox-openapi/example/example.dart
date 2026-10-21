import 'package:dox_openapi/dox_openapi.dart';

/// Builds a small API document and writes it to `example/build`.
Future<void> main() async {
  ApiDoc docs = ApiDoc();
  Map<String, dynamic> user = docs.schema('User', <String, dynamic>{
    'type': 'object',
    'properties': <String, dynamic>{
      'id': <String, dynamic>{'type': 'integer'},
      'name': <String, dynamic>{'type': 'string'},
    },
    'required': <String>['id', 'name'],
  });

  docs.route(
    'GET',
    '/users/{id}',
    summary: 'Get one user',
    tags: <String>['users'],
    params: <String, Object>{
      'id': <String, dynamic>{'type': 'integer'},
    },
    responses: <int, ResponseDoc>{
      200: ResponseDoc(schema: user, description: 'The user'),
      404: const ResponseDoc(description: 'Not found'),
    },
    security: <Map<String, List<String>>>[
      <String, List<String>>{'bearerAuth': <String>[]},
    ],
  );

  OpenApi api = OpenApi(
    info: const Info(title: 'My Dox API', version: '1.0.0'),
    servers: const <Server>[Server('http://localhost:3000')],
    securitySchemes: <String, SecurityScheme>{
      'bearerAuth': SecurityScheme.bearer(),
    },
    docs: docs,
  );

  // In a Dox app, pass `routes: Route().routes` to add undocumented routes.
  await generateOpenApi(api, 'example/build');
  print(api.toYaml());
}
