final RegExp _slashes = RegExp(r'/+');
final RegExp _edgeSlashes = RegExp('^\\/+|\\/+\$');

String sanitizeRoutePath(String path) {
  /// most paths are already clean, like `/` or `/api/users`.
  /// skip the two regex calls for them.
  if (path.startsWith('/') &&
      (path.length == 1 || !path.endsWith('/')) &&
      !path.contains('//')) {
    return path;
  }
  path = path.replaceAll(_slashes, '/');
  return "/${path.replaceAll(_edgeSlashes, '')}";
}
