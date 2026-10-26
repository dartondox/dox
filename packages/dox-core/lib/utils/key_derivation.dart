import 'dart:convert';
import 'dart:typed_data';

import 'package:dox_core/app.dart';
import 'package:pointycastle/export.dart';

/// Makes keys for one purpose from one secret, with HKDF-SHA256
/// (RFC 5869).
///
/// Dox uses `APP_KEY` for many things: cookies, JWTs, signed URLs.
/// Each one gets its own key, made from `APP_KEY` and a label. So a
/// value made for one purpose can not be used for another one.
/// ```
/// Uint8List key = KeyDerivation.forAppKey(KeyDerivation.jwt);
/// ```
class KeyDerivation {
  /// label of the key that `AESEncryptor` uses by default
  static const String encrypt = 'dox:encrypt';

  /// label of the key that encrypts cookies (and the cookie session)
  static const String cookie = 'dox:cookie';

  /// label of the key that signs JWTs of dox_auth
  static const String jwt = 'dox:jwt';

  /// label of the key that signs URLs, like the local signed URLs of
  /// dox_storage
  static const String signedUrl = 'dox:signed-url';

  /// keys made in this isolate, by secret and label
  static final Map<String, Uint8List> _cache = <String, Uint8List>{};

  /// HKDF-SHA256 of RFC 5869: [length] bytes made from [secret], [info]
  /// and [salt]. An empty [salt] is 32 zero bytes, like the RFC says.
  static Uint8List hkdf(
    List<int> secret,
    List<int> info, {
    List<int> salt = const <int>[],
    int length = 32,
  }) {
    if (length < 1 || length > 255 * 32) {
      throw ArgumentError.value(length, 'length', 'must be 1 to 8160');
    }
    // extract: PRK = HMAC(salt, secret)
    Uint8List prk = _hmac(salt.isEmpty ? Uint8List(32) : salt, secret);
    // expand: T(i) = HMAC(PRK, T(i-1) + info + i)
    Uint8List out = Uint8List(length);
    Uint8List block = Uint8List(0);
    int done = 0;
    for (int i = 1; done < length; i++) {
      block = _hmac(prk, <int>[...block, ...info, i]);
      int take = length - done < block.length ? length - done : block.length;
      out.setRange(done, done + take, block);
      done += take;
    }
    return out;
  }

  /// The 32-byte key for [label], made from [secret]. It is made once per
  /// isolate, then read from a cache.
  static Uint8List derive(String secret, String label) {
    return _cache.putIfAbsent(
      '$label\n$secret',
      () => hkdf(utf8.encode(secret), utf8.encode(label)),
    );
  }

  /// The 32-byte key for [label], made from `APP_KEY` of the app.
  static Uint8List forAppKey(String label) {
    return derive(Dox().config.appKey, label);
  }

  static Uint8List _hmac(List<int> key, List<int> data) {
    HMac mac = HMac(SHA256Digest(), 64)
      ..init(KeyParameter(Uint8List.fromList(key)));
    return mac.process(Uint8List.fromList(data));
  }
}
