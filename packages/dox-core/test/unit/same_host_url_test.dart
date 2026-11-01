import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

void main() {
  group('sameHostUrl', () {
    test('a path is kept', () {
      expect(sameHostUrl('/form', 'app.com'), '/form');
      expect(sameHostUrl('/form?a=1#x', null), '/form?a=1#x');
    });

    test('a url of the same host is kept', () {
      expect(
        sameHostUrl('https://app.com/form', 'app.com'),
        'https://app.com/form',
      );
      expect(
        sameHostUrl('http://App.com:8080/a', 'app.com:8080'),
        'http://App.com:8080/a',
      );
    });

    test('another site gives null', () {
      expect(sameHostUrl('https://evil.com/x', 'app.com'), isNull);
      expect(sameHostUrl('https://app.com.evil.com/', 'app.com'), isNull);
      expect(sameHostUrl('http://app.com:9000/', 'app.com:8080'), isNull);
      expect(sameHostUrl('https://app.com@evil.com/', 'app.com'), isNull);
      expect(sameHostUrl('https://evil.com/x', null), isNull);
    });

    test('tricks that browsers read as another site give null', () {
      expect(sameHostUrl('//evil.com', 'app.com'), isNull);
      expect(sameHostUrl('/\\evil.com', 'app.com'), isNull);
      expect(sameHostUrl('/\t/evil.com', 'app.com'), isNull);
      expect(sameHostUrl('javascript:alert(1)', 'app.com'), isNull);
      expect(sameHostUrl('', 'app.com'), isNull);
      expect(sameHostUrl(null, 'app.com'), isNull);
    });
  });
}
