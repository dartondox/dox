
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/aes.dart';

class DoxCookie {
  final String key;
  final String value;
  final bool encrypt;

  String? path;
  String? domain;
  bool httpOnly = false;
  bool secure = false;
  DateTime? expires;

  Duration maxAge = Duration(hours: 1);

  DoxCookie(this.key, this.value, {this.encrypt = true});

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

  String get() {
    String val =
        encrypt ? AESEncoder(Dox().config.appKey).encode(value) : value;

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
