import 'package:dox_core/http/http_cors_handler.dart';
import 'package:test/test.dart';

void main() {
  group('corsAllowOrigin |', () {
    List<String> list = <String>['https://a.com', 'https://b.com'];

    test('a single origin is sent as it is', () {
      expect(
        corsAllowOrigin('https://a.com', 'https://x.com'),
        'https://a.com',
      );
      expect(corsAllowOrigin('*', 'https://x.com'), '*');
      expect(corsAllowOrigin(null, 'https://x.com'), isNull);
    });

    test('a list sends back only the matching request origin', () {
      expect(corsAllowOrigin(list, 'https://b.com'), 'https://b.com');
      expect(corsAllowOrigin(list, 'https://a.com'), 'https://a.com');
    });

    test('a list sends nothing for an origin that is not in it', () {
      expect(corsAllowOrigin(list, 'https://evil.com'), isNull);
      expect(corsAllowOrigin(list, null), isNull);
    });

    test('a list with * allows every origin', () {
      expect(corsAllowOrigin(<String>['*'], 'https://x.com'), '*');
    });
  });
}
