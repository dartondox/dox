import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/http_response_handler.dart';
import 'package:dox_core/http/request/trusted_proxy.dart';
import 'package:mime/mime.dart';

class DoxResponse {
  /// content can be anything
  /// String, int, Map, json serializable object, `Stream<List<int>>`
  dynamic _contentData;

  final Map<String, dynamic> _headers = <String, dynamic>{};
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

  /// Set list of headers by Map. A key in [values] replaces the header
  /// with the same name, in any case (`cache-control` and
  /// `Cache-Control` are one header). Other headers stay.
  /// ```
  /// res.withHeaders({'Authorization' : 'Bearer xxx'});
  /// ```
  DoxResponse withHeaders(Map<String, dynamic> values) {
    for (MapEntry<String, dynamic> entry in values.entries) {
      String name = entry.key.toLowerCase();
      _headers.removeWhere((String key, dynamic _) {
        return key.toLowerCase() == name;
      });
      _headers[entry.key] = entry.value;
    }
    return this;
  }

  /// This function is for internal use only
  dynamic process(HttpRequest request) {
    /// a WebSocket route behind a `next` middleware: the socket is open
    if (_contentData is WebSocket) return null;
    HttpHeaders headers = request.response.headers;
    _headers.forEach((String key, dynamic value) {
      /// Content-Type has one value. `add` would keep the default
      /// `text/plain` too, and the response fails with
      /// "More than one value for header content-type".
      if (key.length == 12 &&
          key.toLowerCase() == HttpHeaders.contentTypeHeader) {
        headers.set(key, value);
      } else {
        headers.add(key, value);
      }
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
///
/// Only a referer on the same host is used. A referer of another site
/// goes to [fallback], so `back` can not send users to other sites
/// (open redirect).
/// ```
/// req.session.flash('message', 'Saved');
/// return back(req);
/// ```
DoxResponse back(DoxRequest req, {String fallback = '/'}) {
  return redirect(
    sameHostUrl(req.referer(), req.header(HttpHeaders.hostHeader)) ?? fallback,
  );
}

/// [url] when it points to the same host as the [host] header, else null.
///
/// - a path like `/form` is kept. `//evil.com` and `/\evil.com` are not
///   paths, browsers read them as other sites.
/// - an `http` or `https` url is kept when its host and port are the
///   same as [host].
/// - anything else (other sites, `javascript:`, bad urls) gives null.
String? sameHostUrl(String? url, String? host) {
  if (url == null) return null;
  String u = url.trim();
  if (u.isEmpty || u.contains('\\') || _hasControlChar(u)) return null;
  if (u.startsWith('/')) {
    return u.startsWith('//') ? null : u;
  }
  if (host == null || host.trim().isEmpty) return null;
  Uri? uri = Uri.tryParse(u);
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
    return null;
  }
  if (uri.host.isEmpty || uri.userInfo.isNotEmpty) return null;
  Uri? hostUri = Uri.tryParse('${uri.scheme}://${host.trim()}');
  if (hostUri == null) return null;
  if (uri.host.toLowerCase() != hostUri.host.toLowerCase()) return null;
  if (uri.port != hostUri.port) return null;
  return u;
}

bool _hasControlChar(String s) {
  for (int c in s.codeUnits) {
    if (c < 0x20 || c == 0x7f) return true;
  }
  return false;
}
