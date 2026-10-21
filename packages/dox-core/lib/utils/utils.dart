final RegExp _slashes = RegExp(r'/+');
final RegExp _edgeSlashes = RegExp('^\\/+|\\/+\$');

String sanitizeRoutePath(String path) {
  path = path.replaceAll(_slashes, '/');
  return "/${path.replaceAll(_edgeSlashes, '')}";
}
