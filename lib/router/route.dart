import 'package:dox_core/dox_core.dart';

class Route {
  /// Singleton
  static final Route _singleton = Route._internal();
  factory Route() => _singleton;
  Route._internal();

  String _prefix = '';

  List _preMiddleware = [];

  List<RouteData> routes = [];

  String? _resourceKey;

  List<RouteData> _getRecentlyAddedRoutes() {
    if (_resourceKey != null) {
      return routes.where((r) => r.resourceKey == _resourceKey).toList();
    } else {
      return [routes.last];
    }
  }

  formRequest(FormRequest Function() formRequest) {
    for (RouteData r in _getRecentlyAddedRoutes()) {
      r.formRequest = formRequest;
    }
  }

  static sanitizeRoutePath(String path) {
    path = path.replaceAll(RegExp(r'/+'), '/');
    return "/${path.replaceAll(RegExp('^\\/+|\\/+\$'), '')}";
  }

  Route _addRoute(method, String path, controller, {String? resourceKey}) {
    Route()._resourceKey = null;
    path = Route.sanitizeRoutePath(path);
    List controllers = [];
    controllers.addAll(_preMiddleware);
    if (controller is Function) {
      controllers.add(controller);
    }
    if (controller is List) {
      controllers.addAll(controller);
    }
    routes.add(RouteData(
      method: method,
      path: path,
      controllers: controllers,
      resourceKey: resourceKey,
    ));
    return this;
  }

  static group(prefix, Function(SubRoute) callback) {
    callback(SubRoute(prefix));
  }

  static use(List controllers) {
    Route()._preMiddleware = controllers;
  }

  static prefix(prefix) {
    Route()._prefix = prefix;
  }

  static websocket({
    required DoxWebsocket websocket,
    String route = 'ws',
    List middleware = const [],
  }) {
    Route()._addRoute('GET', route, [...middleware, websocket.handle]);
  }

  static Route get(route, controller) {
    return Route()._addRoute('GET', Route()._prefix + route, controller);
  }

  static Route post(route, controller, {Function? request}) {
    return Route()._addRoute('POST', Route()._prefix + route, controller);
  }

  static Route put(route, controller) {
    return Route()._addRoute('PUT', Route()._prefix + route, controller);
  }

  static Route delete(route, controller) {
    return Route()._addRoute('DELETE', Route()._prefix + route, controller);
  }

  static Route purge(route, controller) {
    return Route()._addRoute('PURGE', Route()._prefix + route, controller);
  }

  static Route patch(route, controller) {
    return Route()._addRoute('PATCH', Route()._prefix + route, controller);
  }

  static Route options(route, controller) {
    return Route()._addRoute('OPTIONS', Route()._prefix + route, controller);
  }

  static Route copy(route, controller) {
    return Route()._addRoute('COPY', Route()._prefix + route, controller);
  }

  static Route view(route, controller) {
    return Route()._addRoute('VIEW', Route()._prefix + route, controller);
  }

  static Route link(route, controller) {
    return Route()._addRoute('LINK', Route()._prefix + route, controller);
  }

  static Route unlink(route, controller) {
    return Route()._addRoute('UNLINK', Route()._prefix + route, controller);
  }

  static Route lock(route, controller) {
    return Route()._addRoute('UNLINK', Route()._prefix + route, controller);
  }

  static Route unlock(route, controller) {
    return Route()._addRoute('UNLOCK', Route()._prefix + route, controller);
  }

  static Route propfind(route, controller) {
    return Route()._addRoute('PROPFIND', Route()._prefix + route, controller);
  }

  static Route resource(route, controller) {
    var prefix = "${Route()._prefix}/$route";

    /// GET /resource
    Route()._addRoute('GET', prefix, controller.index, resourceKey: prefix);

    /// GET /resource/create
    Route()._addRoute('GET', '$prefix/create', controller.create,
        resourceKey: prefix);

    /// POST /resource
    Route()._addRoute('POST', prefix, controller.store, resourceKey: prefix);

    /// GET /resource/{id}
    Route()
        ._addRoute('GET', '$prefix/{id}', controller.show, resourceKey: prefix);

    /// GET /resource/{id}/edit
    Route()._addRoute('GET', '$prefix/{id}/edit', controller.edit,
        resourceKey: prefix);

    /// PUT /resource/{id}
    Route()._addRoute('PUT', '$prefix/{id}', controller.update,
        resourceKey: prefix);

    /// PATCH /resource/{id}
    Route()._addRoute('PATCH', '$prefix/{id}', controller.update,
        resourceKey: prefix);

    /// DELETE /resource/{id}
    Route()._addRoute('DELETE', '$prefix/{id}', controller.destroy,
        resourceKey: prefix);

    Route()._resourceKey = prefix;

    return Route();
  }
}
