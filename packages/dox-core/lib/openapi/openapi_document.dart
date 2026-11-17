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

  /// the 422 answer with `CoreFlags.laravelErrors`:
  /// `{message, errors: {field: [messages]}}`
  static const Map<String, dynamic> _laravelErrorSchema = <String, dynamic>{
    'type': 'object',
    'required': <String>['message', 'errors'],
    'properties': <String, dynamic>{
      'message': <String, dynamic>{'type': 'string'},
      'errors': <String, dynamic>{
        'type': 'object',
        'additionalProperties': <String, dynamic>{
          'type': 'array',
          'items': <String, dynamic>{'type': 'string'},
        },
      },
    },
    'example': <String, dynamic>{
      'message': 'The title field is required',
      'errors': <String, dynamic>{
        'title': <String>['The title field is required'],
      },
    },
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
    Map<String, Map<String, dynamic>> schemas = config.registry.schemas;
    if (config.include.isNotEmpty || config.exclude.isNotEmpty) {
      schemas = _usedSchemas(docs);
    }
    for (MapEntry<String, Map<String, dynamic>> schema in schemas.entries) {
      docs.schema(schema.key, schema.value);
    }
    if (reader.usesValidationError) {
      docs.schema(
        OpenApiRouteReader.validationError,
        Dox().flags.laravelErrors
            ? _laravelErrorSchema
            : _validationErrorSchema,
      );
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

  /// The registry schemas that the shown routes use, also the ones used
  /// only from inside another used schema. Hidden routes then do not leak
  /// their schemas into the docs. A ref to a name that is not in the
  /// registry is skipped.
  Map<String, Map<String, dynamic>> _usedSchemas(ApiDoc docs) {
    Map<String, Map<String, dynamic>> registry = config.registry.schemas;
    List<String> todo = <String>[];
    for (RouteDoc route in docs.routes) {
      _collectRefs(route.toOperation(docs.resolver), todo);
    }
    Set<String> used = <String>{};
    while (todo.isNotEmpty) {
      String name = todo.removeLast();
      Map<String, dynamic>? schema = registry[name];
      if (schema == null || !used.add(name)) continue;
      _collectRefs(schema, todo);
    }

    /// keep the registry order, so the docs do not change with route order
    Map<String, Map<String, dynamic>> schemas =
        <String, Map<String, dynamic>>{};
    for (MapEntry<String, Map<String, dynamic>> entry in registry.entries) {
      if (used.contains(entry.key)) schemas[entry.key] = entry.value;
    }
    return schemas;
  }

  /// Adds the schema name of every `#/components/schemas/<Name>` ref in
  /// [json] to [names].
  void _collectRefs(Object? json, List<String> names) {
    if (json is Map) {
      for (MapEntry<dynamic, dynamic> entry in json.entries) {
        Object? value = entry.value;
        if (entry.key == r'$ref' &&
            value is String &&
            value.startsWith(OpenApiConstants.schemaRefPrefix)) {
          names.add(value.substring(OpenApiConstants.schemaRefPrefix.length));
        } else {
          _collectRefs(value, names);
        }
      }
    } else if (json is List) {
      for (Object? item in json) {
        _collectRefs(item, names);
      }
    }
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
