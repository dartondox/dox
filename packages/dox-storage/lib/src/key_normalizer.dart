import 'exceptions.dart';

/// Cleans file keys and blocks unsafe ones.
///
/// - Backslashes become `/`.
/// - Empty and `.` segments are removed (`a//./b` -> `a/b`).
/// - `..` segments, absolute paths, drive letters and null bytes are rejected.
class KeyNormalizer {
  const KeyNormalizer();

  static final RegExp _driveLetter = RegExp(r'^[a-zA-Z]:');

  /// Normalize a file key. The result is never empty.
  String key(String input) {
    String result = _normalize(input);
    if (result.isEmpty) {
      throw InvalidKeyException(input, 'key is empty');
    }
    return result;
  }

  /// Normalize a folder prefix. An empty prefix means the root.
  String prefix(String input) {
    return _normalize(input);
  }

  String _normalize(String input) {
    if (input.contains('\u0000')) {
      throw InvalidKeyException(input, 'null byte is not allowed');
    }
    String value = input.replaceAll(r'\', '/');
    if (value.startsWith('/') || _driveLetter.hasMatch(value)) {
      throw InvalidKeyException(input, 'absolute paths are not allowed');
    }
    List<String> parts = <String>[];
    for (String segment in value.split('/')) {
      if (segment.isEmpty || segment == '.') {
        continue;
      }
      if (segment == '..') {
        throw InvalidKeyException(input, 'path traversal is not allowed');
      }
      parts.add(segment);
    }
    return parts.join('/');
  }
}

/// Builds URL paths from keys.
class KeyEncoder {
  const KeyEncoder();

  /// Percent-encode each segment of a key, keep the `/` between them.
  String urlPath(String key) {
    List<String> parts = <String>[];
    for (String segment in key.split('/')) {
      parts.add(Uri.encodeComponent(segment));
    }
    return parts.join('/');
  }
}
