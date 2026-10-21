import '../constants/default_messages.dart';
import '../constants/issue_codes.dart';
import '../core/fluent_schema.dart';
import '../core/parse_state.dart';
import '../core/schema.dart';
import '../core/sentinels.dart';

/// Schema for a map with any keys, where every value matches [values].
/// Made by `v.map()`. Keys are checked with [keys] when given.
class MapSchema<V> extends Schema<Map<String, V>>
    with FluentSchema<MapSchema<V>, Map<String, V>> {
  MapSchema(this.values, {this.keys});

  /// Schema for each value.
  final Schema<V> values;

  /// Schema for each key.
  final Schema<String>? keys;

  @override
  bool get isAsync {
    return super.isAsync || values.isAsync || (keys?.isAsync ?? false);
  }

  @override
  Object? parseType(Object? input, ParseState state, List<Object> path) {
    if (input is! Map) {
      _typeIssue(input, state, path);
      return invalid;
    }
    Map<String, V> output = <String, V>{};
    for (MapEntry<dynamic, dynamic> entry in input.entries) {
      String key = entry.key.toString();
      List<Object> childPath = <Object>[...path, key];
      Object? keyOut = keys?.parseValue(key, state, childPath) ?? key;
      Object? valueOut = values.parseValue(entry.value, state, childPath);
      _put(output, keyOut, valueOut);
    }
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
    Map<String, V> output = <String, V>{};
    for (MapEntry<dynamic, dynamic> entry in input.entries) {
      String key = entry.key.toString();
      List<Object> childPath = <Object>[...path, key];
      Schema<String>? keySchema = keys;
      Object? keyOut = keySchema == null
          ? key
          : await keySchema.parseValueAsync(key, state, childPath);
      Object? valueOut =
          await values.parseValueAsync(entry.value, state, childPath);
      _put(output, keyOut, valueOut);
    }
    return output;
  }

  void _put(Map<String, V> output, Object? key, Object? value) {
    if (key is! String || value is Invalid || value is Undefined) {
      return;
    }
    output[key] = value as V;
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
    Map<String, dynamic> json = <String, dynamic>{
      'type': 'object',
      'additionalProperties': values.toJsonSchema(),
    };
    Schema<String>? keySchema = keys;
    if (keySchema != null) {
      json['propertyNames'] = keySchema.toJsonSchema();
    }
    return json;
  }

  @override
  MapSchema<V> copySchema() {
    return copyBaseInto(MapSchema<V>(values, keys: keys));
  }
}
