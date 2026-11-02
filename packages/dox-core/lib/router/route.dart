import 'dart:async';
import 'dart:io';

import 'package:dox_core/constants/http_request_method.dart';
import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/http_static_handler.dart';
import 'package:dox_core/router/route_data.dart';
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

/// prefixes of the mounts added with `middleware: true`
final Set<String> _mountsWithMiddleware = <String>{};

/// folders added with [Route.staticFiles]. empty unless one is added.
final List<StaticFolder> _statics = <StaticFolder>[];

/// routes added with [Route.fallback]. empty unless one is added.
List<RouteData> _fallbacks = <RouteData>[];

/// gets the open socket of a [Route.websocket] request
typedef WebSocketHandler = FutureOr<void> Function(
  WebSocket socket,
  DoxRequest req,
);

/// upgrades the request, then gives the socket to the handler
class _WebSocketRoute {
  _WebSocketRoute(this.handler, this.allowedOrigins, this.maxMessageSize);

  final WebSocketHandler handler;

  /// null: no origin check, unless `AppConfig.webSocketAllowedOrigins`
  /// is set.
  final List<String>? allowedOrigins;

  /// a bigger message or frame closes the socket with 1009
  final int maxMessageSize;

  Future<WebSocket> call(DoxRequest req) async {
    if (!NativeWebSocket.isUpgradeRequest(req.httpRequest)) {
      throw BadRequestException(message: 'WebSocket upgrade required');
    }
    List<String>? allowedOrigins =
        this.allowedOrigins ?? Dox().config.webSocketAllowedOrigins;
    if (allowedOrigins != null &&
        !webSocketOriginAllowed(
          req.origin(),
          req.header(HttpHeaders.hostHeader),
          allowedOrigins,
        )) {
      throw ForbiddenHttpException(message: 'WebSocket origin not allowed');
    }
    WebSocket socket = await NativeWebSocket.upgrade(
      req.httpRequest,
      maxMessageSize: maxMessageSize,
    );
    await handler(socket, req);
    return socket;
  }
}

/// [Route.websocket] routes that check no origin. Read at start for
/// the warning, see [Route.hasWebSocketWithoutOriginCheck].
final Expando<bool> _noOriginCheck = Expando<bool>();

/// true when a WebSocket upgrade with this [origin] may open.
///
/// A browser always sends `Origin` on a WebSocket upgrade, and it sends
/// the cookies of the app too. So without this check any site could open
/// a socket as the logged in user (cross-site WebSocket hijacking).
///
/// - no `Origin` header: allowed. This is not a browser.
/// - the origin host and port are the same as the `Host` header: allowed.
/// - the origin is in [allowedOrigins] (like `https://app.example.com`),
///   or the list has `*`: allowed.
/// - anything else: not allowed.
bool webSocketOriginAllowed(
  String? origin,
  String? host,
  List<String> allowedOrigins,
) {
  if (origin == null) return true;
  if (allowedOrigins.contains('*')) return true;
  String clean = _cleanOrigin(origin);
  for (String allowed in allowedOrigins) {
    if (_cleanOrigin(allowed) == clean) return true;
  }
  if (host == null || host.isEmpty) return false;
  Uri? originUri = Uri.tryParse(origin.trim());
  if (originUri == null || originUri.host.isEmpty) return false;
  Uri? hostUri = Uri.tryParse('${originUri.scheme}://${host.trim()}');
  if (hostUri == null) return false;
  return originUri.host.toLowerCase() == hostUri.host.toLowerCase() &&
      originUri.port == hostUri.port;
}

/// `HTTPS://App.com/` and `https://app.com` are the same origin
String _cleanOrigin(String origin) {
  String o = origin.trim().toLowerCase();
  while (o.endsWith('/')) {
    o = o.substring(0, o.length - 1);
  }
  return o;
}

/// A route action that points to a method of a controller from the
/// container. The controller is made once per isolate, at start.
/// ```
/// Route.get<UserController>('users', (UserController c) => c.index);
/// ```
class ControllerAction<T extends Object> {
  const ControllerAction(this.select);

  /// gets the controller, gives the method that handles the request
  final Function select;

  /// The controller class, used by the OpenAPI docs.
  Type get controller => T;

  /// the controller method, with the controller from [ioc]
  Function resolve(IocContainer ioc, String where) {
    Object? method;
    try {
      method = (select as dynamic)(ioc.get<T>());
    } on NoSuchMethodError {
      method = null;
    }
    if (method is! Function) {
      throw StateError(
        'Route $where: the action of Route.<method><$T> must take the '
        'controller and give one of its methods, like '
        '($T c) => c.index.',
      );
    }
    return method;
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

  /// all routes of the last [match], [any] or [redirect] call, for
  /// [where] and [timeout]. null when only [_last] was added.
  List<RouteData>? _lastGroup;
  bool? _corsEnabled;

  List<dynamic> _preMiddleware = <dynamic>[];

  /// get list of routes registered
  List<RouteData> get routes => _routes;

  /// raw handlers added with [mount]
  Map<String, RawRequestHandler> get mounts => _mounts;

  /// send every request under [prefix] straight to [handler], before
  /// routing and body reading. the handler writes and closes the
  /// response itself. Socket.IO uses this for `/socket.io/`.
  ///
  /// The prefix matches whole path parts. `/admin` and `/admin/` both
  /// match `/admin`, `/admin/` and `/admin/users`, never `/administrator`.
  /// The query string is not part of the match.
  ///
  /// By default no middleware runs, also no global middleware (security
  /// headers, CSRF, rate limit). With [middleware] set to true, the
  /// `AppConfig.globalMiddleware` runs first. A middleware that gives a
  /// response stops the request before [handler]. The body is not read
  /// for the middleware, so the handler can still read it. A `terminate`
  /// step runs once the answer is sent. The global CORS config does not
  /// apply to a mount. `RequestTimeout` does not run for a mount: the
  /// handler already owns the answer. Cookies that a middleware adds
  /// after the handler (the session cookie, `XSRF-TOKEN`) are not sent.
  /// Get the CSRF token from a normal route.
  ///
  /// When two prefixes match, the longest one wins. `//` counts as one
  /// `/`. The match uses the raw path, so `/admin/secure%2Fx` goes to a
  /// mount at `/admin`. To protect a nested path, set [middleware] on the
  /// outer mount too.
  /// ```
  /// Route.mount('/socket.io/', io.handle);
  /// Route.mount('/admin', admin.handle, middleware: true);
  /// ```
  static void mount(
    String prefix,
    RawRequestHandler handler, {
    bool middleware = false,
  }) {
    _mounts[prefix] = handler;
    if (middleware) {
      _mountsWithMiddleware.add(prefix);
    } else {
      _mountsWithMiddleware.remove(prefix);
    }
  }

  /// remove a handler added with [mount]
  static void unmount(String prefix) {
    _mounts.remove(prefix);
    _mountsWithMiddleware.remove(prefix);
  }

  /// prefixes of the mounts that run the global middleware first
  Set<String> get mountsWithMiddleware => _mountsWithMiddleware;

  /// folders added with [staticFiles]
  List<StaticFolder> get statics => _statics;

  /// serve the files in [folder] under [prefix], for GET and HEAD
  /// requests that match no route. Routes always win, so a normal
  /// request does not touch the disk. No middleware runs for a file.
  /// Like other routes, [prefix] follows [group], the router prefix and
  /// [domain]. [folder] is relative to the folder the app starts in.
  /// Never save user uploads in [folder]: an uploaded html or svg file
  /// would run its script on your site. Use `dox_storage` for them.
  /// `..`, dot files (like `.env`) and folders are never sent: they get
  /// 404. Only a `.well-known` folder at the top of [folder] is sent.
  /// A file gets `ETag` and `Last-Modified` (and 304 when the browser has it),
  /// Range support, and `Cache-Control: public, max-age=...` with
  /// [maxAge]. Give hashed build files (like Vite's) a long [maxAge].
  /// ```
  /// Route.staticFiles('/', 'public');
  /// Route.staticFiles('build', 'public/build', maxAge: Duration(days: 365));
  /// ```
  /// Behind a proxy (nginx, Caddy), the proxy can serve the folder instead.
  static void staticFiles(String prefix, String folder, {Duration? maxAge}) {
    Route r = Route();
    _statics.add(
      StaticFolder(r._join(prefix), folder, maxAge: maxAge, domain: r._domain),
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

  /// answer 503 when the route added last takes longer than [duration].
  /// It covers its middleware too. See [RequestTimeout].
  /// ```
  /// Route.get('report', controller).timeout(Duration(seconds: 30));
  /// ```
  Route timeout(Duration duration) {
    RouteData? last = _last;
    if (last == null) {
      throw StateError('Route.timeout(): there is no route to time.');
    }
    for (RouteData data in _lastGroup ?? <RouteData>[last]) {
      (data.controllers as List<dynamic>).insert(0, RequestTimeout(duration));
    }
    return this;
  }

  /// only match the route added last when its [param] matches [regex].
  /// Else the route does not match, and the next route is tried (or the
  /// client gets 404). The regex must match the whole param text. Use
  /// `(?:...)` for groups, not `(...)`.
  /// ```
  /// Route.get('users/{id}', controller).where('id', '[0-9]+');
  /// Route.get('docs/{page}', controller).where('page', '.*');
  /// ```
  Route where(String param, String regex) {
    RouteData? last = _last;
    if (last == null) {
      throw StateError('Route.where("$param"): there is no route.');
    }
    int groups;
    try {
      groups = RegExp('(?:$regex)|').firstMatch('')!.groupCount;
    } on FormatException catch (error) {
      throw ArgumentError.value(regex, 'regex', error.message);
    }
    if (groups > 0) {
      throw ArgumentError.value(
        regex,
        'regex',
        'Use (?:...) for a group, not (...)',
      );
    }
    for (RouteData data in _lastGroup ?? <RouteData>[last]) {
      if (!data.paramNames.contains(param)) {
        throw ArgumentError.value(
          param,
          'param',
          'Route ${data.method} ${data.path} has no param "$param"',
        );
      }
      data.where(param, regex);
    }
    return this;
  }

  /// routes added with [fallback]
  List<RouteData> get fallbacks => _fallbacks;

  /// set the fallback routes, eg. in a new isolate
  void setFallbacks(List<RouteData> fallbacks) {
    _fallbacks = fallbacks;
  }

  /// the route for a GET or HEAD request that matches no other route and
  /// no [staticFiles] file. Use it for a custom 404 page, or to send
  /// `index.html` of a single page app. Other methods still get 404 or 405.
  ///
  /// Like other routes, it follows [group], the router prefix, [domain]
  /// and middleware. So in a router, the global middleware runs for it.
  /// Inside a group, it only answers paths under the group prefix. When
  /// two fallbacks match, the one with the longest prefix wins.
  /// ```
  /// Route.fallback((DoxRequest req) => res.status(404).json(...));
  /// Route.group('admin', () {
  ///   Route.fallback(controller); // only for /admin/...
  /// });
  /// ```
  static Route fallback<T extends Object>(dynamic controller) {
    Route r = Route();
    RouteData data = r._routeData(
      HttpRequestMethod.GET,
      r._join(''),
      _action<T>(controller),
    );
    _fallbacks.add(data);
    r._last = data;
    r._lastGroup = null;
    return r;
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

  /// [url] with a `signature` query param, so the link can not be
  /// changed. Check it with the `ValidateSignature` middleware. With
  /// [expires], the url also has an `expires` param (unix seconds) and
  /// stops working after that time.
  ///
  /// The url is absolute by default: [baseUrl] (default: `APP_URL` of
  /// the env, like `https://example.com`) is put in front, and the host
  /// is signed too. Use `absolute: false` to sign the path and query
  /// only, and then `ValidateSignature(absolute: false)`.
  /// ```
  /// Route.signedUrl('unsubscribe', params: <String, Object>{'user': 5});
  /// // https://example.com/unsubscribe/5?signature=...
  /// Route.signedUrl('download', expires: Duration(hours: 1));
  /// ```
  static String signedUrl(
    String name, {
    Map<String, Object?> params = const <String, Object?>{},
    Map<String, Object?> query = const <String, Object?>{},
    Duration? expires,
    bool absolute = true,
    String? baseUrl,
  }) {
    if (query.containsKey('signature')) {
      throw ArgumentError('"signature" is a reserved query param.');
    }
    Map<String, Object?> all = <String, Object?>{
      ...query,
      if (expires != null)
        'expires': DateTime.now().add(expires).millisecondsSinceEpoch ~/ 1000,
    };
    String path = url(name, params: params, query: all);
    if (absolute) {
      String base = baseUrl ?? Env.get<String>('APP_URL', '');
      if (base.isEmpty) {
        throw ArgumentError(
          'Route.signedUrl needs a host for an absolute url. Set APP_URL '
          'in the env, give baseUrl, or use absolute: false.',
        );
      }
      if (base.endsWith('/')) base = base.substring(0, base.length - 1);
      path = '$base$path';
    }
    String signature = ValidateSignature.sign(path);
    return '$path${path.contains('?') ? '&' : '?'}signature=$signature';
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
  static void bind<T extends Object>(String param, RouteBinder<T> resolve) {
    _bindings[param] = RouteBinding(T.toString(), resolve);
  }

  /// domain route
  /// ```
  /// Route.domain('example.com', () {
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

  /// group of route to disabled cors
  /// ```
  /// Route.disabledCors(() {
  ///   Route.get('/ping', controller);
  /// });
  /// ```
  static void disabledCors(Function() callback) {
    _cors(false, callback);
  }

  /// group of route to enable/disable cors.
  /// used by [enabledCors] and [disabledCors].
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
  /// Route.middleware(<dynamic>[AuthMiddleware()], () {
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
  ///
  /// By default any site can open the socket from a browser, with the
  /// cookies of the user. To check the `Origin`, set [allowedOrigins]
  /// (or `AppConfig.webSocketAllowedOrigins` for every route). Then only
  /// pages of the same host and the listed sites, like
  /// `https://app.example.com`, can open it. `[]` means the same host
  /// only. `*` allows every site. Other origins get 403. A client with no
  /// `Origin` header (not a browser) is always allowed.
  ///
  /// A message or frame over [maxMessageSize] bytes (default 16 MB)
  /// closes the socket with 1009 before your code gets it.
  /// ```
  /// Route.websocket('echo', (WebSocket socket, DoxRequest req) {
  ///   socket.listen(socket.add);
  /// });
  /// ```
  static Route websocket(
    String route,
    WebSocketHandler handler, {
    List<dynamic> middleware = const <dynamic>[],
    List<String>? allowedOrigins,
    int maxMessageSize = 16 * 1024 * 1024,
  }) {
    if (maxMessageSize < 1) {
      throw ArgumentError.value(
        maxMessageSize,
        'maxMessageSize',
        'must be 1 or more',
      );
    }
    Route r = Route()._addRoute(
      HttpRequestMethod.GET,
      Route()._join(route),
      <dynamic>[
        ...middleware,
        _WebSocketRoute(handler, allowedOrigins, maxMessageSize).call,
      ],
    );
    if (allowedOrigins == null) _noOriginCheck[r._last!] = true;
    return r;
  }

  /// true when a [websocket] route has no `allowedOrigins`.
  /// `AppConfig.webSocketAllowedOrigins` is not looked at here.
  bool get hasWebSocketWithoutOriginCheck =>
      _routes.any((RouteData r) => _noOriginCheck[r] == true);

  /// get route. [controller] is a function, or with a type `T` a
  /// function that picks the method of a controller from the container.
  /// ```
  /// Route.get<UserController>('users', (UserController c) => c.index);
  /// Route.get('ping', (DoxRequest req) => 'pong');
  /// ```
  /// The other methods (post, put, patch, delete, ...) work the same.
  static Route get<T extends Object>(String route, dynamic controller) {
    return Route()._addRoute(
      HttpRequestMethod.GET,
      Route()._join(route),
      _action<T>(controller),
    );
  }

  /// post route
  /// ```
  /// Route.post('path', controller);
  ///
  /// [body] is the request body schema for the OpenAPI docs
  /// (eg. a `dox_validation` schema).
  static Route post<T extends Object>(
    String route,
    dynamic controller, {
    Object? body,
  }) {
    return Route()._addRoute(
      HttpRequestMethod.POST,
      Route()._join(route),
      _action<T>(controller),
      body: body,
    );
  }

  /// put route
  /// ```
  /// Route.put('path', controller);
  ///
  static Route put<T extends Object>(
    String route,
    dynamic controller, {
    Object? body,
  }) {
    return Route()._addRoute(
      HttpRequestMethod.PUT,
      Route()._join(route),
      _action<T>(controller),
      body: body,
    );
  }

  /// delete route
  /// ```
  /// Route.delete('path', controller);
  ///
  static Route delete<T extends Object>(String route, dynamic controller) {
    return Route()._addRoute(
      HttpRequestMethod.DELETE,
      Route()._join(route),
      _action<T>(controller),
    );
  }

  /// purge route
  /// ```
  /// Route.purge('path', controller);
  ///
  static Route purge<T extends Object>(String route, dynamic controller) {
    return Route()._addRoute(
      HttpRequestMethod.PURGE,
      Route()._join(route),
      _action<T>(controller),
    );
  }

  /// patch route
  /// ```
  /// Route.patch('path', controller);
  ///
  static Route patch<T extends Object>(
    String route,
    dynamic controller, {
    Object? body,
  }) {
    return Route()._addRoute(
      HttpRequestMethod.PATCH,
      Route()._join(route),
      _action<T>(controller),
      body: body,
    );
  }

  /// options route
  /// ```
  /// Route.options('path', controller);
  ///
  static Route options<T extends Object>(String route, dynamic controller) {
    return Route()._addRoute(
      HttpRequestMethod.OPTIONS,
      Route()._join(route),
      _action<T>(controller),
    );
  }

  /// copy route
  /// ```
  /// Route.copy('path', controller);
  ///
  static Route copy<T extends Object>(String route, dynamic controller) {
    return Route()._addRoute(
      HttpRequestMethod.COPY,
      Route()._join(route),
      _action<T>(controller),
    );
  }

  /// view route
  /// ```
  /// Route.view('path', controller);
  ///
  static Route view<T extends Object>(String route, dynamic controller) {
    return Route()._addRoute(
      HttpRequestMethod.VIEW,
      Route()._join(route),
      _action<T>(controller),
    );
  }

  /// link route
  /// ```
  /// Route.link('path', controller);
  ///
  static Route link<T extends Object>(String route, dynamic controller) {
    return Route()._addRoute(
      HttpRequestMethod.LINK,
      Route()._join(route),
      _action<T>(controller),
    );
  }

  /// unlink route
  /// ```
  /// Route.unlink('path', controller);
  ///
  static Route unlink<T extends Object>(String route, dynamic controller) {
    return Route()._addRoute(
      HttpRequestMethod.UNLINK,
      Route()._join(route),
      _action<T>(controller),
    );
  }

  /// lock route
  /// ```
  /// Route.lock('path', controller);
  ///
  static Route lock<T extends Object>(String route, dynamic controller) {
    return Route()._addRoute(
      HttpRequestMethod.LOCK,
      Route()._join(route),
      _action<T>(controller),
    );
  }

  /// unlock route
  /// ```
  /// Route.unlock('path', controller);
  ///
  static Route unlock<T extends Object>(String route, dynamic controller) {
    return Route()._addRoute(
      HttpRequestMethod.UNLOCK,
      Route()._join(route),
      _action<T>(controller),
    );
  }

  /// propfind route
  /// ```
  /// Route.propfind('path', controller);
  ///
  static Route propfind<T extends Object>(String route, dynamic controller) {
    return Route()._addRoute(
      HttpRequestMethod.PROPFIND,
      Route()._join(route),
      _action<T>(controller),
    );
  }

  /// the methods of [any]. HEAD comes with GET. OPTIONS is left out, so
  /// the CORS preflight answer still works.
  static const List<HttpRequestMethod> _anyMethods = <HttpRequestMethod>[
    HttpRequestMethod.GET,
    HttpRequestMethod.POST,
    HttpRequestMethod.PUT,
    HttpRequestMethod.PATCH,
    HttpRequestMethod.DELETE,
  ];

  /// one route for each method in [methods], like `['GET', 'POST']`.
  /// HEAD comes with GET, so leave it out. An unknown method throws an
  /// [ArgumentError].
  /// ```
  /// Route.match(<String>['GET', 'POST'], 'contact', controller);
  /// ```
  static Route match<T extends Object>(
    List<String> methods,
    String route,
    dynamic controller,
  ) {
    List<HttpRequestMethod> list = <HttpRequestMethod>[];
    for (String method in methods) {
      String upper = method.toUpperCase();
      HttpRequestMethod? found;
      for (HttpRequestMethod value in HttpRequestMethod.values) {
        if (value.name == upper) found = value;
      }
      if (found == null) {
        throw ArgumentError.value(
          method,
          'methods',
          upper == 'HEAD'
              ? 'HEAD comes with GET, leave it out'
              : 'Unknown HTTP method',
        );
      }
      list.add(found);
    }
    return Route()._addMany(list, route, _action<T>(controller));
  }

  /// one route for GET (and HEAD), POST, PUT, PATCH and DELETE.
  /// OPTIONS is left out, so the CORS preflight answer still works.
  /// ```
  /// Route.any('webhook', controller);
  /// ```
  static Route any<T extends Object>(String route, dynamic controller) {
    return Route()._addMany(_anyMethods, route, _action<T>(controller));
  }

  /// redirect [from] to [to], for every method of [any]. 302 by default.
  /// ```
  /// Route.redirect('home', '/');
  /// Route.redirect('old-blog', '/blog', status: 301);
  /// ```
  static Route redirect(
    String from,
    String to, {
    int status = HttpStatus.found,
  }) {
    DoxResponse send(DoxRequest req) => _redirectTo(to, status: status);
    return Route()._addMany(_anyMethods, from, send);
  }

  /// [redirect] with 301 (moved permanently)
  /// ```
  /// Route.permanentRedirect('old-blog', '/blog');
  /// ```
  static Route permanentRedirect(String from, String to) {
    return redirect(from, to, status: HttpStatus.movedPermanently);
  }

  /// add one route per method. [where] and [timeout] cover all of them.
  Route _addMany(
    List<HttpRequestMethod> methods,
    String route,
    dynamic controller,
  ) {
    List<RouteData> added = <RouteData>[];
    for (HttpRequestMethod method in methods) {
      _addRoute(method, _join(route), controller);
      added.add(_last!);
    }
    _lastGroup = added;
    return this;
  }

  /// resource route. [controller] is a controller class (a [Type]) from
  /// the container, or a controller object.
  /// ```
  /// Route.resource('blog', BlogController);
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
    if (controller is Type) controller = Dox().ioc.getByType(controller);
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

  /// with a type [T], [controller] picks a method of the [T] from the
  /// container. it is read at start, see [ControllerAction].
  static dynamic _action<T extends Object>(dynamic controller) {
    if (T == Object) return controller;
    if (controller is List && controller.isNotEmpty) {
      return <dynamic>[
        ...controller.sublist(0, controller.length - 1),
        ControllerAction<T>(controller.last as Function),
      ];
    }
    return ControllerAction<T>(controller as Function);
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
    RouteData data = _routeData(method, path, controller, body: body);
    _routes.add(data);
    _last = data;
    _lastGroup = null;
    return this;
  }

  RouteData _routeData(
    HttpRequestMethod method,
    String path,
    dynamic controller, {
    Object? body,
  }) {
    path = sanitizeRoutePath(path);
    List<dynamic> controllers = <dynamic>[];
    controllers.addAll(_preMiddleware);
    if (controller is Function || controller is ControllerAction) {
      controllers.add(controller);
    }
    if (controller is List) {
      controllers.addAll(controller);
    }
    return RouteData(
      method: method.name,
      path: path,
      controllers: controllers,
      domain: _domain,
      corsEnabled: _corsEnabled,
      preMiddleware: List<dynamic>.unmodifiable(_preMiddleware),
      body: body,
    );
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

/// the top level [redirect], which [Route.redirect] hides inside [Route]
DoxResponse _redirectTo(String url, {required int status}) {
  return redirect(url, status: status);
}
