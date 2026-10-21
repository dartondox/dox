import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/http_controller_handler.dart';
import 'package:dox_core/router/route_data.dart';
import 'package:dox_openapi/dox_openapi.dart';

/// Turns one live route into a [RouteDoc].
///
/// It joins what the route knows at runtime (method, path, middleware)
/// with what `dox_builder` found in the code ([OpenApiRegistry]).
class OpenApiRouteReader {
  OpenApiRouteReader(this.config)
    : _adapter = DoxRouteAdapter(
        securityByMiddleware: config.securityByMiddleware,
      );

  final OpenApiConfig config;
  final DoxRouteAdapter _adapter;

  /// name of the schema for the 422 answer
  static const String validationError = 'ValidationError';

  /// name of the default login scheme
  static const String bearerAuth = 'bearerAuth';

  static final RegExp _functionName = RegExp(r"from Function '([^']+)'");

  static const Set<String> _bodyMethods = <String>{'post', 'put', 'patch'};

  /// true when a route needs the [validationError] schema
  bool usesValidationError = false;

  /// true when a route got [bearerAuth] by default
  bool usesBearerAuth = false;

  final Set<String> _operationIds = <String>{};

  /// docs for [route], or null when it has `@ApiIgnore()`
  RouteDoc? read(RouteData route) {
    Object? handler = _handler(route);
    OpenApiOperation? op = handler == null ? null : _find(route, handler);
    if (op != null && op.ignore) return null;
    String method = PathConverter.method(route.method);
    String path = PathConverter.path(route.path);
    List<String> middleware = _adapter.middlewareNames(
      route.controllers,
      preMiddleware: route.preMiddleware,
    );
    List<Map<String, List<String>>>? security = _security(middleware);
    Object? request = _request(route, op);
    bool inQuery = _inQuery(method, op, request);
    if (inQuery) request = _queryObject(request);
    return RouteDoc(
      method: method,
      path: path,
      summary: op?.summary ?? '${method.toUpperCase()} $path',
      description: op?.description,
      operationId: _operationId(op, method, path),
      tags: op?.tags ?? const <String>[],
      deprecated: op?.deprecated ?? false,
      params: _params(route, op),
      query: inQuery ? request : null,
      body: inQuery ? null : request,
      responses: _responses(op, request != null, security != null, path),
      security: security,
      extensions: middleware.isEmpty
          ? const <String, dynamic>{}
          : <String, dynamic>{'x-dox-middleware': middleware},
    );
  }

  /// the controller of the route: the last item, when it is a function
  Object? _handler(RouteData route) {
    Object? controllers = route.controllers;
    if (controllers is! List || controllers.isEmpty) return null;
    Object? last = controllers.last;
    return last is Function ? last : null;
  }

  OpenApiOperation? _find(RouteData route, Object handler) {
    if (config.registry.operations.isEmpty) return null;
    String? name = _functionName.firstMatch(handler.toString())?.group(1);
    if (name == null) return null;
    return config.registry.find(
      route.method,
      route.path,
      name,
      controllerArgumentDataTypes(handler),
    );
  }

  String _operationId(OpenApiOperation? op, String method, String path) {
    String id = op?.id ?? PathConverter.operationId(method, path);
    if (!_operationIds.add(id)) {
      /// `Route.resource` sends PUT and PATCH to the same method
      id = '${id}_$method';
      _operationIds.add(id);
    }
    return id;
  }

  /// path param schemas. the controller arguments match the params
  /// by position.
  Map<String, Object> _params(RouteData route, OpenApiOperation? op) {
    if (op == null || op.params.isEmpty) return const <String, Object>{};
    Map<String, Object> params = <String, Object>{};
    List<String> names = route.paramNames;
    for (int i = 0; i < names.length && i < op.params.length; i++) {
      params[names[i]] = op.params[i];
    }
    return params;
  }

  /// request schema. order: route `body:`, the generated schema (a
  /// `@Dto` class), then the form request.
  Object? _request(RouteData route, OpenApiOperation? op) {
    Object? body = route.body;
    if (body != null) return body;
    try {
      Object? schema = op?.schema;
      if (schema != null) return schema;
      String? formRequest = op?.formRequest;
      return formRequest != null
          ? _formRequestSchema(formRequest)
          : _formRequestOfHandler(route);
    } catch (_) {
      /// docs must not break the app. a route without a body is fine.
      return null;
    }
  }

  /// form request of a handler that the registry does not know
  Object? _formRequestOfHandler(RouteData route) {
    Object? handler = _handler(route);
    if (handler == null) return null;
    List<String> types = controllerArgumentDataTypes(handler);
    if (types.isEmpty || types.first == 'DoxRequest') return null;
    return _formRequestSchema(types.first);
  }

  Object? _formRequestSchema(String name) {
    Object? request = Dox().ioc.getByName(name);
    if (request is! FormRequest) return null;
    ObjectSchema? schema = request.schema();
    if (schema != null) return schema;
    Map<String, String> rules = request.rules();
    if (rules.isEmpty) return null;
    return Dox().validator.schemaFor(rules, request.messages());
  }

  /// GET and DELETE send the fields in the query, POST, PUT and PATCH
  /// in the body. `@Body` and `@Query` choose by hand.
  bool _inQuery(String method, OpenApiOperation? op, Object? request) {
    if (request == null) return false;
    String? where = op?.requestIn;
    if (where != null) return where == 'query';
    return !_bodyMethods.contains(method);
  }

  /// a query needs an object with properties, so a `$ref` to a `@Dto`
  /// is replaced by its schema. null when it is not an object.
  Object? _queryObject(Object? request) {
    Object? schema = request;
    if (schema is Map<String, dynamic>) {
      Object? ref = schema[r'$ref'];
      if (ref is String && ref.startsWith(OpenApiConstants.schemaRefPrefix)) {
        String name = ref.substring(OpenApiConstants.schemaRefPrefix.length);
        schema = config.registry.schemas[name];
      }
    } else if (schema != null) {
      schema = const SchemaResolver().resolve(schema);
    }
    return schema is Map && schema['properties'] is Map ? schema : null;
  }

  List<Map<String, List<String>>>? _security(List<String> middleware) {
    List<Map<String, List<String>>> list = <Map<String, List<String>>>[];
    for (String name in middleware) {
      List<Map<String, List<String>>>? custom =
          config.securityByMiddleware[name];
      if (custom != null) {
        list.addAll(custom);
      } else if (name.endsWith('AuthMiddleware')) {
        usesBearerAuth = true;
        list.add(<String, List<String>>{bearerAuth: <String>[]});
      }
    }
    return list.isEmpty ? null : list;
  }

  /// responses from the code, plus the common error answers
  Map<int, ResponseDoc> _responses(
    OpenApiOperation? op,
    bool validates,
    bool secured,
    String path,
  ) {
    Map<int, ResponseDoc> responses = <int, ResponseDoc>{...?op?.responses};
    if (responses.isEmpty) {
      responses[200] = const ResponseDoc(
        description: OpenApiConstants.defaultResponseDescription,
      );
    }
    if (secured) {
      _add(
        responses,
        401,
        const ResponseDoc(
          description: 'Not logged in',
          schema: <String, dynamic>{'type': 'string'},
        ),
      );
    }
    if (path.contains('{')) {
      _add(responses, 404, const ResponseDoc(description: 'Not found'));
    }
    if (validates) {
      usesValidationError = true;
      _add(
        responses,
        422,
        const ResponseDoc(
          description: 'Validation failed',
          schema: <String, dynamic>{
            r'$ref': '${OpenApiConstants.schemaRefPrefix}$validationError',
          },
        ),
      );
    }
    _add(responses, 500, const ResponseDoc(description: 'Server error'));
    return responses;
  }

  /// adds [doc] when the code did not give one for [status]
  void _add(Map<int, ResponseDoc> responses, int status, ResponseDoc doc) {
    if (!responses.containsKey(status)) responses[status] = doc;
  }
}
