import 'dart:io';

class Env {
  static final Env _singleton = Env._internal();

  factory Env() {
    return _singleton;
  }

  Map<String, String> env = <String, String>{};

  Env._internal();

  void load({File? file}) {
    if (env.isEmpty) {
      env = _loadEnv(file: file);
    }
  }

  /// get env value
  /// ```
  /// Env.get('APP_KEY');
  /// Env.get('APP_KEY', 'with_default_value_if_null');
  /// Env.get<int>('PORT', 3000); (This will return int type)
  /// Env.get<num>('PORT', 3000); (This will return num type)
  /// Env.get<bool>('DEBUG', false); (true/1/yes/on is true)
  /// Env.get<String?>('APP_NAME'); (null when it is not set)
  /// ```
  /// A missing or empty key gives the default. With no default:
  /// - a nullable type (`String?`, `dynamic`) gives `null`
  /// - `String` gives an empty string, never the text "null"
  /// - `int`, `num`, `double` and `bool` throw an [ArgumentError]
  ///
  /// A real environment variable wins over the `.env` file, so a docker
  /// or systemd deploy can pass config without a `.env` file.
  static T get<T>(String key, [dynamic defaultValue]) {
    String? value = Platform.environment[key] ?? Env().env[key];
    if (value == null || value.isEmpty || value.toLowerCase() == 'null') {
      if (defaultValue == null) return _missing<T>(key);
      if (defaultValue is T) return defaultValue;
      value = defaultValue.toString();
    }
    return _cast<T>(key, value);
  }

  static T _missing<T>(String key) {
    if (null is T) return null as T;
    if (<T>[] is List<String>) return '' as T;
    throw ArgumentError('Env key "$key" is not set and has no default');
  }

  static T _cast<T>(String key, String value) {
    if (<T>[] is List<String>) return value as T;
    String type = T.toString().replaceAll('?', '');
    Object? result = switch (type) {
      'int' => int.tryParse(value),
      'double' => double.tryParse(value),
      'num' => num.tryParse(value),
      'bool' => _bool(value),
      _ => value,
    };
    if (result == null) {
      throw ArgumentError('Env key "$key" is not a valid $type: "$value"');
    }
    return result as T;
  }

  static bool? _bool(String value) {
    switch (value.toLowerCase()) {
      case 'true' || '1' || 'yes' || 'on':
        return true;
      case 'false' || '0' || 'no' || 'off':
        return false;
    }
    return null;
  }

  /// load env from .env of project directory
  Map<String, String> _loadEnv({File? file}) {
    File envFile = file ?? File('${Directory.current.path}/.env');
    if (!envFile.existsSync()) return <String, String>{};
    return parse(envFile.readAsStringSync());
  }

  /// Reads the text of a `.env` file.
  /// - `KEY=value`, one per line. Lines that start with `#` are comments.
  /// - `KEY=value # note`: a `#` after a space starts a comment.
  /// - `KEY="a # b"`: quotes (`"`, `'` or `` ` ``) keep the value as it is,
  ///   also a `#`. The quotes are removed.
  /// - `KEY=abc#def` stays `abc#def` (no space before the `#`).
  static Map<String, String> parse(String contents) {
    Map<String, String> data = <String, String>{};
    for (String line in contents.split('\n')) {
      String text = line.trim();
      if (text.isEmpty || text.startsWith('#')) continue;
      int equal = text.indexOf('=');
      if (equal < 1) continue;
      data[text.substring(0, equal).trim()] = _value(text.substring(equal + 1));
    }
    return data;
  }

  static final RegExp _comment = RegExp(r'(^|\s)#');

  static String _value(String raw) {
    String value = raw.trim();
    if (value.isNotEmpty && '"\'`'.contains(value[0])) {
      int end = value.indexOf(value[0], 1);
      if (end > 0) return value.substring(1, end);
    }
    Match? comment = _comment.firstMatch(value);
    if (comment != null) value = value.substring(0, comment.start);
    return value.trim();
  }
}
