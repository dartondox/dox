/// Matches a path against a list like `<String>['/api/*', '/ping']`.
/// A `*` at the end matches the rest of the path.
class PathPattern {
  const PathPattern._();

  /// true when [path] matches one of [patterns]
  static bool any(List<String> patterns, String path) {
    for (String pattern in patterns) {
      String rule = pattern.startsWith('/') ? pattern : '/$pattern';
      if (rule.endsWith('*')) {
        if (path.startsWith(rule.substring(0, rule.length - 1))) return true;
      } else if (path == rule) {
        return true;
      }
    }
    return false;
  }
}
