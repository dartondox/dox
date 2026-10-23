import 'dart:io';

import 'package:dox/src/tools/env_tools.dart';
import 'package:test/test.dart';

void main() {
  group('env:generate |', () {
    test('infers types, keeps comments, no secret defaults', () {
      String out = EnvScaffold().build('''
APP_NAME=dox
APP_KEY="secret"

# Server port
APP_PORT=3000
APP_DEBUG=true
# no value means optional
AWS_BUCKET=
S3__X=1
APP_TOTAL_ISOLATE=4 # one per core
APP_MOTTO="a # b"
''');
      expect(out, contains('String get appName;'));
      expect(out, contains('String get appKey;'));
      expect(out, isNot(contains('secret')));
      expect(out, contains('  /// Server port\n  int get appPort => 3000;'));
      expect(out, contains('bool get appDebug => true;'));
      expect(
        out,
        contains('  /// no value means optional\n  String? get awsBucket;'),
      );
      expect(out, contains("@EnvKey('S3__X')\n  int get s3X => 1;"));
      expect(out, contains('int get appTotalIsolate => 4;'));
      expect(out, contains('String get appMotto;'));
      expect(out, contains(r'return _$AppEnv.load(reader);'));
      expect(out, contains('final AppEnv env = AppEnv.load();'));
    });

    test('writes lib/config/env.dart once', () {
      Directory original = Directory.current;
      Directory temp = Directory.systemTemp.createTempSync('dox_env_test_');
      Directory.current = temp;
      try {
        expect(envGenerate(), isFalse); // no .env.example
        File('.env.example').writeAsStringSync('APP_NAME=dox\n');
        expect(envGenerate(), isTrue);
        expect(
          File('lib/config/env.dart').readAsStringSync(),
          contains('String get appName;'),
        );
        expect(envGenerate(), isFalse); // already there
        exitCode = 0;
      } finally {
        Directory.current = original;
        temp.deleteSync(recursive: true);
      }
    });
  });
}
