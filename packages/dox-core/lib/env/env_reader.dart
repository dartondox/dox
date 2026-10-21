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
    return int.tryParse(value) ?? _invalid(key, 'an int', value);
  }

  double? decimal(String key) {
    String? value = raw(key);
    if (value == null) return null;
    return double.tryParse(value) ?? _invalid(key, 'a double', value);
  }

  num? number(String key) {
    String? value = raw(key);
    if (value == null) return null;
    return num.tryParse(value) ?? _invalid(key, 'a number', value);
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
    return _invalid(key, 'a bool (true/false, 1/0, yes/no)', value);
  }

  Uri? uri(String key) {
    String? value = raw(key);
    if (value == null) return null;
    return Uri.tryParse(value) ?? _invalid(key, 'a Uri', value);
  }

  /// a number with a unit: `500ms`, `30s`, `5m`, `2h`, `1d`.
  /// A plain number is seconds: `300` is 5 minutes.
  Duration? duration(String key) {
    String? value = raw(key);
    if (value == null) return null;
    RegExpMatch? match = _durationPattern.firstMatch(value.toLowerCase());
    if (match == null) {
      return _invalid(key, 'a Duration (like 500ms, 30s, 5m, 2h, 1d)', value);
    }
    int amount = int.parse(match.group(1)!);
    return switch (match.group(2)) {
      'ms' => Duration(milliseconds: amount),
      'm' => Duration(minutes: amount),
      'h' => Duration(hours: amount),
      'd' => Duration(days: amount),
      _ => Duration(seconds: amount),
    };
  }

  static final RegExp _durationPattern = RegExp(r'^(\d+)\s*(ms|s|m|h|d)?$');

  /// comma separated: `a, b,c` is `['a', 'b', 'c']`. Empty items are dropped.
  List<String>? list(String key) {
    String? value = raw(key);
    if (value == null) return null;
    List<String> result = <String>[];
    for (String item in value.split(',')) {
      String text = item.trim();
      if (text.isNotEmpty) result.add(text);
    }
    return result;
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
    return _invalid(key, 'one of ${names.join(', ')}', value);
  }

  /// saves an error when the required [key] is missing
  void need(String key) {
    if (raw(key) == null) _errors.add('$key is missing');
  }

  /// throws an [EnvException] with every missing or bad key
  void check() {
    if (_errors.isNotEmpty) throw EnvException(List<String>.of(_errors));
  }

  Null _invalid(String key, String expected, String value) {
    _errors.add('$key must be $expected, not "$value"');
    return null;
  }
}
