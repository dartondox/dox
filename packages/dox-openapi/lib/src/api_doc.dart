import 'route_doc.dart';
import 'schema_resolver.dart';

/// A registry of route docs and named schemas.
///
/// ```dart
/// ApiDoc docs = ApiDoc();
/// Map<String, dynamic> user = docs.schema('User', userSchema);
/// docs.route('GET', '/users/{id}', responses: <int, ResponseDoc>{
///   200: ResponseDoc(schema: user, description: 'One user'),
/// });
/// ```
class ApiDoc {
  final SchemaResolver _resolver;
  final Map<String, RouteDoc> _routes = <String, RouteDoc>{};
  final Map<String, Object> _schemas = <String, Object>{};

  /// Creates an empty registry.
  ApiDoc({SchemaResolver resolver = const SchemaResolver()})
      : _resolver = resolver;

  /// The resolver used for all schemas.
  SchemaResolver get resolver {
    return _resolver;
  }

  /// All route docs, in the order they were added.
  List<RouteDoc> get routes {
    return _routes.values.toList();
  }

  /// All named schemas. Values are not resolved yet.
  Map<String, Object> get schemas {
    return Map<String, Object>.unmodifiable(_schemas);
  }

  /// Adds or replaces the docs for one route.
  RouteDoc route(
    String method,
    String path, {
    String? summary,
    String? description,
    String? operationId,
    List<String> tags = const <String>[],
    Map<String, Object> params = const <String, Object>{},
    Object? query,
    Object? body,
    Map<int, ResponseDoc> responses = const <int, ResponseDoc>{},
    List<Map<String, List<String>>>? security,
    Map<String, dynamic> extensions = const <String, dynamic>{},
  }) {
    return add(RouteDoc(
      method: method,
      path: path,
      summary: summary,
      description: description,
      operationId: operationId,
      tags: tags,
      params: params,
      query: query,
      body: body,
      responses: responses,
      security: security,
      extensions: extensions,
    ));
  }

  /// Adds or replaces [doc].
  RouteDoc add(RouteDoc doc) {
    _routes[_key(doc.method, doc.path)] = doc;
    return doc;
  }

  /// Returns true when docs exist for this method and path.
  bool has(String method, String path) {
    return _routes.containsKey(_key(
      PathConverter.method(method),
      PathConverter.path(path),
    ));
  }

  /// Saves a named schema under `components/schemas` and returns its `$ref`.
  ///
  /// Use this for Dox models too. For now pass a raw JSON Schema map.
  Map<String, dynamic> schema(String name, Object source) {
    _schemas[name] = source;
    return _resolver.ref(name);
  }

  /// Returns a `$ref` to a named schema.
  Map<String, dynamic> ref(String name) {
    return _resolver.ref(name);
  }

  String _key(String method, String path) {
    return '$method $path';
  }
}
