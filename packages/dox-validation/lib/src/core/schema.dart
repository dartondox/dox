import 'dart:async';

import '../constants/default_messages.dart';
import '../constants/issue_codes.dart';
import '../constants/schema_constants.dart';
import '../schemas/wrapper_schemas.dart';
import '../standard/standard_schema.dart';
import 'json_schema_tools.dart';
import 'message_resolver.dart';
import 'parse_result.dart';
import 'parse_state.dart';
import 'rule.dart';
import 'sentinels.dart';
import 'validation_exception.dart';

/// Base class of every schema. [O] is the output type.
///
/// Subclasses implement [parseType] (type check and coercion),
/// [jsonSchemaBase] and [copySchema].
abstract class Schema<O> implements StandardSchema<Object?, O> {
  /// Rules that run after the type check.
  final List<Rule<O>> rules = <Rule<O>>[];

  /// Text for docs. Set with `.describe()`.
  String? description;

  /// Example values for docs. Set with `.example()`.
  final List<Object?> examples = <Object?>[];

  @override
  String get vendor {
    return SchemaConstants.vendor;
  }

  @override
  int get version {
    return SchemaConstants.standardVersion;
  }

  /// `true` when the value may be missing in an object.
  bool get isOptional {
    return false;
  }

  /// `true` when this schema or a child has async rules.
  bool get isAsync {
    for (Rule<O> rule in rules) {
      if (rule.isAsync) {
        return true;
      }
    }
    return false;
  }

  // ---------------------------------------------------------------------
  // Public parse API
  // ---------------------------------------------------------------------

  /// Return the typed output or throw [ValidationException].
  O parse(Object? input, {MessageResolver? messages}) {
    ParseResult<O> result = safeParse(input, messages: messages);
    if (!result.success) {
      throw ValidationException(result.issues);
    }
    return result.value as O;
  }

  /// Return a [ParseResult]. It never throws for bad input.
  ParseResult<O> safeParse(Object? input, {MessageResolver? messages}) {
    if (isAsync) {
      throw StateError('Schema has async rules. Use parseAsync() instead.');
    }
    ParseState state = ParseState(root: input, resolver: messages);
    Object? output = parseValue(input, state, const <Object>[]);
    return _result(output, state);
  }

  /// Async version of [parse]. Needed for async rules.
  Future<O> parseAsync(Object? input, {MessageResolver? messages}) async {
    ParseResult<O> result = await safeParseAsync(input, messages: messages);
    if (!result.success) {
      throw ValidationException(result.issues);
    }
    return result.value as O;
  }

  /// Async version of [safeParse].
  Future<ParseResult<O>> safeParseAsync(
    Object? input, {
    MessageResolver? messages,
  }) async {
    ParseState state = ParseState(root: input, resolver: messages);
    Object? output = await parseValueAsync(input, state, const <Object>[]);
    return _result(output, state);
  }

  /// Standard Schema entry point.
  @override
  FutureOr<StandardResult<O>> validate(Object? value) {
    if (isAsync) {
      return safeParseAsync(value);
    }
    return safeParse(value);
  }

  ParseResult<O> _result(Object? output, ParseState state) {
    if (state.issues.isNotEmpty) {
      return ParseResult<O>.failure(state.issues);
    }
    if (output is Undefined) {
      return ParseResult<O>.success(null as O);
    }
    return ParseResult<O>.success(output as O);
  }

  // ---------------------------------------------------------------------
  // Wrappers
  // ---------------------------------------------------------------------

  /// The value may be missing. `null` is still not allowed.
  OptionalSchema<O> optional() {
    return OptionalSchema<O>(this);
  }

  /// The value may be `null`. It must still be present in an object.
  NullableSchema<O> nullable() {
    return NullableSchema<O>(this);
  }

  /// The value may be missing or `null`.
  OptionalSchema<O?> nullish() {
    return OptionalSchema<O?>(NullableSchema<O>(this));
  }

  /// Use [value] when the input is missing.
  /// (`default` is a reserved word in Dart.)
  DefaultSchema<O> defaultTo(O value) {
    return DefaultSchema<O>(this, value);
  }

  /// Change the output after it passes validation.
  TransformSchema<O, T> transform<T>(T Function(O value) transformer) {
    return TransformSchema<O, T>(this, transformer);
  }

  // ---------------------------------------------------------------------
  // JSON Schema
  // ---------------------------------------------------------------------

  /// JSON Schema (draft 2020-12, OpenAPI 3.1) for this schema.
  Map<String, dynamic> toJsonSchema() {
    Map<String, dynamic> json = jsonSchemaBase();
    for (Rule<O> rule in rules) {
      json.addAll(rule.toJsonSchema());
    }
    return JsonSchemaTools.addMeta(json, description, examples);
  }

  // ---------------------------------------------------------------------
  // For schema classes
  // ---------------------------------------------------------------------

  /// JSON Schema keys for the type, like `{'type': 'string'}`.
  Map<String, dynamic> jsonSchemaBase();

  /// Make a copy with the same settings. Used by the fluent methods.
  Schema<O> copySchema();

  /// Copy rules and meta data from this schema into [target].
  T copyBaseInto<T extends Schema<O>>(T target) {
    target.rules.addAll(rules);
    target.description = description;
    target.examples.addAll(examples);
    return target;
  }

  /// Check the type and return the output, or [invalid].
  /// [input] is never `null` or [undefined] here.
  Object? parseType(Object? input, ParseState state, List<Object> path);

  /// Async version of [parseType]. Container schemas override it.
  Future<Object?> parseTypeAsync(
    Object? input,
    ParseState state,
    List<Object> path,
  ) async {
    return parseType(input, state, path);
  }

  /// Parse one value: check missing values, the type, then the rules.
  Object? parseValue(Object? input, ParseState state, List<Object> path) {
    if (input is Undefined || input == null) {
      addRequiredIssue(input, state, path);
      return invalid;
    }
    int before = state.issues.length;
    Object? output = parseType(input, state, path);
    return runRules(output, before, state, path);
  }

  /// Async version of [parseValue].
  Future<Object?> parseValueAsync(
    Object? input,
    ParseState state,
    List<Object> path,
  ) async {
    if (input is Undefined || input == null) {
      addRequiredIssue(input, state, path);
      return invalid;
    }
    int before = state.issues.length;
    Object? output = await parseTypeAsync(input, state, path);
    return runRulesAsync(output, before, state, path);
  }

  /// Run [rules] on [output]. Skipped when the value already has issues.
  Object? runRules(
    Object? output,
    int issuesBefore,
    ParseState state,
    List<Object> path,
  ) {
    if (output is Invalid || output is Undefined) {
      return output;
    }
    if (state.issues.length > issuesBefore) {
      return output;
    }
    O typed = output as O;
    for (Rule<O> rule in rules) {
      rule.apply(typed, RuleContext(state: state, path: path, value: typed));
    }
    return typed;
  }

  /// Async version of [runRules].
  Future<Object?> runRulesAsync(
    Object? output,
    int issuesBefore,
    ParseState state,
    List<Object> path,
  ) async {
    if (output is Invalid || output is Undefined) {
      return output;
    }
    if (state.issues.length > issuesBefore) {
      return output;
    }
    O typed = output as O;
    for (Rule<O> rule in rules) {
      await rule.applyAsync(
        typed,
        RuleContext(state: state, path: path, value: typed),
      );
    }
    return typed;
  }

  /// Add the `required` issue.
  void addRequiredIssue(Object? input, ParseState state, List<Object> path) {
    state.addIssue(
      path: path,
      code: IssueCodes.required,
      fallback: DefaultMessages.required,
      value: input,
    );
  }

  /// Add a wrong type issue, like "must be a string".
  void addTypeIssue({
    required String code,
    required String fallback,
    required Object? input,
    required ParseState state,
    required List<Object> path,
  }) {
    state.addIssue(
      path: path,
      code: code,
      fallback: fallback,
      value: input,
      params: <String, Object?>{'received': input.runtimeType.toString()},
    );
  }
}
