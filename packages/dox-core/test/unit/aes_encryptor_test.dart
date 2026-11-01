import 'dart:convert';
import 'dart:typed_data';

import 'package:dox_core/dox_core.dart';
import 'package:dox_http_native/dox_http_native.dart';
import 'package:test/test.dart';

/// Made by the old pure Dart AES-GCM (pointycastle) of Dox 3.0.0: the
/// message below, secret [secret], purpose `dox:cookie`, associated data
/// `dox_session`, nonce 0..11. A value from an older Dox must still open.
const String legacyValue =
    'AAECAwQFBgcICQoLJZMCWYL93OlHMVjfg+dWmnlzNFSdlz4E0rb+xopH507kJqvsZlzxL5aejA==';

void main() {
  group('AES Encryptor |', () {
    String secret = '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt';
    String message = 'Dox Framework {"k":"ünï"}';

    test('encode/decode success', () {
      String encoded = AESEncryptor.encode(message, secret);
      expect(AESEncryptor.decode(encoded, secret), message);
    });

    test('works when the secret changes between calls', () {
      String other = 'abcdefghijklmnopqrstuvwxyz123456';
      String a = AESEncryptor.encode(message, secret);
      String b = AESEncryptor.encode('', other);
      expect(AESEncryptor.decode(a, secret), message);
      expect(AESEncryptor.decode(b, other), '');
      expect(
        () => AESEncryptor.decode(a, other),
        throwsA(isA<DecryptException>()),
      );
      // nonce (12) + empty text + tag (16)
      expect(base64.decode(b).length, 28);
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

    test('a value made by the old pure Dart code still opens', () {
      expect(
        AESEncryptor.decode(
          legacyValue,
          secret,
          associatedData: 'dox_session',
          purpose: KeyDerivation.cookie,
        ),
        message,
      );
    });

    test('a new value has the old layout: nonce + ciphertext + tag', () {
      String encoded = AESEncryptor.encode(
        message,
        secret,
        associatedData: 'name',
      );
      Uint8List data = base64.decode(encoded);
      expect(data.length, 12 + utf8.encode(message).length + 16);
      Uint8List key = KeyDerivation.derive(secret, KeyDerivation.encrypt);
      expect(
        utf8.decode(AesGcm.open(key, data, utf8.encode('name'))!),
        message,
      );
    });

    test('text that is not base64 or not UTF-8 throws DecryptException', () {
      expect(
        () => AESEncryptor.decode('***', secret),
        throwsA(isA<DecryptException>()),
      );
      Uint8List key = KeyDerivation.derive(secret, KeyDerivation.encrypt);
      Uint8List sealed = AesGcm.seal(
        key,
        Uint8List.fromList(<int>[0xff, 0xfe]),
        Uint8List(0),
      );
      expect(
        () => AESEncryptor.decode(base64.encode(sealed), secret),
        throwsA(isA<DecryptException>()),
      );
    });
  });
}
