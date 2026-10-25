import 'package:dox_validation/dox_validation.dart';
import 'package:test/test.dart';

class FakeFile implements FileInput {
  FakeFile(this.extension, [this.head = const <int>[]]);

  @override
  final String extension;

  @override
  final List<int> head;

  @override
  int get length => head.length;
}

const List<int> pngBytes = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
];
const List<int> pdfBytes = <int>[0x25, 0x50, 0x44, 0x46, 0x2D, 0x31];

String firstCode(ParseResult<Object?> result) {
  return result.issues.first.code;
}

void main() {
  group('string |', () {
    test('accepts text', () {
      expect(v.string().parse('dox'), 'dox');
    });

    test('rejects a number', () {
      ParseResult<String> result = v.string().safeParse(12);
      expect(result.success, false);
      expect(firstCode(result), IssueCodes.string);
      expect(result.issues.first.message, 'The value must be a string');
    });

    test('null and undefined are required', () {
      expect(firstCode(v.string().safeParse(null)), IssueCodes.required);
      expect(firstCode(v.string().safeParse(undefined)), IssueCodes.required);
    });

    test('min, max, length', () {
      StringSchema s = v.string().min(3).max(5);
      expect(s.safeParse('ab').success, false);
      expect(s.safeParse('abc').success, true);
      expect(s.safeParse('abcdef').success, false);
      expect(v.string().length(2).safeParse('ab').success, true);
      expect(v.string().length(2).safeParse('abc').success, false);
      expect(v.string().nonEmpty().safeParse('').success, false);
    });

    test('collects all failed checks', () {
      ParseResult<String> result = v.string().min(10).email().safeParse('x');
      expect(
        result.issues.map((ValidationIssue i) => i.code).toList(),
        <String>[IssueCodes.minLength, IssueCodes.email],
      );
    });

    test('formats', () {
      expect(v.string().email().safeParse('a@b.dev').success, true);
      expect(v.string().email().safeParse('nope').success, false);
      expect(v.string().url().safeParse('https://dartondox.dev').success, true);
      expect(v.string().url().safeParse('just text').success, false);
      expect(
        v.string().url().safeParse('javascript://x.com/%0aalert(1)').success,
        false,
      );
      expect(
        v
            .string()
            .url(schemes: <String>['ftp'])
            .safeParse('ftp://x.dev')
            .success,
        true,
      );
      expect(
        v
            .string()
            .uuid()
            .safeParse('3f1d2c8e-1b2a-4c3d-9e8f-0a1b2c3d4e5f')
            .success,
        true,
      );
      expect(v.string().uuid().safeParse('abc').success, false);
      expect(v.string().ip().safeParse('192.168.1.1').success, true);
      expect(v.string().ip().safeParse('999.1.1.1').success, false);
      expect(
        v.string().datetime().safeParse('2024-01-31T10:00:00Z').success,
        true,
      );
      expect(v.string().datetime().safeParse('2024/01/31').success, false);
    });

    test('regex, startsWith, endsWith, includes', () {
      expect(v.string().regex(RegExp(r'^\d+$')).safeParse('123').success, true);
      expect(
        v.string().regex(RegExp(r'^\d+$')).safeParse('12a').success,
        false,
      );
      expect(v.string().startsWith('do').safeParse('dox').success, true);
      expect(v.string().startsWith('da').safeParse('dox').success, false);
      expect(v.string().endsWith('x').safeParse('dox').success, true);
      expect(v.string().includes('o').safeParse('dox').success, true);
      expect(v.string().includes('z').safeParse('dox').success, false);
    });

    test('alpha rules', () {
      expect(v.string().alpha().safeParse('dox').success, true);
      expect(v.string().alpha().safeParse('dox1').success, false);
      expect(v.string().alphaDash().safeParse('dox_web-x').success, true);
      expect(v.string().alphaNumeric().safeParse('dox1').success, true);
      expect(v.string().alphaNumeric().safeParse('&@#').success, false);
    });

    test('trim and case run before checks', () {
      expect(v.string().trim().min(3).parse('  dox  '), 'dox');
      expect(v.string().toLowerCase().parse('DoX'), 'dox');
      expect(v.string().toUpperCase().parse('dox'), 'DOX');
    });

    test('custom message per rule', () {
      ParseResult<String> result = v
          .string()
          .min(3, message: 'Too short: {min}')
          .safeParse('a');
      expect(result.issues.first.message, 'Too short: 3');
    });

    test('fluent methods return copies', () {
      StringSchema base = v.string();
      StringSchema strict = base.min(3);
      expect(base.safeParse('a').success, true);
      expect(strict.safeParse('a').success, false);
    });
  });

  group('int and num |', () {
    test('int accepts int only', () {
      expect(v.int().parse(5), 5);
      expect(firstCode(v.int().safeParse('5')), IssueCodes.integer);
      expect(firstCode(v.int().safeParse(5.5)), IssueCodes.integer);
    });

    test('num accepts int and double', () {
      expect(v.num().parse(5), 5);
      expect(v.num().parse(5.5), 5.5);
      expect(firstCode(v.num().safeParse('5')), IssueCodes.numeric);
      expect(v.num().safeParse(double.nan).success, false);
    });

    test('min, max, gt, lt, positive, nonNegative, multipleOf', () {
      expect(v.int().min(1).safeParse(0).success, false);
      expect(v.int().min(1).safeParse(1).success, true);
      expect(v.int().max(1).safeParse(2).success, false);
      expect(v.int().gt(1).safeParse(1).success, false);
      expect(v.int().lt(1).safeParse(1).success, false);
      expect(v.num().positive().safeParse(0).success, false);
      expect(v.num().nonNegative().safeParse(0).success, true);
      expect(v.int().multipleOf(5).safeParse(10).success, true);
      expect(v.int().multipleOf(5).safeParse(11).success, false);
    });

    test('message has the limit', () {
      ParseResult<int> result = v.int().min(18).safeParse(3);
      expect(
        result.issues.first.message,
        'The value must be greater than or equal 18',
      );
    });
  });

  group('bool |', () {
    test('strict by default', () {
      expect(v.bool().parse(true), true);
      expect(firstCode(v.bool().safeParse('true')), IssueCodes.boolean);
    });
  });

  group('date |', () {
    test('accepts DateTime only', () {
      DateTime now = DateTime(2024, 1, 2);
      expect(v.date().parse(now), now);
      expect(firstCode(v.date().safeParse('2024-01-01')), IssueCodes.date);
    });

    test('min and max', () {
      DateSchema s = v.date().min(DateTime(2024)).max(DateTime(2025));
      expect(s.safeParse(DateTime(2023)).success, false);
      expect(s.safeParse(DateTime(2024, 6)).success, true);
      expect(s.safeParse(DateTime(2026)).success, false);
    });
  });

  group('enum and literal |', () {
    test('enumOf', () {
      EnumSchema<String> s = v.enumOf<String>(<String>['active', 'pending']);
      expect(s.parse('active'), 'active');
      ParseResult<String> result = s.safeParse('failed');
      expect(
        result.issues.first.message,
        'The selected value is invalid. Valid options are active, and pending',
      );
    });

    test('literal', () {
      expect(v.literal<String>('yes').parse('yes'), 'yes');
      expect(firstCode(v.literal<int>(1).safeParse(2)), IssueCodes.literal);
    });
  });

  group('any and file |', () {
    test('any accepts everything', () {
      expect(v.any().parse(null), null);
      expect(v.any().parse(undefined), null);
      expect(v.any().parse(<int>[1]), <int>[1]);
    });

    test('file checks type and extension', () {
      expect(v.file().safeParse('x.png').success, false);
      expect(
        v.file().image().safeParse(FakeFile('png', pngBytes)).success,
        true,
      );
      // the name says png, the bytes say pdf
      expect(
        v.file().image().safeParse(FakeFile('png', pdfBytes)).success,
        false,
      );
      expect(
        v
            .file()
            .extensions(<String>['pdf'])
            .safeParse(FakeFile('PDF', pdfBytes))
            .success,
        true,
      );
      // no byte signature: the name decides
      expect(
        v.file().extensions(<String>['csv']).safeParse(FakeFile('csv')).success,
        true,
      );
    });

    test('file extension must fit the bytes', () {
      // GIF bytes in a file named `.html` must not pass as an image
      List<int> gif = 'GIF89a'.codeUnits;
      expect(FileTypes.matches(FakeFile('html', gif), <String>['gif']), false);
      expect(FileTypes.matches(FakeFile('gif', gif), <String>['gif']), true);
      // another known type or a type the browser runs is refused
      expect(FileTypes.matches(FakeFile('png', gif), <String>['gif']), false);
      for (String name in <String>['htm', 'svg', 'xml', 'js', 'mjs']) {
        expect(FileTypes.matches(FakeFile(name, gif), <String>['gif']), false);
      }
      // canvas and fetch uploads are named `blob`: no or unknown extension
      // is fine when the bytes match
      expect(FileTypes.matches(FakeFile('', gif), <String>['gif']), true);
      expect(FileTypes.matches(FakeFile('blob', gif), <String>['gif']), true);
      // aliases still work: a `.jpeg` file passes as `jpg`
      List<int> jpg = <int>[0xFF, 0xD8, 0xFF, 0xE0];
      expect(FileTypes.matches(FakeFile('jpeg', jpg), <String>['jpg']), true);
    });

    test('bmp needs a real BMP header, not only `BM`', () {
      List<int> bmp = <int>[
        ...'BM'.codeUnits,
        ...List<int>.filled(12, 0),
        40, 0, 0, 0, // BITMAPINFOHEADER size
      ];
      expect(FileTypes.sniff(bmp), 'bmp');
      expect(
        FileTypes.sniff('BMW is a car brand, not a bitmap'.codeUnits),
        null,
      );
      expect(FileTypes.sniff('BM'.codeUnits), null);
    });
  });

  group('coerce |', () {
    test('int from text', () {
      expect(v.coerce.int().parse('42'), 42);
      expect(v.coerce.int().parse(' 42 '), 42);
      expect(v.coerce.int().parse(42.0), 42);
      expect(v.coerce.int().safeParse('4.2').success, false);
      expect(v.coerce.int().safeParse('abc').success, false);
    });

    test('num from text', () {
      expect(v.coerce.num().parse('4.5'), 4.5);
      expect(v.coerce.num().safeParse('NaN').success, false);
      expect(v.coerce.num().safeParse('x').success, false);
    });

    test('bool from words', () {
      BoolSchema s = v.coerce.bool();
      for (Object value in <Object>['true', '1', 'yes', 'on', 'TRUE', 1]) {
        expect(s.parse(value), true, reason: '$value');
      }
      for (Object value in <Object>['false', '0', 'no', 'off', 0]) {
        expect(s.parse(value), false, reason: '$value');
      }
      expect(s.safeParse('maybe').success, false);
    });

    test('date from text and millis', () {
      expect(v.coerce.date().parse('2024-01-31'), DateTime(2024, 1, 31));
      expect(
        v.coerce.date().parse(0),
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
      expect(v.coerce.date().safeParse('not a date').success, false);
    });

    test('string from number and bool', () {
      expect(v.coerce.string().parse(5), '5');
      expect(v.coerce.string().parse(true), 'true');
    });

    test('coerced value still runs rules', () {
      expect(v.coerce.int().min(18).safeParse('10').success, false);
    });
  });
}
