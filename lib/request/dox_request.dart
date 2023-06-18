import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/request/form_data_visitor.dart';
import 'package:dox_core/router/route_data.dart';
import 'package:dox_core/utils/aes_encryptor.dart';
import 'package:dox_core/validation/dox_validator.dart';

class DoxRequest {
  final HttpRequest httpRequest;

  String method = 'GET';
  Uri get uri => httpRequest.uri;
  HttpResponse get response => httpRequest.response;

  Map<String, dynamic> param = <String, dynamic>{};
  Map<String, dynamic> query = <String, dynamic>{};
  Map<String, dynamic> body = <String, dynamic>{};

  Map<String, dynamic> _allRequest = <String, dynamic>{};
  HttpHeaders get _headers => httpRequest.headers;
  final Map<String, dynamic> _cookies = <String, dynamic>{};

  DoxRequest(this.httpRequest);

  T? auth<T>() => input(AUTH_REQUEST_KEY);

  /// we are not using constructor here
  /// because we need to call async to read body data
  static Future<DoxRequest> httpRequestToDoxRequest(
    HttpRequest request,
    RouteData route,
  ) async {
    DoxRequest i = DoxRequest(request);
    i.param = route.params;
    i.method = route.method.toUpperCase();
    i.query = request.uri.queryParameters;

    if (i.isJson()) {
      String bodyString = await utf8.decoder.bind(request).join();
      i.body = jsonDecode(bodyString);
    }

    if (i.isFormData()) {
      FormDataVisitor visitor = FormDataVisitor(request);
      await visitor.process();
      i.body = visitor.inputs;
    }

    i._allRequest = <String, dynamic>{...i.query, ...i.body};
    i._getCookies();
    return i;
  }

  /// http request data is form data
  bool isFormData() {
    return httpRequest.headers.contentType?.mimeType.contains('form-data') ==
        true;
  }

  /// http request data is json
  bool isJson() {
    return httpRequest.headers.contentType.toString().contains('json') == true;
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
    return httpRequest.connectionInfo?.remoteAddress.address ?? 'unknown';
  }

  /// Get request value
  /// ```
  /// req.input('email');
  /// ```
  dynamic input(String key) {
    return _allRequest[key];
  }

  /// Check if input is present
  /// ```
  /// if(req.has('email')) {
  ///   /// do something
  /// }
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
    return _headers.value(key);
  }

  /// Get all headers value
  /// ```
  /// req.headers;
  /// ```
  Map<String, dynamic> get headers {
    Map<String, dynamic> ret = <String, dynamic>{};
    _headers.forEach((String name, List<String> values) {
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
    List<String>? cookies = httpRequest.headers[HttpHeaders.cookieHeader];
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
