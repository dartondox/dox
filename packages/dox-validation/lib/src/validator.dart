import 'core/message_resolver.dart';
import 'core/schema.dart';
import 'laravel/rule_registry.dart';
import 'laravel/rules_schema_builder.dart';
import 'schemas/list_schema.dart';
import 'schemas/map_schema.dart';
import 'schemas/number_schemas.dart';
import 'schemas/object_schema.dart';
import 'schemas/scalar_schemas.dart';
import 'schemas/string_schema.dart';
import 'schemas/union_schema.dart';

/// Makes schemas. Use the top-level `v`, or make your own instance
/// with its own [RuleRegistry] (handy for tests and DI).
///
/// ```dart
/// ObjectSchema user = v.object(<String, Schema<Object?>>{
///   'name': v.string().min(3),
///   'age': v.coerce.int().min(18).optional(),
/// });
/// ```
class Validator {
  Validator({RuleRegistry? registry})
      : registry = registry ?? RuleRegistry.withDefaults();

  /// Rules used by [fromRules].
  final RuleRegistry registry;

  /// Schemas that convert text input first. Good for query strings
  /// and form data.
  CoerceBuilder get coerce {
    return CoerceBuilder();
  }

  /// Text.
  StringSchema string() {
    return StringSchema();
  }

  /// Whole number.
  IntSchema int() {
    return IntSchema();
  }

  /// Any number.
  NumSchema num() {
    return NumSchema();
  }

  /// `true` or `false`.
  BoolSchema bool() {
    return BoolSchema();
  }

  /// A [DateTime] object. Use `coerce.date()` for ISO text.
  DateSchema date() {
    return DateSchema();
  }

  /// One of [values]. (`enum` is a reserved word in Dart.)
  EnumSchema<T> enumOf<T>(List<T> values) {
    return EnumSchema<T>(values);
  }

  /// Exactly [value].
  LiteralSchema<T> literal<T>(T value) {
    return LiteralSchema<T>(value);
  }

  /// A list where every item matches [item].
  ListSchema<T> list<T>(Schema<T> item) {
    return ListSchema<T>(item);
  }

  /// A map with known keys.
  ObjectSchema object(Map<String, Schema<Object?>> shape) {
    return ObjectSchema(shape);
  }

  /// A map with any keys. Every value matches [values].
  MapSchema<V> map<V>(Schema<V> values, {Schema<String>? keys}) {
    return MapSchema<V>(values, keys: keys);
  }

  /// The first of [options] that matches.
  UnionSchema<T> union<T>(List<Schema<T>> options) {
    return UnionSchema<T>(options);
  }

  /// Anything, even `null` or missing.
  AnySchema any() {
    return AnySchema();
  }

  /// An uploaded file (a `FileInput`).
  FileSchema file() {
    return FileSchema();
  }

  /// Build a schema from Laravel style rules.
  ///
  /// ```dart
  /// v.fromRules({'email': 'required|email', 'age': 'nullable|integer'});
  /// ```
  ObjectSchema fromRules(
    Map<String, String> rules, {
    Map<String, String> messages = const <String, String>{},
  }) {
    return RulesSchemaBuilder(registry).build(rules, messages: messages);
  }

  /// Add a rule name for [fromRules], like `unique:users,email`.
  void registerRule(String name, RuleBuilder builder) {
    registry.register(name, builder);
  }

  /// The global message resolver. Same as [MessageResolver.global].
  MessageResolver get messages {
    return MessageResolver.global;
  }

  /// Replace the global message resolver (for i18n).
  set messages(MessageResolver resolver) {
    MessageResolver.global = resolver;
  }
}

/// Schemas that convert input first. Made by `v.coerce`.
class CoerceBuilder {
  /// Numbers and booleans become text.
  StringSchema string() {
    return StringSchema(coerce: true);
  }

  /// `"42"` becomes `42`.
  IntSchema int() {
    return IntSchema(coerce: true);
  }

  /// `"4.5"` becomes `4.5`.
  NumSchema num() {
    return NumSchema(coerce: true);
  }

  /// `"true"`, `"1"`, `"yes"`, `"on"` become `true`. The opposites
  /// become `false`.
  BoolSchema bool() {
    return BoolSchema(coerce: true);
  }

  /// ISO text or milliseconds become a [DateTime].
  DateSchema date() {
    return DateSchema(coerce: true);
  }
}
