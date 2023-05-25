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

  _addRoute(method, String route, controller, {FormRequest? request}) {
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
      formRequest: request,
    ));
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

  static resource(route, controller, {FormRequest? request}) {
    route = "/$route";

    /// GET /resource
    Route()._addRoute('GET', Route()._prefix + route, controller.index,
        request: request);

    /// GET /resource/create
    Route()._addRoute(
        'GET', '${Route()._prefix + route}/create', controller.create,
        request: request);

    /// POST /resource
    Route()._addRoute('POST', Route()._prefix + route, controller.store,
        request: request);

    /// GET /resource/{id}
    Route()._addRoute('GET', '${Route()._prefix + route}/{id}', controller.show,
        request: request);

    /// GET /resource/{id}/edit
    Route()._addRoute(
        'GET', '${Route()._prefix + route}/{id}/edit', controller.edit,
        request: request);

    /// PUT /resource/{id}
    Route()._addRoute(
        'PUT', '${Route()._prefix + route}/{id}', controller.update,
        request: request);

    /// PATCH /resource/{id}
    Route()._addRoute(
        'PATCH', '${Route()._prefix + route}/{id}', controller.update,
        request: request);

    /// DELETE /resource/{id}
    Route()._addRoute(
        'DELETE', '${Route()._prefix + route}/{id}', controller.destroy,
        request: request);
  }

  static websocket({
    required DoxWebsocket websocket,
    String route = 'ws',
    List middleware = const [],
  }) {
    Route()._addRoute('GET', route, [...middleware, websocket.handle]);
  }

  static get(route, controller, {FormRequest? request}) {
    Route()._addRoute('GET', Route()._prefix + route, controller,
        request: request);
  }

  static post(route, controller, {FormRequest? request}) {
    Route()._addRoute('POST', Route()._prefix + route, controller,
        request: request);
  }

  static put(route, controller, {FormRequest? request}) {
    Route()._addRoute('PUT', Route()._prefix + route, controller,
        request: request);
  }

  static delete(route, controller, {FormRequest? request}) {
    Route()._addRoute('DELETE', Route()._prefix + route, controller,
        request: request);
  }

  static purge(route, controller, {FormRequest? request}) {
    Route()._addRoute('PURGE', Route()._prefix + route, controller,
        request: request);
  }

  static patch(route, controller, {FormRequest? request}) {
    Route()._addRoute('PATCH', Route()._prefix + route, controller,
        request: request);
  }

  static options(route, controller, {FormRequest? request}) {
    Route()._addRoute('OPTIONS', Route()._prefix + route, controller,
        request: request);
  }

  static copy(route, controller, {FormRequest? request}) {
    Route()._addRoute('COPY', Route()._prefix + route, controller,
        request: request);
  }

  static view(route, controller, {FormRequest? request}) {
    Route()._addRoute('VIEW', Route()._prefix + route, controller,
        request: request);
  }

  static link(route, controller, {FormRequest? request}) {
    Route()._addRoute('LINK', Route()._prefix + route, controller,
        request: request);
  }

  static unlink(route, controller, {FormRequest? request}) {
    Route()._addRoute('UNLINK', Route()._prefix + route, controller,
        request: request);
  }

  static lock(route, controller, {FormRequest? request}) {
    Route()._addRoute('UNLINK', Route()._prefix + route, controller,
        request: request);
  }

  static unlock(route, controller, {FormRequest? request}) {
    Route()._addRoute('UNLOCK', Route()._prefix + route, controller,
        request: request);
  }

  static propfind(route, controller, {FormRequest? request}) {
    Route()._addRoute('PROPFIND', Route()._prefix + route, controller,
        request: request);
  }
}
