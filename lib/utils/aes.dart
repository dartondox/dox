import 'dart:convert';

import 'package:encrypt/encrypt.dart';

class AESEncoder {
  final String secret;

  const AESEncoder(this.secret);

  String encode(content) {
    var encoded = base64.encode(utf8.encode(content));
    return encryptAESCryptoJS(encoded, secret);
  }

  decode(encodedContent) {
    try {
      var decrypted = decryptAESCryptoJS(encodedContent, secret);
      return utf8.decode(base64.decode(decrypted));
    } catch (error) {
      print(error);
      return null;
    }
  }

  String encryptAESCryptoJS(String plainText, String secretKey) {
    final iv = IV.fromLength(16);
    final key = Key.fromUtf8(secretKey);
    final encrypter = Encrypter(AES(key));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return encrypted.base64;
  }

  String decryptAESCryptoJS(String cipherText, String secretKey) {
    final key = Key.fromUtf8(secretKey);
    final iv = IV.fromLength(16);
    final encrypter = Encrypter(AES(key));
    final decrypted = encrypter.decrypt64(cipherText, iv: iv);
    return decrypted;
  }
}
