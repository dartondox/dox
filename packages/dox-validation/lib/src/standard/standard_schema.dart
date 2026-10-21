import 'dart:async';

/// A common interface for validators, based on https://standardschema.dev.
///
/// Other packages (OpenAPI, forms, dox-core) can accept any
/// [StandardSchema] and do not need to know which library made it.
///
/// Dart notes:
/// - [validate] returns a plain result for sync schemas and a [Future]
///   when the schema has async rules.
/// - [StandardResult.issues] is an empty list on success, not `null`.
abstract class StandardSchema<I, O> {
  /// Name of the library that made the schema. Dox schemas use `dox`.
  String get vendor;

  /// Version of the Standard Schema interface. Always `1`.
  int get version;

  /// Check [value] and return the result. It never throws for bad input.
  FutureOr<StandardResult<O>> validate(Object? value);
}

/// The result of [StandardSchema.validate].
abstract class StandardResult<O> {
  /// `true` when there are no issues.
  bool get success;

  /// The output value. Only set when [success] is `true`.
  O? get value;

  /// Problems found. Empty when [success] is `true`.
  List<StandardIssue> get issues;
}

/// One problem found during validation.
abstract class StandardIssue {
  /// Text for people to read.
  String get message;

  /// Where the problem is. Map keys are [String], list indexes are [int].
  List<Object> get path;
}
