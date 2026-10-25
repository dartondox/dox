import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/http_controller_handler.dart';

class RouteData {
  final String method;
  String path;
  final dynamic controllers;

  /// set by `Route.get(...).name('users.show')`, see `Route.url`
  String? name;

  /// set by [withParams]. made only when a plain route reads it.
  late Map<String, dynamic> params = <String, dynamic>{};

  /// middleware from groups and routers (`Route.middleware`, global
  /// middleware). they are also the first items of [controllers].
  final List<dynamic> preMiddleware;

  /// request body schema for the OpenAPI docs, from the `body:` option.
  /// any object with `toJsonSchema()`, like a `dox_validation` schema.
  Object? body;

  final String? domain;

  /// [domain] in lower case, made once.
  late final String? domainLower = domain?.toLowerCase();
  final bool? corsEnabled;

  ControllerPlan? _handler;
  bool _handlerRead = false;

  /// How to call the controller (the last function of [controllers]),
  /// read once. Null when the route has no controller function.
  /// Throws a [StateError] when a parameter type is not known.
  ControllerPlan? get handler {
    if (!_handlerRead) {
      Function? fn = action;
      _handler = fn == null ? null : ControllerPlan.of(fn, this);
      _handlerRead = true;
    }
    return _handler;
  }

  bool? _usesNext;

  /// True when a middleware of this route takes a `next`
  /// ([IDoxNextMiddleware] or a [NextMiddlewareFunction]). Read once.
  bool get usesNext {
    return _usesNext ??= _findNext();
  }

  bool _findNext() {
    Object? list = controllers;
    if (list is! List<dynamic>) return false;
    for (int i = 0; i < list.length; i++) {
      Object? item = list[i];
      if (item is IDoxNextMiddleware) return true;
      if (i < list.length - 1 && item is NextMiddlewareFunction) return true;
    }
    return false;
  }

  Function? _action;
  bool _actionRead = false;

  /// The function that handles the request, read once: the last function
  /// of [controllers], or the controller method that a
  /// [ControllerAction] (`Route.get<C>(path, (C c) => c.index)`) or a
  /// `(C c) => c.index` function picks. The controller comes from the
  /// container. Null when the route has no controller function.
  Function? get action {
    if (!_actionRead) {
      Object? list = controllers;
      Object? last = list is List<dynamic> && list.isNotEmpty
          ? list.last
          : null;
      String where = '$method $path';
      if (last is ControllerAction) {
        _action = last.resolve(Dox().ioc, where);
      } else if (last is Function) {
        _action = ControllerTypes.select(last, Dox().ioc, where) ?? last;
      }
      _actionRead = true;
    }
    return _action;
  }

  RouteData({
    required this.method,
    required this.path,
    required this.controllers,
    this.corsEnabled,
    this.preMiddleware = const <dynamic>[],
    this.domain,
    this.body,
  });

  /// regex for a route with params like `/blog/{id}`, built once.
  /// null for a plain route, which is matched with `==`.
  RegExp? get pattern {
    _compile();
    return _pattern;
  }

  /// names of the params, eg. `['id']` for `/blog/{id}`.
  /// `{path*}` matches the rest of the url, slashes too.
  /// `{id?}` is optional: `/blog` and `/blog/5` both match.
  List<String> get paramNames {
    _compile();
    return _paramNames;
  }

  RegExp? _pattern;
  List<String> _paramNames = const <String>[];
  String? _compiledFor;

  void _compile() {
    if (_compiledFor == path) return;
    _compiledFor = path;
    _paramNames = <String>[
      for (String part in path.split('/'))
        if (part.startsWith('{') && part.endsWith('}'))
          part
              .substring(1, part.length - 1)
              .replaceAll('*', '')
              .replaceAll('?', ''),
    ];
    _pattern = _paramNames.isEmpty
        ? null
        : RegExp('^${path.replaceAllMapped(_param, _paramPattern)}\$');
  }

  static final RegExp _param = RegExp(r'/?{[^/]+}');

  static String _paramPattern(Match match) {
    String text = match[0]!;
    String slash = text.startsWith('/') ? '/' : '';
    if (text.endsWith('*}')) return '$slash(.+)';
    if (text.endsWith('?}')) return '(?:$slash([^/]+))?';
    return '$slash([^/]+)';
  }

  /// a copy for one request, with its own params.
  /// the shared route is never changed, so two requests at the
  /// same time can not see each other's params.
  RouteData withParams(Map<String, dynamic> values) {
    return RouteData(
        method: method,
        path: path,
        controllers: controllers,
        corsEnabled: corsEnabled,
        preMiddleware: preMiddleware,
        domain: domain,
        body: body,
      )
      ..params = values
      ..name = name
      .._handler = handler
      .._handlerRead = true
      .._action = _action
      .._actionRead = _actionRead
      .._usesNext = usesNext
      .._pattern = _pattern
      .._paramNames = _paramNames
      .._compiledFor = _compiledFor;
  }
}
