import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dox_core/exception/bad_request_exception.dart';
import 'package:pointycastle/export.dart';

/// Thrown when encrypted text can not be decrypted.
/// The text was changed, cut, or made with another key.
/// Dox answers with 400 Bad Request.
class DecryptException extends BadRequestException {
  DecryptException()
    : super(
        message: 'The encrypted value is not valid',
        errorCode: 'decrypt_failed',
      );
}

/// Encrypt and decrypt text with AES-GCM.
///
/// Each message gets a new random 12-byte nonce.
/// The output is base64 of `nonce + ciphertext + tag`.
/// The 16-byte tag lets `decode` find any change to the text.
class AESEncryptor {
  static const int _nonceLength = 12;
  static const int _tagBits = 128;
  static final Random _random = Random.secure();

  /// encode a message
  ///```
  /// AESEncryptor.encode('message', secret);
  ///```
  static String encode(String content, String secret) {
    Uint8List nonce = Uint8List(_nonceLength);
    for (int i = 0; i < _nonceLength; i++) {
      nonce[i] = _random.nextInt(256);
    }
    Uint8List sealed = _cipher(
      true,
      secret,
      nonce,
    ).process(utf8.encode(content));
    return base64.encode(<int>[...nonce, ...sealed]);
  }

  /// decode a message.
  /// Throws [DecryptException] when the text was changed or the key is wrong.
  ///```
  /// AESEncryptor.decode('encoded_message', secret);
  ///```
  static String decode(String content, String secret) {
    try {
      Uint8List data = base64.decode(content);
      Uint8List nonce = data.sublist(0, _nonceLength);
      Uint8List sealed = data.sublist(_nonceLength);
      return utf8.decode(_cipher(false, secret, nonce).process(sealed));
    } catch (_) {
      throw DecryptException();
    }
  }

  static GCMBlockCipher _cipher(
    bool forEncryption,
    String secret,
    Uint8List nonce,
  ) {
    return GCMBlockCipher(AESEngine())..init(
      forEncryption,
      AEADParameters<KeyParameter>(
        KeyParameter(utf8.encode(secret)),
        _tagBits,
        nonce,
        Uint8List(0),
      ),
    );
  }
}
