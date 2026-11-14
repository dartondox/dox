import 'dart:io';

import 'package:dox_core/env/env.dart';

/// Thrown by a typed env class when keys are missing or not valid.
/// [errors] has one line per key.
class EnvException implements Exception {
  final List<String> errors;

  const EnvException(this.errors);

  @override
  String toString() {
    return 'EnvException: the env is not valid\n  - ${errors.join('\n  - ')}';
  }
}

/// Reads and converts env values for a `@DoxEnv()` class.
///
/// A real environment variable wins over the `.env` file, the same as
/// `Env.get()`. An empty value (or the text `null`) counts as missing.
///
/// Each read gives `null` when the key is missing or not valid. A bad value
/// is saved and [check] throws one [EnvException] with every problem.
class EnvReader {
  final Map<String, String> _environment;
  final Map<String, String> _dotEnv;
  final List<String> _errors = <String>[];

  /// [environment] is `Platform.environment` and [dotEnv] is the `.env`
  /// file by default. Tests can pass their own maps.
  EnvReader({Map<String, String>? environment, Map<String, String>? dotEnv})
    : _environment = environment ?? Platform.environment,
      _dotEnv = dotEnv ?? _loadDotEnv();

  static Map<String, String> _loadDotEnv() {
    Env().load();
    return Env().env;
  }

  /// the raw text of [key], or null when it is missing or empty
  String? raw(String key) {
    String? value = _environment[key] ?? _dotEnv[key];
    if (value == null) return null;
    value = value.trim();
    if (value.isEmpty || value.toLowerCase() == 'null') return null;
    return value;
  }

  String? string(String key) {
    return raw(key);
  }

  int? integer(String key) {
    String? value = raw(key);
    if (value == null) return null;
    return int.tryParse(value) ?? _invalid(key, 'an int');
  }

  double? decimal(String key) {
    String? value = raw(key);
    if (value == null) return null;
    return double.tryParse(value) ?? _invalid(key, 'a double');
  }

  num? number(String key) {
    String? value = raw(key);
    if (value == null) return null;
    return num.tryParse(value) ?? _invalid(key, 'a number');
  }

  /// true, 1, yes, on / false, 0, no, off (any case)
  bool? boolean(String key) {
    String? value = raw(key);
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'true' || '1' || 'yes' || 'on':
        return true;
      case 'false' || '0' || 'no' || 'off':
        return false;
    }
    return _invalid(key, 'a bool (true/false, 1/0, yes/no)');
  }

  Uri? uri(String key) {
    String? value = raw(key);
    if (value == null) return null;
    return Uri.tryParse(value) ?? _invalid(key, 'a Uri');
  }

  /// a number with a unit: `500ms`, `30s`, `5m`, `2h`, `1d`.
  /// A plain number is seconds: `300` is 5 minutes.
  Duration? duration(String key) {
    String? value = raw(key);
    if (value == null) return null;
    RegExpMatch? match = _durationPattern.firstMatch(value.toLowerCase());
    if (match == null) {
      return _invalid(key, 'a Duration (like 500ms, 30s, 5m, 2h, 1d)');
    }
    int microseconds = switch (match.group(2)) {
      'ms' => Duration.microsecondsPerMillisecond,
      'm' => Duration.microsecondsPerMinute,
      'h' => Duration.microsecondsPerHour,
      'd' => Duration.microsecondsPerDay,
      _ => Duration.microsecondsPerSecond,
    };
    int? amount = int.tryParse(match.group(1)!);
    // too big for an int, or for a Duration
    if (amount == null || amount > _maxInt ~/ microseconds) {
      return _invalid(key, 'a Duration that is not too big');
    }
    return Duration(microseconds: amount * microseconds);
  }

  static const int _maxInt = 9223372036854775807;

  static final RegExp _durationPattern = RegExp(r'^(\d+)\s*(ms|s|m|h|d)?$');

  /// comma separated: `a, b,c` is `['a', 'b', 'c']`. Empty items are dropped.
  /// Only commas (`,`) counts as missing, so the default is used.
  List<String>? list(String key) {
    String? value = raw(key);
    if (value == null) return null;
    List<String> result = <String>[];
    for (String item in value.split(',')) {
      String text = item.trim();
      if (text.isNotEmpty) result.add(text);
    }
    return result.isEmpty ? null : result;
  }

  /// an enum value by its name, in any case
  T? enumByName<T extends Enum>(String key, List<T> values) {
    String? value = raw(key);
    if (value == null) return null;
    String name = value.toLowerCase();
    for (T item in values) {
      if (item.name.toLowerCase() == name) return item;
    }
    List<String> names = <String>[];
    for (T item in values) {
      names.add(item.name);
    }
    return _invalid(key, 'one of ${names.join(', ')}');
  }

  /// saves an error when the required [key] is missing
  void need(String key) {
    if (raw(key) == null) _errors.add('$key is missing');
  }

  /// throws an [EnvException] with every missing or bad key
  void check() {
    if (_errors.isNotEmpty) throw EnvException(List<String>.of(_errors));
  }

  /// saves an error for [key]. The value is never in the text: it may be
  /// a secret, and the error goes to the startup log and to CI output.
  Null _invalid(String key, String expected) {
    _errors.add('$key must be $expected');
    return null;
  }
}
