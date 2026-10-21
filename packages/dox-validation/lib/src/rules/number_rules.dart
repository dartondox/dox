import '../constants/default_messages.dart';
import '../constants/issue_codes.dart';
import '../core/rule.dart';
import 'built_in_rule.dart';

/// Number must be at least [min].
class MinRule<N extends num> extends BuiltInRule<N> {
  MinRule(this.min, {super.message})
      : super(IssueCodes.min, DefaultMessages.min,
            params: <String, Object?>{'min': min},
            json: <String, dynamic>{'minimum': min});

  final num min;

  @override
  bool check(N value, RuleContext context) {
    return value >= min;
  }
}

/// Number may be at most [max].
class MaxRule<N extends num> extends BuiltInRule<N> {
  MaxRule(this.max, {super.message})
      : super(IssueCodes.max, DefaultMessages.max,
            params: <String, Object?>{'max': max},
            json: <String, dynamic>{'maximum': max});

  final num max;

  @override
  bool check(N value, RuleContext context) {
    return value <= max;
  }
}

/// Number must be greater than [min].
class GreaterThanRule<N extends num> extends BuiltInRule<N> {
  GreaterThanRule(this.min, {super.message})
      : super(IssueCodes.greaterThan, DefaultMessages.greaterThan,
            params: <String, Object?>{'min': min},
            json: <String, dynamic>{'exclusiveMinimum': min});

  final num min;

  @override
  bool check(N value, RuleContext context) {
    return value > min;
  }
}

/// Number must be less than [max].
class LessThanRule<N extends num> extends BuiltInRule<N> {
  LessThanRule(this.max, {super.message})
      : super(IssueCodes.lessThan, DefaultMessages.lessThan,
            params: <String, Object?>{'max': max},
            json: <String, dynamic>{'exclusiveMaximum': max});

  final num max;

  @override
  bool check(N value, RuleContext context) {
    return value < max;
  }
}

/// Number must be a multiple of [factor].
class MultipleOfRule<N extends num> extends BuiltInRule<N> {
  MultipleOfRule(this.factor, {super.message})
      : super(IssueCodes.multipleOf, DefaultMessages.multipleOf,
            params: <String, Object?>{'factor': factor},
            json: <String, dynamic>{'multipleOf': factor});

  final num factor;

  @override
  bool check(N value, RuleContext context) {
    return value % factor == 0;
  }
}
