import 'api_doc.dart';
import 'route_doc.dart';

/// Adds routes from the Dox router to an [ApiDoc].
///
/// It reads `method`, `path` and `controllers` from each route object, so
/// it works with dox_core `RouteData` without a direct dependency:
///
/// ```dart
/// DoxRouteAdapter().addTo(docs, Route().routes);
/// ```
///
/// When a route has `preMiddleware` (dox_core sets it), middleware names
/// come from it and from the inline middleware before the handler.
/// When a route has `body` (a schema), it becomes the request body.
///
/// Routes that already have docs are kept as they are. Methods that
/// OpenAPI does not support (for example `PURGE`) are skipped.
class DoxRouteAdapter {
  /// Security to add when a route uses a middleware with this class name.
  /// Example: `{'AuthMiddleware': [{'bearerAuth': []}]}`.
  final Map<String, List<Map<String, List<String>>>> securityByMiddleware;

  /// Creates an adapter.
  const DoxRouteAdapter({
    this.securityByMiddleware =
        const <String, List<Map<String, List<String>>>>{},
  });

  /// Adds a basic entry to [docs] for each route that has no docs yet.
  /// Returns the number of routes added.
  int addTo(ApiDoc docs, Iterable<Object?> routes) {
    int added = 0;
    for (Object? route in routes) {
      dynamic r = route;
      String method = '${r.method}';
      String path = '${r.path}';
      if (!PathConverter.isSupportedMethod(method) || docs.has(method, path)) {
        continue;
      }
      List<String> middleware = middlewareNames(
        r.controllers,
        preMiddleware: _read(() => r.preMiddleware),
      );
      docs.add(
        RouteDoc(
          method: method,
          path: path,
          summary: '${method.toUpperCase()} ${PathConverter.path(path)}',
          body: _read(() => r.body),
          security: _security(middleware),
          extensions: middleware.isEmpty
              ? const <String, dynamic>{}
              : <String, dynamic>{'x-dox-middleware': middleware},
        ),
      );
      added++;
    }
    return added;
  }

  /// Returns class names of the middleware in [controllers].
  /// The last item is the handler, and plain functions have no useful name,
  /// so both are left out. [preMiddleware] are the group middleware that
  /// dox_core puts first in [controllers].
  List<String> middlewareNames(Object? controllers, {Object? preMiddleware}) {
    if (controllers is! List || controllers.isEmpty) {
      return <String>[];
    }
    List<Object?> items = <Object?>[
      if (preMiddleware is List) ...preMiddleware,
      ...controllers.sublist(
        preMiddleware is List && preMiddleware.length < controllers.length
            ? preMiddleware.length
            : 0,
        controllers.length - 1,
      ),
    ];
    List<String> names = <String>[];
    for (Object? item in items) {
      if (item != null && item is! Function) {
        names.add(item.runtimeType.toString());
      }
    }
    return names;
  }

  /// Reads an optional field of a route object. Null when it has none.
  Object? _read(Object? Function() getter) {
    try {
      return getter();
    } on NoSuchMethodError {
      return null;
    }
  }

  List<Map<String, List<String>>>? _security(List<String> middleware) {
    List<Map<String, List<String>>> list = <Map<String, List<String>>>[];
    for (String name in middleware) {
      list.addAll(securityByMiddleware[name] ?? <Map<String, List<String>>>[]);
    }
    return list.isEmpty ? null : list;
  }
}
