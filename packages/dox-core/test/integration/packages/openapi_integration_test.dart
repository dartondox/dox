import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../../../../dox-openapi/test/support/openapi_checker.dart';

const int port = 50024;
const String baseUrl = 'http://localhost:$port';

class AuthMiddleware implements IDoxMiddleware {
  @override
  dynamic handle(IDoxRequest req) => req;
}

class PostRequest extends FormRequest {
  @override
  Map<String, String> rules() => <String, String>{
    'title': 'required|string|max:100',
  };
}

class PostController {
  dynamic store(PostRequest req) => req.validated;

  dynamic show(DoxRequest req, String id) => id;

  dynamic search(DoxRequest req) => <String, dynamic>{};

  dynamic secret(DoxRequest req) => 'x';
}

/// what dox_builder writes into lib/openapi.g.dart for PostController
const OpenApiRegistry registry = OpenApiRegistry(
  operations: <OpenApiOperation>[
    OpenApiOperation(
      controller: 'PostController',
      method: 'show',
      argumentTypes: <String>['DoxRequest', 'String'],
      summary: 'Get one post',
      tags: <String>['Post'],
      params: <Map<String, dynamic>>[
        <String, dynamic>{'type': 'integer'},
      ],
      responses: <int, ResponseDoc>{
        200: ResponseDoc(
          description: 'Successful response',
          schema: <String, dynamic>{r'$ref': '#/components/schemas/Post'},
        ),
      },
    ),
    OpenApiOperation(
      controller: 'PostController',
      method: 'search',
      argumentTypes: <String>['DoxRequest'],
      tags: <String>['Post'],
      schema: <String, dynamic>{r'$ref': '#/components/schemas/SearchPosts'},
    ),
    OpenApiOperation(
      controller: 'PostController',
      method: 'secret',
      argumentTypes: <String>['DoxRequest'],
      ignore: true,
    ),
  ],
  routes: <OpenApiRouteBinding>[
    OpenApiRouteBinding('GET', 'posts/{id}/full', 'PostController.show'),
  ],
  schemas: <String, Map<String, dynamic>>{
    'Post': <String, dynamic>{
      'type': 'object',
      'properties': <String, dynamic>{
        'id': <String, dynamic>{'type': 'integer'},
      },
    },
    'SearchPosts': <String, dynamic>{
      'type': 'object',
      'properties': <String, dynamic>{
        'q': <String, dynamic>{'type': 'string'},
      },
      'required': <String>['q'],
    },
  },
);

class DocsRouter extends Router {
  @override
  List<dynamic> get middleware => <dynamic>[AuthMiddleware()];

  @override
  void register() {
    Route.get('/posts/{id}', (DoxRequest req, String id) => id);
    Route.post('/posts', PostController().store);
    Route.get('/posts/{id}/full', PostController().show);
    Route.get('/search', PostController().search);
    Route.get('/secret', PostController().secret);
    Route.put(
      '/posts/{id}',
      (DoxRequest req, String id) => id,
      body: v.object(<String, Schema<Object?>>{'title': v.string().min(3)}),
    );
  }
}

AppConfig config = AppConfig(
  appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
  serverPort: port,
  totalIsolate: 1,
  routers: <Router>[DocsRouter()],
  formRequests: <Type, FormRequest Function()>{
    PostRequest: () => PostRequest(),
  },
  openApi: OpenApiConfig(
    enabled: true,
    info: Info(title: 'Test API', version: '2.0.0'),
    securitySchemes: <String, SecurityScheme>{
      'bearerAuth': SecurityScheme.bearer(),
    },
    securityByMiddleware: <String, List<Map<String, List<String>>>>{
      'AuthMiddleware': <Map<String, List<String>>>[
        <String, List<String>>{'bearerAuth': <String>[]},
      ],
    },
    registry: registry,
    pageTitle: 'Test docs',
    scalar: ScalarOptions(theme: ScalarTheme.purple, darkMode: true),
  ),
);

void main() {
  setUpAll(() async {
    Dox().initialize(config);
    await Dox().startServer();
  });

  tearDownAll(() async {
    await Dox().server.close(force: true);
  });

  test('openapi.json has the app routes, bodies and security', () async {
    http.Response res = await http.get(Uri.parse('$baseUrl/openapi.json'));
    expect(res.statusCode, 200);
    expect(res.headers['content-type'], startsWith('application/json'));
    Map<String, dynamic> doc = jsonDecode(res.body);
    expect(doc['info']['title'], 'Test API');

    Map<String, dynamic> paths = doc['paths'];
    expect(paths.keys, containsAll(<String>['/posts/{id}', '/posts']));
    expect(paths.keys, isNot(contains('/docs')));

    Map<String, dynamic> post = paths['/posts']['post'];
    Map<String, dynamic> body =
        post['requestBody']['content']['application/json']['schema'];
    expect(body['properties']['title']['maxLength'], 100);
    expect(post['security'], <dynamic>[
      <String, dynamic>{'bearerAuth': <dynamic>[]},
    ]);
    expect(post['x-dox-middleware'], <String>['AuthMiddleware']);

    Map<String, dynamic> put = paths['/posts/{id}']['put'];
    expect(
      put['requestBody']['content']['application/json']['schema']['properties']['title']['minLength'],
      3,
    );
  });

  test('the registry adds summary, params, query, schemas and errors', () {
    Map<String, dynamic> doc = OpenApiDocument(config.openApi)
        .build(Route().routes)
        .toJson();
    expect(OpenApiChecker().check(doc), isEmpty);

    Map<String, dynamic> show = doc['paths']['/posts/{id}/full']['get'];
    expect(show['operationId'], 'PostController.show');
    expect(show['summary'], 'Get one post');
    expect(show['tags'], <String>['Post']);
    expect(show['parameters'][0]['schema'], <String, dynamic>{
      'type': 'integer',
    });
    expect(show['responses'].keys, <String>['200', '401', '404', '500']);

    /// a GET request class becomes query params
    Map<String, dynamic> search = doc['paths']['/search']['get'];
    expect(search['parameters'], <dynamic>[
      <String, dynamic>{
        'name': 'q',
        'in': 'query',
        'required': true,
        'schema': <String, dynamic>{'type': 'string'},
      },
    ]);
    expect(search['responses'].keys, contains('422'));
    expect(doc['components']['schemas'].keys, contains('ValidationError'));

    /// @ApiIgnore
    expect(doc['paths'].keys, isNot(contains('/secret')));

    /// not in the registry: a basic entry
    expect(doc['paths']['/posts']['post']['operationId'], 'postPosts');
  });

  test('AuthMiddleware gets bearerAuth without config', () {
    Map<String, dynamic> doc = OpenApiDocument(
      const OpenApiConfig(registry: registry),
    ).build(Route().routes).toJson();
    expect(OpenApiChecker().check(doc), isEmpty);
    expect(
      doc['components']['securitySchemes']['bearerAuth']['scheme'],
      'bearer',
    );
    expect(doc['paths']['/search']['get']['security'], <dynamic>[
      <String, dynamic>{'bearerAuth': <dynamic>[]},
    ]);
  });

  test('YAML and JSON give the same document', () async {
    http.Response json = await http.get(Uri.parse('$baseUrl/openapi.json'));
    http.Response yaml = await http.get(Uri.parse('$baseUrl/openapi.yaml'));
    Object? fromYaml = jsonDecode(jsonEncode(loadYaml(yaml.body)));
    expect(fromYaml, jsonDecode(json.body));
  });

  test('openapi.yaml and docs page', () async {
    http.Response yaml = await http.get(Uri.parse('$baseUrl/openapi.yaml'));
    expect(yaml.headers['content-type'], startsWith('application/yaml'));
    expect(yaml.body, contains('openapi: "3.1.0"'));

    http.Response docs = await http.get(Uri.parse('$baseUrl/docs'));
    expect(docs.headers['content-type'], startsWith('text/html'));
    expect(docs.body, contains('@scalar/api-reference@1.75.1'));
    expect(docs.body, contains('"url":"/openapi.json"'));
    expect(docs.body, contains('"theme":"purple","darkMode":true'));
    expect(docs.body, contains('<title>Test docs</title>'));
    expect(docs.body, isNot(contains('swagger-ui')));
  });

  test('routes added later show up in the docs', () async {
    Route.delete('/posts/{id}', (DoxRequest req, String id) => id);
    http.Response res = await http.get(Uri.parse('$baseUrl/openapi.json'));
    Map<String, dynamic> doc = jsonDecode(res.body);
    expect(doc['paths']['/posts/{id}'].keys, contains('delete'));
  });

  test('writeOpenApi writes json and yaml files', () async {
    Directory dir = await Directory.systemTemp.createTemp('dox_openapi');
    List<File> files = await OpenApiDocument(config.openApi).write(dir.path);
    expect(files.map((File f) => f.path.split('/').last), <String>[
      'openapi.json',
      'openapi.yaml',
    ]);
    await dir.delete(recursive: true);
  });

  test('docs are off by default outside development', () {
    expect(const OpenApiConfig(enabled: false).isEnabled, isFalse);
    Env().env['APP_ENV'] = 'production';
    expect(const OpenApiConfig().isEnabled, isFalse);
    Env().env['APP_ENV'] = 'development';
    expect(const OpenApiConfig().isEnabled, isTrue);
    Env().env.remove('APP_ENV');
  });
}
