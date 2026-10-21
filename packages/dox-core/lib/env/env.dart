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
    Map<String, String> data = <String, String>{};

    File envFile = file ?? File('${Directory.current.path}/.env');
    if (!envFile.existsSync()) return data;
    String contents = envFile.readAsStringSync();

    // splitting with new line for each variables
    List<String> list = contents.split('\n');

    for (String d in list) {
      // splitting with equal sign to get key and value
      List<String> keyValue = d.toString().split('=');
      if (keyValue.first.isNotEmpty) {
        data[keyValue.first.trim()] = _getValue(keyValue);
      }
    }

    return data;
  }

  String _getValue(List<String> elements) {
    if (elements.length > 1) {
      List<String> elementsExceptFirst = elements.sublist(1);
      String value = elementsExceptFirst.join('=');
      return value
          .replaceAll('"', '')
          .replaceAll("'", '')
          .replaceAll('`', '')
          .trim();
    }
    return '';
  }
}
