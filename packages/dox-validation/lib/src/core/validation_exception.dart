import 'issue.dart';
import 'parse_result.dart';

/// Thrown by `parse` and `parseAsync` when the input is not valid.
class ValidationException implements Exception {
  ValidationException(List<ValidationIssue> issues)
    : issues = List<ValidationIssue>.unmodifiable(issues);

  /// All issues found.
  final List<ValidationIssue> issues;

  /// First message for each dotted path, like `{'email': '...'}`.
  Map<String, String> get errors {
    return IssueMaps.firstErrors(issues);
  }

  /// All messages for each dotted path.
  Map<String, List<String>> get fieldErrors {
    return IssueMaps.allErrors(issues);
  }

  @override
  String toString() {
    return 'ValidationException: ${issues.join('; ')}';
  }
}
