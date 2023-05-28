import 'dart:convert';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/logger.dart';
import 'package:encrypt/encrypt.dart';

class AESEncryptor {
  /// encode a message
  ///```
  /// AESEncryptor.encode('message');
  ///```
  static String encode(content) {
    var plainText = base64.encode(utf8.encode(content));
    final iv = IV.fromLength(16);
    final key = Key.fromUtf8(Dox().config.appKey);
    final encrypter = Encrypter(AES(key));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return encrypted.base64;
  }

  /// decode a message
  ///```
  /// AESEncryptor.decode('encoded_message');
  ///```
  static String decode(content) {
    try {
      final key = Key.fromUtf8(Dox().config.appKey);
      final iv = IV.fromLength(16);
      final encrypter = Encrypter(AES(key));
      final decrypted = encrypter.decrypt64(content, iv: iv);
      return utf8.decode(base64.decode(decrypted));
    } catch (error) {
      DoxLogger.danger(error.toString());
      return '';
    }
  }
}
