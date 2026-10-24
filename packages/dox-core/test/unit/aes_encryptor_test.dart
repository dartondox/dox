import 'dart:convert';

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

void main() {
  group('AES Encryptor |', () {
    String secret = '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt';
    String message = 'Dox Framework {"k":"ünï"}';

    test('encode/decode success', () {
      String encoded = AESEncryptor.encode(message, secret);
      expect(AESEncryptor.decode(encoded, secret), message);
    });

    test('same text gives a different output each time', () {
      expect(
        AESEncryptor.encode(message, secret),
        isNot(AESEncryptor.encode(message, secret)),
      );
    });

    test('decode with a wrong key throws', () {
      String encoded = AESEncryptor.encode(message, secret);
      expect(
        () => AESEncryptor.decode(encoded, 'x' * 32),
        throwsA(isA<DecryptException>()),
      );
    });

    test('decode with other associated data throws', () {
      String encoded = AESEncryptor.encode(
        message,
        secret,
        associatedData: 'locale',
      );
      expect(
        AESEncryptor.decode(encoded, secret, associatedData: 'locale'),
        message,
      );
      expect(
        () => AESEncryptor.decode(encoded, secret, associatedData: 'user_id'),
        throwsA(isA<DecryptException>()),
      );
    });

    test('decode of changed text throws', () {
      List<int> bytes = base64.decode(AESEncryptor.encode(message, secret));
      bytes[20] ^= 1;
      expect(
        () => AESEncryptor.decode(base64.encode(bytes), secret),
        throwsA(isA<DecryptException>()),
      );
    });

    test('decode of bad text throws a 400 error', () {
      for (String bad in <String>['', 'abc', 'not base64!']) {
        expect(
          () => AESEncryptor.decode(bad, secret),
          throwsA(
            isA<DecryptException>().having(
              (DecryptException e) => e.code,
              'code',
              400,
            ),
          ),
        );
      }
    });
  });
}
