import '../constants/default_messages.dart';
import '../constants/issue_codes.dart';
import 'data_path.dart';
import 'parse_state.dart';

/// A reusable check for one value.
///
/// Extend it to make your own rule:
/// ```dart
/// class SlugRule extends Rule<String> {
///   SlugRule({super.message});
///
///   @override
///   String get name {
///     return 'slug';
///   }
///
///   @override
///   String get defaultMessage {
///     return 'The {field} must be a slug';
///   }
///
///   @override
///   bool check(String value, RuleContext context) {
///     return RegExp(r'^[a-z0-9-]+$').hasMatch(value);
///   }
/// }
///
/// v.string().use(SlugRule());
/// ```
abstract class Rule<T> {
  Rule({this.message});

  /// Custom message for this rule. It wins over every other message.
  String? message;

  /// Rule name. Also used as the issue code.
  String get name;

  /// Message template used when no custom message is set.
  String get defaultMessage;

  /// Values for the message placeholders, like `{'min': 3}`.
  Map<String, Object?> get params {
    return <String, Object?>{};
  }

  /// `true` when the rule needs [checkAsync]. Then use `parseAsync`.
  bool get isAsync {
    return false;
  }

  /// `true` when the rule must run even if the value is missing or empty.
  /// Only used by `v.fromRules()`. `required` is an implicit rule.
  bool get isImplicit {
    return false;
  }

  /// Return `true` when [value] is valid.
  bool check(T value, RuleContext context);

  /// Async version of [check]. The default calls [check].
  Future<bool> checkAsync(T value, RuleContext context) async {
    return check(value, context);
  }

  /// Extra JSON Schema keys, like `{'format': 'email'}`.
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{};
  }

  /// Run the rule and add an issue when it fails. Returns `true` on pass.
  bool apply(T value, RuleContext context) {
    if (check(value, context)) {
      return true;
    }
    context.fail(this);
    return false;
  }

  /// Async version of [apply].
  Future<bool> applyAsync(T value, RuleContext context) async {
    if (await checkAsync(value, context)) {
      return true;
    }
    context.fail(this);
    return false;
  }
}

/// A rule that only has an async check, like "email is unique in the DB".
abstract class AsyncRule<T> extends Rule<T> {
  AsyncRule({super.message});

  @override
  bool get isAsync {
    return true;
  }

  @override
  bool check(T value, RuleContext context) {
    throw StateError('Rule "$name" is async. Use parseAsync() instead.');
  }

  @override
  Future<bool> checkAsync(T value, RuleContext context);
}

/// What a rule can see and do while it runs.
class RuleContext {
  RuleContext({required this.state, required this.path, this.value});

  /// The shared parse state.
  final ParseState state;

  /// Path of the value being checked.
  final List<Object> path;

  /// The value being checked.
  final Object? value;

  /// The whole input given to `parse`.
  Object? get root {
    return state.root;
  }

  /// The name used for `{field}`.
  String get field {
    return ParseState.fieldName(path);
  }

  /// Read another value from the root input, like `user.type`.
  /// Returns `undefined` when it is missing.
  Object? lookup(String dottedPath) {
    return DataPath.readDotted(state.root, dottedPath);
  }

  /// Add an issue for a failed [rule].
  void fail(Rule<Object?> rule, {String? fallback}) {
    state.addIssue(
      path: path,
      code: rule.name,
      fallback: fallback ?? rule.defaultMessage,
      value: value,
      params: rule.params,
      message: rule.message,
    );
  }

  /// Add a custom issue. [path] is added to the current path.
  void addIssue(
    String message, {
    String code = IssueCodes.custom,
    List<Object> path = const <Object>[],
    Map<String, Object?> params = const <String, Object?>{},
  }) {
    state.addIssue(
      path: <Object>[...this.path, ...path],
      code: code,
      fallback: message.isEmpty ? DefaultMessages.custom : message,
      value: value,
      params: params,
    );
  }
}
