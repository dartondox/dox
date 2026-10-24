import 'dart:convert';
import 'dart:io';

import 'package:dox_openapi/dox_openapi.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'support/openapi_checker.dart';

/// Same shape as dox_core RouteData (method, path, controllers).
class FakeRoute {
  final String method;
  final String path;
  final List<dynamic> controllers;

  FakeRoute(this.method, this.path, this.controllers);
}

/// Same shape as the new dox_core RouteData, with preMiddleware and body.
class FullRoute extends FakeRoute {
  final List<dynamic> preMiddleware;
  final Object? body;

  FullRoute(
    super.method,
    super.path,
    super.controllers, {
    this.preMiddleware = const <dynamic>[],
    this.body,
  });
}

class AuthMiddleware {}

class LogMiddleware {}

String handler() {
  return 'ok';
}

OpenApi buildApi() {
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
    description: 'Line one.\nLine two: "quoted"',
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
  docs.route(
    'GET',
    '/users',
    tags: <String>['users'],
    query: <String, dynamic>{
      'type': 'object',
      'properties': <String, dynamic>{
        'page': <String, dynamic>{'type': 'integer', 'minimum': 1},
      },
    },
    responses: <int, ResponseDoc>{
      200: ResponseDoc(
        schema: <String, dynamic>{'type': 'array', 'items': user},
        description: 'All users',
      ),
    },
  );
  docs.route('POST', '/users', body: user);
  return OpenApi(
    info: const Info(title: 'Dox API', version: '1.0.0', description: 'Test'),
    servers: const <Server>[
      Server('http://localhost:3000', description: 'Local'),
    ],
    securitySchemes: <String, SecurityScheme>{
      'bearerAuth': SecurityScheme.bearer(),
      'apiKey': SecurityScheme.apiKey(name: 'X-API-Key'),
    },
    docs: docs,
  );
}

List<FakeRoute> doxRoutes() {
  return <FakeRoute>[
    FakeRoute('GET', '/users/{id}', <dynamic>[handler]),
    FakeRoute('DELETE', '/users/{id}', <dynamic>[AuthMiddleware(), handler]),
    FakeRoute('GET', '/blog/:slug/comments', <dynamic>[
      LogMiddleware(),
      handler,
    ]),
    FakeRoute('PURGE', '/cache', <dynamic>[handler]),
    FakeRoute('GET', '/ping', <dynamic>[]),
  ];
}

void main() {
  OpenApiChecker checker = OpenApiChecker();

  group('OpenApi document', () {
    test('passes the structural checks', () {
      Map<String, dynamic> doc = buildApi().toJson();
      expect(checker.check(doc), isEmpty);
      expect(doc['openapi'], '3.1.0');
      expect((doc['paths'] as Map<dynamic, dynamic>).keys, <String>[
        '/users/{id}',
        '/users',
      ]);
      Map<dynamic, dynamic> components =
          doc['components'] as Map<dynamic, dynamic>;
      expect((components['schemas'] as Map<dynamic, dynamic>).keys, <String>[
        'User',
      ]);
      expect(
        (components['securitySchemes'] as Map<dynamic, dynamic>).keys,
        <String>['bearerAuth', 'apiKey'],
      );
    });

    test('groups methods under one path', () {
      Map<dynamic, dynamic> users =
          (buildApi().toJson()['paths'] as Map<dynamic, dynamic>)['/users']
              as Map<dynamic, dynamic>;
      expect(users.keys, <String>['get', 'post']);
    });

    test('leaves out empty optional blocks', () {
      Map<String, dynamic> doc = OpenApi(
        info: const Info(title: 't', version: '1'),
      ).toJson();
      expect(doc, <String, dynamic>{
        'openapi': '3.1.0',
        'info': <String, dynamic>{'title': 't', 'version': '1'},
        'paths': <String, dynamic>{},
      });
      expect(checker.check(doc), isEmpty);
    });

    test('writes global security', () {
      OpenApi api = OpenApi(
        info: const Info(title: 't', version: '1'),
        securitySchemes: <String, SecurityScheme>{
          'bearerAuth': SecurityScheme.bearer(),
        },
        security: <Map<String, List<String>>>[
          <String, List<String>>{'bearerAuth': <String>[]},
        ],
      );
      expect(api.toJson()['security'], isNotNull);
      expect(checker.check(api.toJson()), isEmpty);
    });

    test('pretty and compact JSON decode to the same map', () {
      OpenApi api = buildApi();
      String pretty = api.toJsonString();
      String compact = api.toJsonString(pretty: false);
      expect(pretty, contains('\n  '));
      expect(compact, isNot(contains('\n')));
      expect(jsonDecode(pretty), jsonDecode(compact));
    });

    test('YAML output parses back to the same data as JSON', () {
      OpenApi api = buildApi();
      DoxRouteAdapter().addTo(api.docs, doxRoutes());
      Object? fromYaml = jsonDecode(jsonEncode(loadYaml(api.toYaml())));
      expect(fromYaml, jsonDecode(api.toJsonString()));
    });
  });

  group('DoxRouteAdapter', () {
    test('adds only undocumented, supported routes', () {
      OpenApi api = buildApi();
      int added = const DoxRouteAdapter().addTo(api.docs, doxRoutes());
      expect(added, 3);
      Map<String, dynamic> doc = api.toJson();
      expect(checker.check(doc), isEmpty);
      Map<dynamic, dynamic> paths = doc['paths'] as Map<dynamic, dynamic>;
      expect(paths.containsKey('/cache'), isFalse);
      expect(paths.containsKey('/blog/{slug}/comments'), isTrue);
      Map<dynamic, dynamic> getUser =
          (paths['/users/{id}'] as Map<dynamic, dynamic>)['get']
              as Map<dynamic, dynamic>;
      expect(getUser['summary'], 'Get one user');
    });

    test('reads middleware names and maps them to security', () {
      ApiDoc docs = ApiDoc();
      DoxRouteAdapter adapter = const DoxRouteAdapter(
        securityByMiddleware: <String, List<Map<String, List<String>>>>{
          'AuthMiddleware': <Map<String, List<String>>>[
            <String, List<String>>{'bearerAuth': <String>[]},
          ],
        },
      );
      adapter.addTo(docs, doxRoutes());
      Map<String, RouteDoc> byKey = <String, RouteDoc>{};
      for (RouteDoc doc in docs.routes) {
        byKey['${doc.method} ${doc.path}'] = doc;
      }
      RouteDoc delete = byKey['delete /users/{id}']!;
      expect(delete.extensions['x-dox-middleware'], <String>['AuthMiddleware']);
      expect(delete.security, <Map<String, List<String>>>[
        <String, List<String>>{'bearerAuth': <String>[]},
      ]);
      RouteDoc blog = byKey['get /blog/{slug}/comments']!;
      expect(blog.security, isNull);
      expect(blog.summary, 'GET /blog/{slug}/comments');
      expect(byKey['get /ping']!.extensions, isEmpty);
    });

    test('skips functions and the handler in middleware names', () {
      DoxRouteAdapter adapter = const DoxRouteAdapter();
      expect(
        adapter.middlewareNames(<dynamic>[handler, LogMiddleware(), handler]),
        <String>['LogMiddleware'],
      );
      expect(adapter.middlewareNames(null), isEmpty);
      expect(adapter.middlewareNames(handler), isEmpty);
    });

    test('reads preMiddleware and body when the route has them', () {
      AuthMiddleware auth = AuthMiddleware();
      ApiDoc docs = ApiDoc();
      const DoxRouteAdapter().addTo(docs, <Object>[
        FullRoute(
          'POST',
          '/posts',
          <dynamic>[auth, LogMiddleware(), handler],
          preMiddleware: <dynamic>[auth],
          body: <String, dynamic>{'type': 'object'},
        ),
      ]);
      RouteDoc doc = docs.routes.first;
      expect(doc.extensions['x-dox-middleware'], <String>[
        'AuthMiddleware',
        'LogMiddleware',
      ]);
      expect(doc.body, <String, dynamic>{'type': 'object'});
    });
  });

  group('OpenApiChecker catches broken documents', () {
    test('missing info and bad version', () {
      List<String> errors = checker.check(<String, dynamic>{
        'openapi': '3.0.0',
        'paths': <String, dynamic>{},
      });
      expect(errors, contains('openapi must be a 3.1.x string'));
      expect(errors, contains('info is required'));
    });

    test('undeclared and extra path params', () {
      Map<String, dynamic> doc = buildApi().toJson();
      Map<dynamic, dynamic> op =
          ((doc['paths'] as Map<dynamic, dynamic>)['/users/{id}']
                  as Map<dynamic, dynamic>)['get']
              as Map<dynamic, dynamic>;
      (op['parameters'] as List<dynamic>).clear();
      (op['parameters'] as List<dynamic>).add(<String, dynamic>{
        'name': 'other',
        'in': 'path',
        'required': true,
        'schema': <String, dynamic>{'type': 'string'},
      });
      List<String> errors = checker.check(doc);
      expect(
        errors,
        contains('get /users/{id}: path parameter id is not declared'),
      );
      expect(
        errors,
        contains('get /users/{id}: path parameter other is not in the path'),
      );
    });

    test('broken ref and unknown security scheme', () {
      ApiDoc docs = ApiDoc();
      docs.route(
        'GET',
        '/x',
        body: docs.ref('Missing'),
        security: <Map<String, List<String>>>[
          <String, List<String>>{'nope': <String>[]},
        ],
      );
      List<String> errors = checker.check(
        OpenApi(
          info: const Info(title: 't', version: '1'),
          docs: docs,
        ).toJson(),
      );
      expect(errors.join('\n'), contains('cannot resolve'));
      expect(errors, contains('security scheme nope is not defined'));
    });
  });

  group('writeFiles and generateOpenApi', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('dox_openapi_test');
    });

    tearDown(() async {
      await temp.delete(recursive: true);
    });

    test('writes openapi.json and openapi.yaml', () async {
      String dir = '${temp.path}/nested/out';
      List<File> files = await buildApi().writeFiles(dir);
      expect(
        <String>[
          files[0].uri.pathSegments.last,
          files[1].uri.pathSegments.last,
        ],
        <String>['openapi.json', 'openapi.yaml'],
      );
      Object? json = jsonDecode(await files[0].readAsString());
      Object? yaml = jsonDecode(
        jsonEncode(loadYaml(await files[1].readAsString())),
      );
      expect(yaml, json);
      expect(checker.check(json as Map<String, dynamic>), isEmpty);
    });

    test('generateOpenApi adds routes then writes files', () async {
      OpenApi api = buildApi();
      List<File> files = await generateOpenApi(
        api,
        temp.path,
        routes: doxRoutes(),
      );
      Map<String, dynamic> json =
          jsonDecode(await files[0].readAsString()) as Map<String, dynamic>;
      expect(
        (json['paths'] as Map<dynamic, dynamic>).containsKey('/ping'),
        isTrue,
      );
      expect(checker.check(json), isEmpty);
    });
  });

  group('OpenApiServer', () {
    OpenApiServer server = OpenApiServer(buildApi());

    test('builds and encodes the document once', () {
      expect(identical(server.json().body, server.json().body), isTrue);
      expect(identical(server.yaml().body, server.yaml().body), isTrue);
    });

    test('serves JSON and YAML with content types', () {
      OpenApiResponse json = server.handle('/openapi.json')!;
      expect(json.contentType, startsWith('application/json'));
      expect(jsonDecode(json.body), isA<Map<String, dynamic>>());
      OpenApiResponse yaml = server.handle('/openapi.yaml')!;
      expect(yaml.contentType, startsWith('application/yaml'));
      expect(loadYaml(yaml.body), isA<Map<dynamic, dynamic>>());
    });

    test('serves the Scalar page by default', () {
      OpenApiResponse page = server.handle('/docs')!;
      expect(page.contentType, startsWith('text/html'));
      expect(
        page.body,
        contains(
          'https://cdn.jsdelivr.net/npm/@scalar/api-reference@1.75.1'
          '/dist/browser/standalone.js" integrity="sha384-',
        ),
      );
      expect(
        page.body,
        contains(
          "Scalar.createApiReference('#app', {\"url\":\"/openapi.json\","
          '"theme":"default","darkMode":false,'
          '"documentDownloadType":"both"});',
        ),
      );
      expect(page.body, contains('<title>Dox API</title>'));
      expect(page.body, isNot(contains('swagger')));
    });

    test('serves Swagger UI with DocsUi.swagger', () {
      OpenApiServer s = OpenApiServer(buildApi(), ui: DocsUi.swagger);
      String body = s.handle('/docs')!.body;
      expect(
        body,
        contains(
          'swagger-ui-dist@5.34.0/swagger-ui-bundle.js" integrity="sha384-',
        ),
      );
      expect(body, contains('swagger-ui.css" integrity="sha384-'));
      expect(body, contains('url: "/openapi.json"'));
      expect(body, isNot(contains('scalar')));
    });

    test('puts Scalar options in the config', () {
      OpenApiServer s = OpenApiServer(
        buildApi(),
        scalar: const ScalarOptions(
          theme: ScalarTheme.deepSpace,
          darkMode: true,
          showDownloadButton: false,
          proxyUrl: 'https://proxy.scalar.com',
        ),
      );
      expect(
        s.docsPage().body,
        contains(
          '{"url":"/openapi.json","theme":"deepSpace","darkMode":true,'
          '"documentDownloadType":"none",'
          '"proxyUrl":"https://proxy.scalar.com"}',
        ),
      );
    });

    test('escapes the page title', () {
      OpenApiServer s = OpenApiServer(buildApi(), pageTitle: '<b>&</b>');
      expect(s.docsPage().body, contains('&lt;b&gt;&amp;&lt;&#47;b&gt;'));
      OpenApiServer w = OpenApiServer(
        buildApi(),
        pageTitle: '<b>&</b>',
        ui: DocsUi.swagger,
      );
      expect(w.docsPage().body, contains('&lt;b&gt;&amp;&lt;&#47;b&gt;'));
    });

    test('a script tag in a value can not close the script', () {
      String bad = '</script><script>alert(1)</script>';
      OpenApiServer s = OpenApiServer(
        buildApi(),
        scalar: ScalarOptions(proxyUrl: bad),
      );
      String body = s.docsPage(specUrl: bad).body;
      expect(body, isNot(contains(bad)));
      expect(body, contains(r'"\u003c/script>\u003cscript>alert(1)'));
      String swagger = OpenApiServer(
        buildApi(),
        ui: DocsUi.swagger,
      ).docsPage(specUrl: bad).body;
      expect(swagger, isNot(contains(bad)));
      expect(swagger, contains(r'url: "\u003c/script>'));
    });

    test('scriptJson keeps the value', () {
      String value = '</script> <!-- "x"';
      expect(jsonDecode(scriptJson(value)), value);
    });

    test('returns null for other paths and lists its paths', () {
      expect(server.handle('/other'), isNull);
      expect(server.paths, <String>['/openapi.json', '/openapi.yaml', '/docs']);
    });
  });
}
