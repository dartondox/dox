import '../constants/default_messages.dart';
import '../constants/issue_codes.dart';
import '../constants/patterns.dart';
import '../core/issue.dart';
import '../core/message_resolver.dart';
import '../core/parse_state.dart';
import '../core/rule.dart';
import '../core/sentinels.dart';
import 'file_types.dart';

/// The state of one DTO check. The generated code of a DTO calls it.
///
/// Each read method gets the raw input value and gives back one of:
/// - the typed value,
/// - [undefined]: the key is missing (an empty string counts as missing),
/// - `null`: the value is `null`,
/// - [invalid]: a type error, already added to [issues].
///
/// [text] is `true` for query strings and form data. Then text is turned
/// into the field type. JSON (`text == false`) is strict.
class DtoState extends ParseState {
  DtoState({
    required super.root,
    super.resolver,
    super.issues,
    super.params,
    super.locale,
    this.text = false,
  });

  /// A state that adds its issues to [state] (a DTO inside a fluent schema).
  DtoState.of(ParseState state, {this.text = false})
    : super(
        root: state.root,
        resolver: state.resolver,
        issues: state.issues,
        params: state.params,
        locale: state.locale,
      );

  /// `true` when the input is text (query string, form data).
  final bool text;

  DateTime? _now;

  /// The time of this check, in UTC. `@After('now')` and `@Before('now')`
  /// use it.
  DateTime get now {
    return _now ??= DateTime.now().toUtc();
  }

  // -------------------------------------------------------------------------
  // Issues
  // -------------------------------------------------------------------------

  /// Add an issue at `[...path, key]`.
  ///
  /// The message is [message] (from the annotation), else
  /// `messages['key.code']`, else `messages['code']` (from `@Dto(messages:)`),
  /// else the [MessageResolver] with [fallback].
  void fail(
    List<Object> path,
    Object key,
    String code,
    String fallback,
    Object? value, {
    Map<String, Object?> params = const <String, Object?>{},
    String? message,
    Map<String, String> messages = const <String, String>{},
  }) {
    List<Object> full = <Object>[...path, key];
    String? text = message;
    if (text == null && messages.isNotEmpty) {
      text = messages['${ParseState.fieldName(full)}.$code'] ?? messages[code];
    }
    addIssue(
      path: full,
      code: code,
      fallback: fallback,
      value: value,
      params: params,
      message: text,
    );
  }

  /// Add the `required` issue at `[...path, key]`.
  void required(List<Object> path, Object key, Map<String, String> messages) {
    fail(
      path,
      key,
      IssueCodes.required,
      DefaultMessages.required,
      null,
      messages: messages,
    );
  }

  /// Add the issue of a failed custom [rule] at `[...path, key]`.
  void failRule(
    Rule<Object?> rule,
    List<Object> path,
    Object key,
    Object? value,
    Map<String, String> messages,
  ) {
    fail(
      path,
      key,
      rule.name,
      rule.defaultMessage,
      value,
      params: rule.params,
      message: rule.message,
      messages: messages,
    );
  }

  /// The input is not an object. At the top it is the `_root` key.
  void notObject(Object? input, List<Object> path, Map<String, String> m) {
    if (path.isEmpty) {
      fail(
        path,
        '_root',
        IssueCodes.object,
        DefaultMessages.rootObject,
        input,
        messages: m,
      );
      return;
    }
    Object key = path.last;
    List<Object> parent = path.sublist(0, path.length - 1);
    if (input == null) {
      required(parent, key, m);
      return;
    }
    fail(
      parent,
      key,
      IssueCodes.object,
      DefaultMessages.object,
      input,
      messages: m,
    );
  }

  /// The context for a custom rule.
  RuleContext context(List<Object> path, Object key, Object? value) {
    return RuleContext(state: this, path: <Object>[...path, key], value: value);
  }

  /// Run an async [rule] on [value]. Skipped when the key already has
  /// an error.
  Future<void> asyncRule<V>(
    Rule<V> rule,
    V value,
    List<Object> path,
    Object key,
    Map<String, String> messages,
  ) async {
    if (_hasIssue(path, key)) return;
    if (!await rule.checkAsync(value, context(path, key, value))) {
      failRule(rule as Rule<Object?>, path, key, value, messages);
    }
  }

  /// Run an async [rule] on every item of [values] (one call, so a
  /// database rule can use one query).
  Future<void> asyncItems<V>(
    AsyncRule<V> rule,
    List<V> values,
    List<Object> path,
    Object key,
    Map<String, String> messages,
  ) async {
    if (values.isEmpty || _hasIssue(path, key)) return;
    List<Object> listPath = <Object>[...path, key];
    RuleContext ctx = RuleContext(state: this, path: listPath, value: values);
    for (int index in await rule.failedItems(values, ctx)) {
      failRule(rule as Rule<Object?>, listPath, index, values[index], messages);
    }
  }

  bool _hasIssue(List<Object> path, Object key) {
    if (issues.isEmpty) return false;
    String dotted = <Object>[...path, key].join('.');
    for (ValidationIssue issue in issues) {
      String other = issue.dottedPath;
      if (other == dotted || other.startsWith('$dotted.')) return true;
    }
    return false;
  }

  // -------------------------------------------------------------------------
  // Reading input
  // -------------------------------------------------------------------------

  /// `map[key]`, or [undefined] when the key is missing.
  Object? read(Map<dynamic, dynamic> map, String key) {
    Object? value = map[key];
    if (value == null && !map.containsKey(key)) return undefined;
    return value;
  }

  /// In text input a key can come many times. A single value field takes
  /// the last one.
  Object? _one(Object? raw) {
    if (text && raw is List) {
      return raw.isEmpty ? undefined : raw.last;
    }
    return raw;
  }

  /// A `String`. [textCase]: 0 as is, 1 lower case, 2 upper case.
  Object? string(
    Object? raw,
    List<Object> path,
    Object key,
    Map<String, String> m, {
    bool trim = false,
    int textCase = 0,
    bool allowEmpty = false,
  }) {
    Object? one = _one(raw);
    if (one == null || one is Undefined) return one;
    if (one is! String) {
      return _typeError(
        path,
        key,
        IssueCodes.string,
        DefaultMessages.string,
        one,
        m,
      );
    }
    String value = trim ? one.trim() : one;
    if (textCase == 1) {
      value = value.toLowerCase();
    } else if (textCase == 2) {
      value = value.toUpperCase();
    }
    if (value.isEmpty && !allowEmpty) return undefined;
    return value;
  }

  /// An `int`. JSON: a whole number (`18` or `18.0`). Text: `"18"`.
  Object? integer(
    Object? raw,
    List<Object> path,
    Object key,
    Map<String, String> m,
  ) {
    Object? one = _one(raw);
    if (one == null || one is Undefined) return one;
    if (one is int) return one;
    if (one is double && one.isFinite && one == one.truncateToDouble()) {
      return one.toInt();
    }
    if (one is String) {
      if (one.isEmpty) return undefined;
      if (text) {
        int? value = int.tryParse(one, radix: 10);
        if (value != null) return value;
      }
    }
    return _typeError(
      path,
      key,
      IssueCodes.integer,
      DefaultMessages.integer,
      one,
      m,
    );
  }

  /// A `double`. JSON: any number. Text: `"4.5"`.
  Object? decimal(
    Object? raw,
    List<Object> path,
    Object key,
    Map<String, String> m,
  ) {
    Object? one = _one(raw);
    if (one == null || one is Undefined) return one;
    if (one is num && one.isFinite) return one.toDouble();
    if (one is String) {
      if (one.isEmpty) return undefined;
      if (text) {
        double? value = double.tryParse(one);
        if (value != null && value.isFinite) return value;
      }
    }
    return _typeError(
      path,
      key,
      IssueCodes.numeric,
      DefaultMessages.numeric,
      one,
      m,
    );
  }

  /// A `num`. JSON: any number. Text: `"18"` (an int) or `"4.5"`.
  Object? number(
    Object? raw,
    List<Object> path,
    Object key,
    Map<String, String> m,
  ) {
    Object? one = _one(raw);
    if (one == null || one is Undefined) return one;
    if (one is num && one.isFinite) return one;
    if (one is String) {
      if (one.isEmpty) return undefined;
      if (text) {
        num? value = int.tryParse(one, radix: 10) ?? double.tryParse(one);
        if (value != null && value.isFinite) return value;
      }
    }
    return _typeError(
      path,
      key,
      IssueCodes.numeric,
      DefaultMessages.numeric,
      one,
      m,
    );
  }

  /// A `bool`. JSON: `true` / `false`. Text: `true`, `1`, `yes`, `on` and
  /// the opposites, any case.
  Object? boolean(
    Object? raw,
    List<Object> path,
    Object key,
    Map<String, String> m,
  ) {
    Object? one = _one(raw);
    if (one == null || one is Undefined) return one;
    if (one is bool) return one;
    if (one is String) {
      if (one.isEmpty) return undefined;
      if (text) {
        if (ListText.isTrueWord(one)) return true;
        if (ListText.isFalseWord(one)) return false;
      }
    }
    return _typeError(
      path,
      key,
      IssueCodes.boolean,
      DefaultMessages.boolean,
      one,
      m,
    );
  }

  /// A `DateTime` from an ISO 8601 text, always in UTC.
  /// A text without a time zone is read as UTC.
  Object? date(
    Object? raw,
    List<Object> path,
    Object key,
    Map<String, String> m,
  ) {
    Object? one = _one(raw);
    if (one == null || one is Undefined) return one;
    if (one is String) {
      if (one.isEmpty) return undefined;
      DateTime? value = DtoChecks.parseDate(one);
      if (value != null) return value;
    }
    return _typeError(path, key, IssueCodes.date, DefaultMessages.date, one, m);
  }

  /// The name of an enum value. [names] are the allowed names.
  Object? enumName(
    Object? raw,
    List<Object> path,
    Object key,
    Map<String, String> m,
    List<String> names,
  ) {
    Object? one = _one(raw);
    if (one == null || one is Undefined) return one;
    if (one is String) {
      if (one.isEmpty) return undefined;
      if (names.contains(one)) return one;
    }
    fail(
      path,
      key,
      IssueCodes.inList,
      DefaultMessages.inList,
      one,
      params: <String, Object?>{'values': ListText.joinWithAnd(names)},
      messages: m,
    );
    return invalid;
  }

  /// A list. In text input one value gives a list with one item.
  Object? list(
    Object? raw,
    List<Object> path,
    Object key,
    Map<String, String> m,
  ) {
    if (raw == null || raw is Undefined || raw is List) return raw;
    if (text && raw is! Map) {
      if (raw is String && raw.isEmpty) return undefined;
      return <Object?>[raw];
    }
    return _typeError(
      path,
      key,
      IssueCodes.array,
      DefaultMessages.array,
      raw,
      m,
    );
  }

  /// An object (a map).
  Object? object(
    Object? raw,
    List<Object> path,
    Object key,
    Map<String, String> m,
  ) {
    if (raw == null || raw is Undefined || raw is Map) return raw;
    if (raw is String && raw.isEmpty) return undefined;
    return _typeError(
      path,
      key,
      IssueCodes.object,
      DefaultMessages.object,
      raw,
      m,
    );
  }

  /// An uploaded file. Only in form data.
  Object? file(
    Object? raw,
    List<Object> path,
    Object key,
    Map<String, String> m,
  ) {
    Object? one = _one(raw);
    if (one == null || one is Undefined || one is FileInput) return one;
    if (one is String && one.isEmpty) return undefined;
    return _typeError(path, key, IssueCodes.file, DefaultMessages.file, one, m);
  }

  Invalid _typeError(
    List<Object> path,
    Object key,
    String code,
    String fallback,
    Object? value,
    Map<String, String> m,
  ) {
    fail(path, key, code, fallback, value, messages: m);
    return invalid;
  }
}

/// Checks used by the generated DTO code.
class DtoChecks {
  const DtoChecks._();

  static final RegExp _date = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})([T ]\d{2}:\d{2}(:\d{2}(\.\d{1,9})?)?(Z|[+-]\d{2}(:?\d{2})?)?)?$',
    caseSensitive: false,
  );

  /// An ISO 8601 date or date time, in UTC. `null` when it is not valid.
  static DateTime? parseDate(String text) {
    RegExpMatch? match = _date.firstMatch(text);
    if (match == null) return null;
    int year = int.parse(match[1]!);
    int month = int.parse(match[2]!);
    int day = int.parse(match[3]!);
    DateTime check = DateTime.utc(year, month, day);
    if (check.year != year || check.month != month || check.day != day) {
      return null;
    }
    if (match[4] == null) return check;
    String value = match[7] == null ? '${text}Z' : text;
    DateTime? parsed = DateTime.tryParse(value.replaceFirst(' ', 'T'));
    return parsed?.toUtc();
  }

  /// An `http` or `https` url with a host.
  static bool url(String value) {
    Uri? uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  /// An IPv4 or IPv6 address.
  static bool ip(String value) {
    if (Patterns.ipv4.hasMatch(value)) return true;
    if (!value.contains(':')) return false;
    try {
      Uri.parseIPv6Address(value);
      return true;
    } on FormatException {
      return false;
    }
  }

  /// `true` when [values] has an item twice.
  static bool hasDuplicates(List<Object?> values) {
    return values.toSet().length != values.length;
  }
}
