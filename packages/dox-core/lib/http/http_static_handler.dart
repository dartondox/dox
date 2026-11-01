import 'dart:io';

import 'package:dox_core/http/http_cors_handler.dart';
import 'package:dox_core/http/http_response_handler.dart';
import 'package:dox_core/middleware/etag.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

/// A folder of files served under a path prefix, see `Route.staticFiles`.
class StaticFolder {
  StaticFolder(String prefix, String folder, {this.maxAge, String? domain})
    : domain = domain?.toLowerCase(),
      prefix = Uri(path: prefix).pathSegments
          .where((String s) => s.isNotEmpty)
          .toList(),
      root = p.normalize(p.absolute(folder));

  /// the prefix as path segments: `/assets/` gives `['assets']`
  final List<String> prefix;

  /// the folder as an absolute path
  final String root;

  /// sent as `Cache-Control: public, max-age=...` when set
  final Duration? maxAge;

  /// the host of `Route.domain` (lower case), or null for every host
  final String? domain;

  /// true when the folder serves [host] (the `Host` header). The domain
  /// may have a port (`localhost:3000`) or not, like a domain route.
  bool servesHost(String? host) {
    String? want = domain;
    if (want == null) return true;
    if (host == null) return false;
    host = host.toLowerCase();
    if (want == host) return true;
    int end = host.startsWith('[') ? host.indexOf(']') + 1 : 0;
    int colon = host.indexOf(':', end);
    return colon != -1 && want == host.substring(0, colon);
  }

  /// the file for [segments] (the decoded request path), or null when the
  /// path is not under [prefix] or is not safe. `..`, `.env` and other
  /// dot names, empty segments (`a//b`, a trailing `/`) and `\` are
  /// refused, so no file outside [root] and no hidden file is sent.
  /// The one dot name allowed is a `.well-known` folder at the top of
  /// [root] (ACME challenges, security.txt). Dot names inside it are
  /// still refused.
  File? fileFor(List<String> segments) {
    if (segments.length <= prefix.length) return null;
    for (int i = 0; i < prefix.length; i++) {
      if (segments[i] != prefix[i]) return null;
    }
    List<String> rest = segments.sublist(prefix.length);
    for (int i = 0; i < rest.length; i++) {
      String s = rest[i];
      if (i == 0 && s == '.well-known') continue;
      if (s.isEmpty ||
          s.startsWith('.') ||
          s.contains('/') ||
          s.contains('\\') ||
          s.contains('\x00')) {
        return null;
      }
    }
    String path = p.joinAll(<String>[root, ...rest]);
    return p.isWithin(root, path) ? File(path) : null;
  }
}

/// Sends a file of [folders] for a GET or HEAD request that matched no
/// route. true when a file was sent, false when none of the folders has
/// one (the caller then sends 404).
Future<bool> httpStaticHandler(
  HttpRequest req,
  List<StaticFolder> folders,
) async {
  List<String> segments;
  try {
    segments = req.uri.pathSegments;
  } on FormatException {
    /// `%ff` and other codes that are not UTF-8
    return false;
  } on ArgumentError {
    return false;
  }
  String? host = req.headers.value(HttpHeaders.hostHeader);
  for (StaticFolder folder in folders) {
    if (!folder.servesHost(host)) continue;
    File? file = folder.fileFor(segments);
    if (file == null) continue;
    FileStat stat = await file.stat();
    if (stat.type != FileSystemEntityType.file) continue;

    /// a file that can not be read (no permission, just deleted) is a
    /// 404, not a 200 with an empty body that a cache could keep
    try {
      await (await file.open()).close();
    } on FileSystemException {
      continue;
    }
    _send(req, file, stat, folder.maxAge);
    return true;
  }
  return false;
}

/// CORS, `ETag`, `Last-Modified` and `Cache-Control`, then 304 when
/// the client has this version, else the file (with Range support).
void _send(HttpRequest req, File file, FileStat stat, Duration? maxAge) {
  HttpResponse res = req.response;

  /// the global CORS config, so fonts and `crossorigin` scripts load
  /// from another origin
  httpCorsHandler(null, req);

  /// HTTP dates have whole seconds
  DateTime modified = DateTime.fromMillisecondsSinceEpoch(
    stat.modified.millisecondsSinceEpoch ~/ 1000 * 1000,
    isUtc: true,
  );
  res.headers.set(HttpHeaders.lastModifiedHeader, HttpDate.format(modified));

  /// a weak ETag from the size and the change time, like nginx
  String etag =
      'W/"${stat.size.toRadixString(16)}-'
      '${stat.modified.millisecondsSinceEpoch.toRadixString(16)}"';
  res.headers.set(HttpHeaders.etagHeader, etag);
  if (maxAge != null) {
    res.headers.set(
      HttpHeaders.cacheControlHeader,
      'public, max-age=${maxAge.inSeconds}',
    );
  }
  if (_notModified(req, etag, modified)) {
    res.statusCode = HttpStatus.notModified;
    res.close();
    return;
  }
  res.headers.contentType = ContentType.parse(
    lookupMimeType(file.path) ?? 'application/octet-stream',
  );
  responseDataHandler(file, req);
}

/// true when the client already has this version. `If-None-Match` wins
/// over `If-Modified-Since` when both are sent (RFC 9110).
bool _notModified(HttpRequest req, String etag, DateTime modified) {
  String? match = req.headers.value(HttpHeaders.ifNoneMatchHeader);
  if (match != null) return ETag.matches(match, etag);
  String? header = req.headers.value(HttpHeaders.ifModifiedSinceHeader);
  DateTime? since = header == null ? null : _parseDate(header);

  /// a date in the future is not valid, and is ignored (RFC 9110)
  return since != null &&
      !since.isAfter(DateTime.now()) &&
      !modified.isAfter(since);
}

/// null when [value] is not an HTTP date
DateTime? _parseDate(String value) {
  try {
    return HttpDate.parse(value);
  } on HttpException {
    return null;
  } on FormatException {
    return null;
  }
}
