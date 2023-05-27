import 'package:dart_dotenv/dart_dotenv.dart';

class Env {
  static final Env _singleton = Env._internal();

  factory Env() {
    return _singleton;
  }

  Map<String, dynamic> env = {};

  Env._internal();

  static void load() {
    Env().env = DotEnv().getDotEnv();
  }

  /// get env value
  /// ```
  /// Evn.get('APP_KEY');
  /// Evn.get('APP_KEY', 'with_default_value_if_null');
  /// ```
  static String get(key, [dynamic defaultValue]) {
    String value = Env().env[key].toString();
    return value.isEmpty || value.toLowerCase() == 'null'
        ? defaultValue
        : value;
  }
}
