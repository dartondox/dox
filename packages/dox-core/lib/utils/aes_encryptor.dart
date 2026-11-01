import 'dart:convert';
import 'dart:typed_data';

import 'package:dox_core/exception/bad_request_exception.dart';
import 'package:dox_core/utils/key_derivation.dart';
import 'package:dox_http_native/dox_http_native.dart';

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
///
/// The AES key is not the secret itself. It is made from the secret and
/// a [purpose] label with HKDF-SHA256 (see [KeyDerivation]). Cookies use
/// the label `dox:cookie`, other values `dox:encrypt` by default. A value
/// made for one purpose can not be read with another one.
///
/// The work runs in Rust (`AesGcm` of dox_http_native), with the AES
/// instructions of the CPU.
class AESEncryptor {
  static final Uint8List _noData = Uint8List(0);

  /// encode a message
  ///```
  /// AESEncryptor.encode('message', secret);
  ///```
  static String encode(
    String content,
    String secret, {
    String associatedData = '',
    String purpose = KeyDerivation.encrypt,
  }) {
    Uint8List sealed = AesGcm.seal(
      KeyDerivation.derive(secret, purpose),
      utf8.encode(content),
      _aad(associatedData),
    );
    return base64.encode(sealed);
  }

  /// decode a message.
  /// Throws [DecryptException] when the text was changed or the key is wrong.
  /// When [secret] fails, each of [previousSecrets] is tried (old keys,
  /// see `AppConfig.previousKeys`).
  ///```
  /// AESEncryptor.decode('encoded_message', secret);
  ///```
  static String decode(
    String content,
    String secret, {
    String associatedData = '',
    String purpose = KeyDerivation.encrypt,
    List<String> previousSecrets = const <String>[],
  }) {
    Uint8List data;
    try {
      data = base64.decode(content);
    } on FormatException {
      throw DecryptException();
    }
    Uint8List aad = _aad(associatedData);
    Uint8List? plain = AesGcm.open(
      KeyDerivation.derive(secret, purpose),
      data,
      aad,
    );
    for (int i = 0; plain == null && i < previousSecrets.length; i++) {
      plain = AesGcm.open(
        KeyDerivation.derive(previousSecrets[i], purpose),
        data,
        aad,
      );
    }
    if (plain == null) throw DecryptException();
    try {
      return utf8.decode(plain);
    } on FormatException {
      throw DecryptException();
    }
  }

  static Uint8List _aad(String associatedData) {
    return associatedData.isEmpty ? _noData : utf8.encode(associatedData);
  }
}
