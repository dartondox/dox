import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/http_controller_handler.dart';

class RouteData {
  final String method;
  String path;
  final dynamic controllers;

  /// set by `Route.get(...).name('users.show')`, see `Route.url`
  String? name;

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

  List<IDoxTerminableMiddleware>? _terminable;

  /// The middleware of this route with a `terminate` step
  /// ([IDoxTerminableMiddleware]), in order. Read once. Empty for most
  /// routes.
  List<IDoxTerminableMiddleware> get terminable {
    return _terminable ??= _findTerminable();
  }

  List<IDoxTerminableMiddleware> _findTerminable() {
    Object? list = controllers;
    if (list is! List<dynamic>) return const <IDoxTerminableMiddleware>[];
    List<IDoxTerminableMiddleware> found = <IDoxTerminableMiddleware>[
      for (Object? item in list)
        if (item is IDoxTerminableMiddleware) item,
    ];
    return found.isEmpty ? const <IDoxTerminableMiddleware>[] : found;
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

  /// param name => regex, set with `Route.where`. null for most routes,
  /// so they build the same pattern as before.
  Map<String, String>? wheres;

  /// only match [param] when its text matches [regex], see `Route.where`.
  /// A leading `^` and a trailing `$` are dropped: the regex must match
  /// the whole param text anyway, and inside the route regex they would
  /// never match.
  void where(String param, String regex) {
    (wheres ??= <String, String>{})[param] = _withoutAnchors(regex);
    _compiledFor = null;
    _whereChecks = null;
  }

  Map<String, RegExp>? _whereChecks;

  /// The `Route.where` regex of [param] as a full match (`^(?:regex)$`),
  /// built once. Null when [param] has no `where`. The router checks the
  /// param with it again after `%` decoding, so `%2F` can not sneak a `/`
  /// past a rule like `[^/]+`.
  RegExp? whereCheck(String param) {
    String? regex = wheres?[param];
    if (regex == null) return null;
    // dotAll: `.` must match a decoded `%0A` too, like it matches the
    // raw `%0A` text in the route regex
    return (_whereChecks ??= <String, RegExp>{})[param] ??= RegExp(
      '^(?:$regex)\$',
      dotAll: true,
    );
  }

  /// `^[0-9]+$` gives `[0-9]+`. An escaped `\$` at the end stays.
  static String _withoutAnchors(String regex) {
    if (regex.startsWith('^')) regex = regex.substring(1);
    if (regex.endsWith(r'$')) {
      int slashes = 0;
      for (int i = regex.length - 2; i >= 0 && regex[i] == r'\'; i--) {
        slashes++;
      }
      if (slashes.isEven) regex = regex.substring(0, regex.length - 1);
    }
    return regex;
  }

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
        : RegExp(
            '^${path.replaceAllMapped(_param, wheres == null ? _paramPattern : _wherePattern)}\$',
          );
  }

  /// like [_paramPattern], with the regex of `Route.where` for the param
  String _wherePattern(Match match) {
    String text = match[0]!;
    String name = text.replaceAll(_paramMarks, '');
    String? regex = wheres![name];
    if (regex == null) return _paramPattern(match);
    String slash = text.startsWith('/') ? '/' : '';
    if (text.endsWith('?}')) return '(?:$slash((?:$regex)))?';
    return '$slash((?:$regex))';
  }

  static final RegExp _paramMarks = RegExp(r'[/{}*?]');

  static final RegExp _param = RegExp(r'/?{[^/]+}');

  static String _paramPattern(Match match) {
    String text = match[0]!;
    String slash = text.startsWith('/') ? '/' : '';
    if (text.endsWith('*}')) return '$slash(.+)';
    if (text.endsWith('?}')) return '(?:$slash([^/]+))?';
    return '$slash([^/]+)';
  }
}
