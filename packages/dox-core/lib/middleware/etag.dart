import 'dart:async';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/http_response_handler.dart';
import 'package:dox_core/server/dox_server.dart';

/// Adds an `ETag` header to GET and HEAD answers, and answers
/// `304 Not Modified` with no body when the client already has the same
/// answer (its `If-None-Match` header has the same ETag).
///
/// ```
/// Route.get('posts', <dynamic>[const ETag(), postController.index]);
/// ```
///
/// It works on `200` answers with a body in memory: a String, or a
/// value that is sent as JSON (a Map, a List, a model). Files and
/// streams are not touched. An answer that already has an `ETag` or
/// `Cache-Control: no-store` is not touched either.
///
/// The ETag is weak (`W/"..."`): a 64-bit FNV-1a hash of the body and
/// its length. It is fast, but not a secure hash. The controller still
/// runs, so a 304 saves bandwidth, not server time.
class ETag implements IDoxNextMiddleware {
  const ETag();

  @override
  Future<DoxResponse> handle(DoxRequest req, Next next) async {
    DoxResponse res = await next();
    String method = req.method;
    if (method != 'GET' && method != 'HEAD') return res;
    int? status = res.status;
    if (status != null && status != HttpStatus.ok) return res;
    if (_skip(res, req.httpRequest.response.headers)) return res;

    Object? content = res.getContent();
    String tag;
    if (content is String) {
      tag = ETag.of(content.codeUnits);
    } else if (_isJson(content)) {
      List<int> bytes = encodeJson(content);
      tag = ETag.of(bytes);
      // a custom response handler may change the content, so keep it
      if (DoxServer().responseHandler == null) res.content(JsonBytes(bytes));
    } else {
      return res;
    }

    res.header(HttpHeaders.etagHeader, tag);
    String? given = req.header(HttpHeaders.ifNoneMatchHeader);
    if (given != null && matches(given, tag)) {
      return res.content(null).statusCode(HttpStatus.notModified);
    }
    return res;
  }

  /// The weak ETag of [units] (bytes or code units).
  static String of(List<int> units) {
    // 64-bit FNV-1a. Dart ints wrap around at 64 bits.
    int hash = 0xcbf29ce484222325;
    for (int i = 0; i < units.length; i++) {
      hash = (hash ^ units[i]) * 0x100000001b3;
    }
    String high = ((hash >> 32) & 0xffffffff).toRadixString(16);
    String low = (hash & 0xffffffff).toRadixString(16);
    return 'W/"${units.length.toRadixString(16)}-'
        '${high.padLeft(8, '0')}${low.padLeft(8, '0')}"';
  }

  /// True when the `If-None-Match` value [header] has [tag], or is `*`.
  /// `W/` is not compared (weak comparison, as GET needs).
  static bool matches(String header, String tag) {
    String want = _opaque(tag);
    for (String part in header.split(',')) {
      String item = part.trim();
      if (item == '*' || _opaque(item) == want) return true;
    }
    return false;
  }

  static String _opaque(String tag) {
    return tag.startsWith('W/') ? tag.substring(2) : tag;
  }

  /// the answer already has an ETag, or must not be cached
  static bool _skip(DoxResponse res, HttpHeaders sent) {
    if (sent.value(HttpHeaders.etagHeader) != null) return true;
    if (_noStore(sent.value(HttpHeaders.cacheControlHeader))) return true;
    for (MapEntry<String, dynamic> entry in res.headers.entries) {
      String key = entry.key.toLowerCase();
      if (key == HttpHeaders.etagHeader) return true;
      if (key == HttpHeaders.cacheControlHeader && _noStore('${entry.value}')) {
        return true;
      }
    }
    return false;
  }

  static bool _noStore(String? value) {
    return value != null && value.toLowerCase().contains('no-store');
  }

  /// a body that is sent as JSON. Files, streams and errors are not.
  static bool _isJson(Object? content) {
    return content != null &&
        content is! Stream &&
        content is! File &&
        content is! StreamFile &&
        content is! DownloadableFile &&
        content is! WebSocket &&
        content is! JsonBytes &&
        content is! DateTime &&
        content is! IHttpException &&
        content is! Exception &&
        content is! Error;
  }
}
