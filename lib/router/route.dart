import 'package:dox_core/dox_core.dart';

class Route {
  /// Singleton
  static final Route _singleton = Route._internal();
  factory Route() => _singleton;
  Route._internal();

  String _prefix = '';

  List _preMiddleware = [];

  List<RouteData> routes = [];

  static sanitizeRoutePath(String path) {
    path = path.replaceAll(RegExp(r'/+'), '/');
    return "/${path.replaceAll(RegExp('^\\/+|\\/+\$'), '')}";
  }

  _addRoute(method, String route, controller) {
    route = Route.sanitizeRoutePath(route);
    List controllers = [];
    controllers.addAll(_preMiddleware);
    if (controller is Function) {
      controllers.add(controller);
    }
    if (controller is List) {
      controllers.addAll(controller);
    }
    routes.add(RouteData(method, route, controllers));
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

  static resource(route, controller) {
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
  }

  static websocket({
    required DoxWebsocket websocket,
    String route = 'ws',
    List middleware = const [],
  }) {
    Route()._addRoute('GET', route, [...middleware, websocket.handle]);
  }

  static get(route, controller) {
    Route()._addRoute('GET', Route()._prefix + route, controller);
  }

  static post(route, controller) {
    Route()._addRoute('POST', Route()._prefix + route, controller);
  }

  static put(route, controller) {
    Route()._addRoute('PUT', Route()._prefix + route, controller);
  }

  static delete(route, controller) {
    Route()._addRoute('DELETE', Route()._prefix + route, controller);
  }

  static purge(route, controller) {
    Route()._addRoute('PURGE', Route()._prefix + route, controller);
  }

  static patch(route, controller) {
    Route()._addRoute('PATCH', Route()._prefix + route, controller);
  }

  static options(route, controller) {
    Route()._addRoute('OPTIONS', Route()._prefix + route, controller);
  }

  static copy(route, controller) {
    Route()._addRoute('COPY', Route()._prefix + route, controller);
  }

  static view(route, controller) {
    Route()._addRoute('VIEW', Route()._prefix + route, controller);
  }

  static link(route, controller) {
    Route()._addRoute('LINK', Route()._prefix + route, controller);
  }

  static unlink(route, controller) {
    Route()._addRoute('UNLINK', Route()._prefix + route, controller);
  }

  static lock(route, controller) {
    Route()._addRoute('UNLINK', Route()._prefix + route, controller);
  }

  static unlock(route, controller) {
    Route()._addRoute('UNLOCK', Route()._prefix + route, controller);
  }

  static propfind(route, controller) {
    Route()._addRoute('PROPFIND', Route()._prefix + route, controller);
  }
}
