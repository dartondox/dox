import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import '../env/app_env.dart';
import '../env/loop_env.dart';

AppEnv load(Map<String, String> dotEnv) {
  return AppEnv.load(
    EnvReader(environment: const <String, String>{}, dotEnv: dotEnv),
  );
}

void main() {
  group('typed env class |', () {
    test('a default sees the loaded value of another key', () {
      AppEnv env = load(<String, String>{'APP_PORT': '4000'});
      expect(env.appPort, 4000);
      expect(env.appUrl, 'http://localhost:4000');
    });

    test('no APP_PORT uses the default of both getters', () {
      AppEnv env = load(<String, String>{});
      expect(env.appPort, 3000);
      expect(env.appUrl, 'http://localhost:3000');
      expect(env.region, isNull);
    });

    test('a set key wins over the getter body', () {
      AppEnv env = load(<String, String>{
        'APP_PORT': '4000',
        'APP_URL': 'https://dox.dev',
        'REGION': 'eu',
        'R': 'r',
        'READER': 'reader',
      });
      expect(env.appUrl, 'https://dox.dev');
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

    test('a default that reads the global env gives a clear error', () {
      expect(
        () => loopEnv,
        throwsA(
          isA<StateError>().having(
            (StateError e) => e.message,
            'message',
            contains('A default of LoopEnv reads the global `env`'),
          ),
        ),
      );
      // the failed load does not block the next one
      LoopEnv env = LoopEnv.load(
        EnvReader(
          environment: const <String, String>{},
          dotEnv: <String, String>{'APP_URL': 'https://dox.dev'},
        ),
      );
      expect(env.appUrl, 'https://dox.dev');
      expect(load(<String, String>{}).appEnv, 'production');
    });
  });
}
