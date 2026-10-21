import '../core/fluent_schema.dart';
import '../core/json_schema_tools.dart';
import '../core/parse_state.dart';
import '../core/schema.dart';
import '../core/sentinels.dart';

/// The value may be missing. Made by `.optional()`.
class OptionalSchema<O> extends BaseSchema<O?>
    with FluentSchema<OptionalSchema<O>, O?> {
  OptionalSchema(this.inner);

  /// The wrapped schema.
  final Schema<O> inner;

  @override
  bool get isOptional {
    return true;
  }

  @override
  bool get isAsync {
    return super.isAsync || inner.isAsync;
  }

  @override
  Object? parseValue(Object? input, ParseState state, List<Object> path) {
    if (input is Undefined) {
      return undefined;
    }
    int before = state.issues.length;
    Object? output = inner.parseValue(input, state, path);
    return runRules(output, before, state, path);
  }

  @override
  Future<Object?> parseValueAsync(
    Object? input,
    ParseState state,
    List<Object> path,
  ) async {
    if (input is Undefined) {
      return undefined;
    }
    int before = state.issues.length;
    Object? output = await inner.parseValueAsync(input, state, path);
    return runRulesAsync(output, before, state, path);
  }

  @override
  Object? parseType(Object? input, ParseState state, List<Object> path) {
    return inner.parseType(input, state, path);
  }

  @override
  Map<String, dynamic> jsonSchemaBase() {
    return inner.toJsonSchema();
  }

  @override
  OptionalSchema<O> copySchema() {
    return copyBaseInto(OptionalSchema<O>(inner));
  }
}

/// The value may be `null`. Made by `.nullable()`.
class NullableSchema<O> extends BaseSchema<O?>
    with FluentSchema<NullableSchema<O>, O?> {
  NullableSchema(this.inner);

  /// The wrapped schema.
  final Schema<O> inner;

  @override
  bool get isOptional {
    return inner.isOptional;
  }

  @override
  bool get isAsync {
    return super.isAsync || inner.isAsync;
  }

  @override
  Object? parseValue(Object? input, ParseState state, List<Object> path) {
    if (input == null) {
      return null;
    }
    int before = state.issues.length;
    Object? output = inner.parseValue(input, state, path);
    return runRules(output, before, state, path);
  }

  @override
  Future<Object?> parseValueAsync(
    Object? input,
    ParseState state,
    List<Object> path,
  ) async {
    if (input == null) {
      return null;
    }
    int before = state.issues.length;
    Object? output = await inner.parseValueAsync(input, state, path);
    return runRulesAsync(output, before, state, path);
  }

  @override
  Object? parseType(Object? input, ParseState state, List<Object> path) {
    return inner.parseType(input, state, path);
  }

  @override
  Map<String, dynamic> jsonSchemaBase() {
    return JsonSchemaTools.makeNullable(inner.toJsonSchema());
  }

  @override
  NullableSchema<O> copySchema() {
    return copyBaseInto(NullableSchema<O>(inner));
  }
}

/// Uses a default value when the input is missing. Made by `.defaultTo()`.
class DefaultSchema<O> extends BaseSchema<O>
    with FluentSchema<DefaultSchema<O>, O> {
  DefaultSchema(this.inner, this.defaultValue);

  /// The wrapped schema.
  final Schema<O> inner;

  /// Value used when the input is missing.
  final O defaultValue;

  @override
  bool get isOptional {
    return true;
  }

  @override
  bool get isAsync {
    return super.isAsync || inner.isAsync;
  }

  @override
  Object? parseValue(Object? input, ParseState state, List<Object> path) {
    if (input is Undefined) {
      return defaultValue;
    }
    int before = state.issues.length;
    Object? output = inner.parseValue(input, state, path);
    return runRules(output, before, state, path);
  }

  @override
  Future<Object?> parseValueAsync(
    Object? input,
    ParseState state,
    List<Object> path,
  ) async {
    if (input is Undefined) {
      return defaultValue;
    }
    int before = state.issues.length;
    Object? output = await inner.parseValueAsync(input, state, path);
    return runRulesAsync(output, before, state, path);
  }

  @override
  Object? parseType(Object? input, ParseState state, List<Object> path) {
    return inner.parseType(input, state, path);
  }

  @override
  Map<String, dynamic> jsonSchemaBase() {
    Map<String, dynamic> json = inner.toJsonSchema();
    json['default'] = JsonSchemaTools.toJsonValue(defaultValue);
    return json;
  }

  @override
  DefaultSchema<O> copySchema() {
    return copyBaseInto(DefaultSchema<O>(inner, defaultValue));
  }
}

/// Changes the output after the inner schema passes.
/// Made by `.transform()`. JSON Schema shows the input shape.
class TransformSchema<I, O> extends BaseSchema<O>
    with FluentSchema<TransformSchema<I, O>, O> {
  TransformSchema(this.inner, this.transformer);

  /// The wrapped schema.
  final Schema<I> inner;

  /// Function that makes the new output.
  final O Function(I value) transformer;

  @override
  bool get isOptional {
    return inner.isOptional;
  }

  @override
  bool get isAsync {
    return super.isAsync || inner.isAsync;
  }

  @override
  Object? parseValue(Object? input, ParseState state, List<Object> path) {
    int before = state.issues.length;
    Object? output = inner.parseValue(input, state, path);
    return runRules(_apply(output, before, state), before, state, path);
  }

  @override
  Future<Object?> parseValueAsync(
    Object? input,
    ParseState state,
    List<Object> path,
  ) async {
    int before = state.issues.length;
    Object? output = await inner.parseValueAsync(input, state, path);
    return runRulesAsync(_apply(output, before, state), before, state, path);
  }

  Object? _apply(Object? output, int before, ParseState state) {
    if (output is Invalid || output is Undefined) {
      return output;
    }
    if (state.issues.length > before) {
      return invalid;
    }
    return transformer(output as I);
  }

  @override
  Object? parseType(Object? input, ParseState state, List<Object> path) {
    return parseValue(input, state, path);
  }

  @override
  Map<String, dynamic> jsonSchemaBase() {
    return inner.toJsonSchema();
  }

  @override
  TransformSchema<I, O> copySchema() {
    return copyBaseInto(TransformSchema<I, O>(inner, transformer));
  }
}
