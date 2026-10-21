import 'package:dox_storage/dox_storage.dart';
import 'package:test/test.dart';

void main() {
  KeyNormalizer normalizer = const KeyNormalizer();

  group('KeyNormalizer', () {
    test('cleans slashes and dot segments', () {
      expect(normalizer.key('a//b/./c.txt'), 'a/b/c.txt');
      expect(normalizer.key(r'a\b\c.txt'), 'a/b/c.txt');
      expect(normalizer.key('a/b/'), 'a/b');
    });

    test('keeps names that only look like dots', () {
      expect(normalizer.key('a/..b/c..'), 'a/..b/c..');
      expect(normalizer.key('.hidden'), '.hidden');
    });

    test('rejects path traversal', () {
      for (String bad in <String>[
        '..',
        '../a',
        'a/../b',
        'a/..',
        r'a\..\b',
      ]) {
        expect(
          () => normalizer.key(bad),
          throwsA(isA<InvalidKeyException>()),
          reason: bad,
        );
      }
    });

    test('rejects absolute paths and drive letters', () {
      for (String bad in <String>['/etc/passwd', r'\etc', 'C:/x', r'c:\x']) {
        expect(
          () => normalizer.key(bad),
          throwsA(isA<InvalidKeyException>()),
          reason: bad,
        );
      }
    });

    test('rejects null bytes and empty keys', () {
      expect(() => normalizer.key('a\u0000b'),
          throwsA(isA<InvalidKeyException>()));
      expect(() => normalizer.key(''), throwsA(isA<InvalidKeyException>()));
      expect(() => normalizer.key('./'), throwsA(isA<InvalidKeyException>()));
    });

    test('prefix allows empty (root)', () {
      expect(normalizer.prefix(''), '');
      expect(normalizer.prefix('photos/'), 'photos');
      expect(
          () => normalizer.prefix('../x'), throwsA(isA<InvalidKeyException>()));
    });
  });

  test('KeyEncoder encodes each segment', () {
    expect(const KeyEncoder().urlPath('my dir/a&b.txt'), 'my%20dir/a%26b.txt');
  });
}
