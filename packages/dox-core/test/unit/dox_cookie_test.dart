import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import '../integration/requirements/config/app.dart';

void main() {
  group('DoxCookie |', () {
    test('get', () {
      Dox().config = Config();
      DoxCookie cookie = DoxCookie('x-auth', 'Bearerxxxxxxxxx');
      String cookieValue = cookie.get();
      expect(cookieValue,
          'x-auth=EzBl7TV9yA+U1lLsyfMgTPjbCRh/5FQOODjbEwej58Y=; Max-Age=3600000');
    });

    test('expire', () {
      Dox().config = Config();
      DoxCookie cookie = DoxCookie('x-auth', '');
      String cookieValue = cookie.expire();
      expect(cookieValue, 'x-auth=; Max-Age=-1000');
    });
  });
}
