import 'dart:io';

import 'package:dox_migration/src/utils/env.dart';
import 'package:test/test.dart';

void main() {
  group('loadEnv', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('dox_migration_env_');
    });

    tearDown(() => dir.deleteSync(recursive: true));

    test('real env wins over .env, .env fills the rest', () {
      File('${dir.path}/.env').writeAsStringSync(
        'DB_HOST=from-file\nDB_PORT=5432\nDB_NAME="dox"\n'
        'DATABASE_URL=postgres://u:p@h/d?sslmode=disable\n',
      );
      Map<String, String> env = loadEnv(
        environment: <String, String>{'DB_HOST': 'from-env'},
        dir: dir.path,
      );
      expect(env['DB_HOST'], 'from-env');
      expect(env['DB_PORT'], '5432');
      expect(env['DB_NAME'], 'dox');
      // a second `=` is kept
      expect(env['DATABASE_URL'], 'postgres://u:p@h/d?sslmode=disable');
    });

    test('no .env file: the real env only', () {
      Map<String, String> env = loadEnv(
        environment: <String, String>{'DB_HOST': 'h'},
        dir: dir.path,
      );
      expect(env, <String, String>{'DB_HOST': 'h'});
    });

    test('empty and null values count as missing', () {
      File('${dir.path}/.env').writeAsStringSync('DB_HOST=\nDB_PORT=null\n');
      Map<String, String> env = loadEnv(
        environment: <String, String>{'DB_USERNAME': ' '},
        dir: dir.path,
      );
      expect(env, isEmpty);
    });
  });
}
