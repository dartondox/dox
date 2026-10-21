import 'package:dox_core/utils/aes_encryptor.dart';
import 'package:test/test.dart';

void main() {
  group('AES Encryptor |', () {
    test('encode/decode success', () {
      String secret = '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt';
      String message = 'Dox Framework';
      String encoded = AESEncryptor.encode(message, secret);
      String decoded = AESEncryptor.decode(encoded, secret);
      expect(decoded, message);
    });

    test('encode/decode failed', () {
      String secret = '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt';
      String message = 'Dox Framework';
      String encoded = AESEncryptor.encode(message, secret);
      String decoded = AESEncryptor.decode(encoded, 'abcd');
      expect(decoded, '');
    });

    // made with the old `encrypt` package, so old cookies and cache still work
    test('decodes values from the old encrypt package', () {
      String secret = '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt';
      Map<String, String> old = <String, String>{
        'Dox Framework': 'EBoKsR9VxA+oyQu0yIlxAfzkXBF/5FQOODjbEwej58Y=',
        'a' * 47: 'Gwp17Q9H2B6oyXyw9ewOEMTEJ0Qqvx5qbWORd1L4raLje4tpcVK+juv8fkAGyznaEqFmhZChKuVGxm/AVqJlDn1we1pQCEsmKpUzF1a6H/A=',
        '{"k":"ünï"}': 'JyR59x968R+GqUKt241wEfvCXBF/5FQOODjbEwej58Y=',
      };
      for (MapEntry<String, String> e in old.entries) {
        expect(AESEncryptor.decode(e.value, secret), e.key);
        expect(AESEncryptor.encode(e.key, secret), e.value);
      }
    });
  });
}
