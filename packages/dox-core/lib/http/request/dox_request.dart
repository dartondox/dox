import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/request/http_request_body.dart';
import 'package:dox_core/router/route_data.dart';
import 'package:dox_core/utils/aes_encryptor.dart';

class DoxRequest implements IDoxRequest {
  final RouteData route;

  final HttpHeaders httpHeaders;

  @override
  final ContentType? contentType;

  @override
  final HttpRequest httpRequest;

  @override
  late Uri uri;

  final String? clientIp;

  final String _scheme;

  @override
  String method = 'GET';

  Map<String, dynamic> body = <String, dynamic>{};
  Map<String, dynamic> param = <String, dynamic>{};
  Map<String, dynamic> query = <String, dynamic>{};

  final Map<String, dynamic> _cookies = <String, dynamic>{};
  Map<String, dynamic> _allRequest = <String, dynamic>{};

  DoxRequest({
    required this.route,
    required this.uri,
    required this.body,
    this.contentType,
    this.clientIp,
    this._scheme = 'http',
    required this.httpHeaders,
    required this.httpRequest,
  }) {
    method = route.method.toUpperCase();
    param = route.params;
    query = uri.queryParameters;
    _allRequest = <String, dynamic>{...query, ...body};
    _getCookies();
  }

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
  @override
  Map<String, dynamic> only(List<String> keys) {
    Map<String, dynamic> ret = <String, dynamic>{};
    for (String key in keys) {
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

  /// get auth class
  @override
  IAuth? get auth => input(AUTH_REQUEST_KEY);

  /// Get request value
  /// ```
  /// req.input('email');
  /// ```
  @override
  dynamic input(String key) {
    return _allRequest[key];
  }

  /// Check if input is present
  /// ```
  /// req.has('email')
  /// ```
  @override
  bool has(String key) {
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
      ret[name] = values.join();
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

  /// get cookie value from header
  /// ```
  /// req.cookie('authKey');
  /// ```
  @override
  String? cookie(String key, {bool decrypt = true}) {
    if (_cookies[key] == null) return null;
    if (decrypt) return AESEncryptor.decode(_cookies[key], Dox().config.appKey);
    return _cookies[key];
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

  /// validate input request with string rules.
  /// returns the validated fields (only the fields that have rules).
  /// throws `ValidationException` (422) when the data is not valid.
  /// ```
  /// req.validate({'title': 'required'});
  /// req.validate({'title': 'required'},
  ///   messages : {'required' : 'The {field} is required'});
  /// ```
  /// rules that need the database (`unique`, `exists`) are async,
  /// use [validateAsync] for them.
  @override
  Map<String, dynamic> validate(
    Map<String, String> rules, {
    Map<String, String> messages = const <String, String>{},
  }) {
    return Dox().validator.validate(all(), rules, messages: messages);
  }

  /// same as [validate], and also runs async rules like `unique:users,email`
  /// ```
  /// await req.validateAsync({'email': 'required|email|unique:users,email'});
  /// ```
  Future<Map<String, dynamic>> validateAsync(
    Map<String, String> rules, {
    Map<String, String> messages = const <String, String>{},
  }) {
    return Dox().validator.validateAsync(all(), rules, messages: messages);
  }

  /// validate the request with a `dox_validation` schema and
  /// return its typed output. Async rules work too.
  /// ```
  /// Map<String, dynamic> data = await req.validateSchema(v.object({
  ///   'email': v.string().email(),
  ///   'age': v.coerce.int().min(18),
  /// }));
  /// ```
  Future<O> validateSchema<O>(Schema<O> schema) {
    return Dox().validator.validateSchema(schema, all());
  }

  void _getCookies() {
    List<String>? cookies = httpHeaders[HttpHeaders.cookieHeader];
    if (cookies == null) {
      return;
    }

    /// one header can hold many cookies, eg. `a=1; b=2`
    for (String cookie in cookies.expand((String c) => c.split(';'))) {
      int equalsIndex = cookie.indexOf('=');
      if (equalsIndex < 0) continue;
      String name = cookie.substring(0, equalsIndex).trim();
      String value = cookie.substring(equalsIndex + 1).trim();
      _cookies[name] = value;
    }
  }

  /// map the request input keys
  @override
  void processInputMapper(Map<String, String> mapper) {
    mapper.forEach((String from, String to) {
      if (from != to) {
        dynamic temp = _allRequest[from];
        _allRequest[to] = temp;
        _allRequest.remove(from);
      }
    });
  }

  /// To support jsonEncode
  @override
  Map<String, dynamic> toJson() {
    Map<String, dynamic> ret = <String, dynamic>{};
    _allRequest.forEach((String key, dynamic value) {
      if (value is RequestFile) {
        ret[key] = value.filename;
      } else {
        ret[key] = value;
      }
    });
    return ret;
  }
}
