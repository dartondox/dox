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
///
/// [associatedData] binds the text to a context, like a cookie name.
/// It is not stored in the output. `decode` needs the same value, or it
/// fails. So a value made for one cookie can not be used as another.
class AESEncryptor {
  static const int _nonceLength = 12;
  static const int _tagBits = 128;
  static final Random _random = Random.secure();

  /// key bytes of the last secret. Apps use one secret, so this skips
  /// the utf8 encode on every call.
  static String? _lastSecret;
  static Uint8List _lastKey = Uint8List(0);

  /// encode a message
  ///```
  /// AESEncryptor.encode('message', secret);
  ///```
  static String encode(
    String content,
    String secret, {
    String associatedData = '',
  }) {
    Uint8List nonce = Uint8List(_nonceLength);
    for (int i = 0; i < _nonceLength; i++) {
      nonce[i] = _random.nextInt(256);
    }
    GCMBlockCipher cipher = _cipher(true, secret, nonce, associatedData);
    Uint8List input = utf8.encode(content);

    /// write nonce + ciphertext + tag into one buffer
    Uint8List out = Uint8List(
      _nonceLength + cipher.getOutputSize(input.length),
    );
    out.setAll(0, nonce);
    int length = cipher.processBytes(input, 0, input.length, out, _nonceLength);
    length += cipher.doFinal(out, _nonceLength + length);
    return base64.encode(Uint8List.sublistView(out, 0, _nonceLength + length));
  }

  /// decode a message.
  /// Throws [DecryptException] when the text was changed or the key is wrong.
  ///```
  /// AESEncryptor.decode('encoded_message', secret);
  ///```
  static String decode(
    String content,
    String secret, {
    String associatedData = '',
  }) {
    try {
      Uint8List data = base64.decode(content);
      Uint8List nonce = Uint8List.sublistView(data, 0, _nonceLength);
      Uint8List sealed = Uint8List.sublistView(data, _nonceLength);
      return utf8.decode(
        _cipher(false, secret, nonce, associatedData).process(sealed),
      );
    } catch (_) {
      throw DecryptException();
    }
  }

  static GCMBlockCipher _cipher(
    bool forEncryption,
    String secret,
    Uint8List nonce,
    String associatedData,
  ) {
    return GCMBlockCipher(AESEngine())..init(
      forEncryption,
      AEADParameters<KeyParameter>(
        KeyParameter(_key(secret)),
        _tagBits,
        nonce,
        utf8.encode(associatedData),
      ),
    );
  }

  static Uint8List _key(String secret) {
    if (secret != _lastSecret) {
      _lastKey = utf8.encode(secret);
      _lastSecret = secret;
    }
    return _lastKey;
  }
}
