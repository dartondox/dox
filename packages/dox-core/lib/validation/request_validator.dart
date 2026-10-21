import 'package:dox_core/exception/validation_exception.dart';
import 'package:dox_validation/dox_validation.dart' hide ValidationException;

/// Checks request data with `dox_validation`.
///
/// String rules (`'required|email'`) are turned into a schema with
/// `v.fromRules()`. The schema is kept, so the same rules are only parsed
/// once per isolate.
///
/// A failed check throws the dox-core [ValidationException] (HTTP 422)
/// with `{field: message}`, the same shape as before.
class RequestValidator {
  /// [validator] gives the rule registry. Default is the global `v`,
  /// so rules added with `v.registerRule()` work here too.
  RequestValidator({Validator? validator}) : validator = validator ?? v;

  /// The validator that builds schemas from rule strings.
  final Validator validator;

  /// built schemas by rules text.
  /// ponytail: cleared when full, an LRU is not worth it for a few
  /// hundred rule sets.
  final Map<String, ObjectSchema> _schemas = <String, ObjectSchema>{};
  static const int _maxSchemas = 512;

  /// The schema for [rules] and [messages], built once.
  ObjectSchema schemaFor(
    Map<String, String> rules, [
    Map<String, String> messages = const <String, String>{},
  ]) {
    String key = _key(rules, messages);
    ObjectSchema? schema = _schemas[key];
    if (schema != null) return schema;
    if (_schemas.length >= _maxSchemas) _schemas.clear();
    return _schemas[key] = validator.fromRules(rules, messages: messages);
  }

  /// Check [data] with string rules. Returns the validated fields.
  /// Throws a [StateError] when a rule is async (like `unique`),
  /// use [validateAsync] for those.
  Map<String, dynamic> validate(
    Map<String, dynamic> data,
    Map<String, String> rules, {
    Map<String, String> messages = const <String, String>{},
  }) {
    ObjectSchema schema = schemaFor(rules, messages);
    if (schema.isAsync) {
      throw StateError(
        'These rules have an async rule (like unique or exists). '
        'Use `await req.validateAsync(...)` instead.',
      );
    }
    return _output(schema.safeParse(data));
  }

  /// Same as [validate], and also runs async rules like `unique`.
  Future<Map<String, dynamic>> validateAsync(
    Map<String, dynamic> data,
    Map<String, String> rules, {
    Map<String, String> messages = const <String, String>{},
  }) async {
    return validateSchema(schemaFor(rules, messages), data);
  }

  /// Check [data] with any schema and return its typed output.
  Future<O> validateSchema<O>(Schema<O> schema, Object? data) async {
    if (!schema.isAsync) return _output(schema.safeParse(data));
    return _output(await schema.safeParseAsync(data));
  }

  O _output<O>(ParseResult<O> result) {
    if (!result.success) throw ValidationException(message: result.errors);
    return result.value as O;
  }

  String _key(Map<String, String> rules, Map<String, String> messages) {
    StringBuffer buffer = StringBuffer();
    rules.forEach((String field, String rule) {
      buffer
        ..write(field)
        ..write('\u0000')
        ..write(rule)
        ..write('\u0001');
    });
    messages.forEach((String code, String message) {
      buffer
        ..write('\u0002')
        ..write(code)
        ..write('\u0000')
        ..write(message);
    });
    return buffer.toString();
  }
}
