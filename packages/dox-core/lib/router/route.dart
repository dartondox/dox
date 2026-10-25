import 'dart:async';
import 'dart:io';

import 'package:dox_core/constants/http_request_method.dart';
import 'package:dox_core/dox_core.dart';
import 'package:dox_core/router/route_data.dart';
import 'package:dox_core/storage/storage_file_controller.dart';
import 'package:dox_core/utils/utils.dart';
import 'package:dox_http_native/dox_http_native.dart';

/// list of routes registered
List<RouteData> _routes = <RouteData>[];

/// param name => binder, see [Route.bind]
Map<String, RouteBinding> _bindings = <String, RouteBinding>{};

/// name => route, made on first [Route.url] call
Map<String, RouteData>? _named;
List<RouteData>? _namedFor;
int _namedLength = -1;

/// turns the raw text of a route param into a value, like a model.
/// null means not found: the request gets 404.
typedef RouteBinder<T> = FutureOr<T?> Function(String value);

/// one binder added with [Route.bind]
class RouteBinding {
  const RouteBinding(this.type, this.resolve);

  /// the type name, like `User`. a controller parameter of this type
  /// gets the bound value.
  final String type;
  final RouteBinder<Object> resolve;
}

/// raw handler for every request under a path prefix, see [Route.mount]
typedef RawRequestHandler = Future<void> Function(HttpRequest request);

/// prefix => handler. empty unless something is mounted.
final Map<String, RawRequestHandler> _mounts = <String, RawRequestHandler>{};

/// gets the open socket of a [Route.websocket] request
typedef WebSocketHandler = FutureOr<void> Function(
  WebSocket socket,
  DoxRequest req,
);

/// upgrades the request, then gives the socket to the handler
class _WebSocketRoute {
  _WebSocketRoute(this.handler);

  final WebSocketHandler handler;

  Future<WebSocket> call(DoxRequest req) async {
    if (!NativeWebSocket.isUpgradeRequest(req.httpRequest)) {
      throw BadRequestException(message: 'WebSocket upgrade required');
    }
    WebSocket socket = await NativeWebSocket.upgrade(req.httpRequest);
    await handler(socket, req);
    return socket;
  }
}

class Route {
  /// register as singleton
  static final Route _singleton = Route._internal();
  factory Route() => _singleton;
  Route._internal();

  String _prefix = '';
  String _namePrefix = '';
  String? _domain;

  /// the last added route, for [name]
  RouteData? _last;
  bool? _corsEnabled;

  List<dynamic> _preMiddleware = <dynamic>[];

  /// get list of routes registered
  List<RouteData> get routes => _routes;

  /// raw handlers added with [mount]
  Map<String, RawRequestHandler> get mounts => _mounts;

  /// send every request whose path starts with [prefix] straight to
  /// [handler], before routing, middleware and body reading.
  /// the handler writes and closes the response itself.
  /// Socket.IO uses this for `/socket.io/`.
  /// ```
  /// Route.mount('/socket.io/', io.handle);
  /// ```
  static void mount(String prefix, RawRequestHandler handler) {
    _mounts[prefix] = handler;
  }

  /// remove a handler added with [mount]
  static void unmount(String prefix) {
    _mounts.remove(prefix);
  }

  /// serve files of a storage disk at `GET <path>/<key>`.
  /// with [signed] (default) only URLs from `Storage().signedUrl()` work,
  /// others get 403. set the disk `url` option to the full url of [path].
  /// ```
  /// html, svg, xml and javascript files are always sent as a download in
  /// a sandbox, so an uploaded file can not run script on the app origin.
  /// with [download] every file is sent as a download
  /// (`Content-Disposition: attachment`). use it for user uploads.
  /// ```
  /// Route.files('files'); // GET /files/{key*}
  /// Route.files('uploads', download: true);
  /// String url = await Storage().signedUrl('images/a.png');
  /// ```
  static Route files(
    String path, {
    String? disk,
    bool signed = true,
    bool download = false,
  }) {
    return get(
      '$path/{key*}',
      StorageFileController(disk, signed, download: download).serve,
    );
  }

  /// health check route: `GET <path>` answers 200 `{"status": "ok"}`,
  /// or 503 when one of the [checks] fails. See [HealthCheck].
  /// ```
  /// Route.health('/health', checks: <String, HealthCheckFunction>{
  ///   'database': () => QueryBuilder.query('select 1'),
  ///   'cache': HealthCheck.cache(),
  /// });
  /// ```
  static Route health(
    String path, {
    Map<String, HealthCheckFunction> checks =
        const <String, HealthCheckFunction>{},
    Duration timeout = const Duration(seconds: 5),
  }) {
    return get(path, HealthCheck(checks: checks, timeout: timeout).handle);
  }

  // set route list
  void setRoutes(List<RouteData> routeList) {
    _routes = routeList;
  }

  /// binders added with [bind]
  Map<String, RouteBinding> get bindings => _bindings;

  /// set the binders, eg. in a new isolate
  void setBindings(Map<String, RouteBinding> bindings) {
    _bindings = bindings;
  }

  /// group route. [name] is put in front of the route names inside.
  /// ```
  /// Route.group('blog', () {
  ///   Route.get('all', controller).name('all'); // blog.all
  ///   Route.put('{id}/activate', controller);
  /// }, name: 'blog.');
  /// ```
  static void group(String prefix, Function() callback, {String name = ''}) {
    Route r = Route();
    String originalPrefix = r._prefix;
    String originalName = r._namePrefix;

    /// set new prefix
    r._prefix = '$originalPrefix/$prefix';
    r._namePrefix = '$originalName$name';
    callback();

    /// restore original prefix
    r._prefix = originalPrefix;
    r._namePrefix = originalName;
  }

  /// name the route added last. a group `name:` is put in front.
  /// the same name twice throws a [StateError] at start.
  /// ```
  /// Route.get('users/{id}', controller).name('users.show');
  /// route('users.show', params: <String, Object>{'id': 5}); // /users/5
  /// ```
  Route name(String name) {
    RouteData? last = _last;
    if (last == null) {
      throw StateError('Route.name("$name"): there is no route to name.');
    }
    _setName(last, '$_namePrefix$name');
    return this;
  }

  void _setName(RouteData data, String name) {
    for (RouteData other in _routes) {
      if (other.name == name && !identical(other, data)) {
        throw StateError(
          'Route name "$name" is used twice: ${other.method} ${other.path} '
          'and ${data.method} ${data.path}.',
        );
      }
    }
    data.name = name;
    _named = null;
  }

  /// the path of the route named [name], with its `{params}` filled in.
  /// a param value is url encoded. [query] is added as the query string.
  /// an unknown name or a missing param throws an [ArgumentError].
  /// ```
  /// Route.url('users.show', params: <String, Object>{'id': 5});
  /// // /users/5
  /// ```
  static String url(
    String name, {
    Map<String, Object?> params = const <String, Object?>{},
    Map<String, Object?> query = const <String, Object?>{},
  }) {
    RouteData? data = Route()._byName()[name];
    if (data == null) {
      throw ArgumentError.value(name, 'name', 'No route has this name');
    }
    Set<String> used = <String>{};
    List<String> parts = <String>[];
    for (String part in data.path.split('/')) {
      if (!part.startsWith('{') || !part.endsWith('}')) {
        parts.add(part);
        continue;
      }
      bool rest = part.endsWith('*}');
      bool optional = part.endsWith('?}');
      String param = part
          .substring(1, part.length - 1)
          .replaceAll('*', '')
          .replaceAll('?', '');
      Object? value = params[param];
      used.add(param);
      if (value == null) {
        if (optional) continue;
        throw ArgumentError(
          'Route "$name" (${data.path}) needs the param "$param".',
        );
      }
      parts.add(
        rest
            ? '$value'.split('/').map(Uri.encodeComponent).join('/')
            : Uri.encodeComponent('$value'),
      );
    }
    for (String key in params.keys) {
      if (!used.contains(key)) {
        throw ArgumentError(
          'Route "$name" (${data.path}) has no param "$key". '
          'Use query: for the query string.',
        );
      }
    }
    String path = parts.join('/');
    if (path.isEmpty) path = '/';
    if (query.isEmpty) return path;
    Map<String, String> values = <String, String>{
      for (MapEntry<String, Object?> entry in query.entries)
        if (entry.value != null) entry.key: '${entry.value}',
    };
    if (values.isEmpty) return path;
    return '$path?${Uri(queryParameters: values).query}';
  }

  Map<String, RouteData> _byName() {
    Map<String, RouteData>? named = _named;
    if (named != null &&
        identical(_namedFor, _routes) &&
        _namedLength == _routes.length) {
      return named;
    }
    named = <String, RouteData>{
      for (RouteData data in _routes)
        if (data.name != null) data.name!: data,
    };
    _named = named;
    _namedFor = _routes;
    _namedLength = _routes.length;
    return named;
  }

  /// turn the route param [param] into a value before the controller
  /// runs. [resolve] gets the raw text and gives the value, or null
  /// when there is none: then the request gets 404.
  /// read it with `req.bound<T>(param)`, or add a controller parameter
  /// of type [T]. call it before the server starts.
  /// ```
  /// Route.bind<User>('user', (String id) => User().find(id));
  /// Route.get('users/{user}', (DoxRequest req, User user) => user);
  /// ```
  // ponytail: explicit binders only. binding by type alone needs a
  // generated IoC, add it with that.
  static void bind<T extends Object>(String param, RouteBinder<T> resolve) {
    _bindings[param] = RouteBinding(T.toString(), resolve);
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

  /// group of route to enabled cors
  /// ```
  /// Route.enabledCors(() {
  ///   Route.get('/ping', controller);
  /// });
  /// ```
  static void enabledCors(Function() callback) {
    _cors(true, callback);
  }

  // group of route to disabled cors
  /// ```
  /// Route.disabledCors() {
  ///   Route.get('/ping', controller);
  /// });
  /// ```
  static void disabledCors(Function() callback) {
    _cors(false, callback);
  }

  /// group of route to enable/disable cors
  /// ```
  /// Route.cors(true, () {
  ///   Route.get('/ping', controller);
  /// });
  /// ```
  static void _cors(bool enabled, Function() callback) {
    bool? originalCorsConfig = Route()._corsEnabled;

    /// set new domain
    Route()._corsEnabled = enabled;
    callback();

    /// restore original domain
    Route()._corsEnabled = originalCorsConfig;
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
  static void resetWithNewMiddleware(List<dynamic> middleware) {
    Route()._preMiddleware = middleware;
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
    Route()._preMiddleware.addAll(list);
  }

  /// set prefix for the route, this will affect
  /// its below routes
  /// ```
  /// Route.prefix('blog');
  /// ```
  static void prefix(String prefix) {
    Route()._prefix = prefix;
  }

  /// join the prefix and [path] with one `/`.
  /// `_addRoute` cleans double and edge slashes later.
  String _join(String path) => '$_prefix/$path';

  /// raw WebSocket route. [handler] gets the open socket.
  /// Middleware runs first, so it can check auth.
  /// For rooms, acks and the socket.io clients, use `dox_socketio`.
  /// ```
  /// Route.websocket('echo', (WebSocket socket, DoxRequest req) {
  ///   socket.listen(socket.add);
  /// });
  /// ```
  static Route websocket(
    String route,
    WebSocketHandler handler, {
    List<dynamic> middleware = const <dynamic>[],
  }) {
    return Route()._addRoute(
      HttpRequestMethod.GET,
      Route()._join(route),
      <dynamic>[...middleware, _WebSocketRoute(handler).call],
    );
  }

  /// get route
  /// ```
  /// Route.get('path', controller);
  /// ```
  static Route get(String route, dynamic controller) {
    return Route()._addRoute(
      HttpRequestMethod.GET,
      Route()._join(route),
      controller,
    );
  }

  /// post route
  /// ```
  /// Route.post('path', controller);
  ///
  /// [body] is the request body schema for the OpenAPI docs
  /// (eg. a `dox_validation` schema).
  static Route post(String route, dynamic controller, {Object? body}) {
    return Route()._addRoute(
      HttpRequestMethod.POST,
      Route()._join(route),
      controller,
      body: body,
    );
  }

  /// put route
  /// ```
  /// Route.put('path', controller);
  ///
  static Route put(String route, dynamic controller, {Object? body}) {
    return Route()._addRoute(
      HttpRequestMethod.PUT,
      Route()._join(route),
      controller,
      body: body,
    );
  }

  /// delete route
  /// ```
  /// Route.delete('path', controller);
  ///
  static Route delete(String route, dynamic controller) {
    return Route()._addRoute(
      HttpRequestMethod.DELETE,
      Route()._join(route),
      controller,
    );
  }

  /// purge route
  /// ```
  /// Route.purge('path', controller);
  ///
  static Route purge(String route, dynamic controller) {
    return Route()._addRoute(
      HttpRequestMethod.PURGE,
      Route()._join(route),
      controller,
    );
  }

  /// patch route
  /// ```
  /// Route.patch('path', controller);
  ///
  static Route patch(String route, dynamic controller, {Object? body}) {
    return Route()._addRoute(
      HttpRequestMethod.PATCH,
      Route()._join(route),
      controller,
      body: body,
    );
  }

  /// options route
  /// ```
  /// Route.options('path', controller);
  ///
  static Route options(String route, dynamic controller) {
    return Route()._addRoute(
      HttpRequestMethod.OPTIONS,
      Route()._join(route),
      controller,
    );
  }

  /// copy route
  /// ```
  /// Route.copy('path', controller);
  ///
  static Route copy(String route, dynamic controller) {
    return Route()._addRoute(
      HttpRequestMethod.COPY,
      Route()._join(route),
      controller,
    );
  }

  /// view route
  /// ```
  /// Route.view('path', controller);
  ///
  static Route view(String route, dynamic controller) {
    return Route()._addRoute(
      HttpRequestMethod.VIEW,
      Route()._join(route),
      controller,
    );
  }

  /// link route
  /// ```
  /// Route.link('path', controller);
  ///
  static Route link(String route, dynamic controller) {
    return Route()._addRoute(
      HttpRequestMethod.LINK,
      Route()._join(route),
      controller,
    );
  }

  /// unlink route
  /// ```
  /// Route.unlink('path', controller);
  ///
  static Route unlink(String route, dynamic controller) {
    return Route()._addRoute(
      HttpRequestMethod.UNLINK,
      Route()._join(route),
      controller,
    );
  }

  /// lock route
  /// ```
  /// Route.lock('path', controller);
  ///
  static Route lock(String route, dynamic controller) {
    return Route()._addRoute(
      HttpRequestMethod.LOCK,
      Route()._join(route),
      controller,
    );
  }

  /// unlock route
  /// ```
  /// Route.unlock('path', controller);
  ///
  static Route unlock(String route, dynamic controller) {
    return Route()._addRoute(
      HttpRequestMethod.UNLOCK,
      Route()._join(route),
      controller,
    );
  }

  /// propfind route
  /// ```
  /// Route.propfind('path', controller);
  ///
  static Route propfind(String route, dynamic controller) {
    return Route()._addRoute(
      HttpRequestMethod.PROPFIND,
      Route()._join(route),
      controller,
    );
  }

  /// resource route
  /// ```
  /// Route.resource('blog', BlogController());
  /// ```
  /// the routes are named `blog.index`, `blog.create`, `blog.store`,
  /// `blog.show`, `blog.edit`, `blog.update` and `blog.destroy`.
  /// the name is the path with `.` for `/`, without `{params}`.
  /// set [name] to use another one. a group `name:` is put in front.
  /// ```
  /// Route.resource('blog', BlogController());
  /// ```
  static Route resource(String route, dynamic controller, {String? name}) {
    Route r = Route();
    String path = r._join(route);
    String base = name ?? route.split('/').where(_isNamePart).join('.');
    r._resourceRoute(
      HttpRequestMethod.GET,
      path,
      () => controller.index,
      '$base.index',
    );
    r._resourceRoute(
      HttpRequestMethod.GET,
      '$path/create',
      () => controller.create,
      '$base.create',
    );
    r._resourceRoute(
      HttpRequestMethod.POST,
      path,
      () => controller.store,
      '$base.store',
    );
    r._resourceRoute(
      HttpRequestMethod.GET,
      '$path/{id}',
      () => controller.show,
      '$base.show',
    );
    r._resourceRoute(
      HttpRequestMethod.GET,
      '$path/{id}/edit',
      () => controller.edit,
      '$base.edit',
    );
    r._resourceRoute(
      HttpRequestMethod.PUT,
      '$path/{id}',
      () => controller.update,
      '$base.update',
    );
    r._resourceRoute(
      HttpRequestMethod.PATCH,
      '$path/{id}',
      () => controller.update,
      null,
    );
    r._resourceRoute(
      HttpRequestMethod.DELETE,
      '$path/{id}',
      () => controller.destroy,
      '$base.destroy',
    );
    return r;
  }

  static bool _isNamePart(String part) {
    return part.isNotEmpty && !part.startsWith('{');
  }

  /// add one route of [resource]. a controller without this method
  /// (eg. no `store`) gets no route. any other error is not caught.
  void _resourceRoute(
    HttpRequestMethod method,
    String path,
    dynamic Function() readAction,
    String? name,
  ) {
    dynamic action;
    try {
      action = readAction();
    } on NoSuchMethodError {
      return;
    }
    _addRoute(method, path, action);
    if (name != null) _setName(_last!, '$_namePrefix$name');
  }

  Route _addRoute(
    HttpRequestMethod method,
    String path,
    dynamic controller, {
    Object? body,
  }) {
    path = sanitizeRoutePath(path);
    List<dynamic> controllers = <dynamic>[];
    controllers.addAll(_preMiddleware);
    if (controller is Function) {
      controllers.add(controller);
    }
    if (controller is List) {
      controllers.addAll(controller);
    }
    RouteData data = RouteData(
      method: method.name,
      path: path,
      controllers: controllers,
      domain: _domain,
      corsEnabled: _corsEnabled,
      preMiddleware: List<dynamic>.unmodifiable(_preMiddleware),
      body: body,
    );
    _routes.add(data);
    _last = data;
    return this;
  }
}

/// the path of the route named [name], see [Route.url].
/// ```
/// route('users.show', params: <String, Object>{'id': 5}); // /users/5
/// ```
String route(
  String name, {
  Map<String, Object?> params = const <String, Object?>{},
  Map<String, Object?> query = const <String, Object?>{},
}) {
  return Route.url(name, params: params, query: query);
}
