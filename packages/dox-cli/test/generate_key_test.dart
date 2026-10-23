import 'dart:io';

import 'package:dox/src/tools/generate_key.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late File env;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('dox_key_');
    env = File('${dir.path}/.env');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('overrideKey keeps every other line as it is', () {
    env.writeAsStringSync(
      '# app\n'
      'APP_NAME="My App"\n'
      'APP_KEY=old\n'
      '\n'
      'DATABASE_URL=postgres://u:p@h/db?sslmode=require\n',
    );
    overrideKey('new', env.path);
    expect(
      env.readAsStringSync(),
      '# app\n'
      'APP_NAME="My App"\n'
      'APP_KEY=new\n'
      '\n'
      'DATABASE_URL=postgres://u:p@h/db?sslmode=require\n',
    );
  });

  test('overrideKey adds APP_KEY as the first line when missing', () {
    env.writeAsStringSync('A=b=c\n# note\n');
    overrideKey('new', env.path);
    expect(env.readAsStringSync(), 'APP_KEY=new\nA=b=c\n# note\n');
  });
}
