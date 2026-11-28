import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/http_response_handler.dart';
import 'package:dox_core/http/response/dox_response.dart' show textBytesOf;
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

    Uint8List? textBytes = textBytesOf(res);
    Object? content = textBytes == null ? res.getContent() : null;
    String tag;
    if (textBytes != null) {
      // the same tag as the text would get, with no decode
      tag = ETag.ofUtf8(textBytes);
    } else if (content is String) {
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
    return _tag(hash, units.length);
  }

  /// The same tag as [of] gives for the UTF-16 code units of the text in
  /// the UTF-8 [bytes], with no decode. Bytes that are not valid UTF-8
  /// are decoded like `utf8.decode` with `allowMalformed`.
  static String ofUtf8(List<int> bytes) {
    int hash = 0xcbf29ce484222325;
    int units = 0;
    int length = bytes.length;
    int i = 0;
    while (i < length) {
      int b = bytes[i];
      if (b < 0x80) {
        hash = (hash ^ b) * 0x100000001b3;
        units++;
        i++;
        continue;
      }
      int size = b >= 0xC2 && b < 0xE0
          ? 2
          : b >= 0xE0 && b < 0xF0
          ? 3
          : b >= 0xF0 && b < 0xF5
          ? 4
          : 0;
      int code = size == 2
          ? b & 0x1F
          : size == 3
          ? b & 0x0F
          : b & 0x07;
      if (size == 0 || i + size > length) return _ofMalformed(bytes);
      for (int k = 1; k < size; k++) {
        int next = bytes[i + k];
        if (next & 0xC0 != 0x80) return _ofMalformed(bytes);
        code = (code << 6) | (next & 0x3F);
      }
      // too long a form, a surrogate, or past U+10FFFF
      if ((size == 3 && code < 0x800) ||
          (size == 4 && (code < 0x10000 || code > 0x10FFFF)) ||
          (code >= 0xD800 && code <= 0xDFFF)) {
        return _ofMalformed(bytes);
      }
      i += size;
      if (code > 0xFFFF) {
        code -= 0x10000;
        hash = (hash ^ (0xD800 | (code >> 10))) * 0x100000001b3;
        hash = (hash ^ (0xDC00 | (code & 0x3FF))) * 0x100000001b3;
        units += 2;
      } else {
        hash = (hash ^ code) * 0x100000001b3;
        units++;
      }
    }
    return _tag(hash, units);
  }

  static String _ofMalformed(List<int> bytes) {
    return of(utf8.decode(bytes, allowMalformed: true).codeUnits);
  }

  static String _tag(int hash, int length) {
    String high = ((hash >> 32) & 0xffffffff).toRadixString(16);
    String low = (hash & 0xffffffff).toRadixString(16);
    return 'W/"${length.toRadixString(16)}-'
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
