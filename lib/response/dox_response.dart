import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/router/http_response_handler.dart';

class DoxResponse {
  final dynamic content;
  Map<String, dynamic> _headers = {};
  int _statusCode = HttpStatus.ok;
  ContentType? _contentType;
  String? _cookie;

  DoxResponse(this.content);

  /// Set response status code default 200
  /// ```
  /// res.statusCode(200);
  /// ```
  DoxResponse statusCode(int code) {
    _statusCode = code;
    return this;
  }

  /// set content type such as json, text, html
  /// ```
  /// res.statusCode(ContentType.json);
  /// ```
  DoxResponse contentType(ContentType contentType) {
    _contentType = contentType;
    return this;
  }

  /// set headers
  /// ```
  /// res.header('Authorization', 'Bearer xxx');
  /// ```
  DoxResponse header(key, value) {
    _headers[key] = value;
    return this;
  }

  /// Set cookie
  /// ```
  /// var DoxCookie('key', 'value');
  /// res.cookie(cookie);
  /// ```
  DoxResponse cookie(DoxCookie cookie, {bool setExpire = false}) {
    _cookie = setExpire ? cookie.expire() : cookie.get();
    return this;
  }

  /// set cache
  /// ```
  /// res.cache(Duration(seconds: 10));
  /// ```
  DoxResponse cache(Duration duration) {
    _headers['Cache-Control'] = 'max-age=${duration.inSeconds}';
    return this;
  }

  /// Set list of headers by Map
  /// ```
  /// res.withHeaders({'Authorization' : 'Bearer xxx'});
  /// ```
  DoxResponse withHeaders(Map<String, dynamic> values) {
    _headers = values;
    return this;
  }

  /// This function is for internal use only
  process(HttpRequest request) {
    _headers.forEach((key, value) {
      request.response.headers.add(key, value);
    });
    request.response.statusCode = _statusCode;
    if (_contentType != null) {
      request.response.headers.contentType = _contentType;
    }
    if (_cookie != null) {
      request.response.headers.add(HttpHeaders.setCookieHeader, _cookie!);
    }
    return HttpResponseHandler.send(content, request);
  }
}

DoxResponse response(content) {
  return DoxResponse(content);
}
