import 'package:dox_app/config/env.dart';
import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

AppEnv load(
  Map<String, String> dotEnv, [
  Map<String, String> environment = const <String, String>{},
]) {
  return AppEnv.load(EnvReader(environment: environment, dotEnv: dotEnv));
}

void main() {
  group('AppEnv |', () {
    test('defaults when keys are missing', () {
      AppEnv env = load(<String, String>{});
      expect(env.appName, 'dox');
      expect(env.appPort, 3000);
      expect(env.socketioEnabled, isFalse);
      expect(env.dbPort, isNull);
      expect(env.awsBucket, isNull);
    });

    test('reads and converts values', () {
      AppEnv env = load(<String, String>{
        'APP_PORT': '8080',
        'SOCKETIO_ENABLED': 'true',
        'DB_PORT': '5433',
        'AWS_BUCKET': 'files',
      });
      expect(env.appPort, 8080);
      expect(env.socketioEnabled, isTrue);
      expect(env.dbPort, 5433);
      expect(env.awsBucket, 'files');
    });

    test('real environment wins over .env', () {
      AppEnv env = load(
        <String, String>{'APP_NAME': 'file'},
        <String, String>{'APP_NAME': 'shell'},
      );
      expect(env.appName, 'shell');
    });

    test('one error lists every bad key', () {
      expect(
        () => load(<String, String>{'APP_PORT': 'x', 'REDIS_DB': 'y'}),
        throwsA(
          isA<EnvException>().having(
            (EnvException e) => e.errors.length,
            'errors',
            2,
          ),
        ),
      );
    });
  });
}
