import '../constants/default_messages.dart';
import '../constants/issue_codes.dart';
import '../constants/patterns.dart';
import '../core/fluent_schema.dart';
import '../core/parse_state.dart';
import '../core/schema.dart';
import '../core/sentinels.dart';
import '../rules/string_rules.dart';

/// Schema for text. Made by `v.string()`.
class StringSchema extends Schema<String>
    with FluentSchema<StringSchema, String> {
  StringSchema({
    this.coerce = false,
    this.trimText = false,
    this.caseMode = TextCase.keep,
  });

  /// Turn numbers and booleans into text.
  final bool coerce;

  /// Remove spaces at both ends before the checks.
  final bool trimText;

  /// Change the letter case before the checks.
  final TextCase caseMode;

  /// At least [length] characters.
  StringSchema min(int length, {String? message}) {
    return use(MinLengthRule(length, message: message));
  }

  /// At most [length] characters.
  StringSchema max(int length, {String? message}) {
    return use(MaxLengthRule(length, message: message));
  }

  /// Exactly [size] characters.
  StringSchema length(int size, {String? message}) {
    return use(LengthRule(size, message: message));
  }

  /// At least one character.
  StringSchema nonEmpty({String? message}) {
    return min(1, message: message);
  }

  /// Must be an email address.
  StringSchema email({String? message}) {
    return use(EmailRule(message: message));
  }

  /// Must be a URL.
  StringSchema url({String? message}) {
    return use(UrlRule(message: message));
  }

  /// Must be a UUID.
  StringSchema uuid({String? message}) {
    return use(UuidRule(message: message));
  }

  /// Must be an IPv4 address.
  StringSchema ip({String? message}) {
    return use(IpRule(message: message));
  }

  /// Must be an ISO 8601 date time, like `2024-01-31T10:00:00Z`.
  StringSchema datetime({String? message}) {
    return use(DateTimeStringRule(message: message));
  }

  /// Must match [pattern].
  StringSchema regex(RegExp pattern, {String? message}) {
    return use(RegexRule(pattern, message: message));
  }

  /// Must start with [prefix].
  StringSchema startsWith(String prefix, {String? message}) {
    return use(StartsWithRule(prefix, message: message));
  }

  /// Must end with [suffix].
  StringSchema endsWith(String suffix, {String? message}) {
    return use(EndsWithRule(suffix, message: message));
  }

  /// Must contain [text].
  StringSchema includes(String text, {String? message}) {
    return use(IncludesRule(text, message: message));
  }

  /// Only letters.
  StringSchema alpha({String? message}) {
    return use(RegexRule(Patterns.alpha,
        code: IssueCodes.alpha,
        defaultMessage: DefaultMessages.alpha,
        message: message));
  }

  /// Only letters, dash and underscore.
  StringSchema alphaDash({String? message}) {
    return use(RegexRule(Patterns.alphaDash,
        code: IssueCodes.alphaDash,
        defaultMessage: DefaultMessages.alphaDash,
        message: message));
  }

  /// Only letters and numbers.
  StringSchema alphaNumeric({String? message}) {
    return use(RegexRule(Patterns.alphaNumeric,
        code: IssueCodes.alphaNumeric,
        defaultMessage: DefaultMessages.alphaNumeric,
        message: message));
  }

  /// Remove spaces at both ends before the checks.
  StringSchema trim() {
    return copyBaseInto(
        StringSchema(coerce: coerce, trimText: true, caseMode: caseMode));
  }

  /// Make the text lower case before the checks.
  StringSchema toLowerCase() {
    return copyBaseInto(StringSchema(
        coerce: coerce, trimText: trimText, caseMode: TextCase.lower));
  }

  /// Make the text upper case before the checks.
  StringSchema toUpperCase() {
    return copyBaseInto(StringSchema(
        coerce: coerce, trimText: trimText, caseMode: TextCase.upper));
  }

  @override
  Object? parseType(Object? input, ParseState state, List<Object> path) {
    String? text;
    if (input is String) {
      text = input;
    } else if (coerce && (input is num || input is bool)) {
      text = input.toString();
    }
    if (text == null) {
      addTypeIssue(
        code: IssueCodes.string,
        fallback: DefaultMessages.string,
        input: input,
        state: state,
        path: path,
      );
      return invalid;
    }
    if (trimText) {
      text = text.trim();
    }
    if (caseMode == TextCase.lower) {
      text = text.toLowerCase();
    } else if (caseMode == TextCase.upper) {
      text = text.toUpperCase();
    }
    return text;
  }

  @override
  Map<String, dynamic> jsonSchemaBase() {
    return <String, dynamic>{'type': 'string'};
  }

  @override
  StringSchema copySchema() {
    return copyBaseInto(
        StringSchema(coerce: coerce, trimText: trimText, caseMode: caseMode));
  }
}

/// Letter case change for [StringSchema].
enum TextCase { keep, lower, upper }
