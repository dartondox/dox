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

  static String get(key, [dynamic defaultValue]) {
    String value = Env().env[key].toString();
    return value.isEmpty || value == 'null' ? defaultValue : value;
  }
}
