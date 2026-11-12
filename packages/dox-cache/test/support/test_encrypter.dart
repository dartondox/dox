import 'dart:convert';

import 'package:dox_cache/dox_cache.dart';

/// A fake encrypter for tests. Text made with one key does not decrypt
/// with another key.
class TestEncrypter implements CacheEncrypter {
  const TestEncrypter(this.key);

  final String key;

  @override
  String encrypt(String text) {
    return base64Encode(utf8.encode('$key|$text'));
  }

  @override
  String decrypt(String text) {
    String plain = utf8.decode(base64Decode(text));
    if (!plain.startsWith('$key|')) {
      throw const FormatException('wrong key');
    }
    return plain.substring(key.length + 1);
  }
}
