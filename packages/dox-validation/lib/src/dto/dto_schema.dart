import 'dart:async';

import '../core/issue.dart';
import '../core/message_resolver.dart';
import '../core/parse_result.dart';
import '../core/parse_state.dart';
import '../core/rule.dart';
import '../core/schema.dart';
import '../core/sentinels.dart';
import '../core/validation_exception.dart';
import 'dto_annotations.dart';
import 'dto_state.dart';

/// The checks, the converter and the JSON Schema of one `@Dto` class.
///
/// `dox_builder` writes one `const` subclass per DTO, named `$<Name>Dto`.
/// Reach it with the `static const DtoSchema<T> schema = $<Name>Dto;` line
/// of the class: `CreateUser.schema`.
///
/// It is also a [Schema], so it works inside `v.object()` and `v.list()`.
abstract class DtoSchema<T> extends Schema<T> {
  const DtoSchema();

  /// The DTO class.
  Type get type;

  /// The class name, like `CreateUser`.
  String get name;

  /// Where a request reads this DTO. See [Source].
  Source get source {
    return Source.auto;
  }

  /// `true` when this DTO (or a nested one) has a `validate()` method.
  bool get hasChecks {
    return false;
  }

  @override
  List<Rule<T>> get rules {
    return const <Never>[];
  }

  @override
  String? get description {
    return null;
  }

  @override
  List<Object?> get examples {
    return const <Object?>[];
  }

  // -------------------------------------------------------------------------
  // Written by the generator
  // -------------------------------------------------------------------------

  /// Steps 1 and 2: read the input, convert types, change text, then the
  /// field rules. Gives the object, or `null` when it has errors.
  T? convert(Object? input, DtoState state, List<Object> path);

  /// Step 3: the `validate()` methods, nested DTOs first.
  FutureOr<void> crossCheck(T value, DtoState state, List<Object> path) {}

  /// Step 4: async rules like `@Unique`, in field order.
  Future<void> checkAsync(T value, DtoState state, List<Object> path) async {}

  /// Build the object with no checks, from trusted JSON-like data.
  /// A wrong type throws a [TypeError].
  T fromMap(Map<String, dynamic> input);

  /// The object as a map with the input keys.
  Map<String, dynamic> toMap(T value);

  /// JSON Schema (draft 2020-12) of this DTO.
  @override
  Map<String, dynamic> toJsonSchema();

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Run all checks on [input] and give the object.
  /// Throws a [ValidationException] with the errors.
  ///
  /// [source] `Source.query` reads [input] like a query string (text is
  /// converted). [params] are path params, for `@Unique(ignoreParam:)`.
  Future<T> validateMap(
    Map<String, dynamic> input, {
    Source source = Source.body,
    Map<String, String> params = const <String, String>{},
    MessageResolver? messages,
    String? locale,
  }) async {
    ParseResult<T> result = await safeValidateMap(
      input,
      source: source,
      params: params,
      messages: messages,
      locale: locale,
    );
    if (!result.success) throw ValidationException(result.issues);
    return result.value as T;
  }

  /// Like [validateMap], but it never throws for bad input.
  Future<ParseResult<T>> safeValidateMap(
    Map<String, dynamic> input, {
    Source source = Source.body,
    Map<String, String> params = const <String, String>{},
    MessageResolver? messages,
    String? locale,
  }) {
    return run(
      input,
      DtoState(
        root: input,
        resolver: messages,
        params: params,
        locale: locale,
        text: source == Source.query,
      ),
    );
  }

  /// Run the four steps on [input] with [state]. Each step runs only
  /// when the step before it had no errors.
  Future<ParseResult<T>> run(Object? input, DtoState state) async {
    T? value = convert(input, state, const <Object>[]);
    if (state.issues.isEmpty && hasChecks) {
      await crossCheck(value as T, state, const <Object>[]);
    }
    if (state.issues.isEmpty && isAsync) {
      await checkAsync(value as T, state, const <Object>[]);
    }
    if (state.issues.isNotEmpty) return ParseResult<T>.failure(state.issues);
    return ParseResult<T>.success(value as T);
  }

  // -------------------------------------------------------------------------
  // Schema
  // -------------------------------------------------------------------------

  @override
  Map<String, dynamic> jsonSchemaBase() {
    return toJsonSchema();
  }

  @override
  Object? parseType(Object? input, ParseState state, List<Object> path) {
    DtoState dto = state is DtoState ? state : DtoState.of(state);
    int before = dto.issues.length;
    T? value = convert(input, dto, path);
    if (dto.issues.length != before) return invalid;
    if (hasChecks) {
      FutureOr<void> pending = crossCheck(value as T, dto, path);
      if (pending is Future<void>) {
        throw StateError(
          'DTO $name has an async validate(). Use parseAsync() instead.',
        );
      }
      if (dto.issues.length != before) return invalid;
    }
    return value;
  }

  @override
  Future<Object?> parseTypeAsync(
    Object? input,
    ParseState state,
    List<Object> path,
  ) async {
    DtoState dto = state is DtoState ? state : DtoState.of(state);
    int before = dto.issues.length;
    T? value = convert(input, dto, path);
    if (dto.issues.length != before) return invalid;
    if (hasChecks) await crossCheck(value as T, dto, path);
    if (dto.issues.length != before) return invalid;
    if (isAsync) await checkAsync(value as T, dto, path);
    if (dto.issues.length != before) return invalid;
    return value;
  }
}

/// Errors added by the `validate(DtoErrors errors)` method of a DTO.
///
/// ```dart
/// void validate(DtoErrors errors) {
///   if (password != passwordConfirmation) {
///     errors.add('password_confirmation', 'The passwords do not match');
///   }
/// }
/// ```
class DtoErrors {
  DtoErrors(this._state, this._path);

  final ParseState _state;
  final List<Object> _path;

  /// Add an error for the input [key] (snake_case, not the Dart name).
  /// [message] is used as it is. Use `_root` for an error about the
  /// whole object.
  void add(String key, String message) {
    _state.issues.add(
      ValidationIssue(
        path: List<Object>.unmodifiable(<Object>[..._path, key]),
        code: 'custom',
        message: message,
      ),
    );
  }

  /// `true` when [key] already has an error.
  bool has(String key) {
    String dotted = <Object>[..._path, key].join('.');
    for (ValidationIssue issue in _state.issues) {
      if (issue.dottedPath == dotted) return true;
    }
    return false;
  }
}
