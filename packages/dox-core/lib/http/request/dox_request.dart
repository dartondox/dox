import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/request/http_request_body.dart';
import 'package:dox_core/http/request/trusted_proxy.dart';
import 'package:dox_core/router/route_data.dart';

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

  @override
  String method = 'GET';

  Map<String, dynamic> body = <String, dynamic>{};
  Map<String, dynamic> param = <String, dynamic>{};

  /// the query string, read on first use
  late Map<String, dynamic> query = uri.queryParameters;

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
  }) : _givenIp = clientIp,
       _givenScheme = scheme,
       requestBody = requestBody ?? RequestBody(body) {
    method = route.method.toUpperCase();
    param = route.params;
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
    try {
      return AESEncryptor.decode(
        _cookies[key],
        Dox().config.appKey,
        associatedData: key,
      );
    } on DecryptException {
      return null;
    }
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
        '(lib/dtos.g.dart) in AppConfig.',
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
      if (value is RequestFile) {
        ret[key] = value.filename;
      } else {
        ret[key] = value;
      }
    });
    return ret;
  }
}
