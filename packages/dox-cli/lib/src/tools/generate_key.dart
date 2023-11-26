import 'dart:io';
import 'dart:math';

generateKey() {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  final random = Random.secure();
  var secret = String.fromCharCodes(
    Iterable.generate(
      32,
      (_) => chars.codeUnitAt(random.nextInt(chars.length)),
    ),
  );
  print("\x1B[34m$secret : Key have been updated successfully in .env!\x1B[0m");
  overrideKey(secret);
}

void overrideKey(secret) {
  List<String> content = [];
  final file = File('${Directory.current.path}/.env');
  final contents = file.readAsStringSync();
  List list = contents.split('\n');

  List<String> keys = [];

  for (var d in list) {
    if (d.toString().trim().isEmpty) {
      content.add('');
    } else {
      List keyValue = d.toString().split('=');
      if (keyValue.length == 2) {
        String key = keyValue[0];
        String value = keyValue[1];
        if (key == 'APP_KEY') {
          value = secret;
        }
        keys.add(key);
        content.add("$key=$value");
      }
    }
  }
  if (!keys.contains('APP_KEY')) {
    content = ["APP_KEY=$secret", ...content];
  }
  file.writeAsStringSync(content.join("\n"));
}
