import 'package:dox_core/utils/aes_encryptor.dart';
import 'package:test/test.dart';

void main() {
  group('AES Encryptor |', () {
    test('encode/decode', () {
      String secret = '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt';
      String message = 'Dox Framework';
      String encoded = AESEncryptor.encode(message, secret);
      String decoded = AESEncryptor.decode(encoded, secret);
      expect(decoded, message);
    });
  });
}
