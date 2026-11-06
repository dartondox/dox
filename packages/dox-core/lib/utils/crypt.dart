import 'dart:convert';

import 'package:dox_core/dox_core.dart';

/// Encrypt and decrypt with the `APP_KEY` of the app (AES-256-GCM).
/// Old keys in `AppConfig.previousKeys` can still decrypt.
/// ```
/// String secret = Crypt.encryptString('card-1234');
/// String card = Crypt.decryptString(secret);
/// ```
/// It gives the same text as `AESEncryptor.encode(value, appKey)`.
class Crypt {
  /// [value] encrypted, as base64 text
  static String encryptString(String value) {
    return AESEncryptor.encode(value, Dox().config.appKey);
  }

  /// the text of [encrypted]. Throws [DecryptException] when it was
  /// changed or made with another key.
  static String decryptString(String encrypted) {
    AppConfig config = Dox().config;
    return AESEncryptor.decode(
      encrypted,
      config.appKey,
      previousSecrets: config.previousKeys,
    );
  }

  /// [value] as JSON, encrypted. Use it for maps, lists and numbers.
  static String encrypt(Object? value) {
    return encryptString(jsonEncode(value));
  }

  /// the value of [encrypted] made with [encrypt]. Throws
  /// [DecryptException] when it is not valid, or the text in it is not JSON
  /// (it was made with [encryptString]).
  static dynamic decrypt(String encrypted) {
    String text = decryptString(encrypted);
    try {
      return jsonDecode(text);
    } on FormatException {
      throw DecryptException();
    }
  }
}
