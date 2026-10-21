import '../constants/default_messages.dart';
import '../constants/issue_codes.dart';
import '../constants/patterns.dart';
import '../core/rule.dart';
import 'built_in_rule.dart';

/// Text must have at least [min] characters.
class MinLengthRule extends BuiltInRule<String> {
  MinLengthRule(this.min, {super.message})
    : super(
        IssueCodes.minLength,
        DefaultMessages.minLength,
        params: <String, Object?>{'min': min},
        json: <String, dynamic>{'minLength': min},
      );

  final int min;

  @override
  bool check(String value, RuleContext context) {
    return value.length >= min;
  }
}

/// Text may have at most [max] characters.
class MaxLengthRule extends BuiltInRule<String> {
  MaxLengthRule(this.max, {super.message})
    : super(
        IssueCodes.maxLength,
        DefaultMessages.maxLength,
        params: <String, Object?>{'max': max},
        json: <String, dynamic>{'maxLength': max},
      );

  final int max;

  @override
  bool check(String value, RuleContext context) {
    return value.length <= max;
  }
}

/// Text must have exactly [length] characters.
class LengthRule extends BuiltInRule<String> {
  LengthRule(this.length, {super.message})
    : super(
        IssueCodes.length,
        DefaultMessages.length,
        params: <String, Object?>{'length': length},
        json: <String, dynamic>{'minLength': length, 'maxLength': length},
      );

  final int length;

  @override
  bool check(String value, RuleContext context) {
    return value.length == length;
  }
}

/// Text must match [pattern].
class RegexRule extends BuiltInRule<String> {
  RegexRule(
    this.pattern, {
    String code = IssueCodes.regex,
    String defaultMessage = DefaultMessages.regex,
    Map<String, dynamic>? json,
    super.message,
  }) : super(
         code,
         defaultMessage,
         params: <String, Object?>{'pattern': pattern.pattern},
         json: json ?? <String, dynamic>{'pattern': pattern.pattern},
       );

  final RegExp pattern;

  @override
  bool check(String value, RuleContext context) {
    return pattern.hasMatch(value);
  }
}

/// Text must be an email address.
class EmailRule extends RegexRule {
  EmailRule({super.message})
    : super(
        Patterns.email,
        code: IssueCodes.email,
        defaultMessage: DefaultMessages.email,
        json: <String, dynamic>{'format': 'email'},
      );
}

/// Text must be a UUID.
class UuidRule extends RegexRule {
  UuidRule({super.message})
    : super(
        Patterns.uuid,
        code: IssueCodes.uuid,
        defaultMessage: DefaultMessages.uuid,
        json: <String, dynamic>{'format': 'uuid'},
      );
}

/// Text must be an IPv4 address.
class IpRule extends RegexRule {
  IpRule({super.message})
    : super(
        Patterns.ipv4,
        code: IssueCodes.ip,
        defaultMessage: DefaultMessages.ip,
        json: <String, dynamic>{'format': 'ipv4'},
      );
}

/// Text must be an ISO 8601 date time.
class DateTimeStringRule extends BuiltInRule<String> {
  DateTimeStringRule({super.message})
    : super(
        IssueCodes.datetime,
        DefaultMessages.datetime,
        json: <String, dynamic>{'format': 'date-time'},
      );

  @override
  bool check(String value, RuleContext context) {
    return Patterns.isoDateTime.hasMatch(value) &&
        DateTime.tryParse(value) != null;
  }
}

/// Text must be a URL with a scheme and a host, like `https://x.dev`.
class UrlRule extends BuiltInRule<String> {
  UrlRule({super.message})
    : super(
        IssueCodes.url,
        DefaultMessages.url,
        json: <String, dynamic>{'format': 'uri'},
      );

  @override
  bool check(String value, RuleContext context) {
    Uri? uri = Uri.tryParse(value);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }
}

/// Text must start with [prefix].
class StartsWithRule extends BuiltInRule<String> {
  StartsWithRule(this.prefix, {super.message})
    : super(
        IssueCodes.startWith,
        DefaultMessages.startWith,
        params: <String, Object?>{'prefix': prefix},
        json: <String, dynamic>{'pattern': '^${RegExp.escape(prefix)}'},
      );

  final String prefix;

  @override
  bool check(String value, RuleContext context) {
    return value.startsWith(prefix);
  }
}

/// Text must end with [suffix].
class EndsWithRule extends BuiltInRule<String> {
  EndsWithRule(this.suffix, {super.message})
    : super(
        IssueCodes.endWith,
        DefaultMessages.endWith,
        params: <String, Object?>{'suffix': suffix},
        json: <String, dynamic>{'pattern': '${RegExp.escape(suffix)}\$'},
      );

  final String suffix;

  @override
  bool check(String value, RuleContext context) {
    return value.endsWith(suffix);
  }
}

/// Text must contain [text].
class IncludesRule extends BuiltInRule<String> {
  IncludesRule(this.text, {super.message})
    : super(
        IssueCodes.includes,
        DefaultMessages.includes,
        params: <String, Object?>{'text': text},
        json: <String, dynamic>{'pattern': RegExp.escape(text)},
      );

  final String text;

  @override
  bool check(String value, RuleContext context) {
    return value.contains(text);
  }
}
