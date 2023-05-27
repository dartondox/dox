import 'dart:io';

import 'package:dox_core/dox_core.dart';

class DoxCookie {
  final String key;
  final String value;
  final bool encrypt;

  String? path;
  String? domain;
  bool httpOnly;
  bool secure;
  DateTime? expires;
  Duration maxAge;

  DoxCookie(
    this.key,
    this.value, {
    this.encrypt = true,
    this.domain,
    this.path,
    this.httpOnly = false,
    this.secure = false,
    this.expires,
    this.maxAge = const Duration(hours: 1),
  });

  /// set expire the cookie
  /// ```
  /// cookie.expire();
  /// ```
  String expire() {
    var cookie = Cookie(key, value);
    cookie.maxAge = Duration(milliseconds: -1).inMicroseconds;
    cookie.path = path;
    cookie.domain = domain;
    cookie.httpOnly = httpOnly;
    cookie.secure = secure;
    cookie.expires = expires;
    return cookie.toString();
  }

  /// get the cookie to response in http response
  /// ```
  /// cookie.get();
  /// ```
  String get() {
    String val = encrypt ? AESEncryptor.encode(value) : value;

    var cookie = Cookie(key, val);
    cookie.maxAge = maxAge.inMilliseconds;
    cookie.path = path;
    cookie.domain = domain;
    cookie.httpOnly = httpOnly;
    cookie.secure = secure;
    cookie.expires = expires;
    return cookie.toString();
  }
}
