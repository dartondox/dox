import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

void main() {
  group('webSocketOriginAllowed', () {
    test('no Origin header is allowed (not a browser)', () {
      expect(webSocketOriginAllowed(null, 'app.com', <String>[]), isTrue);
    });

    test('the same host is allowed', () {
      expect(
        webSocketOriginAllowed('https://app.com', 'app.com', <String>[]),
        isTrue,
      );
      expect(
        webSocketOriginAllowed(
          'http://App.com:8080',
          'app.com:8080',
          <String>[],
        ),
        isTrue,
      );
      expect(
        webSocketOriginAllowed('http://app.com', 'app.com:80', <String>[]),
        isTrue,
      );
    });

    test('another site is not allowed', () {
      expect(
        webSocketOriginAllowed('https://evil.com', 'app.com', <String>[]),
        isFalse,
      );
      expect(
        webSocketOriginAllowed(
          'http://app.com:9000',
          'app.com:8080',
          <String>[],
        ),
        isFalse,
      );
      expect(
        webSocketOriginAllowed(
          'https://app.com.evil.com',
          'app.com',
          <String>[],
        ),
        isFalse,
      );
      expect(webSocketOriginAllowed('null', 'app.com', <String>[]), isFalse);
      expect(
        webSocketOriginAllowed('https://evil.com', null, <String>[]),
        isFalse,
      );
    });

    test('a site in allowedOrigins is allowed', () {
      List<String> allowed = <String>['https://admin.app.com/'];
      expect(
        webSocketOriginAllowed('https://ADMIN.app.com', 'api.app.com', allowed),
        isTrue,
      );
      expect(
        webSocketOriginAllowed('http://admin.app.com', 'api.app.com', allowed),
        isFalse,
      );
    });

    test('* allows every site', () {
      expect(
        webSocketOriginAllowed('https://evil.com', 'app.com', <String>['*']),
        isTrue,
      );
    });
  });
}
