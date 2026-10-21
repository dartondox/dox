import '../constants/default_messages.dart';
import '../constants/issue_codes.dart';
import 'rule.dart';

/// Signature for a simple check.
typedef CheckFunction<T> = bool Function(T value);

/// Signature for an async check.
typedef AsyncCheckFunction<T> = Future<bool> Function(T value);

/// Signature for a check that adds its own issues.
typedef SuperCheckFunction<T> = void Function(T value, RuleContext context);

/// Signature for an async check that adds its own issues.
typedef AsyncSuperCheckFunction<T> = Future<void> Function(
  T value,
  RuleContext context,
);

/// Rule made by `.refine()` and `.refineAsync()`.
class RefineRule<T> extends Rule<T> {
  RefineRule({
    this._check,
    this._asyncCheck,
    super.message,
    this.code = IssueCodes.custom,
    this.extraPath = const <Object>[],
  });

  final CheckFunction<T>? _check;
  final AsyncCheckFunction<T>? _asyncCheck;

  /// Issue code.
  final String code;

  /// Path added after the current path, like `['password_confirmation']`.
  final List<Object> extraPath;

  @override
  String get name {
    return code;
  }

  @override
  String get defaultMessage {
    return DefaultMessages.custom;
  }

  @override
  bool get isAsync {
    return _asyncCheck != null;
  }

  @override
  bool check(T value, RuleContext context) {
    CheckFunction<T>? fn = _check;
    if (fn == null) {
      throw StateError('This refine is async. Use parseAsync() instead.');
    }
    return fn(value);
  }

  @override
  Future<bool> checkAsync(T value, RuleContext context) async {
    AsyncCheckFunction<T>? fn = _asyncCheck;
    if (fn != null) {
      return fn(value);
    }
    return check(value, context);
  }

  @override
  bool apply(T value, RuleContext context) {
    if (check(value, context)) {
      return true;
    }
    _report(context);
    return false;
  }

  @override
  Future<bool> applyAsync(T value, RuleContext context) async {
    if (await checkAsync(value, context)) {
      return true;
    }
    _report(context);
    return false;
  }

  void _report(RuleContext context) {
    context.state.addIssue(
      path: <Object>[...context.path, ...extraPath],
      code: code,
      fallback: defaultMessage,
      value: context.value,
      message: message,
    );
  }
}

/// Rule made by `.superRefine()` and `.superRefineAsync()`.
/// The function adds issues itself with `context.addIssue()`.
class SuperRefineRule<T> extends Rule<T> {
  SuperRefineRule({this._check, this._asyncCheck});

  final SuperCheckFunction<T>? _check;
  final AsyncSuperCheckFunction<T>? _asyncCheck;

  @override
  String get name {
    return IssueCodes.custom;
  }

  @override
  String get defaultMessage {
    return DefaultMessages.custom;
  }

  @override
  bool get isAsync {
    return _asyncCheck != null;
  }

  @override
  bool check(T value, RuleContext context) {
    return apply(value, context);
  }

  @override
  bool apply(T value, RuleContext context) {
    SuperCheckFunction<T>? fn = _check;
    if (fn == null) {
      throw StateError('This superRefine is async. Use parseAsync() instead.');
    }
    int before = context.state.issues.length;
    fn(value, context);
    return context.state.issues.length == before;
  }

  @override
  Future<bool> applyAsync(T value, RuleContext context) async {
    AsyncSuperCheckFunction<T>? fn = _asyncCheck;
    if (fn == null) {
      return apply(value, context);
    }
    int before = context.state.issues.length;
    await fn(value, context);
    return context.state.issues.length == before;
  }
}

/// A rule from a plain function. Handy for `v.registerRule()`.
///
/// ```dart
/// v.registerRule('even', (RuleDefinition d) {
///   return CallbackRule(
///     name: 'even',
///     defaultMessage: 'The {field} must be even',
///     callback: (Object? value, RuleContext context) {
///       return value is int && value.isEven;
///     },
///   );
/// });
/// ```
class CallbackRule extends Rule<Object?> {
  CallbackRule({
    required this._name,
    required this._defaultMessage,
    required this._callback,
    this._params = const <String, Object?>{},
    super.message,
  });

  final String _name;
  final String _defaultMessage;
  final bool Function(Object? value, RuleContext context) _callback;
  final Map<String, Object?> _params;

  /// Extra JSON Schema keys for this rule.
  Map<String, dynamic> jsonHint = <String, dynamic>{};

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{...jsonHint};
  }

  @override
  String get name {
    return _name;
  }

  @override
  String get defaultMessage {
    return _defaultMessage;
  }

  @override
  Map<String, Object?> get params {
    return _params;
  }

  @override
  bool check(Object? value, RuleContext context) {
    return _callback(value, context);
  }
}
