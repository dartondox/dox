import '../constants/default_messages.dart';
import '../constants/issue_codes.dart';
import '../core/fluent_schema.dart';
import '../core/parse_state.dart';
import '../core/schema.dart';
import '../core/sentinels.dart';
import '../rules/number_rules.dart';

/// Shared number methods for [IntSchema] and [NumSchema].
mixin NumberChecks<S extends Schema<N>, N extends num>
    on Schema<N>, FluentSchema<S, N> {
  /// At least [value].
  S min(num value, {String? message}) {
    return use(MinRule<N>(value, message: message));
  }

  /// At most [value].
  S max(num value, {String? message}) {
    return use(MaxRule<N>(value, message: message));
  }

  /// Greater than [value].
  S gt(num value, {String? message}) {
    return use(GreaterThanRule<N>(value, message: message));
  }

  /// Less than [value].
  S lt(num value, {String? message}) {
    return use(LessThanRule<N>(value, message: message));
  }

  /// Greater than zero.
  S positive({String? message}) {
    return gt(0, message: message);
  }

  /// Zero or more.
  S nonNegative({String? message}) {
    return min(0, message: message);
  }

  /// A multiple of [factor].
  S multipleOf(num factor, {String? message}) {
    return use(MultipleOfRule<N>(factor, message: message));
  }
}

/// Schema for whole numbers. Made by `v.int()`.
class IntSchema extends Schema<int>
    with FluentSchema<IntSchema, int>, NumberChecks<IntSchema, int> {
  IntSchema({this.coerce = false});

  /// Accept text like `"42"` and whole doubles like `42.0`.
  final bool coerce;

  @override
  Object? parseType(Object? input, ParseState state, List<Object> path) {
    if (input is int) {
      return input;
    }
    if (coerce) {
      int? value = _coerce(input);
      if (value != null) {
        return value;
      }
    }
    addTypeIssue(
      code: IssueCodes.integer,
      fallback: DefaultMessages.integer,
      input: input,
      state: state,
      path: path,
    );
    return invalid;
  }

  int? _coerce(Object? input) {
    if (input is double && input.isFinite && input == input.truncate()) {
      return input.toInt();
    }
    if (input is String) {
      return int.tryParse(input.trim());
    }
    return null;
  }

  @override
  Map<String, dynamic> jsonSchemaBase() {
    return <String, dynamic>{'type': 'integer'};
  }

  @override
  IntSchema copySchema() {
    return copyBaseInto(IntSchema(coerce: coerce));
  }
}

/// Schema for any number. Made by `v.num()`.
class NumSchema extends Schema<num>
    with FluentSchema<NumSchema, num>, NumberChecks<NumSchema, num> {
  NumSchema({this.coerce = false});

  /// Accept text like `"4.5"`.
  final bool coerce;

  @override
  Object? parseType(Object? input, ParseState state, List<Object> path) {
    if (input is num && !input.isNaN) {
      return input;
    }
    if (coerce && input is String) {
      num? value = num.tryParse(input.trim());
      if (value != null && value.isFinite) {
        return value;
      }
    }
    addTypeIssue(
      code: IssueCodes.numeric,
      fallback: DefaultMessages.numeric,
      input: input,
      state: state,
      path: path,
    );
    return invalid;
  }

  @override
  Map<String, dynamic> jsonSchemaBase() {
    return <String, dynamic>{'type': 'number'};
  }

  @override
  NumSchema copySchema() {
    return copyBaseInto(NumSchema(coerce: coerce));
  }
}
