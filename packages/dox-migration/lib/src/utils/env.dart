import 'dart:io';

Map<String, String> loadEnv() {
  Map<String, String> data = <String, String>{};

  File envFile = File('${Directory.current.path}/.env');
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
