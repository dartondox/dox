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
}
