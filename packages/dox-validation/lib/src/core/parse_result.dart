import '../standard/standard_schema.dart';
import 'issue.dart';

/// The result of `safeParse`.
class ParseResult<O> implements StandardResult<O> {
  ParseResult.success(O this.value)
    : success = true,
      issues = const <ValidationIssue>[];

  ParseResult.failure(List<ValidationIssue> issues)
    : success = false,
      value = null,
      issues = List<ValidationIssue>.unmodifiable(issues);

  @override
  final bool success;

  @override
  final O? value;

  @override
  final List<ValidationIssue> issues;

  /// First message for each dotted path, like `{'user.email': '...'}`.
  ///
  /// This is the same shape as the old dox-core validator errors.
  Map<String, String> get errors {
    return IssueMaps.firstErrors(issues);
  }

  /// All messages for each dotted path.
  Map<String, List<String>> get fieldErrors {
    return IssueMaps.allErrors(issues);
  }
}

/// Helpers to group issues by path.
class IssueMaps {
  /// First message for each dotted path.
  static Map<String, String> firstErrors(List<ValidationIssue> issues) {
    Map<String, String> result = <String, String>{};
    for (ValidationIssue issue in issues) {
      if (!result.containsKey(issue.dottedPath)) {
        result[issue.dottedPath] = issue.message;
      }
    }
    return result;
  }

  /// All messages for each dotted path.
  static Map<String, List<String>> allErrors(List<ValidationIssue> issues) {
    Map<String, List<String>> result = <String, List<String>>{};
    for (ValidationIssue issue in issues) {
      List<String> messages = result[issue.dottedPath] ?? <String>[];
      messages.add(issue.message);
      result[issue.dottedPath] = messages;
    }
    return result;
  }
}
