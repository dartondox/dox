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
  /// Evn.get('APP_KEY');
  /// Evn.get('APP_KEY', 'with_default_value_if_null');
  /// Evn.get<int>('PORT', 3000); (This will return int type)
  /// Evn.get<num>('PORT', 3000); (This will return num type)
  /// Evn.get<String>('APP_KEY'); (This will return String type)
  /// Currently this function support String, int and num types.
  /// ```
  static T get<T>(String key, [dynamic defaultValue]) {
    String value = Env().env[key].toString();
    String val = value.isEmpty || value.toLowerCase() == 'null'
        ? defaultValue.toString()
        : value;
    if (T.toString() == 'int') {
      return int.parse(val) as T;
    }
    if (T.toString() == 'num') {
      return num.parse(val) as T;
    }
    return val as T;
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
