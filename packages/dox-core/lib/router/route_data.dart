import 'package:dox_core/dox_core.dart';

class RouteData {
  final String method;
  String path;
  final dynamic controllers;
  Map<String, dynamic> params = <String, dynamic>{};

  /// middleware from groups and routers (`Route.middleware`, global
  /// middleware). they are also the first items of [controllers].
  final List<dynamic> preMiddleware;
  FormRequest Function()? formRequest;

  /// request body schema for the OpenAPI docs, from the `body:` option.
  /// any object with `toJsonSchema()`, like a `dox_validation` schema.
  Object? body;

  final String? domain;
  final bool? corsEnabled;

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
          part.substring(1, part.length - 1).replaceAll('*', ''),
    ];
    _pattern = _paramNames.isEmpty
        ? null
        : RegExp(
            '^${path.replaceAllMapped(RegExp(r'{[^/]+}'), _paramPattern).replaceAll('/', '\\/')}\$',
          );
  }

  static String _paramPattern(Match match) {
    return match[0]!.endsWith('*}') ? '(.+)' : '([^/]+)';
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
      ..formRequest = formRequest
      .._pattern = _pattern
      .._paramNames = _paramNames
      .._compiledFor = _compiledFor;
  }
}
