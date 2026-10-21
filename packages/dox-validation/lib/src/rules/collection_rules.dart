import '../dto/file_types.dart';
import '../constants/default_messages.dart';
import '../constants/issue_codes.dart';
import '../core/rule.dart';
import 'built_in_rule.dart';

/// List must have at least [min] items.
class MinItemsRule<T> extends BuiltInRule<List<T>> {
  MinItemsRule(this.min, {super.message})
    : super(
        IssueCodes.minItems,
        DefaultMessages.minItems,
        params: <String, Object?>{'min': min},
        json: <String, dynamic>{'minItems': min},
      );

  final int min;

  @override
  bool check(List<T> value, RuleContext context) {
    return value.length >= min;
  }
}

/// List may have at most [max] items.
class MaxItemsRule<T> extends BuiltInRule<List<T>> {
  MaxItemsRule(this.max, {super.message})
    : super(
        IssueCodes.maxItems,
        DefaultMessages.maxItems,
        params: <String, Object?>{'max': max},
        json: <String, dynamic>{'maxItems': max},
      );

  final int max;

  @override
  bool check(List<T> value, RuleContext context) {
    return value.length <= max;
  }
}

/// Date must be on or after [date].
class AfterOrEqualRule extends BuiltInRule<DateTime> {
  AfterOrEqualRule(this.date, {super.message})
    : super(
        IssueCodes.afterOrEqual,
        DefaultMessages.afterOrEqual,
        params: <String, Object?>{'date': date},
      );

  final DateTime date;

  @override
  bool check(DateTime value, RuleContext context) {
    return !value.isBefore(date);
  }
}

/// Date must be on or before [date].
class BeforeOrEqualRule extends BuiltInRule<DateTime> {
  BeforeOrEqualRule(this.date, {super.message})
    : super(
        IssueCodes.beforeOrEqual,
        DefaultMessages.beforeOrEqual,
        params: <String, Object?>{'date': date},
      );

  final DateTime date;

  @override
  bool check(DateTime value, RuleContext context) {
    return !value.isAfter(date);
  }
}

/// The file must be one of the types [extensions], like `['pdf']`.
/// The real type comes from the first bytes of the file (see [FileTypes]).
class FileExtensionRule extends BuiltInRule<FileInput> {
  FileExtensionRule(
    this.extensions, {
    String code = IssueCodes.file,
    super.message,
  }) : super(
         code,
         DefaultMessages.fileExtension,
         params: <String, Object?>{'extensions': extensions.join(', ')},
       );

  final List<String> extensions;

  @override
  bool check(FileInput value, RuleContext context) {
    return FileTypes.matches(value, extensions);
  }
}
