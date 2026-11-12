import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/request/form_input.dart';
import 'package:dox_core/http/request/http_request_body.dart';
import 'package:dox_core/http/request/trusted_proxy.dart';
import 'package:dox_core/router/route_data.dart';
import 'package:dox_core/utils/utils.dart';

class DoxRequest implements IDoxRequest {
  final RouteData route;

  final HttpHeaders httpHeaders;

  @override
  final ContentType? contentType;

  @override
  final HttpRequest httpRequest;

  @override
  late Uri uri;

  final String? _givenIp;
  final String _givenScheme;
  final bool _readClient;

  /// ip and scheme, read from the socket on first use when [_readClient].
  /// the socket call is slow, and most requests never need it.
  late final ({String? ip, String scheme}) _client = _readClient
      ? TrustedProxy.readClient(httpRequest, Dox().config.trustedProxies)
      : (ip: _givenIp, scheme: _givenScheme);

  String? get clientIp => _client.ip;

  String get _scheme => _client.scheme;

  /// made on first use
  @override
  /// the request method, so a HEAD request on a GET route says HEAD
  late String method = httpRequest.method.toUpperCase();

  Map<String, dynamic> body;

  /// the route params, eg. `{'id': '5'}`. each request has its own map.
  late Map<String, dynamic> param = _params ?? <String, dynamic>{};

  /// the params the router found, null for a route with no params
  final Map<String, dynamic>? _params;

  /// values from `Route.bind`, set before the controller runs
  late final Map<String, Object> boundValues = <String, Object>{};

  /// the value `Route.bind` made for the route param [param].
  /// ```
  /// User user = req.bound<User>('user');
  /// ```
  T bound<T>(String param) {
    Object? value = boundValues[param];
    if (value is T) return value;
    throw StateError(
      'No bound value of type $T for the route param "$param". '
      'Add Route.bind<$T>(\'$param\', ...) and a {$param} in the route.',
    );
  }

  /// The id of this request, set by the `RequestId` middleware.
  /// Null when the route does not use it.
  String? requestId;

  Session? _session;

  /// The session of the request. Needs `SessionMiddleware` on the route.
  /// ```
  /// req.session.put('cart', <int>[1, 2]);
  /// ```
  Session get session {
    Session? session = _session;
    if (session != null) return session;
    throw StateError(
      'This request has no session. Add SessionMiddleware() to '
      'globalMiddleware or to the route.',
    );
  }

  /// set by `SessionMiddleware`
  set session(Session value) => _session = value;

  /// True when the request has a session, see [session].
  bool get hasSession => _session != null;

  /// True when the client wants a JSON answer, not a page: an `Accept`
  /// header with json, a JSON body, or an `X-Requested-With:
  /// XMLHttpRequest` header. An Inertia request (`X-Inertia`) is not.
  bool expectsJson() => expectsJsonFor(httpHeaders);

  /// [expectsJson] for the [headers] of a request.
  static bool expectsJsonFor(HttpHeaders headers) {
    if (headers.value('x-inertia') != null) return false;
    String accept = headers.value(HttpHeaders.acceptHeader) ?? '';
    if (accept.contains('/json') || accept.contains('+json')) return true;
    return HttpBody.isJson(headers.contentType) ||
        headers.value('x-requested-with') == 'XMLHttpRequest';
  }

  /// the query string, read on first use. bracket keys nest, like the
  /// body: `?tags[]=a&tags[]=b` gives `{'tags': ['a', 'b']}`.
  late Map<String, dynamic> query = const FormInput().nested(
    uri.queryParameters,
    () => const FormInput().queryPairs(uri),
  );

  /// cookies from the header, read on first use
  late final Map<String, dynamic> _cookies = _getCookies();

  /// query and body together, made on first use
  late Map<String, dynamic> _allRequest = <String, dynamic>{...query, ...body};

  /// The body as it was read, for DTOs. `body` is its map.
  final RequestBody requestBody;

  DoxRequest({
    required this.route,
    required this.uri,
    required this.body,
    this.contentType,
    String? clientIp,
    String scheme = 'http',
    required this.httpHeaders,
    required this.httpRequest,
    RequestBody? requestBody,
    this._readClient = false,
    this._params,
  }) : _givenIp = clientIp,
       _givenScheme = scheme,
       requestBody = requestBody ?? RequestBody(body);

  /// get route identifier
  @override
  String getRouteIdentifier() {
    return base64.encode(
      utf8.encode('${route.method}|${route.domain ?? ''}${route.path}'),
    );
  }

  /// get route identifier
  @override
  RouteData getRouteData() {
    return route;
  }

  /// http request data is form data
  @override
  bool isFormData() {
    return HttpBody.isFormData(contentType);
  }

  /// http request data is json
  @override
  bool isJson() {
    return HttpBody.isJson(contentType);
  }

  /// Get all request from body and query
  /// ```
  /// req.all();
  /// ```
  @override
  Map<String, dynamic> all() {
    return _allRequest;
  }

  /// Get Only specific request from body and query
  /// ```
  /// req.only(['email', 'name']);
  /// ```
  /// A key that is not in the input is in the map with `null`. With
  /// `CoreFlags.onlyPresent` it is left out.
  @override
  Map<String, dynamic> only(List<String> keys) {
    bool present = Dox().flags.onlyPresent;
    Map<String, dynamic> ret = <String, dynamic>{};
    for (String key in keys) {
      if (present && !_allRequest.containsKey(key)) continue;
      ret[key] = _allRequest[key];
    }
    return ret;
  }

  /// Get user IP
  /// ```
  /// req.ip();
  /// ```
  @override
  String ip() {
    return clientIp ?? UNKNOWN;
  }

  /// `http` or `https`. Behind a proxy listed in `trustedProxies` this
  /// comes from `X-Forwarded-Proto`. Dart itself only serves plain http.
  /// ```
  /// req.scheme();
  /// ```
  String scheme() {
    return _scheme;
  }

  /// true when the client used https (see [scheme])
  bool isSecure() {
    return _scheme == 'https';
  }

  /// the auth of the logged in user. `AuthMiddleware` and
  /// `Auth.setUser` set it. It is not in the input (query and body), so
  /// a client field can not set it.
  @override
  IAuth? auth;

  /// Get request value
  /// ```
  /// req.input('email');
  /// ```
  /// A dot key reads inside maps and lists, like `user.name` or
  /// `items.0.id`. A key that is in the input as it is wins.
  /// [defaultValue] is given when the key is not there or is null.
  /// ```
  /// req.input('user.name', 'guest');
  /// ```
  @override
  dynamic input(String key, [dynamic defaultValue]) {
    return _find(key).value ?? defaultValue;
  }

  /// The input without [keys].
  /// ```
  /// req.except(['password']);
  /// ```
  Map<String, dynamic> except(List<String> keys) {
    Map<String, dynamic> ret = <String, dynamic>{..._allRequest};
    for (String key in keys) {
      ret.remove(key);
    }
    return ret;
  }

  /// True when the key is in the input, with any value (also `''` or
  /// null). Dot keys work.
  /// ```
  /// req.exists('remember');
  /// ```
  bool exists(String key) {
    return _find(key).found;
  }

  /// True when the key is not in the input. The opposite of [exists].
  bool missing(String key) {
    return !exists(key);
  }

  /// True when the key is in the input and is not empty: not null, not
  /// a blank string, not an empty list or map. Dot keys work.
  /// ```
  /// req.filled('name');
  /// ```
  bool filled(String key) {
    dynamic val = _find(key).value;
    if (val == null) return false;
    if (val is String) return val.trim().isNotEmpty;
    if (val is Iterable) return val.isNotEmpty;
    if (val is Map) return val.isNotEmpty;
    return true;
  }

  /// The input as a bool. `true`, `1`, `on` and `yes` give true. Any
  /// other value gives false. [defaultValue] is given when the key is
  /// not there.
  /// ```
  /// req.boolean('remember');
  /// ```
  bool boolean(String key, [bool defaultValue = false]) {
    dynamic val = _find(key).value;
    if (val == null) return defaultValue;
    if (val is bool) return val;
    return _trueWords.contains(val.toString().trim().toLowerCase());
  }

  static const Set<String> _trueWords = <String>{'1', 'true', 'on', 'yes'};

  /// The input as an int. [defaultValue] is given when the key is not
  /// there or the value is not a number.
  /// ```
  /// req.integer('page', 1);
  /// ```
  int integer(String key, [int defaultValue = 0]) {
    dynamic val = _find(key).value;
    if (val == null) return defaultValue;
    num? number = val is num ? val : num.tryParse(val.toString().trim());
    // NaN, Infinity and 1e400 have no int value
    if (number == null || !number.isFinite) return defaultValue;
    return number.toInt();
  }

  /// The uploaded file of the key, or null when it is not a file.
  /// For a field with many files, use [input].
  /// ```
  /// RequestFile? photo = req.file('photo');
  /// ```
  RequestFile? file(String key) {
    dynamic val = _find(key).value;
    return val is RequestFile ? val : null;
  }

  /// True when the key holds an uploaded file, or a list of files.
  bool hasFile(String key) {
    dynamic val = _find(key).value;
    if (val is RequestFile) return true;
    return val is List && val.isNotEmpty && val.every(_isFile);
  }

  static bool _isFile(dynamic value) => value is RequestFile;

  /// The token of an `Authorization: Bearer <token>` header, or null.
  /// ```
  /// req.bearerToken();
  /// ```
  String? bearerToken() {
    String? value = header(HttpHeaders.authorizationHeader);
    if (value == null || value.length < 7) return null;
    if (value.substring(0, 7).toLowerCase() != 'bearer ') return null;
    String token = value.substring(7).trim();
    return token.isEmpty ? null : token;
  }

  /// The path of the request, like `/users/5`.
  String path() {
    return uri.path;
  }

  /// The full URL with the query string, like
  /// `https://example.com/users?page=2`.
  String fullUrl() {
    String query = uri.hasQuery ? '?${uri.query}' : '';
    return '${scheme()}://${host()}${uri.path}$query';
  }

  /// True when the path matches [pattern]. `*` matches any text.
  /// The path and [pattern] are cleaned like the router does: `//` is one
  /// `/`, and a `/` at the start or the end does not matter. So `/admin/`
  /// and `/admin//` both match `admin`, like they reach the `/admin`
  /// route. (`is` is a Dart keyword.)
  /// ```
  /// req.pathIs('admin/*');
  /// ```
  bool pathIs(String pattern) {
    RegExp regex = _pathWildcard(pattern);
    String raw = uri.path;
    String clean = sanitizeRoutePath(raw);
    try {
      if (regex.hasMatch(Uri.decodeComponent(clean.substring(1)))) return true;
      // the path as it came still counts, so `/admin/` keeps matching
      // `admin/*` like before
      return clean != raw &&
          regex.hasMatch(Uri.decodeComponent(_trimSlash(raw)));
    } on FormatException {
      // a bad escape, like `/%ff`, matches no pattern
      return false;
    } on ArgumentError {
      // a bare `%` or a bad code like `%zz` matches no pattern
      return false;
    }
  }

  /// True when the route name matches [pattern]. `*` matches any text.
  /// ```
  /// req.routeIs('users.*');
  /// ```
  bool routeIs(String pattern) {
    String? name = route.name;
    return name != null && _wildcard(pattern).hasMatch(name);
  }

  static String _trimSlash(String path) {
    return path.replaceFirst(RegExp(r'^/+'), '');
  }

  /// pattern => its regex. patterns are most often fixed text in the
  /// code, so the map stays small.
  // ponytail: cleared when full, an LRU if apps build many patterns
  static final Map<String, RegExp> _wildcards = <String, RegExp>{};

  /// raw `pathIs` pattern => its regex, so the pattern is cleaned once
  // ponytail: cleared when full, like [_wildcards]
  static final Map<String, RegExp> _pathWildcards = <String, RegExp>{};

  static RegExp _pathWildcard(String pattern) {
    RegExp? cached = _pathWildcards[pattern];
    if (cached != null) return cached;
    if (_pathWildcards.length >= 256) _pathWildcards.clear();
    return _pathWildcards[pattern] = _wildcard(
      sanitizeRoutePath(pattern).substring(1),
    );
  }

  static RegExp _wildcard(String pattern) {
    RegExp? cached = _wildcards[pattern];
    if (cached != null) return cached;
    if (_wildcards.length >= 256) _wildcards.clear();
    return _wildcards[pattern] = RegExp(
      '^${pattern.split('*').map(RegExp.escape).join('.*')}\$',
    );
  }

  /// the value of [key] in the input. a key that is there as it is wins,
  /// else a dot key reads inside maps and lists.
  ({bool found, dynamic value}) _find(String key) {
    if (_allRequest.containsKey(key)) {
      return (found: true, value: _allRequest[key]);
    }
    if (!key.contains('.')) return (found: false, value: null);
    dynamic current = _allRequest;
    for (String part in key.split('.')) {
      if (current is Map && current.containsKey(part)) {
        current = current[part];
      } else if (current is List) {
        int? index = int.tryParse(part);
        if (index == null || index < 0 || index >= current.length) {
          return (found: false, value: null);
        }
        current = current[index];
      } else {
        return (found: false, value: null);
      }
    }
    return (found: true, value: current);
  }

  /// Check if input is present
  /// ```
  /// req.has('email')
  /// ```
  /// `''` and null give false, like [filled]. With `CoreFlags.hasKeyOnly`
  /// it only checks that the key is there, like [exists].
  @override
  bool has(String key) {
    if (Dox().flags.hasKeyOnly) return exists(key);
    dynamic val = _allRequest[key];
    if (val == null) {
      return false;
    }
    return val.toString().isNotEmpty ? true : false;
  }

  /// Get header value
  /// ```
  /// req.header('X-Token');
  /// req.header(HttpHeaders.userAgentHeader);
  /// ```
  @override
  String? header(String key) {
    return httpHeaders.value(key);
  }

  /// Get all headers value
  /// ```
  /// req.headers;
  /// ```
  @override
  Map<String, dynamic> get headers {
    Map<String, dynamic> ret = <String, dynamic>{};
    httpHeaders.forEach((String name, List<String> values) {
      ret[name] = values.join(', ');
    });
    return ret;
  }

  /// Add new request value
  /// ```
  /// req.add('foo', bar);
  /// ```
  @override
  void add(String key, dynamic value) {
    _allRequest[key] = value;
    body[key] = value;
  }

  /// Merge request values
  /// ```
  /// req.merge({"foo" : bar});
  /// ```
  @override
  void merge(Map<String, dynamic> values) {
    _allRequest = <String, dynamic>{..._allRequest, ...values};
    body = <String, dynamic>{...body, ...values};
  }

  /// get cookie value from header.
  /// An encrypted cookie that was changed, made with another key, or
  /// made for another cookie name gives null.
  /// ```
  /// req.cookie('authKey');
  /// ```
  @override
  String? cookie(String key, {bool decrypt = true}) {
    if (_cookies[key] == null) return null;
    if (!decrypt) return _cookies[key];
    return DoxCookie.decrypt(key, _cookies[key]);
  }

  /// get user agent from header
  /// ```
  /// req.userAgent();
  /// ```
  @override
  String userAgent() {
    return header(HttpHeaders.userAgentHeader) ?? UNKNOWN;
  }

  /// get host|domain
  /// ```
  /// req.host()
  /// ```
  @override
  String host() {
    return header(HttpHeaders.hostHeader) ?? UNKNOWN;
  }

  /// get origin
  /// ```
  /// req.origin()
  /// ```
  @override
  String? origin() {
    return header('origin');
  }

  /// get referer
  /// ```
  /// req.referer()
  /// ```
  @override
  String? referer() {
    return header(HttpHeaders.refererHeader);
  }

  /// Check the request with the DTO [T] and give the typed object.
  /// Throws the 422 [ValidationException] when the input is not valid.
  /// [source] wins over the `source` of the DTO.
  /// ```
  /// CreateUser data = await req.validate<CreateUser>();
  /// ```
  Future<T> validate<T>({Source? source}) async {
    DtoSchema<Object>? schema = Dox().dtos.ofType(T);
    if (schema == null) {
      throw StateError(
        '$T is not a known DTO. Add @Dto() to it, run '
        '`dart run build_runner build` and set `dtos: dtos` '
        '(lib/generated/dtos.g.dart) in AppConfig.',
      );
    }
    return await Dox().validator.validateDto(this, schema, source: source) as T;
  }

  /// Check the request (query and body) with a fluent `dox_validation`
  /// schema and give its output. Only for input you know at runtime.
  /// ```
  /// Map<String, dynamic> data = await req.validateSchema(v.object({
  ///   'email': v.string().email(),
  /// }));
  /// ```
  Future<O> validateSchema<O>(Schema<O> schema) {
    return Dox().validator.validateSchema(schema, all());
  }

  /// The first language of the `Accept-Language` header, like `th`.
  /// `null` when there is none.
  String? get locale {
    String? header = httpHeaders.value(HttpHeaders.acceptLanguageHeader);
    if (header == null) return null;
    String first = header.split(',').first.split(';').first.trim();
    if (first.isEmpty || first == '*') return null;
    return first.split('-').first.toLowerCase();
  }

  /// The path params as text, like `{'id': '5'}`.
  Map<String, String> get pathParams {
    Map<String, String> out = <String, String>{};
    for (MapEntry<String, dynamic> entry in param.entries) {
      if (entry.value != null) out[entry.key] = '${entry.value}';
    }
    return out;
  }

  Map<String, dynamic> _getCookies() {
    Map<String, dynamic> out = <String, dynamic>{};
    List<String>? cookies = httpHeaders[HttpHeaders.cookieHeader];
    if (cookies == null) {
      return out;
    }

    /// one header can hold many cookies, eg. `a=1; b=2`
    for (String cookie in cookies.expand((String c) => c.split(';'))) {
      int equalsIndex = cookie.indexOf('=');
      if (equalsIndex < 0) continue;
      String name = cookie.substring(0, equalsIndex).trim();
      String value = cookie.substring(equalsIndex + 1).trim();
      out[name] = value;
    }
    return out;
  }

  /// To support jsonEncode
  @override
  Map<String, dynamic> toJson() {
    Map<String, dynamic> ret = <String, dynamic>{};
    _allRequest.forEach((String key, dynamic value) {
      ret[key] = _withFileNames(value);
    });
    return ret;
  }

  /// [value] with each file as its name, also inside lists and maps
  static dynamic _withFileNames(dynamic value) {
    if (value is RequestFile) return value.filename;
    if (value is List) return value.map(_withFileNames).toList();
    if (value is Map<String, dynamic>) {
      return value.map(
        (String k, dynamic v) =>
            MapEntry<String, dynamic>(k, _withFileNames(v)),
      );
    }
    return value;
  }
}
