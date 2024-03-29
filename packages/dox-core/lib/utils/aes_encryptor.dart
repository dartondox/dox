import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';

class AESEncryptor {
  static IV iv = IV(Uint8List(16));

  /// encode a message
  ///```
  /// AESEncryptor.encode('message');
  ///```
  static String encode(String content, String secret) {
    String plainText = base64.encode(utf8.encode(content));
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
      Encrypter encrypter = Encrypter(AES(key));
      String decrypted = encrypter.decrypt64(content, iv: iv);
      return utf8.decode(base64.decode(decrypted));
    } catch (error) {
      print('AESEncryption Error: ${error.toString()}');
      return '';
    }
  }
}
