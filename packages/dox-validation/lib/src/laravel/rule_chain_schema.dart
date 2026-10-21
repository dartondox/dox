import '../core/json_schema_tools.dart';
import '../core/parse_state.dart';
import '../core/rule.dart';
import '../core/schema.dart';
import '../core/sentinels.dart';
import '../schemas/object_schema.dart';

/// Schema for one field of `v.fromRules()`, like `required|email|max:255`.
///
/// Laravel semantics:
/// - missing and not required: skip all other rules
/// - `sometimes`: skip everything when missing, even `required`
/// - `nullable`: `null` is fine and skips other rules
/// - empty text and not required: skip other rules
/// - stop at the first failed rule (one message per field, like old dox)
///
/// The output is the input value, not changed.
class RuleChainSchema extends Schema<Object?> {
  RuleChainSchema({
    required List<Rule<Object?>> fieldRules,
    this.allowNull = false,
    this.sometimes = false,
    this.child,
  }) : fieldRules = List<Rule<Object?>>.unmodifiable(fieldRules);

  /// Rules in the order they were written.
  final List<Rule<Object?>> fieldRules;

  /// `nullable` was in the rule string.
  final bool allowNull;

  /// `sometimes` was in the rule string.
  final bool sometimes;

  /// Schema for nested keys, like `info.name` under `info`.
  final Schema<Object?>? child;

  /// `true` when the rule string has a plain `required` rule.
  bool get isRequired {
    for (Rule<Object?> rule in fieldRules) {
      if (rule.name == 'required') {
        return true;
      }
    }
    return false;
  }

  @override
  bool get isOptional {
    return sometimes || !isRequired;
  }

  @override
  bool get isAsync {
    for (Rule<Object?> rule in fieldRules) {
      if (rule.isAsync) {
        return true;
      }
    }
    return child?.isAsync ?? false;
  }

  @override
  Object? parseValue(Object? input, ParseState state, List<Object> path) {
    if (sometimes && input is Undefined) {
      return undefined;
    }
    for (Rule<Object?> rule in fieldRules) {
      if (!_shouldRun(rule, input)) {
        continue;
      }
      RuleContext context = _context(input, state, path);
      if (!rule.apply(_value(input), context)) {
        return invalid;
      }
    }
    return _finish(input, state, path);
  }

  @override
  Future<Object?> parseValueAsync(
    Object? input,
    ParseState state,
    List<Object> path,
  ) async {
    if (sometimes && input is Undefined) {
      return undefined;
    }
    for (Rule<Object?> rule in fieldRules) {
      if (!_shouldRun(rule, input)) {
        continue;
      }
      RuleContext context = _context(input, state, path);
      if (!await rule.applyAsync(_value(input), context)) {
        return invalid;
      }
    }
    Schema<Object?>? nested = child;
    if (nested == null || _skipOthers(input)) {
      return input;
    }
    return nested.parseValueAsync(input, state, path);
  }

  bool _shouldRun(Rule<Object?> rule, Object? input) {
    if (rule.isImplicit) {
      return true;
    }
    return !_skipOthers(input);
  }

  /// Missing, `null` with `nullable`, or empty text: skip normal rules.
  bool _skipOthers(Object? input) {
    if (input is Undefined) {
      return true;
    }
    if (input == null) {
      return allowNull;
    }
    return input is String && input.trim().isEmpty;
  }

  Object? _finish(Object? input, ParseState state, List<Object> path) {
    Schema<Object?>? nested = child;
    if (nested == null || _skipOthers(input)) {
      return input;
    }
    return nested.parseValue(input, state, path);
  }

  Object? _value(Object? input) {
    return input is Undefined ? null : input;
  }

  RuleContext _context(Object? input, ParseState state, List<Object> path) {
    return RuleContext(state: state, path: path, value: _value(input));
  }

  @override
  Object? parseType(Object? input, ParseState state, List<Object> path) {
    return parseValue(input, state, path);
  }

  @override
  Map<String, dynamic> jsonSchemaBase() {
    Map<String, dynamic> json = child?.toJsonSchema() ?? <String, dynamic>{};
    for (Rule<Object?> rule in fieldRules) {
      json.addAll(rule.toJsonSchema());
    }
    if (allowNull) {
      return JsonSchemaTools.makeNullable(json);
    }
    return json;
  }

  @override
  RuleChainSchema copySchema() {
    return copyBaseInto(
      RuleChainSchema(
        fieldRules: fieldRules,
        allowNull: allowNull,
        sometimes: sometimes,
        child: child,
      ),
    );
  }
}

/// Parent of dotted keys, like `info` for `info.name`. It has no rules
/// of its own. A missing parent is read as an empty map, so
/// `info.name: required` still fails when `info` is missing.
class ImplicitObjectSchema extends Schema<Object?> {
  ImplicitObjectSchema(this.inner);

  /// Schema with the child keys.
  final ObjectSchema inner;

  @override
  bool get isOptional {
    for (Schema<Object?> child in inner.shape.values) {
      if (!child.isOptional) {
        return false;
      }
    }
    return true;
  }

  @override
  bool get isAsync {
    return inner.isAsync;
  }

  @override
  Object? parseValue(Object? input, ParseState state, List<Object> path) {
    Map<dynamic, dynamic> map = input is Map ? input : <String, dynamic>{};
    Object? output = inner.parseType(map, state, path);
    return _clean(input, output);
  }

  @override
  Future<Object?> parseValueAsync(
    Object? input,
    ParseState state,
    List<Object> path,
  ) async {
    Map<dynamic, dynamic> map = input is Map ? input : <String, dynamic>{};
    Object? output = await inner.parseTypeAsync(map, state, path);
    return _clean(input, output);
  }

  Object? _clean(Object? input, Object? output) {
    if (input is! Map && output is Map && output.isEmpty) {
      return undefined;
    }
    return output;
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
  ImplicitObjectSchema copySchema() {
    return copyBaseInto(ImplicitObjectSchema(inner));
  }
}

/// Parent of wildcard keys, like `products` for `products.*.name`.
/// Each list item is checked with [item]. Anything that is not a list
/// is skipped.
class ImplicitListSchema extends Schema<Object?> {
  ImplicitListSchema(this.item);

  /// Schema for each item.
  final Schema<Object?> item;

  @override
  bool get isOptional {
    return true;
  }

  @override
  bool get isAsync {
    return item.isAsync;
  }

  @override
  Object? parseValue(Object? input, ParseState state, List<Object> path) {
    if (input is! List) {
      return undefined;
    }
    List<Object?> output = <Object?>[];
    for (int i = 0; i < input.length; i++) {
      _add(output, item.parseValue(input[i], state, <Object>[...path, i]));
    }
    return output;
  }

  @override
  Future<Object?> parseValueAsync(
    Object? input,
    ParseState state,
    List<Object> path,
  ) async {
    if (input is! List) {
      return undefined;
    }
    List<Object?> output = <Object?>[];
    for (int i = 0; i < input.length; i++) {
      _add(
        output,
        await item.parseValueAsync(input[i], state, <Object>[...path, i]),
      );
    }
    return output;
  }

  void _add(List<Object?> output, Object? value) {
    if (value is Invalid || value is Undefined) {
      return;
    }
    output.add(value);
  }

  @override
  Object? parseType(Object? input, ParseState state, List<Object> path) {
    return parseValue(input, state, path);
  }

  @override
  Map<String, dynamic> jsonSchemaBase() {
    return <String, dynamic>{'type': 'array', 'items': item.toJsonSchema()};
  }

  @override
  ImplicitListSchema copySchema() {
    return copyBaseInto(ImplicitListSchema(item));
  }
}
