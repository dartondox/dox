import 'package:dox_validation/dox_validation.dart';
import 'package:test/test.dart';

class FakeFile implements FileInput {
  FakeFile(this.extension);

  @override
  final String extension;
}

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
      expect(v.file().image().safeParse(FakeFile('png')).success, true);
      expect(v.file().image().safeParse(FakeFile('pdf')).success, false);
      expect(
        v.file().extensions(<String>['pdf']).safeParse(FakeFile('PDF')).success,
        true,
      );
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
