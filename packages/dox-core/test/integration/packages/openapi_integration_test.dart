import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../../../../dox-openapi/test/support/openapi_checker.dart';

String get baseUrl => 'http://localhost:${Dox().server.httpServer.port}';

class AuthMiddleware implements IDoxMiddleware {
  @override
  dynamic handle(IDoxRequest req) => req;
}

/// a bearer API key, not a JWT. `@Security` wins over the name rule.
@Security.bearer(format: 'API key')
class ApiKeyAuthMiddleware implements IDoxMiddleware {
  @override
  dynamic handle(IDoxRequest req) => req;
}

class LoginGuard implements IDoxMiddleware {
  @override
  dynamic handle(IDoxRequest req) => req;
}

/// like the your-qr app: two controllers with the same method names and
/// the same paths, one under `api`
class LinkApiController {
  dynamic index(DoxRequest req) => <dynamic>[];

  dynamic show(DoxRequest req, String id) => id;
}

class LinkPageController {
  dynamic index(DoxRequest req) => <dynamic>[];

  dynamic show(DoxRequest req, String id) => id;
}

class PostController {
  dynamic store(DoxRequest req) => 'ok';

  dynamic show(DoxRequest req, String id) => id;

  dynamic search(DoxRequest req) => <String, dynamic>{};

  dynamic secret(DoxRequest req) => 'x';

  dynamic upload(DoxRequest req) => 'ok';
}

class UserController {
  dynamic index(DoxRequest req) => <dynamic>[];
}

class TagController {
  dynamic index(DoxRequest req) => <dynamic>[];
}

/// two controllers with the same method name
class AuthController {
  dynamic login(DoxRequest req) => 'token';
}

class WebAuthController {
  dynamic login(DoxRequest req) => 'session';
}

/// what dox_builder writes into lib/generated/openapi.g.dart for PostController
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
      method: 'upload',
      argumentTypes: <String>['DoxRequest'],
      schema: <String, dynamic>{r'$ref': '#/components/schemas/UploadPhoto'},
    ),
    OpenApiOperation(
      controller: 'UserController',
      method: 'index',
      argumentTypes: <String>['DoxRequest'],
      summary: 'List users',
    ),
    OpenApiOperation(
      controller: 'TagController',
      method: 'index',
      argumentTypes: <String>['DoxRequest'],
      summary: 'List tags',
    ),
    OpenApiOperation(
      controller: 'PostController',
      method: 'secret',
      argumentTypes: <String>['DoxRequest'],
      ignore: true,
    ),
    OpenApiOperation(
      controller: 'AuthController',
      method: 'login',
      argumentTypes: <String>['DoxRequest'],
      summary: 'Token login',
    ),
    OpenApiOperation(
      controller: 'WebAuthController',
      method: 'login',
      argumentTypes: <String>['DoxRequest'],
      summary: 'Session login',
    ),
    OpenApiOperation(
      controller: 'LinkApiController',
      method: 'index',
      argumentTypes: <String>['DoxRequest'],
      summary: 'API links',
    ),
    OpenApiOperation(
      controller: 'LinkApiController',
      method: 'show',
      argumentTypes: <String>['DoxRequest', 'String'],
      summary: 'API link',
    ),
    OpenApiOperation(
      controller: 'LinkPageController',
      method: 'index',
      argumentTypes: <String>['DoxRequest'],
      summary: 'Page links',
    ),
    OpenApiOperation(
      controller: 'LinkPageController',
      method: 'show',
      argumentTypes: <String>['DoxRequest', 'String'],
      summary: 'Page link',
    ),
  ],
  routes: <OpenApiRouteBinding>[
    // `/login` ends both live paths, so only the controller tells them apart
    OpenApiRouteBinding('POST', 'api/login', 'AuthController.login'),
    OpenApiRouteBinding('POST', '/login', 'WebAuthController.login'),
    OpenApiRouteBinding('GET', 'posts/{id}/full', 'PostController.show'),
    // the builder writes the full path, with the group prefix
    OpenApiRouteBinding('GET', '/users/', 'UserController.index'),
    OpenApiRouteBinding('GET', '/tags/', 'TagController.index'),
    OpenApiRouteBinding('POST', '/upload', 'PostController.upload'),
    OpenApiRouteBinding('GET', 'api/links', 'LinkApiController.index'),
    OpenApiRouteBinding('GET', 'api/links/{id}', 'LinkApiController.show'),
    OpenApiRouteBinding('GET', '/links', 'LinkPageController.index'),
    OpenApiRouteBinding('GET', '/links/{id}', 'LinkPageController.show'),
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
    'UploadPhoto': <String, dynamic>{
      'type': 'object',
      'properties': <String, dynamic>{
        'photo': <String, dynamic>{'type': 'string', 'format': 'binary'},
        'note': <String, dynamic>{'type': 'string'},
      },
    },
  },
  security: <String, OpenApiSecurity>{
    'ApiKeyAuthMiddleware': OpenApiSecurity('apiKeyAuth', <String, dynamic>{
      'type': 'http',
      'scheme': 'bearer',
      'bearerFormat': 'API key',
    }),
  },
);

class ApiRouter extends Router {
  @override
  String get prefix => 'api';

  @override
  List<dynamic> get middleware => <dynamic>[ApiKeyAuthMiddleware()];

  @override
  void register() {
    Route.get('/links', (LinkApiController c) => c.index);
    Route.get('/links/{id}', (LinkApiController c) => c.show);
  }
}

class WebRouter extends Router {
  @override
  void register() {
    Route.middleware(<dynamic>[LoginGuard()], registerDashboard);
  }

  void registerDashboard() {
    Route.get('/links', (LinkPageController c) => c.index);
    Route.get('/links/{id}', (LinkPageController c) => c.show);
  }
}

class DocsRouter extends Router {
  @override
  List<dynamic> get middleware => <dynamic>[AuthMiddleware()];

  @override
  void register() {
    Route.get('/posts/{id}', (DoxRequest req, String id) => id);
    Route.post(
      '/posts',
      PostController().store,
      body: v.object(<String, Schema<Object?>>{'title': v.string().max(100)}),
    );
    // three `'/'` routes in groups, each with its own docs
    Route.group('/users', () {
      Route.get('/', UserController().index);
    });
    Route.group('/tags', () {
      Route.get('/', TagController().index);
    });
    Route.get('/posts/{id}/full', PostController().show);
    Route.get('/search', PostController().search);
    Route.get('/secret', PostController().secret);
    Route.post('/upload', PostController().upload);
    Route.group('/api/auth', () {
      Route.post('/login', (AuthController c) => c.login);
    });
    Route.group('/web-auth', () {
      Route.post<WebAuthController>('/login', (WebAuthController c) => c.login);
    });
    Route.put(
      '/posts/{id}',
      (DoxRequest req, String id) => id,
      body: v.object(<String, Schema<Object?>>{'title': v.string().min(3)}),
    );
  }
}

AppConfig config = AppConfig(
  appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
  // the OS picks a free port, so test files can run in parallel
  serverPort: 0,
  totalIsolate: 1,
  routers: <Router>[DocsRouter(), ApiRouter(), WebRouter()],
  container: (IocContainer c) {
    c.singleton<LinkApiController>((IocContainer c) => LinkApiController());
    c.singleton<LinkPageController>((IocContainer c) => LinkPageController());
    c.singleton<AuthController>((IocContainer c) => AuthController());
    c.singleton<WebAuthController>((IocContainer c) => WebAuthController());
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

    /// `'/'` routes in groups each find their own docs
    expect(doc['paths']['/users']['get']['summary'], 'List users');
    expect(doc['paths']['/tags']['get']['summary'], 'List tags');

    /// two controllers with a `login` method each get their own docs
    expect(doc['paths']['/api/auth/login']['post']['summary'], 'Token login');
    expect(doc['paths']['/web-auth/login']['post']['summary'], 'Session login');

    /// the your-qr routes: same paths and method names, two controllers
    expect(doc['paths']['/api/links']['get']['summary'], 'API links');
    expect(doc['paths']['/api/links/{id}']['get']['summary'], 'API link');
    expect(doc['paths']['/links']['get']['summary'], 'Page links');
    expect(doc['paths']['/links/{id}']['get']['summary'], 'Page link');
  });

  test('@Security on a middleware class gives its own scheme', () {
    Map<String, dynamic> doc = OpenApiDocument(
      const OpenApiConfig(registry: registry),
    ).build(Route().routes).toJson();
    expect(OpenApiChecker().check(doc), isEmpty);
    expect(
      doc['components']['securitySchemes']['apiKeyAuth'],
      <String, dynamic>{
        'type': 'http',
        'scheme': 'bearer',
        'bearerFormat': 'API key',
      },
    );
    expect(doc['paths']['/api/links']['get']['security'], <dynamic>[
      <String, dynamic>{'apiKeyAuth': <dynamic>[]},
    ]);
    expect(doc['paths']['/links']['get'].containsKey('security'), isFalse);
  });

  test('a body with a file field uses multipart/form-data', () {
    Map<String, dynamic> doc = OpenApiDocument(config.openApi)
        .build(Route().routes)
        .toJson();
    Map<String, dynamic> content =
        doc['paths']['/upload']['post']['requestBody']['content'];
    expect(content.keys, <String>['multipart/form-data']);
    expect(content['multipart/form-data']['schema'], <String, dynamic>{
      r'$ref': '#/components/schemas/UploadPhoto',
    });
  });

  test('AuthMiddleware gets bearerAuth without config', () {
    Map<String, dynamic> doc = OpenApiDocument(
      const OpenApiConfig(registry: registry),
    ).build(Route().routes).toJson();
    expect(OpenApiChecker().check(doc), isEmpty);

    /// the name rule does not know the token format, so no `JWT`
    expect(
      doc['components']['securitySchemes']['bearerAuth'],
      <String, dynamic>{'type': 'http', 'scheme': 'bearer'},
    );
    expect(doc['paths']['/search']['get']['security'], <dynamic>[
      <String, dynamic>{'bearerAuth': <dynamic>[]},
    ]);
  });

  test('include and exclude pick the routes by path', () {
    Map<String, dynamic> doc = OpenApiDocument(
      const OpenApiConfig(
        registry: registry,
        include: <String>['/api/auth/*', '/web-auth/*'],
        exclude: <String>['/web-auth/login'],
      ),
    ).build(Route().routes).toJson();
    expect(doc['paths'].keys, <String>['/api/auth/login']);
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

  test('docs are on in development and when APP_ENV is not set', () {
    expect(const OpenApiConfig(enabled: false).isEnabled, isFalse);
    Env().env['APP_ENV'] = 'production';
    expect(const OpenApiConfig().isEnabled, isFalse);
    Env().env['APP_ENV'] = 'development';
    expect(const OpenApiConfig().isEnabled, isTrue);

    /// not set: the same default as `appEnv` of the typed env
    Env().env.remove('APP_ENV');
    if (Platform.environment['APP_ENV'] == null) {
      expect(const OpenApiConfig().isEnabled, isTrue);
    }
  });
}
