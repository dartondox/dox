import '../constants/default_messages.dart';
import '../constants/issue_codes.dart';
import '../constants/schema_constants.dart';
import '../core/message_resolver.dart';
import '../core/rule.dart';
import '../core/sentinels.dart';
import '../rules/built_in_rule.dart';
import '../rules/collection_rules.dart';

/// Rules for `v.fromRules()`. They work on any value, like the old
/// dox-core validator: most rules read the value as text.
class ValueTools {
  /// `true` for missing, `null`, blank text, empty list or empty map.
  static bool isEmpty(Object? value) {
    if (value == null || value is Undefined) {
      return true;
    }
    if (value is String) {
      return value.trim().isEmpty;
    }
    if (value is List) {
      return value.isEmpty;
    }
    if (value is Map) {
      return value.isEmpty;
    }
    return false;
  }

  /// The value as a number, or `null`.
  static num? asNumber(Object? value) {
    if (value is num) {
      return value;
    }
    if (value is String) {
      return num.tryParse(value.trim());
    }
    return null;
  }

  /// Turn `undefined` into `null` and everything else into text.
  static String text(Object? value) {
    if (value is Undefined) {
      return 'null';
    }
    return value.toString();
  }
}

/// `required`: value must be present and not empty.
class RequiredRule extends BuiltInRule<Object?> {
  RequiredRule({super.message})
    : super(IssueCodes.required, DefaultMessages.required);

  @override
  bool get isImplicit {
    return true;
  }

  @override
  bool check(Object? value, RuleContext context) {
    return !ValueTools.isEmpty(value);
  }
}

/// `required_if:other,value1,value2` and `required_if_not:other,value`.
class RequiredIfRule extends BuiltInRule<Object?> {
  RequiredIfRule(this.other, this.values, {this.negate = false, super.message})
    : super(
        negate ? IssueCodes.requiredIfNot : IssueCodes.requiredIf,
        DefaultMessages.required,
        params: <String, Object?>{
          'other': other,
          'values': ListText.joinWithAnd(values),
          'args': <Object?>[other, ...values],
        },
      );

  /// Dotted path of the other field, from the root.
  final String other;

  /// Values of the other field that make this field required.
  final List<String> values;

  /// When `true`, required if the other field is NOT one of [values].
  final bool negate;

  @override
  bool get isImplicit {
    return true;
  }

  @override
  bool check(Object? value, RuleContext context) {
    String otherText = ValueTools.text(context.lookup(other));
    bool matched = values.contains(otherText);
    bool needed = negate ? !matched : matched;
    if (!needed) {
      return true;
    }
    return !ValueTools.isEmpty(value);
  }
}

/// A rule from a simple test on the value.
class ValueTestRule extends BuiltInRule<Object?> {
  ValueTestRule(
    super.name,
    super.defaultMessage,
    this.test, {
    super.params,
    super.json,
    super.message,
  });

  /// The test.
  final bool Function(Object? value) test;

  @override
  bool check(Object? value, RuleContext context) {
    return test(value);
  }
}

/// `min:n` and `max:n`. Checks text length, list size or number value.
///
/// It checks a number when the field has `numeric` / `integer` /
/// `double`, or when the value looks like a number and the field has
/// no `string` rule (old dox behavior).
class SizeRule extends BuiltInRule<Object?> {
  SizeRule(this.limit, {required this.isMax, required this.kind, super.message})
    : super(
        isMax ? IssueCodes.max : IssueCodes.min,
        isMax ? DefaultMessages.max : DefaultMessages.min,
        params: <String, Object?>{
          isMax ? 'max' : 'min': limit,
          'args': <Object?>[limit],
        },
      );

  /// The limit.
  final num limit;

  /// `true` for `max`, `false` for `min`.
  final bool isMax;

  /// Known kind of the field from other rules.
  final SizeKind kind;

  @override
  bool check(Object? value, RuleContext context) {
    num? size = _size(value);
    if (size == null) {
      return false;
    }
    return isMax ? size <= limit : size >= limit;
  }

  @override
  bool apply(Object? value, RuleContext context) {
    if (check(value, context)) {
      return true;
    }
    context.fail(this, fallback: _message(value));
    return false;
  }

  String _message(Object? value) {
    if (value is List || value is Map) {
      return isMax ? DefaultMessages.maxItems : DefaultMessages.minItems;
    }
    if (_kindOf(value) == SizeKind.text) {
      return isMax ? DefaultMessages.maxLength : DefaultMessages.minLength;
    }
    return defaultMessage;
  }

  SizeKind _kindOf(Object? value) {
    if (kind != SizeKind.unknown) {
      return kind;
    }
    if (value is num || ValueTools.asNumber(value) != null) {
      return SizeKind.number;
    }
    return SizeKind.text;
  }

  num? _size(Object? value) {
    if (value is List) {
      return value.length;
    }
    if (value is Map) {
      return value.length;
    }
    if (_kindOf(value) == SizeKind.number) {
      return ValueTools.asNumber(value);
    }
    return value.toString().length;
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    if (kind == SizeKind.number) {
      return <String, dynamic>{isMax ? 'maximum' : 'minimum': limit};
    }
    if (kind == SizeKind.text) {
      return <String, dynamic>{isMax ? 'maxLength' : 'minLength': limit};
    }
    if (kind == SizeKind.list) {
      return <String, dynamic>{isMax ? 'maxItems' : 'minItems': limit};
    }
    return <String, dynamic>{};
  }
}

/// What `min` / `max` measure.
enum SizeKind { unknown, number, text, list }

/// `confirmed` or `confirmed:other_field`.
class ConfirmedRule extends BuiltInRule<Object?> {
  ConfirmedRule(this.other, {super.message})
    : super(IssueCodes.confirmed, DefaultMessages.confirmed);

  /// Dotted path of the other field. Empty means `<field>_confirmation`.
  final String other;

  @override
  bool check(Object? value, RuleContext context) {
    Object? confirm;
    if (other.isNotEmpty) {
      confirm = context.lookup(other);
    } else {
      List<Object> path = <Object>[...context.path];
      Object last = path.removeLast();
      path.add('${last}_confirmation');
      confirm = context.lookup(path.join('.'));
    }
    return confirm == value;
  }
}

/// `file` and `image`: value must be a [FileInput], with an allowed
/// extension when [extensions] is not empty.
class FileValueRule extends BuiltInRule<Object?> {
  FileValueRule(String name, this.extensions, {super.message})
    : super(
        name,
        DefaultMessages.file,
        json: <String, dynamic>{'type': 'string', 'format': 'binary'},
      );

  /// Allowed extensions. Empty means any.
  final List<String> extensions;

  @override
  bool check(Object? value, RuleContext context) {
    if (value is! FileInput) {
      return false;
    }
    if (extensions.isEmpty) {
      return true;
    }
    return extensions.contains(value.extension.toLowerCase());
  }

  /// Default image extensions.
  static List<String> get imageExtensions {
    return SchemaConstants.imageExtensions;
  }
}
