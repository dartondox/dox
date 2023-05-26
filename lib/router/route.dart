import 'package:dox_core/dox_core.dart';

class Route {
  /// Singleton
  static final Route _singleton = Route._internal();
  factory Route() => _singleton;
  Route._internal();

  String _prefix = '';

  List _preMiddleware = [];

  List<RouteData> routes = [];

  bool resourceAdded = false;

  formRequest(FormRequest Function() formRequest) {
    if (resourceAdded) {
      List<RouteData> resourceRoutes = routes.sublist(routes.length - 8);
      for (RouteData r in resourceRoutes) {
        r.formRequest = formRequest;
      }
    } else {
      RouteData latestRoute = routes.last;
      latestRoute.formRequest = formRequest;
    }
  }

  static sanitizeRoutePath(String path) {
    path = path.replaceAll(RegExp(r'/+'), '/');
    return "/${path.replaceAll(RegExp('^\\/+|\\/+\$'), '')}";
  }

  Route _addRoute(method, String route, controller) {
    Route().resourceAdded = false;
    route = Route.sanitizeRoutePath(route);
    List controllers = [];
    controllers.addAll(_preMiddleware);
    if (controller is Function) {
      controllers.add(controller);
    }
    if (controller is List) {
      controllers.addAll(controller);
    }
    routes.add(RouteData(
      method,
      route,
      controllers,
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
    route = "/$route";

    /// GET /resource
    Route()._addRoute('GET', Route()._prefix + route, controller.index);

    /// GET /resource/create
    Route()._addRoute(
        'GET', '${Route()._prefix + route}/create', controller.create);

    /// POST /resource
    Route()._addRoute('POST', Route()._prefix + route, controller.store);

    /// GET /resource/{id}
    Route()
        ._addRoute('GET', '${Route()._prefix + route}/{id}', controller.show);

    /// GET /resource/{id}/edit
    Route()._addRoute(
        'GET', '${Route()._prefix + route}/{id}/edit', controller.edit);

    /// PUT /resource/{id}
    Route()
        ._addRoute('PUT', '${Route()._prefix + route}/{id}', controller.update);

    /// PATCH /resource/{id}
    Route()._addRoute(
        'PATCH', '${Route()._prefix + route}/{id}', controller.update);

    /// DELETE /resource/{id}
    Route()._addRoute(
        'DELETE', '${Route()._prefix + route}/{id}', controller.destroy);

    Route().resourceAdded = true;

    return Route();
  }
}
