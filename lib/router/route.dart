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

  addRoute(method, String route, controllers) {
    route = Route.sanitizeRoutePath(route);
    routes.add(RouteData(method, route, controllers));
  }

  static group(prefix, Function(SubRoute) callback) {
    callback(SubRoute(prefix));
  }

  static prefix(prefix) {
    Route()._prefix = prefix;
  }

  static get(route, controllers) {
    Route().addRoute('GET', Route()._prefix + route, controllers);
  }

  static post(route, controllers) {
    Route().addRoute('POST', Route()._prefix + route, controllers);
  }

  static put(route, controllers) {
    Route().addRoute('PUT', Route()._prefix + route, controllers);
  }

  static delete(route, controllers) {
    Route().addRoute('DELETE', Route()._prefix + route, controllers);
  }

  static purge(route, controllers) {
    Route().addRoute('PURGE', Route()._prefix + route, controllers);
  }

  static patch(route, controllers) {
    Route().addRoute('PATCH', Route()._prefix + route, controllers);
  }

  static options(route, controllers) {
    Route().addRoute('OPTIONS', Route()._prefix + route, controllers);
  }

  static copy(route, controllers) {
    Route().addRoute('COPY', Route()._prefix + route, controllers);
  }

  static view(route, controllers) {
    Route().addRoute('VIEW', Route()._prefix + route, controllers);
  }

  static link(route, controllers) {
    Route().addRoute('LINK', Route()._prefix + route, controllers);
  }

  static unlink(route, controllers) {
    Route().addRoute('UNLINK', Route()._prefix + route, controllers);
  }

  static lock(route, controllers) {
    Route().addRoute('UNLINK', Route()._prefix + route, controllers);
  }

  static unlock(route, controllers) {
    Route().addRoute('UNLOCK', Route()._prefix + route, controllers);
  }

  static propfind(route, controllers) {
    Route().addRoute('PROPFIND', Route()._prefix + route, controllers);
  }
}
