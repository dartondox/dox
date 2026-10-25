import 'route_doc.dart';

/// Docs of one controller method, made at build time by `dox_builder`.
///
/// The generated `lib/generated/openapi.g.dart` holds a list of these. They are
/// matched to the live routes by the method name, see [OpenApiRegistry].
class OpenApiOperation {
  /// Class name, for example `BlogController`.
  final String controller;

  /// Method name, for example `index`.
  final String method;

  /// Argument types, for example `['DoxRequest', 'String']`.
  /// Used to tell two methods with the same name apart.
  final List<String> argumentTypes;

  /// Short title.
  final String? summary;

  /// Longer text.
  final String? description;

  /// Tags to group the route.
  final List<String> tags;

  /// True when the route is deprecated.
  final bool deprecated;

  /// True for `@ApiIgnore()`: the route is left out of the document.
  final bool ignore;

  /// Schemas of the path params, in order. They match the route params
  /// by position: the first one is for the first `{param}`.
  final List<Map<String, dynamic>> params;

  /// The request schema: a JSON Schema map (often a `$ref` to a `@Dto`
  /// class) or an object with `toJsonSchema()`.
  final Object? schema;

  /// `body` or `query`. Null means body for POST, PUT and PATCH,
  /// and query for the other methods.
  final String? requestIn;

  /// Responses by status code, from the return type and `@Response`.
  final Map<int, ResponseDoc> responses;

  /// Creates the docs of one controller method.
  const OpenApiOperation({
    required this.controller,
    required this.method,
    this.argumentTypes = const <String>[],
    this.summary,
    this.description,
    this.tags = const <String>[],
    this.deprecated = false,
    this.ignore = false,
    this.params = const <Map<String, dynamic>>[],
    this.schema,
    this.requestIn,
    this.responses = const <int, ResponseDoc>{},
  });

  /// `Class.method`, used as the operation id.
  String get id {
    return '$controller.$method';
  }
}

/// A `Route.get('path', controller.method)` call the builder found.
/// It tells which class a route handler belongs to.
class OpenApiRouteBinding {
  /// HTTP method in upper case, for example `GET`.
  final String method;

  /// The full path: the router prefix, the `Route.group` prefixes and
  /// the path of the route call. Null when one part is not a plain string.
  final String? path;

  /// The operation id, `Class.method`.
  final String operation;

  /// Creates a binding.
  const OpenApiRouteBinding(this.method, this.path, this.operation);
}

/// Everything `dox_builder` found in the app: controller methods,
/// route calls and model schemas. The generated file makes one.
class OpenApiRegistry {
  /// Docs of the controller methods.
  final List<OpenApiOperation> operations;

  /// Route calls found in the code.
  final List<OpenApiRouteBinding> routes;

  /// Named schemas (models), placed under `components/schemas`.
  final Map<String, Map<String, dynamic>> schemas;

  /// Creates a registry. The default is empty.
  const OpenApiRegistry({
    this.operations = const <OpenApiOperation>[],
    this.routes = const <OpenApiRouteBinding>[],
    this.schemas = const <String, Map<String, dynamic>>{},
  });

  /// Finds the docs for one live route.
  ///
  /// [functionName] and [argumentTypes] come from the route handler.
  /// [controller] is the class name of the handler, when the route knows
  /// it (`(C c) => c.index` or `Route.get<C>`). Then only methods of that
  /// class match, so two controllers with the same method name never mix.
  ///
  /// A route call with the same HTTP method, a path that ends the same
  /// way and the same method name wins. Else a single method with the
  /// same name and argument types wins. Else it returns null.
  OpenApiOperation? find(
    String httpMethod,
    String path,
    String functionName,
    List<String> argumentTypes, {
    String? controller,
  }) {
    String method = httpMethod.toUpperCase();
    String openApiPath = PathConverter.path(path);
    OpenApiRouteBinding? best;
    int bestLength = 0;
    for (OpenApiRouteBinding binding in routes) {
      if (binding.method != method ||
          !_sameName(binding, functionName, controller)) {
        continue;
      }
      String? raw = binding.path;
      String? bindingPath = raw == null ? null : PathConverter.path(raw);
      if (bindingPath != null && !_endsWith(openApiPath, bindingPath)) {
        continue;
      }
      int length = bindingPath?.length ?? 0;
      if (best == null || length > bestLength) {
        best = binding;
        bestLength = length;
      }
    }
    if (best != null) {
      OpenApiOperation? op = _byId(best.operation);
      if (op != null) return op;
    }
    OpenApiOperation? found;
    for (OpenApiOperation op in operations) {
      if (op.method != functionName || !_sameTypes(op, argumentTypes)) {
        continue;
      }
      if (controller != null && op.controller != controller) continue;
      if (found != null) return null;
      found = op;
    }
    return found;
  }

  bool _sameName(
    OpenApiRouteBinding binding,
    String functionName,
    String? controller,
  ) {
    if (controller != null) {
      return binding.operation == '$controller.$functionName';
    }
    return binding.operation.endsWith('.$functionName');
  }

  bool _endsWith(String path, String suffix) {
    return suffix == '/'
        ? path == '/'
        : path == suffix || path.endsWith(suffix);
  }

  bool _sameTypes(OpenApiOperation op, List<String> types) {
    if (op.argumentTypes.length != types.length) return false;
    for (int i = 0; i < types.length; i++) {
      if (op.argumentTypes[i] != types[i]) return false;
    }
    return true;
  }

  OpenApiOperation? _byId(String id) {
    for (OpenApiOperation op in operations) {
      if (op.id == id) return op;
    }
    return null;
  }
}
