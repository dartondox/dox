import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import '../integration/requirements/config/app.dart';

void main() {
  group('Crypt |', () {
    setUpAll(() {
      Dox().initialize(config);
    });

    test('encryptString and decryptString use APP_KEY', () {
      String secret = Crypt.encryptString('card-1234');
      expect(secret, isNot(contains('card')));
      expect(Crypt.decryptString(secret), 'card-1234');
      expect(AESEncryptor.decode(secret, config.appKey), 'card-1234');
    });

    test('encrypt and decrypt keep JSON values', () {
      String secret = Crypt.encrypt(<String, dynamic>{'id': 5});
      expect(Crypt.decrypt(secret), <String, dynamic>{'id': 5});
    });

    test('a value made with another key throws', () {
      String other = AESEncryptor.encode(
        'x',
        'another-key-of-32-characters-xxx',
      );
      expect(
        () => Crypt.decryptString(other),
        throwsA(isA<DecryptException>()),
      );
    });
  });
}
