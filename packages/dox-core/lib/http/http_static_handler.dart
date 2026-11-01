import 'dart:io';

import 'package:dox_core/http/http_response_handler.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

/// A folder of files served under a path prefix, see `Route.staticFiles`.
class StaticFolder {
  StaticFolder(String prefix, String folder, {this.maxAge})
    : prefix = Uri(path: prefix).pathSegments
          .where((String s) => s.isNotEmpty)
          .toList(),
      root = p.normalize(p.absolute(folder));

  /// the prefix as path segments: `/assets/` gives `['assets']`
  final List<String> prefix;

  /// the folder as an absolute path
  final String root;

  /// sent as `Cache-Control: public, max-age=...` when set
  final Duration? maxAge;

  /// the file for [segments] (the decoded request path), or null when the
  /// path is not under [prefix] or is not safe. `..`, `.env` and other
  /// dot names, empty segments (`a//b`, a trailing `/`) and `\` are
  /// refused, so no file outside [root] and no hidden file is sent.
  File? fileFor(List<String> segments) {
    if (segments.length <= prefix.length) return null;
    for (int i = 0; i < prefix.length; i++) {
      if (segments[i] != prefix[i]) return null;
    }
    List<String> rest = segments.sublist(prefix.length);
    for (String s in rest) {
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
  for (StaticFolder folder in folders) {
    File? file = folder.fileFor(segments);
    if (file == null) continue;
    FileStat stat = await file.stat();
    if (stat.type != FileSystemEntityType.file) continue;
    _send(req, file, stat, folder.maxAge);
    return true;
  }
  return false;
}

/// `Last-Modified` and `Cache-Control`, then 304 when the client has this
/// version, else the file (with Range support).
void _send(HttpRequest req, File file, FileStat stat, Duration? maxAge) {
  HttpResponse res = req.response;

  /// HTTP dates have whole seconds
  DateTime modified = DateTime.fromMillisecondsSinceEpoch(
    stat.modified.millisecondsSinceEpoch ~/ 1000 * 1000,
    isUtc: true,
  );
  res.headers.set(HttpHeaders.lastModifiedHeader, HttpDate.format(modified));
  if (maxAge != null) {
    res.headers.set(
      HttpHeaders.cacheControlHeader,
      'public, max-age=${maxAge.inSeconds}',
    );
  }
  String? header = req.headers.value(HttpHeaders.ifModifiedSinceHeader);
  DateTime? since = header == null ? null : _parseDate(header);
  if (since != null && !modified.isAfter(since)) {
    res.statusCode = HttpStatus.notModified;
    res.close();
    return;
  }
  res.headers.contentType = ContentType.parse(
    lookupMimeType(file.path) ?? 'application/octet-stream',
  );
  responseDataHandler(file, req);
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
