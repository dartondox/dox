import '../standard/standard_schema.dart';

/// One validation problem.
class ValidationIssue implements StandardIssue {
  ValidationIssue({
    required this.path,
    required this.code,
    required this.message,
    this.params = const <String, Object?>{},
  });

  /// Where the problem is, like `['products', 0, 'name']`.
  @override
  final List<Object> path;

  /// Short code, like `required` or `min_length`. See [IssueCodes].
  final String code;

  /// Text for people to read.
  @override
  final String message;

  /// Values used in the message, like `{'min': 3}`.
  final Map<String, Object?> params;

  /// The path joined with dots, like `products.0.name`.
  String get dottedPath {
    return path.join('.');
  }

  @override
  String toString() {
    String where = path.isEmpty ? '(root)' : dottedPath;
    return '$where: $message';
  }
}
