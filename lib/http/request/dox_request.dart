import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/request/http_request_body.dart';
import 'package:dox_core/router/route_data.dart';
import 'package:dox_core/utils/aes_encryptor.dart';
import 'package:dox_core/validation/dox_validator.dart';

class DoxRequest {
  final RouteData route;
  final Uri uri;
  final ContentType? contentType;
  final HttpHeaders httpHeaders;

  final String? clientIp;
  String method = 'GET';
  HttpRequest? httpRequest;

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
    required this.httpHeaders,
  }) {
    method = route.method.toUpperCase();
    param = route.params;
    query = uri.queryParameters;
    _allRequest = <String, dynamic>{...query, ...body};
    _getCookies();
  }

  void setHttpRequest(HttpRequest req) {
    httpRequest = req;
  }

  /// http request data is form data
  bool isFormData() {
    return HttpBody.isFormData(contentType);
  }

  /// http request data is json
  bool isJson() {
    return HttpBody.isJson(contentType);
  }

  /// Get all request from body and query
  /// ```
  /// req.all();
  /// ```
  Map<String, dynamic> all() {
    return _allRequest;
  }

  /// Get Only specific request from body and query
  /// ```
  /// req.only(['email', 'name']);
  /// ```
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
  String ip() {
    return clientIp ?? 'unknown';
  }

  /// get auth class
  T? auth<T>() => input(AUTH_REQUEST_KEY);

  /// Get request value
  /// ```
  /// req.input('email');
  /// ```
  dynamic input(String key) {
    return _allRequest[key];
  }

  /// Check if input is present
  /// ```
  /// req.has('email')
  /// ```
  bool has(String key) {
    String? val = _allRequest[key];
    if (val == null) {
      return false;
    }
    return val.toString().isNotEmpty ? true : false;
  }

  /// Get header value
  /// ```
  /// req.header('X-Token');
  /// ```
  String? header(String key) {
    return httpHeaders.value(key);
  }

  /// Get all headers value
  /// ```
  /// req.headers;
  /// ```
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
  void add(String key, dynamic value) {
    _allRequest[key] = value;
    body[key] = value;
  }

  /// Merge request values
  /// ```
  /// req.merge({"foo" : bar});
  /// ```
  void merge(Map<String, dynamic> values) {
    _allRequest = <String, dynamic>{..._allRequest, ...values};
    body = <String, dynamic>{...body, ...values};
  }

  /// get cookie value from header
  /// ```
  /// req.cookie('authKey');
  /// ```
  String? cookie(String key, {bool decrypt = true}) {
    if (_cookies[key] == null) return null;
    if (decrypt) AESEncryptor.decode(_cookies[key], Dox().config.appKey);
    return _cookies[key];
  }

  /// get user agent from header
  /// ```
  /// req.userAgent();
  /// ```
  String userAgent() {
    return header('user-agent') ?? 'unknown';
  }

  /// get host|domain
  /// ```
  /// req.host()
  /// ```
  String host() {
    return header('host') ?? 'unknown';
  }

  /// get origin
  /// ```
  /// req.origin()
  /// ```
  String? origin() {
    return header('origin');
  }

  /// get referer
  /// ```
  /// req.referer()
  /// ```
  String? referer() {
    return header('referer');
  }

  /// validate input request
  /// ```
  /// req.validate({'title': 'required'});
  /// req.validate({'title': 'required'},
  ///   messages : {'required' : 'The {attribute} is required'});
  /// ```
  void validate(Map<String, String> rules,
      {Map<String, String> messages = const <String, String>{}}) {
    DoxValidator validator = DoxValidator(all());
    if (messages.isNotEmpty) {
      validator.setMessages(messages);
    }
    validator.validate(rules);
    if (validator.hasError) {
      throw ValidationException(message: validator.errors);
    }
  }

  void _getCookies() {
    List<String>? cookies = httpHeaders[HttpHeaders.cookieHeader];
    if (cookies == null) {
      return;
    }
    for (String cookie in cookies) {
      int equalsIndex = cookie.indexOf('=');
      String name = cookie.substring(0, equalsIndex);
      String value = cookie.substring(equalsIndex + 1);
      _cookies[name] = value;
    }
  }

  /// map request input keys
  void mapInputs(Map<String, String> mapper) {
    mapper.forEach((String from, String to) {
      if (from != to) {
        dynamic temp = _allRequest[from];
        _allRequest[to] = temp;
        _allRequest.remove(from);
      }
    });
  }

  /// support jsonEncode to convert json
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
