import 'dart:convert';
import 'dart:typed_data';

import 'package:dox_core/dox_core.dart';
import 'package:pointycastle/export.dart';
import 'package:test/test.dart';

/// AES-GCM in pure Dart, like `AESEncryptor` before it moved to Rust.
/// Values made by older Dox versions must still open.
GCMBlockCipher dartGcm(
  bool forEncryption,
  Uint8List key,
  Uint8List nonce,
  String aad,
) {
  return GCMBlockCipher(AESEngine())..init(
    forEncryption,
    AEADParameters<KeyParameter>(
      KeyParameter(key),
      128,
      nonce,
      utf8.encode(aad),
    ),
  );
}

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
      Uint8List nonce = Uint8List.fromList(
        List<int>.generate(12, (int i) => i),
      );
      Uint8List key = KeyDerivation.derive(secret, KeyDerivation.cookie);
      Uint8List sealed = dartGcm(
        true,
        key,
        nonce,
        'dox_session',
      ).process(utf8.encode(message));
      String old = base64.encode(<int>[...nonce, ...sealed]);
      expect(
        AESEncryptor.decode(
          old,
          secret,
          associatedData: 'dox_session',
          purpose: KeyDerivation.cookie,
        ),
        message,
      );
    });

    test('the old pure Dart code opens a new value', () {
      String encoded = AESEncryptor.encode(
        message,
        secret,
        associatedData: 'name',
      );
      Uint8List data = base64.decode(encoded);
      Uint8List key = KeyDerivation.derive(secret, KeyDerivation.encrypt);
      Uint8List plain = dartGcm(
        false,
        key,
        data.sublist(0, 12),
        'name',
      ).process(data.sublist(12));
      expect(utf8.decode(plain), message);
    });

    test('text that is not base64 or not UTF-8 throws DecryptException', () {
      expect(
        () => AESEncryptor.decode('***', secret),
        throwsA(isA<DecryptException>()),
      );
      Uint8List key = KeyDerivation.derive(secret, KeyDerivation.encrypt);
      Uint8List nonce = Uint8List(12);
      Uint8List sealed = dartGcm(
        true,
        key,
        nonce,
        '',
      ).process(Uint8List.fromList(<int>[0xff, 0xfe]));
      expect(
        () => AESEncryptor.decode(
          base64.encode(<int>[...nonce, ...sealed]),
          secret,
        ),
        throwsA(isA<DecryptException>()),
      );
    });
  });
}
