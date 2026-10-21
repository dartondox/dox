import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'api_doc.dart';
import 'constants/openapi_constants.dart';
import 'info.dart';
import 'route_doc.dart';
import 'yaml_emitter.dart';

/// Builds an OpenAPI 3.1 document from [Info] and an [ApiDoc].
class OpenApi {
  /// The info block.
  final Info info;

  /// The servers list.
  final List<Server> servers;

  /// Security schemes by name, for example `{'bearerAuth': ...}`.
  final Map<String, SecurityScheme> securitySchemes;

  /// Security that applies to every route unless a route sets its own.
  final List<Map<String, List<String>>>? security;

  /// The route docs and named schemas.
  final ApiDoc docs;

  /// Writes the YAML output.
  final YamlEmitter yamlEmitter;

  /// Creates a builder. A new [ApiDoc] is made when [docs] is not given.
  OpenApi({
    required this.info,
    this.servers = const <Server>[],
    this.securitySchemes = const <String, SecurityScheme>{},
    this.security,
    ApiDoc? docs,
    this.yamlEmitter = const YamlEmitter(),
  }) : docs = docs ?? ApiDoc();

  /// Returns the full document as a map.
  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = <String, dynamic>{
      'openapi': OpenApiConstants.openApiVersion,
      'info': info.toJson(),
    };
    if (servers.isNotEmpty) {
      json['servers'] = _servers();
    }
    json['paths'] = _paths();
    Map<String, dynamic> components = _components();
    if (components.isNotEmpty) {
      json['components'] = components;
    }
    if (security != null) {
      json['security'] = security;
    }
    return json;
  }

  /// Returns the document as JSON text.
  String toJsonString({bool pretty = true}) {
    JsonEncoder encoder = pretty
        ? const JsonEncoder.withIndent('  ')
        : const JsonEncoder();
    return encoder.convert(toJson());
  }

  /// Returns the document as YAML text.
  String toYaml() {
    return yamlEmitter.emit(toJson());
  }

  /// Writes `openapi.json` and `openapi.yaml` into [dir].
  /// Makes the folder when it does not exist. Returns the two files.
  Future<List<File>> writeFiles(String dir) async {
    await Directory(dir).create(recursive: true);
    File json = File(p.join(dir, OpenApiConstants.jsonFileName));
    File yaml = File(p.join(dir, OpenApiConstants.yamlFileName));
    await json.writeAsString('${toJsonString()}\n');
    await yaml.writeAsString(toYaml());
    return <File>[json, yaml];
  }

  List<Map<String, dynamic>> _servers() {
    List<Map<String, dynamic>> list = <Map<String, dynamic>>[];
    for (Server server in servers) {
      list.add(server.toJson());
    }
    return list;
  }

  Map<String, dynamic> _paths() {
    Map<String, Map<String, dynamic>> paths = <String, Map<String, dynamic>>{};
    for (RouteDoc route in docs.routes) {
      Map<String, dynamic> item = paths.putIfAbsent(route.path, _emptyPathItem);
      item[route.method] = route.toOperation(docs.resolver);
    }
    return paths;
  }

  Map<String, dynamic> _emptyPathItem() {
    return <String, dynamic>{};
  }

  Map<String, dynamic> _components() {
    Map<String, dynamic> components = <String, dynamic>{};
    if (docs.schemas.isNotEmpty) {
      Map<String, dynamic> schemas = <String, dynamic>{};
      for (MapEntry<String, Object> entry in docs.schemas.entries) {
        schemas[entry.key] = docs.resolver.resolve(entry.value);
      }
      components['schemas'] = schemas;
    }
    if (securitySchemes.isNotEmpty) {
      Map<String, dynamic> schemes = <String, dynamic>{};
      for (MapEntry<String, SecurityScheme> entry in securitySchemes.entries) {
        schemes[entry.key] = entry.value.toJson();
      }
      components['securitySchemes'] = schemes;
    }
    return components;
  }
}
