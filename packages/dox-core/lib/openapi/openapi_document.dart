import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/http_controller_handler.dart';
import 'package:dox_core/router/route_data.dart';
import 'package:dox_openapi/dox_openapi.dart';

/// Builds the OpenAPI document from the registered routes and serves it.
///
/// Request bodies come from the route `body:` option, or from the form
/// request of the controller (`schema()`, else `rules()`).
class OpenApiDocument {
  OpenApiDocument(this.config);

  final OpenApiConfig config;

  static const List<String> _paths = <String>[
    OpenApiConstants.docsPath,
    OpenApiConstants.jsonPath,
    OpenApiConstants.yamlPath,
  ];

  OpenApiServer? _server;
  int _builtFor = -1;

  /// The document for [routes].
  OpenApi build(Iterable<RouteData> routes) {
    List<RouteData> list = <RouteData>[];
    for (RouteData route in routes) {
      if (_paths.contains(route.path)) continue;
      route.body ??= _formRequestBody(route);
      list.add(route);
    }
    ApiDoc docs = ApiDoc();
    DoxRouteAdapter(securityByMiddleware: config.securityByMiddleware)
        .addTo(docs, list);
    return OpenApi(
      info: config.info,
      servers: config.servers,
      securitySchemes: config.securitySchemes,
      docs: docs,
    );
  }

  /// Write `openapi.json` and `openapi.yaml` into [dir].
  Future<List<File>> write(String dir) {
    return build(Route().routes).writeFiles(dir);
  }

  /// Add `GET /docs`, `/openapi.json` and `/openapi.yaml`.
  void register() {
    for (String path in _paths) {
      Route.get(path, serve);
    }
  }

  /// Controller of the docs routes. The document is built on the first
  /// request, and again only when routes were added.
  dynamic serve(DoxRequest req) {
    List<RouteData> routes = Route().routes;
    OpenApiServer? server = _server;
    if (server == null || _builtFor != routes.length) {
      server = _server = OpenApiServer(build(routes));
      _builtFor = routes.length;
    }
    OpenApiResponse? res = server.handle(req.uri.path);
    if (res == null) return null;
    return response(res.body).contentType(ContentType.parse(res.contentType));
  }

  /// schema of the form request that the controller takes, if any
  Object? _formRequestBody(RouteData route) {
    Object? controllers = route.controllers;
    if (controllers is! List || controllers.isEmpty) return null;
    Object? handler = controllers.last;
    if (handler is! Function) return null;
    try {
      List<String> types = controllerArgumentDataTypes(handler);
      if (types.isEmpty || types.first == 'DoxRequest') return null;
      Object? request = Dox().ioc.getByName(types.first);
      if (request is! FormRequest) return null;
      ObjectSchema? schema = request.schema();
      if (schema != null) return schema;
      Map<String, String> rules = request.rules();
      if (rules.isEmpty) return null;
      return Dox().validator.schemaFor(rules, request.messages());
    } catch (_) {
      /// docs must not break the app. a route without a body is fine.
      return null;
    }
  }
}
