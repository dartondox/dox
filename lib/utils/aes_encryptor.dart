import 'dart:convert';

import 'package:dox_core/utils/logger.dart';
import 'package:encrypt/encrypt.dart';

class AESEncryptor {
  /// encode a message
  ///```
  /// AESEncryptor.encode('message');
  ///```
  static String encode(String content, String secret) {
    String plainText = base64.encode(utf8.encode(content));
    IV iv = IV.fromLength(16);
    Key key = Key.fromUtf8(secret);
    Encrypter encrypter = Encrypter(AES(key));
    Encrypted encrypted = encrypter.encrypt(plainText, iv: iv);
    return encrypted.base64;
  }

  /// decode a message
  ///```
  /// AESEncryptor.decode('encoded_message');
  ///```
  static String decode(String content, String secret) {
    try {
      Key key = Key.fromUtf8(secret);
      IV iv = IV.fromLength(16);
      Encrypter encrypter = Encrypter(AES(key));
      String decrypted = encrypter.decrypt64(content, iv: iv);
      return utf8.decode(base64.decode(decrypted));
    } catch (error) {
      DoxLogger.danger('AESEncryption Error: ${error.toString()}');
      return '';
    }
  }
}
