import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import '../integration/requirements/config/app.dart';

void main() {
  group('DoxCookie |', () {
    test('get', () {
      Dox().config = config;
      DoxCookie cookie = DoxCookie('x-auth', 'Bearerxxxxxxxxx');
      String cookieValue = cookie.get();
      RegExpMatch m = RegExp(r'^x-auth=(.+); Max-Age=3600$')
          .firstMatch(cookieValue)!;
      expect(
        AESEncryptor.decode(m.group(1)!, config.appKey),
        'Bearerxxxxxxxxx',
      );
    });

    test('expire', () {
      Dox().config = config;
      DoxCookie cookie = DoxCookie('x-auth', '');
      String cookieValue = cookie.expire();
      expect(cookieValue, 'x-auth=; Max-Age=-1');
    });
  });
}
