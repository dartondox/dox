import 'dart:convert';

import 'package:dox_core/dox.dart';
import 'package:encrypt/encrypt.dart';

class AESEncryptor {
  static String encode(content) {
    var plainText = base64.encode(utf8.encode(content));
    final iv = IV.fromLength(16);
    final key = Key.fromUtf8(Dox().config.appKey);
    final encrypter = Encrypter(AES(key));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return encrypted.base64;
  }

  static String decode(cipherText) {
    try {
      final key = Key.fromUtf8(Dox().config.appKey);
      final iv = IV.fromLength(16);
      final encrypter = Encrypter(AES(key));
      final decrypted = encrypter.decrypt64(cipherText, iv: iv);
      return utf8.decode(base64.decode(decrypted));
    } catch (error) {
      print(error);
      return '';
    }
  }
}
