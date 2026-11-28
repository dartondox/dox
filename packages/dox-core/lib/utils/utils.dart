import 'dart:io';

import 'package:dox_http_native/dox_http_native.dart';

final RegExp _slashes = RegExp(r'/+');
final RegExp _edgeSlashes = RegExp('^\\/+|\\/+\$');

String sanitizeRoutePath(String path) {
  /// most paths are already clean, like `/` or `/api/users`.
  /// skip the two regex calls for them.
  if (_isClean(path)) return path;
  path = path.replaceAll(_slashes, '/');
  return "/${path.replaceAll(_edgeSlashes, '')}";
}

/// true when [path] starts with `/`, has no `//` and does not end with
/// `/` (except `/` itself). One pass over the code units: no
/// `String.contains`.
bool _isClean(String path) {
  int n = path.length;
  if (n == 0 || path.codeUnitAt(0) != 0x2f) return false;
  if (n == 1) return true;
  if (path.codeUnitAt(n - 1) == 0x2f) return false;
  for (int i = 1; i < n; i++) {
    if (path.codeUnitAt(i) == 0x2f && path.codeUnitAt(i - 1) == 0x2f) {
      return false;
    }
  }
  return true;
}

/// The path of [req], with no query. The same as `req.uri.path`, but the
/// native server gives a plain path with no [Uri].
String requestPath(HttpRequest req) =>
    req is NativeRequest ? req.path : req.uri.path;
