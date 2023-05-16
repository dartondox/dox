import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';

class RouterResponse {
  dynamic payload;

  final HttpResponse response;

  RouterResponse(this.response);

  static send(payload, HttpRequest request) {
    if (payload is WebSocket) {
      return;
    }

    if (payload is DoxResponse) {
      return payload.write(request);
    }

    HttpResponse res = request.response;

    if (DoxServer().exceptionHandler != null) {
      var exceptionHandlerResponse =
          DoxServer().exceptionHandler?.handle(payload, res);
      if (exceptionHandlerResponse != null) {
        payload = exceptionHandlerResponse;
      }
    }

    String responseData;

    if (payload is Map) {
      responseData = jsonEncode(payload as Map<String, dynamic>);
      res.headers.contentType = ContentType.json;
    } else if (_hasMethod(() => payload.toJson)) {
      responseData = (payload).toJson();
      res.headers.contentType = ContentType.json;
    } else if (payload is List) {
      var data = (payload).map((e) {
        if (_hasMethod(() => e.toMap)) {
          return e.toMap();
        }
        return e;
      }).toList();
      res.headers.contentType = ContentType.json;
      responseData = jsonEncode(data);
    } else {
      responseData = payload.toString();
    }

    res.write(responseData);
    print(
        "\x1B[34m[${res.statusCode}]\x1B[0m \x1B[32m${request.method} ${request.uri.path}\x1B[0m");
    res.close();
  }

  static bool _hasMethod(Function creator) {
    try {
      creator();
      return true;
    } catch (err) {
      return false;
    }
  }
}

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
