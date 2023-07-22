// ignore_for_file: empty_catches

import 'package:dox_core/constants/http_request_method.dart';
import 'package:dox_core/router/route_data.dart';
import 'package:dox_core/utils/utils.dart';
import 'package:dox_core/websocket/dox_websocket.dart';

class Route {
  /// register as singleton
  static final Route _singleton = Route._internal();
  factory Route() => _singleton;
  Route._internal();

  String _prefix = '';
  String? _domain;
  List<dynamic> _preMiddleware = <dynamic>[];

  /// get list of routes registered
  List<RouteData> routes = <RouteData>[];

  /// group route
  /// ```
  /// Route.group('blog', () {
  ///   Route.get('all', controller);
  ///   Route.put('{id}/activate', controller);
  /// });
  /// ```
  static void group(String prefix, Function() callback) {
    String originalPrefix = Route()._prefix;

    /// set new prefix
    Route()._prefix = originalPrefix + prefix;
    callback();

    /// restore original prefix
    Route()._prefix = originalPrefix;
  }

  /// domain route
  /// ```
  /// Route.group('example.com', () {
  ///   Route.get('/ping', controller);
  /// });
  /// ```
  static void domain(String domain, Function() callback) {
    String? originalDomain = Route()._domain;

    /// set new domain
    Route()._domain = domain;
    callback();

    /// restore original domain
    Route()._domain = originalDomain;
  }

  /// middleware for group of routes
  /// ```
  /// Route.group('example.com', () {
  ///   Route.get('/ping', controller);
  /// });
  /// ```
  static void middleware(List<dynamic> middleware, Function() callback) {
    List<dynamic> originalMiddleware = Route()._preMiddleware;

    /// set new middleware
    Route()._preMiddleware = <dynamic>[...originalMiddleware, ...middleware];
    callback();

    /// restore original middleware
    Route()._preMiddleware = originalMiddleware;
  }

  /// set global middleware
  /// this will remove previous middleware and
  /// update new middleware from input
  /// input can be list for single middleware
  /// ```
  /// Route.resetWithNewMiddleware([Middleware()]);
  /// ```
  static void resetWithNewMiddleware(dynamic middleware) {
    List<dynamic> list = <dynamic>[];
    if (middleware is List) {
      list = middleware;
    } else {
      list = <dynamic>[middleware];
    }
    Route()._preMiddleware = list;
  }

  /// add global middleware
  /// ```
  /// Route.use([Middleware()]);
  /// ```
  static void use(dynamic middleware) {
    List<dynamic> list = <dynamic>[];
    if (middleware is List) {
      list = middleware;
    } else {
      list = <dynamic>[middleware];
    }
    Route()._preMiddleware.add(list);
  }

  /// set prefix for the route, this will affect
  /// its below routes
  /// ```
  /// Route.prefix('blog');
  /// ```
  static void prefix(String prefix) {
    Route()._prefix = '$prefix/';
  }

  /// add websocket route
  /// ```
  /// Route.websocket('ws', (socket) {
  ///   socket.on('intro', controller);
  /// });
  /// ```
  static void websocket(String route, Function(DoxWebsocket) callback,
      {List<dynamic> middleware = const <dynamic>[]}) {
    DoxWebsocket ws = DoxWebsocket(route);
    Route()._addRoute(HttpRequestMethod.GET, Route()._prefix + route,
        <dynamic>[...middleware, ws.handle]);
    callback(ws);
  }

  /// get route
  /// ```
  /// Route.get('path', controller);
  /// ```
  static Route get(String route, dynamic controller) {
    return Route()
        ._addRoute(HttpRequestMethod.GET, Route()._prefix + route, controller);
  }

  /// post route
  /// ```
  /// Route.post('path', controller);
  ///
  static Route post(String route, dynamic controller, {Function? request}) {
    return Route()
        ._addRoute(HttpRequestMethod.POST, Route()._prefix + route, controller);
  }

  /// put route
  /// ```
  /// Route.put('path', controller);
  ///
  static Route put(String route, dynamic controller) {
    return Route()
        ._addRoute(HttpRequestMethod.PUT, Route()._prefix + route, controller);
  }

  /// delete route
  /// ```
  /// Route.delete('path', controller);
  ///
  static Route delete(String route, dynamic controller) {
    return Route()._addRoute(
        HttpRequestMethod.DELETE, Route()._prefix + route, controller);
  }

  /// purge route
  /// ```
  /// Route.purge('path', controller);
  ///
  static Route purge(String route, dynamic controller) {
    return Route()._addRoute(
        HttpRequestMethod.PURGE, Route()._prefix + route, controller);
  }

  /// patch route
  /// ```
  /// Route.patch('path', controller);
  ///
  static Route patch(String route, dynamic controller) {
    return Route()._addRoute(
        HttpRequestMethod.PATCH, Route()._prefix + route, controller);
  }

  /// options route
  /// ```
  /// Route.options('path', controller);
  ///
  static Route options(String route, dynamic controller) {
    return Route()._addRoute(
        HttpRequestMethod.OPTIONS, Route()._prefix + route, controller);
  }

  /// copy route
  /// ```
  /// Route.copy('path', controller);
  ///
  static Route copy(String route, dynamic controller) {
    return Route()
        ._addRoute(HttpRequestMethod.COPY, Route()._prefix + route, controller);
  }

  /// view route
  /// ```
  /// Route.view('path', controller);
  ///
  static Route view(String route, dynamic controller) {
    return Route()
        ._addRoute(HttpRequestMethod.VIEW, Route()._prefix + route, controller);
  }

  /// link route
  /// ```
  /// Route.link('path', controller);
  ///
  static Route link(String route, dynamic controller) {
    return Route()
        ._addRoute(HttpRequestMethod.LINK, Route()._prefix + route, controller);
  }

  /// unlink route
  /// ```
  /// Route.unlink('path', controller);
  ///
  static Route unlink(String route, dynamic controller) {
    return Route()._addRoute(
        HttpRequestMethod.UNLINK, Route()._prefix + route, controller);
  }

  /// lock route
  /// ```
  /// Route.lock('path', controller);
  ///
  static Route lock(String route, dynamic controller) {
    return Route()
        ._addRoute(HttpRequestMethod.LOCK, Route()._prefix + route, controller);
  }

  /// unlock route
  /// ```
  /// Route.unlock('path', controller);
  ///
  static Route unlock(String route, dynamic controller) {
    return Route()._addRoute(
        HttpRequestMethod.UNLOCK, Route()._prefix + route, controller);
  }

  /// propfind route
  /// ```
  /// Route.propfind('path', controller);
  ///
  static Route propfind(String route, dynamic controller) {
    return Route()._addRoute(
        HttpRequestMethod.PROPFIND, Route()._prefix + route, controller);
  }

  /// resource route
  /// ```
  /// Route.resource('blog', BlogController());
  ///
  static Route resource(String route, dynamic controller) {
    String prefix = '${Route()._prefix}/$route';

    /// GET /resource
    try {
      Route()._addRoute(HttpRequestMethod.GET, prefix, controller.index);
    } catch (error) {}

    /// GET /resource/create
    try {
      Route()._addRoute(
          HttpRequestMethod.GET, '$prefix/create', controller.create);
    } catch (error) {}

    /// POST /resource
    try {
      Route()._addRoute(HttpRequestMethod.POST, prefix, controller.store);
    } catch (error) {}

    /// GET /resource/{id}
    try {
      Route()._addRoute(HttpRequestMethod.GET, '$prefix/{id}', controller.show);
    } catch (error) {}

    /// GET /resource/{id}/edit
    try {
      Route()._addRoute(
          HttpRequestMethod.GET, '$prefix/{id}/edit', controller.edit);
    } catch (error) {}

    /// PUT /resource/{id}
    try {
      Route()
          ._addRoute(HttpRequestMethod.PUT, '$prefix/{id}', controller.update);
    } catch (error) {}

    /// PATCH /resource/{id}
    try {
      Route()._addRoute(
          HttpRequestMethod.PATCH, '$prefix/{id}', controller.update);
    } catch (error) {}

    /// DELETE /resource/{id}
    try {
      Route()._addRoute(
          HttpRequestMethod.DELETE, '$prefix/{id}', controller.destroy);
    } catch (error) {}

    return Route();
  }

  Route _addRoute(HttpRequestMethod method, String path, dynamic controller) {
    path = sanitizeRoutePath(path);
    List<dynamic> controllers = <dynamic>[];
    controllers.addAll(_preMiddleware);
    if (controller is Function) {
      controllers.add(controller);
    }
    if (controller is List) {
      controllers.addAll(controller);
    }
    routes.add(RouteData(
      method: method.name,
      path: path,
      controllers: controllers,
      domain: _domain,
    ));
    return this;
  }
}
