import 'dart:io';

import 'package:dox_core/dox_core.dart';

class DoxResponse {
  final dynamic content;
  Map<String, dynamic> _headers = {};
  int _statusCode = HttpStatus.ok;
  ContentType? _contentType;
  String? _cookie;

  DoxResponse(this.content);

  /// Set response status code default 200
  DoxResponse statusCode(int code) {
    _statusCode = code;
    return this;
  }

  /// set content type such as json, text, html
  DoxResponse contentType(ContentType contentType) {
    _contentType = contentType;
    return this;
  }

  /// set headers
  DoxResponse header(key, value) {
    _headers[key] = value;
    return this;
  }

  /// Set cookie
  DoxResponse cookie(DoxCookie cookie, {bool setExpire = false}) {
    _cookie = setExpire ? cookie.expire() : cookie.get();
    return this;
  }

  /// Set list of headers by Map
  DoxResponse withHeaders(Map<String, dynamic> values) {
    _headers = values;
    return this;
  }

  /// This function for internal use only
  write(HttpRequest request) {
    _headers.forEach((key, value) {
      request.response.headers.add(key, value);
    });
    request.response.statusCode = _statusCode;
    if (_contentType != null) {
      request.response.headers.contentType = _contentType;
    }
    request.response.headers.add(HttpHeaders.setCookieHeader, _cookie!);
    return RouterResponse.send(content, request);
  }
}

DoxResponse response(content) {
  return DoxResponse(content);
}
