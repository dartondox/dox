import '../constants/default_messages.dart';
import '../constants/issue_codes.dart';
import '../core/fluent_schema.dart';
import '../core/message_resolver.dart';
import '../core/parse_state.dart';
import '../core/schema.dart';
import '../core/sentinels.dart';
import 'wrapper_schemas.dart';

/// What an [ObjectSchema] does with keys that are not in its shape.
enum UnknownKeys {
  /// Drop them from the output. This is the default.
  strip,

  /// Add an `unrecognized_keys` issue.
  strict,

  /// Keep them in the output as they are.
  passthrough,
}

/// Schema for a map with known keys. Made by `v.object()`.
/// The output is a new `Map<String, dynamic>`.
class ObjectSchema extends BaseSchema<Map<String, dynamic>>
    with FluentSchema<ObjectSchema, Map<String, dynamic>> {
  ObjectSchema(
    Map<String, Schema<Object?>> shape, {
    this.unknownKeys = UnknownKeys.strip,
  }) : shape = Map<String, Schema<Object?>>.unmodifiable(shape);

  /// Schema for each key.
  final Map<String, Schema<Object?>> shape;

  /// What to do with keys that are not in [shape].
  final UnknownKeys unknownKeys;

  @override
  bool get isAsync {
    if (super.isAsync) {
      return true;
    }
    for (Schema<Object?> child in shape.values) {
      if (child.isAsync) {
        return true;
      }
    }
    return false;
  }

  /// Unknown keys are an error.
  ObjectSchema strict() {
    return _withShape(shape, UnknownKeys.strict);
  }

  /// Keep unknown keys in the output.
  ObjectSchema passthrough() {
    return _withShape(shape, UnknownKeys.passthrough);
  }

  /// Drop unknown keys from the output (the default).
  ObjectSchema strip() {
    return _withShape(shape, UnknownKeys.strip);
  }

  /// Add or replace keys.
  ObjectSchema extend(Map<String, Schema<Object?>> more) {
    return _withShape(<String, Schema<Object?>>{
      ...shape,
      ...more,
    }, unknownKeys);
  }

  /// Keep only [keys].
  ObjectSchema pick(List<String> keys) {
    Map<String, Schema<Object?>> next = <String, Schema<Object?>>{};
    for (String key in keys) {
      Schema<Object?>? child = shape[key];
      if (child != null) {
        next[key] = child;
      }
    }
    return _withShape(next, unknownKeys);
  }

  /// Remove [keys].
  ObjectSchema omit(List<String> keys) {
    Map<String, Schema<Object?>> next = <String, Schema<Object?>>{...shape};
    for (String key in keys) {
      next.remove(key);
    }
    return _withShape(next, unknownKeys);
  }

  /// Make every key optional. Good for PATCH requests.
  ObjectSchema partial() {
    Map<String, Schema<Object?>> next = <String, Schema<Object?>>{};
    for (MapEntry<String, Schema<Object?>> entry in shape.entries) {
      Schema<Object?> child = entry.value;
      next[entry.key] = child.isOptional
          ? child
          : OptionalSchema<Object?>(child);
    }
    return _withShape(next, unknownKeys);
  }

  ObjectSchema _withShape(
    Map<String, Schema<Object?>> nextShape,
    UnknownKeys keys,
  ) {
    return copyBaseInto(ObjectSchema(nextShape, unknownKeys: keys));
  }

  @override
  Object? parseType(Object? input, ParseState state, List<Object> path) {
    if (input is! Map) {
      _typeIssue(input, state, path);
      return invalid;
    }
    Map<String, dynamic> output = <String, dynamic>{};
    for (MapEntry<String, Schema<Object?>> entry in shape.entries) {
      Object? value = entry.value.parseValue(
        _read(input, entry.key),
        state,
        <Object>[...path, entry.key],
      );
      _put(output, entry.key, value);
    }
    _unknown(input, output, state, path);
    return output;
  }

  @override
  Future<Object?> parseTypeAsync(
    Object? input,
    ParseState state,
    List<Object> path,
  ) async {
    if (input is! Map) {
      _typeIssue(input, state, path);
      return invalid;
    }
    Map<String, dynamic> output = <String, dynamic>{};
    for (MapEntry<String, Schema<Object?>> entry in shape.entries) {
      Object? value = await entry.value.parseValueAsync(
        _read(input, entry.key),
        state,
        <Object>[...path, entry.key],
      );
      _put(output, entry.key, value);
    }
    _unknown(input, output, state, path);
    return output;
  }

  Object? _read(Map<dynamic, dynamic> input, String key) {
    if (input.containsKey(key)) {
      return input[key];
    }
    return undefined;
  }

  void _put(Map<String, dynamic> output, String key, Object? value) {
    if (value is Invalid || value is Undefined) {
      return;
    }
    output[key] = value;
  }

  void _unknown(
    Map<dynamic, dynamic> input,
    Map<String, dynamic> output,
    ParseState state,
    List<Object> path,
  ) {
    if (unknownKeys == UnknownKeys.strip) {
      return;
    }
    List<String> extra = <String>[];
    for (Object? key in input.keys) {
      String name = key.toString();
      if (!shape.containsKey(name)) {
        extra.add(name);
        if (unknownKeys == UnknownKeys.passthrough) {
          output[name] = input[key];
        }
      }
    }
    if (unknownKeys == UnknownKeys.strict && extra.isNotEmpty) {
      state.addIssue(
        path: path,
        code: IssueCodes.unrecognizedKeys,
        fallback: DefaultMessages.unrecognizedKeys,
        params: <String, Object?>{'keys': ListText.joinWithAnd(extra)},
      );
    }
  }

  void _typeIssue(Object? input, ParseState state, List<Object> path) {
    addTypeIssue(
      code: IssueCodes.object,
      fallback: DefaultMessages.object,
      input: input,
      state: state,
      path: path,
    );
  }

  @override
  Map<String, dynamic> jsonSchemaBase() {
    Map<String, dynamic> properties = <String, dynamic>{};
    List<String> required = <String>[];
    for (MapEntry<String, Schema<Object?>> entry in shape.entries) {
      properties[entry.key] = entry.value.toJsonSchema();
      if (!entry.value.isOptional) {
        required.add(entry.key);
      }
    }
    Map<String, dynamic> json = <String, dynamic>{
      'type': 'object',
      'properties': properties,
    };
    if (required.isNotEmpty) {
      json['required'] = required;
    }
    if (unknownKeys == UnknownKeys.strict) {
      json['additionalProperties'] = false;
    }
    return json;
  }

  @override
  ObjectSchema copySchema() {
    return copyBaseInto(ObjectSchema(shape, unknownKeys: unknownKeys));
  }
}
