import '../constants/default_messages.dart';
import '../constants/issue_codes.dart';
import '../core/fluent_schema.dart';
import '../core/parse_state.dart';
import '../core/schema.dart';
import '../core/sentinels.dart';

/// The value must match one of [options]. The first match wins.
/// Made by `v.union()`.
class UnionSchema<O> extends Schema<O> with FluentSchema<UnionSchema<O>, O> {
  UnionSchema(List<Schema<O>> options)
    : options = List<Schema<O>>.unmodifiable(options);

  /// The schemas to try, in order.
  final List<Schema<O>> options;

  @override
  bool get isOptional {
    for (Schema<O> option in options) {
      if (option.isOptional) {
        return true;
      }
    }
    return false;
  }

  @override
  bool get isAsync {
    if (super.isAsync) {
      return true;
    }
    for (Schema<O> option in options) {
      if (option.isAsync) {
        return true;
      }
    }
    return false;
  }

  @override
  Object? parseValue(Object? input, ParseState state, List<Object> path) {
    int before = state.issues.length;
    for (Schema<O> option in options) {
      ParseState trial = state.fork();
      Object? output = option.parseValue(input, trial, path);
      if (trial.issues.isEmpty) {
        return runRules(output, before, state, path);
      }
    }
    _fail(input, state, path);
    return invalid;
  }

  @override
  Future<Object?> parseValueAsync(
    Object? input,
    ParseState state,
    List<Object> path,
  ) async {
    int before = state.issues.length;
    for (Schema<O> option in options) {
      ParseState trial = state.fork();
      Object? output = await option.parseValueAsync(input, trial, path);
      if (trial.issues.isEmpty) {
        return runRulesAsync(output, before, state, path);
      }
    }
    _fail(input, state, path);
    return invalid;
  }

  void _fail(Object? input, ParseState state, List<Object> path) {
    if (input is Undefined || input == null) {
      addRequiredIssue(input, state, path);
      return;
    }
    state.addIssue(
      path: path,
      code: IssueCodes.union,
      fallback: DefaultMessages.union,
      value: input,
    );
  }

  @override
  Object? parseType(Object? input, ParseState state, List<Object> path) {
    return parseValue(input, state, path);
  }

  @override
  Map<String, dynamic> jsonSchemaBase() {
    List<Map<String, dynamic>> anyOf = <Map<String, dynamic>>[];
    for (Schema<O> option in options) {
      anyOf.add(option.toJsonSchema());
    }
    return <String, dynamic>{'anyOf': anyOf};
  }

  @override
  UnionSchema<O> copySchema() {
    return copyBaseInto(UnionSchema<O>(options));
  }
}
