import 'dart:io';

import 'package:dox/src/tools/create_project.dart';
import 'package:test/test.dart';

void main() {
  test('replaceProjectName skips binary files and renames text files', () {
    Directory dir = Directory.systemTemp.createTempSync('dox_create_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File text = File('${dir.path}/pubspec.yaml')
      ..writeAsStringSync('name: dox_sample\n');
    File same = File('${dir.path}/README.md')..writeAsStringSync('hello\n');
    DateTime before = same.lastModifiedSync();
    Directory('${dir.path}/db').createSync();
    List<int> bytes = <int>[0xff, 0xfe, 0x00, 0x80, 0xc3];
    File binary = File('${dir.path}/db/dox.sqlite-shm')
      ..writeAsBytesSync(bytes);

    replaceProjectName(dir, 'my_app');

    expect(text.readAsStringSync(), 'name: my_app\n');
    expect(binary.readAsBytesSync(), bytes);
    expect(same.lastModifiedSync(), before);
  });

  test('createEnv copies .env.example to .env with a new APP_KEY', () {
    Directory dir = Directory.systemTemp.createTempSync('dox_create_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/.env.example')
        .writeAsStringSync('APP_NAME=dox\nAPP_KEY=\nAPP_PORT=3000\n');

    createEnv(dir);

    List<String> lines = File('${dir.path}/.env').readAsLinesSync();
    expect(lines[0], 'APP_NAME=dox');
    expect(lines[1], matches(RegExp(r'^APP_KEY=[A-Za-z0-9]{32}$')));
    expect(lines[2], 'APP_PORT=3000');
  });
}
