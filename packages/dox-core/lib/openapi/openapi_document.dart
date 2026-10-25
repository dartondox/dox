import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/openapi/openapi_route_reader.dart';
import 'package:dox_core/router/route_data.dart';
import 'package:dox_openapi/dox_openapi.dart';

/// Builds the OpenAPI document from the registered routes and serves it.
///
/// Each route gets its docs from [OpenApiConfig.registry] (made by
/// `dox_builder` from the controllers), the route `body:` option and the
/// form request. Routes the registry does not know still get a basic entry.
class OpenApiDocument {
  OpenApiDocument(this.config);

  final OpenApiConfig config;

  static const List<String> _paths = <String>[
    OpenApiConstants.docsPath,
    OpenApiConstants.jsonPath,
    OpenApiConstants.yamlPath,
  ];

  /// the 422 answer of dox: `{field: message}`
  static const Map<String, dynamic> _validationErrorSchema = <String, dynamic>{
    'type': 'object',
    'additionalProperties': <String, dynamic>{'type': 'string'},
    'example': <String, dynamic>{'title': 'The title field is required'},
  };

  OpenApiServer? _server;
  int _builtFor = -1;

  /// The document for [routes].
  OpenApi build(Iterable<RouteData> routes) {
    OpenApiRouteReader reader = OpenApiRouteReader(config);
    ApiDoc docs = ApiDoc();
    for (RouteData route in routes) {
      if (_paths.contains(route.path) ||
          !PathConverter.isSupportedMethod(route.method) ||
          !config.documents(route.path)) {
        continue;
      }
      RouteDoc? doc = reader.read(route);
      if (doc != null) docs.add(doc);
    }
    for (MapEntry<String, Map<String, dynamic>> schema
        in config.registry.schemas.entries) {
      docs.schema(schema.key, schema.value);
    }
    if (reader.usesValidationError) {
      docs.schema(OpenApiRouteReader.validationError, _validationErrorSchema);
    }

    /// a scheme in the config wins over one found in the code
    Map<String, SecurityScheme> schemes = <String, SecurityScheme>{
      ...reader.usedSchemes,
      ...config.securitySchemes,
    };
    return OpenApi(
      info: config.info,
      servers: config.servers,
      securitySchemes: schemes,
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

  /// Controller of the docs routes. The document is built and encoded on
  /// the first request, and again only when routes were added.
  dynamic serve(DoxRequest req) {
    List<RouteData> routes = Route().routes;
    OpenApiServer? server = _server;
    if (server == null || _builtFor != routes.length) {
      server = _server = OpenApiServer(
        build(routes),
        pageTitle: config.pageTitle,
        ui: config.ui,
        scalar: config.scalar,
      );
      _builtFor = routes.length;
    }
    OpenApiResponse? res = server.handle(req.uri.path);
    if (res == null) return null;
    return response(res.body).contentType(ContentType.parse(res.contentType));
  }
}
