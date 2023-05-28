import 'package:dox_core/router/route_data.dart';
import 'package:dox_core/utils/utils.dart';
import 'package:dox_core/websocket/dox_websocket.dart';

class Route {
  /// Singleton
  static final Route _singleton = Route._internal();
  factory Route() => _singleton;
  Route._internal();

  String _prefix = '';
  String? _domain;
  List _preMiddleware = [];
  String? _resourceKey;

  /// get list of routes registered
  List<RouteData> routes = [];

  /// group route
  /// ```
  /// Route.group('blog', (route) {
  ///   route.get('all', controller);
  ///   route.put('{id}/activate', controller);
  /// });
  /// ```
  static group(prefix, Function() callback) {
    var originalPrefix = Route()._prefix;

    /// set new prefix
    Route()._prefix = originalPrefix + prefix;
    callback();

    /// restore original prefix
    Route()._prefix = originalPrefix;
  }

  static domain(domain, Function() callback) {
    var originalDomain = Route()._domain;

    /// set new domain
    Route()._domain = domain;
    callback();

    /// restore original domain
    Route()._domain = originalDomain;
  }

  /// add global middleware
  /// ```
  /// Route.use([Middleware()]);
  /// ```
  static use(List middleware) {
    Route()._preMiddleware = middleware;
  }

  /// set prefix for the route, this will affect
  /// its below routes
  /// ```
  /// Route.prefix('blog');
  /// ```
  static prefix(prefix) {
    Route()._prefix = prefix;
  }

  /// add websocket route
  /// ```
  /// Route.websocket('ws', (socket) {
  ///   socket.on('intro', controller);
  /// });
  /// ```
  static websocket(String route, Function(DoxWebsocket) callback,
      {List middleware = const []}) {
    var ws = DoxWebsocket(route);
    Route()
        ._addRoute('GET', Route()._prefix + route, [...middleware, ws.handle]);
    callback(ws);
  }

  /// get route
  /// ```
  /// Route.get('path', controller);
  /// ```
  static Route get(route, controller) {
    return Route()._addRoute('GET', Route()._prefix + route, controller);
  }

  /// post route
  /// ```
  /// Route.post('path', controller);
  ///
  static Route post(route, controller, {Function? request}) {
    return Route()._addRoute('POST', Route()._prefix + route, controller);
  }

  /// put route
  /// ```
  /// Route.put('path', controller);
  ///
  static Route put(route, controller) {
    return Route()._addRoute('PUT', Route()._prefix + route, controller);
  }

  /// delete route
  /// ```
  /// Route.delete('path', controller);
  ///
  static Route delete(route, controller) {
    return Route()._addRoute('DELETE', Route()._prefix + route, controller);
  }

  /// purge route
  /// ```
  /// Route.purge('path', controller);
  ///
  static Route purge(route, controller) {
    return Route()._addRoute('PURGE', Route()._prefix + route, controller);
  }

  /// patch route
  /// ```
  /// Route.patch('path', controller);
  ///
  static Route patch(route, controller) {
    return Route()._addRoute('PATCH', Route()._prefix + route, controller);
  }

  /// options route
  /// ```
  /// Route.options('path', controller);
  ///
  static Route options(route, controller) {
    return Route()._addRoute('OPTIONS', Route()._prefix + route, controller);
  }

  /// copy route
  /// ```
  /// Route.copy('path', controller);
  ///
  static Route copy(route, controller) {
    return Route()._addRoute('COPY', Route()._prefix + route, controller);
  }

  /// view route
  /// ```
  /// Route.view('path', controller);
  ///
  static Route view(route, controller) {
    return Route()._addRoute('VIEW', Route()._prefix + route, controller);
  }

  /// link route
  /// ```
  /// Route.link('path', controller);
  ///
  static Route link(route, controller) {
    return Route()._addRoute('LINK', Route()._prefix + route, controller);
  }

  /// unlink route
  /// ```
  /// Route.unlink('path', controller);
  ///
  static Route unlink(route, controller) {
    return Route()._addRoute('UNLINK', Route()._prefix + route, controller);
  }

  /// lock route
  /// ```
  /// Route.lock('path', controller);
  ///
  static Route lock(route, controller) {
    return Route()._addRoute('UNLINK', Route()._prefix + route, controller);
  }

  /// unlock route
  /// ```
  /// Route.unlock('path', controller);
  ///
  static Route unlock(route, controller) {
    return Route()._addRoute('UNLOCK', Route()._prefix + route, controller);
  }

  /// propfind route
  /// ```
  /// Route.propfind('path', controller);
  ///
  static Route propfind(route, controller) {
    return Route()._addRoute('PROPFIND', Route()._prefix + route, controller);
  }

  /// resource route
  /// ```
  /// Route.resource('blog', BlogController());
  ///
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

  List<RouteData> _getRecentlyAddedRoutes() {
    if (_resourceKey != null) {
      return routes.where((r) => r.resourceKey == _resourceKey).toList();
    } else {
      return [routes.last];
    }
  }

  Route _addRoute(method, String path, controller, {String? resourceKey}) {
    Route()._resourceKey = null;
    path = sanitizeRoutePath(path);
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
      domain: _domain,
    ));
    return this;
  }
}
