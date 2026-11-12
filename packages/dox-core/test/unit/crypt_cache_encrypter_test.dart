import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

const String oldKey = 'old-key-of-32-characters-xxxxxxx';
const String newKey = 'new-key-of-32-characters-xxxxxxx';

void main() {
  group('CryptCacheEncrypter |', () {
    const CryptCacheEncrypter encrypter = CryptCacheEncrypter();

    test('an empty APP_KEY makes encrypt throw a StateError', () {
      Dox().initialize(AppConfig(appKey: ''));
      expect(() => encrypter.encrypt('x'), throwsA(isA<StateError>()));
    });

    test('a value made with an old key is read through previousKeys', () {
      Dox().initialize(AppConfig(appKey: oldKey));
      String secret = encrypter.encrypt('{"a":1}');
      Dox().initialize(
        AppConfig(appKey: newKey, previousKeys: <String>[oldKey]),
      );
      expect(encrypter.decrypt(secret), '{"a":1}');
      Dox().initialize(AppConfig(appKey: newKey));
      expect(() => encrypter.decrypt(secret), throwsA(isA<Object>()));
    });
  });
}
