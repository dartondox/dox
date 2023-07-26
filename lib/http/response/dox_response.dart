import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/http_response_handler.dart';

class DoxResponse {
  /// content can be anything
  /// String, int, Map, json serializable object, Stream<List<int>>
  dynamic content;

  Map<String, dynamic> _headers = <String, dynamic>{};
  int? _statusCode;
  ContentType? _contentType;

  final List<String> _cookies = <String>[];

  /// content can be anything
  /// String, int, Map, json serializable object, Stream<List<int>>
  DoxResponse(this.content) {
    if (content is StreamFile) {
      _contentType = content.contentType;
      content = content.stream;
    }

    if (content is DownloadableFile) {
      header(FILE_DOWNLOAD_HEADER, content.contentDisposition);
      _contentType = content.contentType;
      content = content.stream;
    }
  }

  /// Set response status code default 200
  /// ```
  /// res.statusCode(200);
  /// ```
  DoxResponse statusCode(int code) {
    _statusCode = code;
    return this;
  }

  DoxResponse stream(Stream<List<int>> stream) {
    content = stream;
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
  DoxResponse header(String key, dynamic value) {
    _headers[key] = value;
    return this;
  }

  /// Set cookie
  /// ```
  /// var DoxCookie('key', 'value');
  /// res.cookie(cookie);
  /// ```
  DoxResponse cookie(DoxCookie cookie, {bool setExpire = false}) {
    _cookies.add(setExpire ? cookie.expire() : cookie.get());
    return this;
  }

  /// set cache
  /// ```
  /// res.cache(Duration(seconds: 10));
  /// ```
  DoxResponse cache(Duration duration) {
    _headers[HttpHeaders.cacheControlHeader] = 'max-age=${duration.inSeconds}';
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
  dynamic process(HttpRequest request) {
    _headers.forEach((String key, dynamic value) {
      request.response.headers.add(key, value);
    });
    if (_statusCode != null) {
      request.response.statusCode = _statusCode!;
    }
    if (_contentType != null) {
      request.response.headers.contentType = _contentType;
    }
    for (String cookie in _cookies) {
      request.response.headers.add(HttpHeaders.setCookieHeader, cookie);
    }
    return httpResponseHandler(content, request);
  }
}

/// content can be anything
/// String, int, Map, json serializable object, Stream<List<int>>
DoxResponse response([dynamic content]) {
  return DoxResponse(content);
}
