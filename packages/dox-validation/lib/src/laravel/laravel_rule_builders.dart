import '../constants/default_messages.dart';
import '../constants/issue_codes.dart';
import '../constants/patterns.dart';
import '../core/message_resolver.dart';
import '../core/refine_rules.dart';
import '../core/rule.dart';
import 'laravel_rules.dart';
import 'rule_registry.dart';

/// Builders for every built-in rule name in `v.fromRules()`.
///
/// It covers all rules of the old dox-core validator.
class LaravelRuleBuilders {
  /// All builders by rule name.
  static Map<String, RuleBuilder> all() {
    return <String, RuleBuilder>{
      'required': required,
      'required_if': requiredIf,
      'required_if_not': requiredIfNot,
      'string': string,
      'numeric': numeric,
      'integer': integer,
      'double': doubleType,
      'boolean': boolean,
      'array': array,
      'json': json,
      'date': date,
      'email': email,
      'ip': ip,
      'url': url,
      'uuid': uuid,
      'alpha': alpha,
      'alpha_dash': alphaDash,
      'alpha_numeric': alphaNumeric,
      'min_length': minLength,
      'max_length': maxLength,
      'length_between': lengthBetween,
      'between': between,
      'greater_than': greaterThan,
      'less_than': lessThan,
      'min': min,
      'max': max,
      'in': inList,
      'not_in': notIn,
      'start_with': startWith,
      'end_with': endWith,
      'confirmed': confirmed,
      'image': image,
      'file': file,
    };
  }

  // Presence -------------------------------------------------------------

  static Rule<Object?> required(RuleDefinition d) {
    return RequiredRule();
  }

  static Rule<Object?> requiredIf(RuleDefinition d) {
    return RequiredIfRule(d.arg(0), d.args.skip(1).toList());
  }

  static Rule<Object?> requiredIfNot(RuleDefinition d) {
    return RequiredIfRule(d.arg(0), d.args.skip(1).toList(), negate: true);
  }

  // Types ----------------------------------------------------------------

  static Rule<Object?> string(RuleDefinition d) {
    return ValueTestRule(
      IssueCodes.string,
      DefaultMessages.string,
      isString,
      json: <String, dynamic>{'type': 'string'},
    );
  }

  static Rule<Object?> numeric(RuleDefinition d) {
    return ValueTestRule(
      IssueCodes.numeric,
      DefaultMessages.numeric,
      isNumeric,
      json: <String, dynamic>{'type': 'number'},
    );
  }

  static Rule<Object?> integer(RuleDefinition d) {
    return ValueTestRule(
      IssueCodes.integer,
      DefaultMessages.integer,
      isInteger,
      json: <String, dynamic>{'type': 'integer'},
    );
  }

  static Rule<Object?> doubleType(RuleDefinition d) {
    return ValueTestRule(
      IssueCodes.double,
      DefaultMessages.double,
      isDouble,
      json: <String, dynamic>{'type': 'number'},
    );
  }

  static Rule<Object?> boolean(RuleDefinition d) {
    return ValueTestRule(
      IssueCodes.boolean,
      DefaultMessages.boolean,
      isBoolean,
      json: <String, dynamic>{'type': 'boolean'},
    );
  }

  static Rule<Object?> array(RuleDefinition d) {
    return ValueTestRule(
      IssueCodes.array,
      DefaultMessages.array,
      isArray,
      json: <String, dynamic>{'type': 'array'},
    );
  }

  static Rule<Object?> json(RuleDefinition d) {
    return ValueTestRule(
      IssueCodes.json,
      DefaultMessages.json,
      isMap,
      json: <String, dynamic>{'type': 'object'},
    );
  }

  static Rule<Object?> date(RuleDefinition d) {
    return ValueTestRule(
      IssueCodes.date,
      DefaultMessages.date,
      isDate,
      json: <String, dynamic>{'type': 'string', 'format': 'date'},
    );
  }

  // Formats --------------------------------------------------------------

  static Rule<Object?> email(RuleDefinition d) {
    return _pattern(
      IssueCodes.email,
      DefaultMessages.email,
      Patterns.email,
      <String, dynamic>{'type': 'string', 'format': 'email'},
    );
  }

  static Rule<Object?> ip(RuleDefinition d) {
    return _pattern(
      IssueCodes.ip,
      DefaultMessages.ip,
      Patterns.ipv4,
      <String, dynamic>{'type': 'string', 'format': 'ipv4'},
    );
  }

  static Rule<Object?> uuid(RuleDefinition d) {
    return _pattern(
      IssueCodes.uuid,
      DefaultMessages.uuid,
      Patterns.uuid,
      <String, dynamic>{'type': 'string', 'format': 'uuid'},
    );
  }

  static Rule<Object?> alpha(RuleDefinition d) {
    return _pattern(
      IssueCodes.alpha,
      DefaultMessages.alpha,
      Patterns.alpha,
      <String, dynamic>{'pattern': Patterns.alpha.pattern},
    );
  }

  static Rule<Object?> alphaDash(RuleDefinition d) {
    return _pattern(
      IssueCodes.alphaDash,
      DefaultMessages.alphaDash,
      Patterns.alphaDash,
      <String, dynamic>{'pattern': Patterns.alphaDash.pattern},
    );
  }

  static Rule<Object?> alphaNumeric(RuleDefinition d) {
    return _pattern(
      IssueCodes.alphaNumeric,
      DefaultMessages.alphaNumeric,
      Patterns.alphaNumeric,
      <String, dynamic>{'pattern': Patterns.alphaNumeric.pattern},
    );
  }

  static Rule<Object?> url(RuleDefinition d) {
    return ValueTestRule(
      IssueCodes.url,
      DefaultMessages.url,
      isUrl,
      json: <String, dynamic>{'type': 'string', 'format': 'uri'},
    );
  }

  static Rule<Object?> startWith(RuleDefinition d) {
    String prefix = d.arg(0);
    return CallbackRule(
      name: IssueCodes.startWith,
      defaultMessage: DefaultMessages.startWith,
      params: <String, Object?>{
        'prefix': prefix,
        'args': <Object?>[prefix],
      },
      callback: _StartsWith(prefix).check,
    );
  }

  static Rule<Object?> endWith(RuleDefinition d) {
    String suffix = d.arg(0);
    return CallbackRule(
      name: IssueCodes.endWith,
      defaultMessage: DefaultMessages.endWith,
      params: <String, Object?>{
        'suffix': suffix,
        'args': <Object?>[suffix],
      },
      callback: _EndsWith(suffix).check,
    );
  }

  // Sizes ----------------------------------------------------------------

  static Rule<Object?> minLength(RuleDefinition d) {
    num limit = _number(d, 0);
    return CallbackRule(
      name: IssueCodes.minLength,
      defaultMessage: DefaultMessages.minLength,
      params: <String, Object?>{
        'min': limit,
        'args': <Object?>[d.arg(0)],
      },
      callback: _Length(limit, null).check,
    )..jsonHint = <String, dynamic>{'minLength': limit};
  }

  static Rule<Object?> maxLength(RuleDefinition d) {
    num limit = _number(d, 0);
    return CallbackRule(
      name: IssueCodes.maxLength,
      defaultMessage: DefaultMessages.maxLength,
      params: <String, Object?>{
        'max': limit,
        'args': <Object?>[d.arg(0)],
      },
      callback: _Length(null, limit).check,
    )..jsonHint = <String, dynamic>{'maxLength': limit};
  }

  static Rule<Object?> lengthBetween(RuleDefinition d) {
    List<num> range = _range(d);
    return CallbackRule(
        name: IssueCodes.lengthBetween,
        defaultMessage: DefaultMessages.lengthBetween,
        params: <String, Object?>{
          'min': range[0],
          'max': range[1],
          'args': <Object?>[d.arg(0), d.arg(1)],
        },
        callback: _Length(range[0], range[1]).check,
      )
      ..jsonHint = <String, dynamic>{
        'minLength': range[0],
        'maxLength': range[1],
      };
  }

  static Rule<Object?> between(RuleDefinition d) {
    List<num> range = _range(d);
    return CallbackRule(
      name: IssueCodes.between,
      defaultMessage: DefaultMessages.between,
      params: <String, Object?>{
        'min': range[0],
        'max': range[1],
        'args': <Object?>[d.arg(0), d.arg(1)],
      },
      callback: _NumberRange(range[0], range[1], inclusive: true).check,
    )..jsonHint = <String, dynamic>{'minimum': range[0], 'maximum': range[1]};
  }

  static Rule<Object?> greaterThan(RuleDefinition d) {
    num limit = _number(d, 0);
    return CallbackRule(
      name: IssueCodes.greaterThan,
      defaultMessage: DefaultMessages.greaterThan,
      params: <String, Object?>{
        'min': limit,
        'args': <Object?>[d.arg(0)],
      },
      callback: _NumberRange(limit, null, inclusive: false).check,
    )..jsonHint = <String, dynamic>{'exclusiveMinimum': limit};
  }

  static Rule<Object?> lessThan(RuleDefinition d) {
    num limit = _number(d, 0);
    return CallbackRule(
      name: IssueCodes.lessThan,
      defaultMessage: DefaultMessages.lessThan,
      params: <String, Object?>{
        'max': limit,
        'args': <Object?>[d.arg(0)],
      },
      callback: _NumberRange(null, limit, inclusive: false).check,
    )..jsonHint = <String, dynamic>{'exclusiveMaximum': limit};
  }

  static Rule<Object?> min(RuleDefinition d) {
    return SizeRule(_number(d, 0), isMax: false, kind: _sizeKind(d));
  }

  static Rule<Object?> max(RuleDefinition d) {
    return SizeRule(_number(d, 0), isMax: true, kind: _sizeKind(d));
  }

  // Lists of values ------------------------------------------------------

  static Rule<Object?> inList(RuleDefinition d) {
    String joined = ListText.joinWithAnd(d.args);
    return CallbackRule(
      name: IssueCodes.inList,
      defaultMessage: DefaultMessages.inList,
      params: <String, Object?>{
        'values': joined,
        'args': <Object?>[joined],
      },
      callback: _OneOf(d.args, expected: true).check,
    )..jsonHint = <String, dynamic>{'enum': d.args};
  }

  static Rule<Object?> notIn(RuleDefinition d) {
    String joined = ListText.joinWithAnd(d.args);
    return CallbackRule(
      name: IssueCodes.notIn,
      defaultMessage: DefaultMessages.notIn,
      params: <String, Object?>{
        'values': joined,
        'args': <Object?>[joined],
      },
      callback: _OneOf(d.args, expected: false).check,
    );
  }

  // Other ----------------------------------------------------------------

  static Rule<Object?> confirmed(RuleDefinition d) {
    return ConfirmedRule(d.arg(0));
  }

  static Rule<Object?> image(RuleDefinition d) {
    List<String> extensions = d.args.isEmpty
        ? FileValueRule.imageExtensions
        : d.args;
    return FileValueRule(IssueCodes.image, extensions);
  }

  static Rule<Object?> file(RuleDefinition d) {
    return FileValueRule(IssueCodes.file, d.args);
  }

  // Tests ----------------------------------------------------------------

  static bool isString(Object? value) {
    return value is String;
  }

  static bool isNumeric(Object? value) {
    return num.tryParse(value.toString()) != null;
  }

  static bool isInteger(Object? value) {
    return int.tryParse(value.toString()) != null;
  }

  static bool isDouble(Object? value) {
    return double.tryParse(value.toString()) != null;
  }

  /// Laravel style: `true`, `false`, `1`, `0`, `"1"`, `"0"`.
  static bool isBoolean(Object? value) {
    return value is bool ||
        value == 1 ||
        value == 0 ||
        value == '1' ||
        value == '0';
  }

  static bool isArray(Object? value) {
    return value is List;
  }

  static bool isMap(Object? value) {
    return value is Map;
  }

  static bool isDate(Object? value) {
    return value is DateTime || DateTime.tryParse(value.toString()) != null;
  }

  static bool isUrl(Object? value) {
    Uri? uri = Uri.tryParse(value.toString());
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }

  // Helpers --------------------------------------------------------------

  static Rule<Object?> _pattern(
    String code,
    String message,
    RegExp pattern,
    Map<String, dynamic> json,
  ) {
    return CallbackRule(
      name: code,
      defaultMessage: message,
      callback: _Matches(pattern).check,
    )..jsonHint = json;
  }

  static num _number(RuleDefinition d, int index) {
    num? value = num.tryParse(d.arg(index));
    if (value == null) {
      throw ArgumentError(
        'Rule "${d.name}" on "${d.field}" needs a number, got "${d.arg(index)}".',
      );
    }
    return value;
  }

  static List<num> _range(RuleDefinition d) {
    num a = _number(d, 0);
    num b = _number(d, 1);
    return a <= b ? <num>[a, b] : <num>[b, a];
  }

  static SizeKind _sizeKind(RuleDefinition d) {
    for (String name in d.fieldRules) {
      if (name == 'numeric' || name == 'integer' || name == 'double') {
        return SizeKind.number;
      }
    }
    for (String name in d.fieldRules) {
      if (name == 'string' || name == 'email' || name == 'url') {
        return SizeKind.text;
      }
      if (name == 'array') {
        return SizeKind.list;
      }
    }
    return SizeKind.unknown;
  }
}

class _Matches {
  _Matches(this.pattern);

  final RegExp pattern;

  bool check(Object? value, RuleContext context) {
    return pattern.hasMatch(value.toString());
  }
}

class _StartsWith {
  _StartsWith(this.prefix);

  final String prefix;

  bool check(Object? value, RuleContext context) {
    return value.toString().startsWith(prefix);
  }
}

class _EndsWith {
  _EndsWith(this.suffix);

  final String suffix;

  bool check(Object? value, RuleContext context) {
    return value.toString().endsWith(suffix);
  }
}

class _Length {
  _Length(this.min, this.max);

  final num? min;
  final num? max;

  bool check(Object? value, RuleContext context) {
    int length = value.toString().length;
    num? low = min;
    num? high = max;
    if (low != null && length < low) {
      return false;
    }
    if (high != null && length > high) {
      return false;
    }
    return true;
  }
}

class _NumberRange {
  _NumberRange(this.min, this.max, {required this.inclusive});

  final num? min;
  final num? max;
  final bool inclusive;

  bool check(Object? value, RuleContext context) {
    num? number = ValueTools.asNumber(value);
    if (number == null) {
      return false;
    }
    num? low = min;
    num? high = max;
    if (low != null && (inclusive ? number < low : number <= low)) {
      return false;
    }
    if (high != null && (inclusive ? number > high : number >= high)) {
      return false;
    }
    return true;
  }
}

class _OneOf {
  _OneOf(this.values, {required this.expected});

  final List<String> values;
  final bool expected;

  bool check(Object? value, RuleContext context) {
    return values.contains(value.toString()) == expected;
  }
}
