import 'dart:typed_data';

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

Uint8List _hex(String hex) {
  return Uint8List.fromList(<int>[
    for (int i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ]);
}

String _toHex(List<int> bytes) {
  return bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();
}

void main() {
  group('KeyDerivation.hkdf | RFC 5869', () {
    test('test case 1', () {
      Uint8List okm = KeyDerivation.hkdf(
        _hex('0b' * 22),
        _hex('f0f1f2f3f4f5f6f7f8f9'),
        salt: _hex('000102030405060708090a0b0c'),
        length: 42,
      );
      expect(
        _toHex(okm),
        '3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf'
        '34007208d5b887185865',
      );
    });

    test('test case 2: long inputs', () {
      String bytes(int from, int to) {
        return _toHex(<int>[for (int i = from; i <= to; i++) i]);
      }

      Uint8List okm = KeyDerivation.hkdf(
        _hex(bytes(0x00, 0x4f)),
        _hex(bytes(0xb0, 0xff)),
        salt: _hex(bytes(0x60, 0xaf)),
        length: 82,
      );
      expect(
        _toHex(okm),
        'b11e398dc80327a1c8e7f78c596a49344f012eda2d4efad8a050cc4c19afa97c'
        '59045a99cac7827271cb41c65e590e09da3275600c2f09b8367793a9aca3db71'
        'cc30c58179ec3e87c14c01d5c1f3434f1d87',
      );
    });

    test('test case 3: no salt and no info', () {
      Uint8List okm = KeyDerivation.hkdf(_hex('0b' * 22), <int>[], length: 42);
      expect(
        _toHex(okm),
        '8da4e775a563c18f715f802a063c5a31b8a11f5c5ee1879ec3454e5f3c738d2d'
        '9d201395faa4b61a96c8',
      );
    });
  });

  group('KeyDerivation.derive |', () {
    String secret = '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt';

    test('one 32-byte key per label, not the secret itself', () {
      Uint8List cookie = KeyDerivation.derive(secret, KeyDerivation.cookie);
      Uint8List jwt = KeyDerivation.derive(secret, KeyDerivation.jwt);
      expect(cookie.length, 32);
      expect(_toHex(cookie), isNot(_toHex(jwt)));
      expect(_toHex(cookie), isNot(_toHex(secret.codeUnits)));
      // the same key again, from the cache
      expect(
        identical(cookie, KeyDerivation.derive(secret, 'dox:cookie')),
        isTrue,
      );
    });

    test('a value encrypted for one purpose can not be read with another', () {
      String sealed = AESEncryptor.encode(
        'hello',
        secret,
        purpose: KeyDerivation.cookie,
      );
      expect(
        AESEncryptor.decode(sealed, secret, purpose: KeyDerivation.cookie),
        'hello',
      );
      expect(
        () => AESEncryptor.decode(sealed, secret),
        throwsA(isA<DecryptException>()),
      );
    });
  });
}
