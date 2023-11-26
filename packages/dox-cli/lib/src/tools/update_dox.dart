import 'dart:convert';
import 'dart:io';

updateDox() async {
  final process =
      await Process.start('dart', ['pub', 'global', 'activate', 'dox']);
  process.stdout.transform(utf8.decoder).listen((data) {
    List lines = data.split("\n");
    for (String line in lines) {
      if (line.isNotEmpty) {
        print(line);
      }
    }
  });

  process.stderr.transform(utf8.decoder).listen((data) {
    List lines = data.split("\n");
    for (String line in lines) {
      if (line.isNotEmpty) {
        print(line);
      }
    }
  });
}
