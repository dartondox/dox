import 'dart:io';

import 'package:dox_core/app.dart';
import 'package:dox_core/utils/aes_encryptor.dart';

class DoxCookie {
  final String key;
  final String value;
  final bool encrypt;

  String? path;
  String? domain;

  /// true by default, so page scripts can not read the cookie.
  bool httpOnly;

  /// null by default: secure when the request came over https
  /// (see `req.scheme()`). set true or false to choose yourself.
  bool? secure;
  DateTime? expires;
  Duration maxAge;

  DoxCookie(
    this.key,
    this.value, {
    this.encrypt = true,
    this.domain,
    this.path,
    this.httpOnly = true,
    this.secure,
    this.expires,
    this.maxAge = const Duration(hours: 1),
  });

  /// set expire the cookie
  /// ```
  /// cookie.expire();
  /// ```
  /// [https] sets `Secure` when [secure] is null.
  String expire({bool https = false}) {
    Cookie cookie = Cookie(key, value);
    cookie.maxAge = -1;
    cookie.path = path;
    cookie.domain = domain;
    cookie.httpOnly = httpOnly;
    cookie.secure = secure ?? https;
    cookie.expires = expires;
    return cookie.toString();
  }

  /// get the cookie to response in http response
  /// ```
  /// cookie.get();
  /// ```
  /// [https] sets `Secure` when [secure] is null.
  /// the cookie name is bound to the encrypted value, so the value can
  /// not be copied to another cookie.
  String get({bool https = false}) {
    String val = encrypt
        ? AESEncryptor.encode(value, Dox().config.appKey, associatedData: key)
        : value;

    Cookie cookie = Cookie(key, val);
    cookie.maxAge = maxAge.inSeconds;
    cookie.path = path;
    cookie.domain = domain;
    cookie.httpOnly = httpOnly;
    cookie.secure = secure ?? https;
    cookie.expires = expires;
    return cookie.toString();
  }
}
