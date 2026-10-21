import 'constants/openapi_constants.dart';
import 'schema_resolver.dart';

/// Docs for one response of a route.
class ResponseDoc {
  /// The response body schema. Can be null for an empty body.
  final Object? schema;

  /// Short text about the response.
  final String description;

  /// Creates response docs.
  const ResponseDoc({this.schema, this.description = 'Response'});

  /// Returns the OpenAPI response object.
  Map<String, dynamic> toJson(SchemaResolver resolver) {
    Map<String, dynamic> json = <String, dynamic>{'description': description};
    Object? body = schema;
    if (body != null) {
      json['content'] = <String, dynamic>{
        OpenApiConstants.bodyMediaType: <String, dynamic>{
          'schema': resolver.resolve(body),
        },
      };
    }
    return json;
  }
}

/// Docs for one route (one method on one path).
class RouteDoc {
  /// HTTP method in lower case, for example `get`.
  final String method;

  /// OpenAPI path, for example `/users/{id}`.
  final String path;

  /// Short summary.
  final String? summary;

  /// Longer description.
  final String? description;

  /// Unique id. Made from the method and path when not given.
  final String? operationId;

  /// Tags to group routes in the docs page.
  final List<String> tags;

  /// Path parameter schemas by name. Missing path params get a string schema.
  final Map<String, Object> params;

  /// Object schema. Each property becomes one query parameter.
  final Object? query;

  /// Request body schema.
  final Object? body;

  /// Media type of the request body. Null means `multipart/form-data`
  /// when [body] has a file field (`format: binary`), else JSON.
  final String? bodyMediaType;

  /// Responses by status code.
  final Map<int, ResponseDoc> responses;

  /// Security requirements, for example `[{'bearerAuth': []}]`.
  final List<Map<String, List<String>>>? security;

  /// True when the route is deprecated.
  final bool deprecated;

  /// Extra `x-` fields added to the operation as they are.
  final Map<String, dynamic> extensions;

  /// Creates route docs. [method] and [path] are normalised.
  RouteDoc({
    required String method,
    required String path,
    this.summary,
    this.description,
    this.operationId,
    this.tags = const <String>[],
    this.params = const <String, Object>{},
    this.query,
    this.body,
    this.bodyMediaType,
    this.responses = const <int, ResponseDoc>{},
    this.security,
    this.deprecated = false,
    this.extensions = const <String, dynamic>{},
  }) : method = PathConverter.method(method),
       path = PathConverter.path(path);

  /// Returns the OpenAPI operation object.
  Map<String, dynamic> toOperation(SchemaResolver resolver) {
    Map<String, dynamic> op = <String, dynamic>{};
    _put(op, 'tags', tags.isEmpty ? null : tags);
    _put(op, 'summary', summary);
    _put(op, 'description', description);
    op['operationId'] = operationId ?? PathConverter.operationId(method, path);
    List<Map<String, dynamic>> parameters = <Map<String, dynamic>>[
      ..._pathParameters(resolver),
      ..._queryParameters(resolver),
    ];
    _put(op, 'parameters', parameters.isEmpty ? null : parameters);
    Object? requestBody = body;
    if (requestBody != null) {
      Map<String, dynamic> schema = resolver.resolve(requestBody);
      op['requestBody'] = <String, dynamic>{
        'required': true,
        'content': <String, dynamic>{
          bodyMediaType ?? mediaTypeFor(schema): <String, dynamic>{
            'schema': schema,
          },
        },
      };
    }
    op['responses'] = _responses(resolver);
    _put(op, 'security', security);
    _put(op, 'deprecated', deprecated ? true : null);
    op.addAll(extensions);
    return op;
  }

  /// Returns `multipart/form-data` when [schema] has a file field
  /// (`format: binary`, also in a list), else `application/json`.
  /// A `$ref` schema is not followed: pass the schema it points to.
  static String mediaTypeFor(Map<String, dynamic> schema) {
    Object? properties = schema['properties'];
    if (properties is Map) {
      for (Object? field in properties.values) {
        if (_isFile(field) || (field is Map && _isFile(field['items']))) {
          return OpenApiConstants.multipartMediaType;
        }
      }
    }
    return OpenApiConstants.bodyMediaType;
  }

  static bool _isFile(Object? schema) {
    if (schema is! Map) return false;
    if (schema['format'] == 'binary') return true;
    Object? anyOf = schema['anyOf'] ?? schema['oneOf'];
    if (anyOf is List) {
      for (Object? option in anyOf) {
        if (_isFile(option)) return true;
      }
    }
    return false;
  }

  List<Map<String, dynamic>> _pathParameters(SchemaResolver resolver) {
    List<Map<String, dynamic>> list = <Map<String, dynamic>>[];
    for (String name in PathConverter.paramNames(path)) {
      Object? schema = params[name];
      list.add(<String, dynamic>{
        'name': name,
        'in': 'path',
        'required': true,
        'schema': schema == null
            ? <String, dynamic>{'type': 'string'}
            : resolver.resolve(schema),
      });
    }
    return list;
  }

  List<Map<String, dynamic>> _queryParameters(SchemaResolver resolver) {
    Object? source = query;
    if (source == null) {
      return <Map<String, dynamic>>[];
    }
    Map<String, dynamic> schema = resolver.resolve(source);
    Object? properties = schema['properties'];
    if (properties is! Map) {
      throw ArgumentError.value(
        source,
        'query',
        'Query schema must be an object with properties',
      );
    }
    Object? requiredList = schema['required'];
    Set<Object?> required = requiredList is List
        ? requiredList.toSet()
        : <Object?>{};
    List<Map<String, dynamic>> list = <Map<String, dynamic>>[];
    for (MapEntry<dynamic, dynamic> entry in properties.entries) {
      list.add(<String, dynamic>{
        'name': entry.key,
        'in': 'query',
        'required': required.contains(entry.key),
        'schema': entry.value,
      });
    }
    return list;
  }

  Map<String, dynamic> _responses(SchemaResolver resolver) {
    if (responses.isEmpty) {
      return <String, dynamic>{
        '200': <String, dynamic>{
          'description': OpenApiConstants.defaultResponseDescription,
        },
      };
    }
    Map<String, dynamic> json = <String, dynamic>{};
    for (MapEntry<int, ResponseDoc> entry in responses.entries) {
      json['${entry.key}'] = entry.value.toJson(resolver);
    }
    return json;
  }

  void _put(Map<String, dynamic> map, String key, Object? value) {
    if (value != null) {
      map[key] = value;
    }
  }
}

/// Helpers to turn Dox paths and methods into OpenAPI form.
class PathConverter {
  static final RegExp _colonParam = RegExp(r':([A-Za-z_][A-Za-z0-9_]*)');
  static final RegExp _braceParam = RegExp(r'\{([^{}/]+)\}');

  /// Turns `/users/:id` or `users/{id}/` into `/users/{id}`.
  /// A Dox catch-all param `{path*}` becomes `{path}`.
  static String path(String input) {
    String out = input
        .replaceAllMapped(_colonParam, _toBrace)
        .replaceAll('*}', '}')
        .replaceAll('?}', '}');
    out = out.replaceAll(RegExp(r'/+'), '/');
    out = out.replaceAll(RegExp(r'^/+|/+$'), '');
    return '/$out';
  }

  /// Returns the lower case method. Throws when OpenAPI does not support it.
  static String method(String input) {
    String lower = input.toLowerCase();
    if (!OpenApiConstants.methods.contains(lower)) {
      throw ArgumentError.value(input, 'method', 'Not an OpenAPI method');
    }
    return lower;
  }

  /// Returns true when OpenAPI supports [input] as a method.
  static bool isSupportedMethod(String input) {
    return OpenApiConstants.methods.contains(input.toLowerCase());
  }

  /// Returns the path param names in order, for example `['id']`.
  static List<String> paramNames(String openApiPath) {
    List<String> names = <String>[];
    for (RegExpMatch match in _braceParam.allMatches(openApiPath)) {
      names.add(match.group(1)!);
    }
    return names;
  }

  /// Makes an id like `getUsersById` from `get` and `/users/{id}`.
  static String operationId(String method, String openApiPath) {
    StringBuffer buffer = StringBuffer(method.toLowerCase());
    for (String part in openApiPath.split('/')) {
      if (part.isEmpty) {
        continue;
      }
      Match? param = _braceParam.matchAsPrefix(part);
      if (param != null && param.end == part.length) {
        buffer.write('By');
        buffer.write(_capitalize(param.group(1)!));
      } else {
        buffer.write(_capitalize(part));
      }
    }
    return buffer.toString();
  }

  static String _capitalize(String word) {
    StringBuffer buffer = StringBuffer();
    bool upper = true;
    for (int i = 0; i < word.length; i++) {
      String char = word[i];
      if (RegExp(r'[A-Za-z0-9]').hasMatch(char)) {
        buffer.write(upper ? char.toUpperCase() : char);
        upper = false;
      } else {
        upper = true;
      }
    }
    return buffer.toString();
  }

  static String _toBrace(Match match) {
    return '{${match.group(1)}}';
  }
}
