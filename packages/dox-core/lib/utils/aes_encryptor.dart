import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// AES-CTR (SIC) with PKCS7 padding and a zero IV.
/// The output is the same as the old `encrypt` package gave with
/// `Encrypter(AES(key))`, so cookies and cache files made before still decode.
class AESEncryptor {
  static final Uint8List _iv = Uint8List(16);

  /// encode a message
  ///```
  /// AESEncryptor.encode('message');
  ///```
  static String encode(String content, String secret) {
    Uint8List plain = utf8.encode(base64.encode(utf8.encode(content)));
    return base64.encode(_cipher(true, secret).process(plain));
  }

  /// decode a message
  ///```
  /// AESEncryptor.decode('encoded_message');
  ///```
  static String decode(String content, String secret) {
    try {
      Uint8List decrypted = _cipher(
        false,
        secret,
      ).process(base64.decode(content));
      return utf8.decode(base64.decode(utf8.decode(decrypted)));
    } catch (error) {
      print('AESEncryption Error: ${error.toString()}');
      return '';
    }
  }

  static PaddedBlockCipher _cipher(bool forEncryption, String secret) {
    return PaddedBlockCipherImpl(
      PKCS7Padding(),
      SICBlockCipher(16, SICStreamCipher(AESEngine())),
    )..init(
      forEncryption,
      PaddedBlockCipherParameters<CipherParameters, CipherParameters?>(
        ParametersWithIV<KeyParameter>(KeyParameter(utf8.encode(secret)), _iv),
        null,
      ),
    );
  }
}
