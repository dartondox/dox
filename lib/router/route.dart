import 'package:dox_core/dox_core.dart';

class Route {
  /// Singleton
  static final Route _singleton = Route._internal();
  factory Route() => _singleton;
  Route._internal();

  String _prefix = '';

  List<RouteData> routes = [];

  static sanitizeRoutePath(String path) {
    path = path.replaceAll(RegExp(r'/+'), '/');
    return "/${path.replaceAll(RegExp('^\\/+|\\/+\$'), '')}";
  }

  addRoute(method, String route, controller) {
    route = Route.sanitizeRoutePath(route);
    routes.add(RouteData(method, route, controller));
  }

  static group(prefix, Function(SubRoute) callback) {
    callback(SubRoute(prefix));
  }

  static prefix(prefix) {
    Route()._prefix = prefix;
  }

  static resource(route, controller) {
    /// GET /resource
    Route().addRoute('GET', Route()._prefix + route, controller.index);

    /// GET /resource/create
    Route().addRoute(
        'GET', '${Route()._prefix + route}/create', controller.create);

    /// POST /resource
    Route().addRoute('POST', Route()._prefix + route, controller.store);

    /// GET /resource/{id}
    Route().addRoute('GET', '${Route()._prefix + route}/{id}', controller.show);

    /// GET /resource/{id}/edit
    Route().addRoute(
        'GET', '${Route()._prefix + route}/{id}/edit', controller.edit);

    /// PUT /resource/{id}
    Route()
        .addRoute('PUT', '${Route()._prefix + route}/{id}', controller.update);

    /// PATCH /resource/{id}
    Route().addRoute(
        'PATCH', '${Route()._prefix + route}/{id}', controller.update);

    /// DELETE /resource/{id}
    Route().addRoute(
        'DELETE', '${Route()._prefix + route}/{id}', controller.destroy);
  }

  static websocket({
    required DoxWebsocket websocket,
    String route = 'ws',
    List middleware = const [],
  }) {
    Route().addRoute('GET', route, [...middleware, websocket.handle]);
  }

  static get(route, controller) {
    Route().addRoute('GET', Route()._prefix + route, controller);
  }

  static post(route, controller) {
    Route().addRoute('POST', Route()._prefix + route, controller);
  }

  static put(route, controller) {
    Route().addRoute('PUT', Route()._prefix + route, controller);
  }

  static delete(route, controller) {
    Route().addRoute('DELETE', Route()._prefix + route, controller);
  }

  static purge(route, controller) {
    Route().addRoute('PURGE', Route()._prefix + route, controller);
  }

  static patch(route, controller) {
    Route().addRoute('PATCH', Route()._prefix + route, controller);
  }

  static options(route, controller) {
    Route().addRoute('OPTIONS', Route()._prefix + route, controller);
  }

  static copy(route, controller) {
    Route().addRoute('COPY', Route()._prefix + route, controller);
  }

  static view(route, controller) {
    Route().addRoute('VIEW', Route()._prefix + route, controller);
  }

  static link(route, controller) {
    Route().addRoute('LINK', Route()._prefix + route, controller);
  }

  static unlink(route, controller) {
    Route().addRoute('UNLINK', Route()._prefix + route, controller);
  }

  static lock(route, controller) {
    Route().addRoute('UNLINK', Route()._prefix + route, controller);
  }

  static unlock(route, controller) {
    Route().addRoute('UNLOCK', Route()._prefix + route, controller);
  }

  static propfind(route, controller) {
    Route().addRoute('PROPFIND', Route()._prefix + route, controller);
  }
}
