import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import '../integration/requirements/config/app.dart';

void main() {
  group('DoxCookie |', () {
    test('get', () {
      Dox().config = config;
      DoxCookie cookie = DoxCookie('x-auth', 'Bearerxxxxxxxxx');
      String cookieValue = cookie.get();
      RegExpMatch m = RegExp(r'^x-auth=(.+); Max-Age=3600; HttpOnly$')
          .firstMatch(cookieValue)!;
      expect(
        AESEncryptor.decode(
          m.group(1)!,
          config.appKey,
          associatedData: 'x-auth',
          purpose: KeyDerivation.cookie,
        ),
        'Bearerxxxxxxxxx',
      );
      // the cookie key is made from APP_KEY, it is not APP_KEY itself
      expect(
        () => AESEncryptor.decode(
          m.group(1)!,
          config.appKey,
          associatedData: 'x-auth',
        ),
        throwsA(isA<DecryptException>()),
      );
    });

    test('value made for one cookie name fails as another', () {
      Dox().config = config;
      String value = DoxCookie('locale', 'en').get().split(';').first;
      expect(
        () => AESEncryptor.decode(
          value.substring('locale='.length),
          config.appKey,
          associatedData: 'user_id',
          purpose: KeyDerivation.cookie,
        ),
        throwsA(isA<DecryptException>()),
      );
    });

    test('HttpOnly by default, Secure on https', () {
      Dox().config = config;
      DoxCookie cookie = DoxCookie('x', 'y', encrypt: false);
      expect(cookie.get(), 'x=y; Max-Age=3600; HttpOnly');
      expect(cookie.get(https: true), 'x=y; Max-Age=3600; Secure; HttpOnly');
      cookie.secure = false;
      expect(cookie.get(https: true), 'x=y; Max-Age=3600; HttpOnly');
    });

    test('expire', () {
      Dox().config = config;
      DoxCookie cookie = DoxCookie('x-auth', '');
      String cookieValue = cookie.expire();
      expect(cookieValue, 'x-auth=; Max-Age=-1; HttpOnly');
    });
  });
}
