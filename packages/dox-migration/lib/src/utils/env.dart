import 'dart:io';

/// The env for migrations: the `.env` file and the real environment.
///
/// Same rule as `Env.get()` of dox_core: a real environment variable wins
/// over the `.env` file. An empty value, or the text `null`, counts as
/// missing. [environment] and [dir] are for tests.
Map<String, String> loadEnv({Map<String, String>? environment, String? dir}) {
  environment ??= Platform.environment;
  Map<String, String> data = <String, String>{};

  File envFile = File('${dir ?? Directory.current.path}/.env');
  if (envFile.existsSync()) {
    for (String line in envFile.readAsLinesSync()) {
      // splitting with equal sign to get key and value
      List<String> keyValue = line.split('=');
      String key = keyValue.first.trim();
      if (key.isNotEmpty) {
        data[key] = _getValue(keyValue);
      }
    }
  }
  data.addAll(environment);
  data.removeWhere(_missing);
  return data;
}

bool _missing(String key, String value) {
  String text = value.trim();
  return text.isEmpty || text.toLowerCase() == 'null';
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
