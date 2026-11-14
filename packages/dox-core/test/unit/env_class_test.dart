import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import '../env/app_env.dart';

AppEnv load(Map<String, String> dotEnv) {
  return AppEnv.load(
    EnvReader(environment: const <String, String>{}, dotEnv: dotEnv),
  );
}

void main() {
  group('typed env class |', () {
    test('a default sees the loaded value of another key', () {
      AppEnv env = load(<String, String>{'APP_ENV': 'development'});
      expect(env.appEnv, 'development');
      expect(env.isDevelopment, isTrue);
    });

    test('no APP_ENV uses the default of both getters', () {
      AppEnv env = load(<String, String>{});
      expect(env.appEnv, 'production');
      expect(env.isDevelopment, isFalse);
      expect(env.region, isNull);
    });

    test('a set key wins over the getter body', () {
      AppEnv env = load(<String, String>{
        'APP_ENV': 'development',
        'IS_DEVELOPMENT': 'false',
        'REGION': 'eu',
        'R': 'r',
        'READER': 'reader',
      });
      expect(env.isDevelopment, isFalse);
      expect(env.region, 'eu');
      expect(env.r, 'r');
      expect(env.reader, 'reader');
    });

    test('a default that throws still fails in load()', () {
      expect(
        () => load(<String, String>{'APP_ENV': 'broken'}),
        throwsA(isA<StateError>()),
      );
      AppEnv env = load(<String, String>{'APP_ENV': 'broken', 'BROKEN': 'x'});
      expect(env.broken, 'x');
    });
  });
}
