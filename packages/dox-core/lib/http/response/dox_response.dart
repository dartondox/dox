import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/http_response_handler.dart';
import 'package:dox_core/http/request/trusted_proxy.dart';
import 'package:mime/mime.dart';

class DoxResponse {
  /// content can be anything
  /// String, int, Map, json serializable object, `Stream<List<int>>`
  dynamic _contentData;

  Map<String, dynamic> _headers = <String, dynamic>{};
  int? _statusCode;
  ContentType? _contentType;

  /// cookies and their expire flag. the header is made in [process],
  /// when Dox knows if the request came over https.
  final List<(DoxCookie, bool)> _cookies = <(DoxCookie, bool)>[];

  /// content can be anything
  /// String, int, Map, json serializable object, `Stream<List<int>>`, File
  DoxResponse(this._contentData) {
    if (_contentData is StreamFile) {
      _contentType = _contentData.contentType;
    }

    dynamic data = _contentData;
    if (data is DownloadableFile) {
      header(FILE_DOWNLOAD_HEADER, data.contentDisposition);
      _contentType = data.contentType;
      _contentData = StreamFile(
        data.contentType,
        data.stream,
        length: data.length,
      );
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

  /// The status set with [statusCode], or null (200).
  int? get status => _statusCode;

  /// The headers set with [header], by name.
  Map<String, dynamic> get headers => _headers;

  /// Set response status code default 200
  /// ```
  /// res.setContent({"foo": "bar"});
  /// ```
  DoxResponse content(dynamic content) {
    _contentData = content;
    return this;
  }

  /// Get original content data
  /// ```
  /// res.getContent();
  /// ```
  dynamic getContent() {
    return _contentData;
  }

  /// set stream data to response
  /// ```
  /// res.stream(streamData);
  /// ```
  DoxResponse stream(Stream<List<int>> stream) {
    content(stream);
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
    _cookies.add((cookie, setExpire));
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
    /// a WebSocket route behind a `next` middleware: the socket is open
    if (_contentData is WebSocket) return null;
    _headers.forEach((String key, dynamic value) {
      request.response.headers.add(key, value);
    });
    if (_statusCode != null) {
      request.response.statusCode = _statusCode!;
    }
    dynamic content = _contentData;
    if (_contentType == null && content is File) {
      _contentType = ContentType.parse(
        lookupMimeType(content.path) ?? 'application/octet-stream',
      );
    }
    if (_contentType != null) {
      request.response.headers.contentType = _contentType;
    }
    if (_cookies.isNotEmpty) {
      bool https =
          TrustedProxy.readClient(
            request,
            Dox().config.trustedProxies,
          ).scheme ==
          'https';
      for ((DoxCookie, bool) item in _cookies) {
        DoxCookie cookie = item.$1;
        request.response.headers.add(
          HttpHeaders.setCookieHeader,
          item.$2 ? cookie.expire(https: https) : cookie.get(https: https),
        );
      }
    }
    return responseDataHandler(_contentData, request);
  }
}

/// content can be anything
/// String, int, Map, json serializable object, `Stream<List<int>>`, File
DoxResponse response([dynamic content]) {
  return DoxResponse(content);
}

/// A redirect to [url]. 302 by default.
/// ```
/// return redirect('/login');
/// ```
DoxResponse redirect(String url, {int status = HttpStatus.found}) {
  return DoxResponse(null)
      .statusCode(status)
      .header(HttpHeaders.locationHeader, url);
}

/// A 302 redirect to the page the request came from (the `Referer`
/// header), or to [fallback] when there is none.
/// ```
/// req.session.flash('message', 'Saved');
/// return back(req);
/// ```
DoxResponse back(DoxRequest req, {String fallback = '/'}) {
  return redirect(req.referer() ?? fallback);
}
