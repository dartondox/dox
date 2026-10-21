import '../constants/default_messages.dart';
import '../constants/issue_codes.dart';
import '../constants/schema_constants.dart';
import '../core/fluent_schema.dart';
import '../core/json_schema_tools.dart';
import '../core/message_resolver.dart';
import '../core/parse_state.dart';
import '../core/schema.dart';
import '../core/sentinels.dart';
import '../rules/collection_rules.dart';

/// Schema for `true` / `false`. Made by `v.bool()`.
class BoolSchema extends Schema<bool> with FluentSchema<BoolSchema, bool> {
  BoolSchema({this.coerce = false});

  /// Accept `"true"`, `"1"`, `"yes"`, `"on"`, `1` and the false words.
  final bool coerce;

  @override
  Object? parseType(Object? input, ParseState state, List<Object> path) {
    if (input is bool) {
      return input;
    }
    if (coerce) {
      String text = input.toString();
      if (ListText.isTrueWord(text)) {
        return true;
      }
      if (ListText.isFalseWord(text)) {
        return false;
      }
    }
    addTypeIssue(
      code: IssueCodes.boolean,
      fallback: DefaultMessages.boolean,
      input: input,
      state: state,
      path: path,
    );
    return invalid;
  }

  @override
  Map<String, dynamic> jsonSchemaBase() {
    return <String, dynamic>{'type': 'boolean'};
  }

  @override
  BoolSchema copySchema() {
    return copyBaseInto(BoolSchema(coerce: coerce));
  }
}

/// Schema for [DateTime]. Made by `v.date()`.
///
/// Without coercion it only accepts [DateTime] objects. Use
/// `v.coerce.date()` for ISO text (JSON, query strings).
class DateSchema extends Schema<DateTime>
    with FluentSchema<DateSchema, DateTime> {
  DateSchema({this.coerce = false});

  /// Accept ISO text and milliseconds since epoch.
  final bool coerce;

  /// On or after [date].
  DateSchema min(DateTime date, {String? message}) {
    return use(AfterOrEqualRule(date, message: message));
  }

  /// On or before [date].
  DateSchema max(DateTime date, {String? message}) {
    return use(BeforeOrEqualRule(date, message: message));
  }

  @override
  Object? parseType(Object? input, ParseState state, List<Object> path) {
    if (input is DateTime) {
      return input;
    }
    if (coerce && input is String) {
      DateTime? date = DateTime.tryParse(input.trim());
      if (date != null) {
        return date;
      }
    }
    if (coerce && input is int) {
      return DateTime.fromMillisecondsSinceEpoch(input, isUtc: true);
    }
    addTypeIssue(
      code: IssueCodes.date,
      fallback: DefaultMessages.date,
      input: input,
      state: state,
      path: path,
    );
    return invalid;
  }

  @override
  Map<String, dynamic> jsonSchemaBase() {
    return <String, dynamic>{'type': 'string', 'format': 'date-time'};
  }

  @override
  DateSchema copySchema() {
    return copyBaseInto(DateSchema(coerce: coerce));
  }
}

/// Value must be one of [values]. Made by `v.enumOf()`.
class EnumSchema<T> extends Schema<T> with FluentSchema<EnumSchema<T>, T> {
  EnumSchema(List<T> values) : values = List<T>.unmodifiable(values);

  /// Allowed values.
  final List<T> values;

  @override
  Object? parseType(Object? input, ParseState state, List<Object> path) {
    for (T value in values) {
      if (value == input) {
        return value;
      }
    }
    state.addIssue(
      path: path,
      code: IssueCodes.inList,
      fallback: DefaultMessages.inList,
      value: input,
      params: <String, Object?>{'values': ListText.joinWithAnd(values)},
    );
    return invalid;
  }

  @override
  Map<String, dynamic> jsonSchemaBase() {
    Map<String, dynamic> json = <String, dynamic>{};
    String? type = JsonSchemaTools.typeOfValues(values);
    if (type != null) {
      json['type'] = type;
    }
    json['enum'] = JsonSchemaTools.toJsonValue(values);
    return json;
  }

  @override
  EnumSchema<T> copySchema() {
    return copyBaseInto(EnumSchema<T>(values));
  }
}

/// Value must equal [value]. Made by `v.literal()`.
class LiteralSchema<T> extends Schema<T>
    with FluentSchema<LiteralSchema<T>, T> {
  LiteralSchema(this.value);

  /// The only allowed value.
  final T value;

  @override
  Object? parseType(Object? input, ParseState state, List<Object> path) {
    if (input == value) {
      return value;
    }
    state.addIssue(
      path: path,
      code: IssueCodes.literal,
      fallback: DefaultMessages.literal,
      value: input,
      params: <String, Object?>{'expected': value},
    );
    return invalid;
  }

  @override
  Map<String, dynamic> jsonSchemaBase() {
    Map<String, dynamic> json = <String, dynamic>{};
    String? type = JsonSchemaTools.typeOfValues(<Object?>[value]);
    if (type != null) {
      json['type'] = type;
    }
    json['const'] = JsonSchemaTools.toJsonValue(value);
    return json;
  }

  @override
  LiteralSchema<T> copySchema() {
    return copyBaseInto(LiteralSchema<T>(value));
  }
}

/// Accepts any value, even `null` or missing. Made by `v.any()`.
class AnySchema extends Schema<Object?> with FluentSchema<AnySchema, Object?> {
  @override
  bool get isOptional {
    return true;
  }

  @override
  Object? parseValue(Object? input, ParseState state, List<Object> path) {
    return runRules(input, state.issues.length, state, path);
  }

  @override
  Future<Object?> parseValueAsync(
    Object? input,
    ParseState state,
    List<Object> path,
  ) {
    return runRulesAsync(input, state.issues.length, state, path);
  }

  @override
  Object? parseType(Object? input, ParseState state, List<Object> path) {
    return input;
  }

  @override
  Map<String, dynamic> jsonSchemaBase() {
    return <String, dynamic>{};
  }

  @override
  AnySchema copySchema() {
    return copyBaseInto(AnySchema());
  }
}

/// Schema for uploaded files. Made by `v.file()`.
/// The value must implement [FileInput].
class FileSchema extends Schema<FileInput>
    with FluentSchema<FileSchema, FileInput> {
  /// Extension must be one of [allowed], like `['pdf']`.
  FileSchema extensions(List<String> allowed, {String? message}) {
    return use(FileExtensionRule(allowed, message: message));
  }

  /// Must be an image (jpg, png, gif and more).
  FileSchema image({String? message}) {
    return use(
      FileExtensionRule(
        SchemaConstants.imageExtensions,
        code: IssueCodes.image,
        message: message,
      ),
    );
  }

  @override
  Object? parseType(Object? input, ParseState state, List<Object> path) {
    if (input is FileInput) {
      return input;
    }
    addTypeIssue(
      code: IssueCodes.file,
      fallback: DefaultMessages.file,
      input: input,
      state: state,
      path: path,
    );
    return invalid;
  }

  @override
  Map<String, dynamic> jsonSchemaBase() {
    return <String, dynamic>{'type': 'string', 'format': 'binary'};
  }

  @override
  FileSchema copySchema() {
    return copyBaseInto(FileSchema());
  }
}
