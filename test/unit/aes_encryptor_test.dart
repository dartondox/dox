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
  });
}
