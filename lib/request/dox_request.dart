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

  Map<String, dynamic> param = {};
  Map<String, dynamic> query = {};
  Map<String, dynamic> body = {};

  Map<String, dynamic> _allRequest = {};
  HttpHeaders get _headers => httpRequest.headers;
  final Map<String, dynamic> _cookies = {};

  DoxRequest(this.httpRequest);

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
      var bodyString = await utf8.decoder.bind(request).join();
      i.body = jsonDecode(bodyString);
    }

    if (i.isFormData()) {
      var visitor = FormDataVisitor(request);
      await visitor.process();
      i.body = visitor.inputs;
    }

    i._allRequest = {...i.query, ...i.body};
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
    Map<String, dynamic> ret = {};
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
  dynamic input(key) {
    return _allRequest[key];
  }

  /// Check if input is present
  /// ```
  /// if(req.has('email')) {
  ///   /// do something
  /// }
  /// ```
  bool has(String key) {
    String val = _allRequest[key].toString();
    return val != 'null' || val.isNotEmpty ? true : false;
  }

  /// Get header value
  /// ```
  /// req.header('X-Token');
  /// ```
  String? header(key) {
    return _headers.value(key);
  }

  /// Get all headers value
  /// ```
  /// req.headers;
  /// ```
  Map<String, dynamic> get headers {
    Map<String, dynamic> ret = {};
    _headers.forEach((name, values) {
      ret[name] = values.join('');
    });
    return ret;
  }

  /// Add new request value
  /// ```
  /// req.add('foo', bar);
  /// ```
  void add(key, value) {
    _allRequest[key] = value;
    body[key] = value;
  }

  /// Merge request values
  /// ```
  /// req.merge({"foo" : bar});
  /// ```
  void merge(Map<String, dynamic> values) {
    _allRequest = {..._allRequest, ...values};
    body = {...body, ...values};
  }

  /// get cookie value from header
  /// ```
  /// req.cookie('authKey');
  /// ```
  String cookie(key, {bool decrypt = true}) {
    if (decrypt) {
      return AESEncryptor.decode(_cookies[key]);
    }
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
  validate(Map<String, String> rules,
      {Map<String, String> messages = const {}}) {
    var validator = DoxValidator(all());
    if (messages.isNotEmpty) {
      validator.setMessages(messages);
    }
    validator.validate(rules);
    if (validator.hasError) {
      throw ValidationException(message: validator.errors);
    }
  }

  _getCookies() {
    List<String>? cookies = httpRequest.headers[HttpHeaders.cookieHeader];
    if (cookies == null) {
      return;
    }
    for (var cookie in cookies) {
      int equalsIndex = cookie.indexOf('=');
      String name = cookie.substring(0, equalsIndex);
      String value = cookie.substring(equalsIndex + 1);
      _cookies[name] = value;
    }
  }

  void mapInputs(Map<String, String> mapper) {
    mapper.forEach((from, to) {
      if (from != to) {
        var temp = _allRequest[from];
        _allRequest[to] = temp;
        _allRequest.remove(from);
      }
    });
  }
}
