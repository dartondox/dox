import 'package:dox_validation/dox_validation.dart';
import 'package:test/test.dart';

void main() {
  group('optional, nullable, nullish, default |', () {
    test('optional allows missing, not null', () {
      ObjectSchema s = v.object(<String, Schema<Object?>>{
        'nick': v.string().optional(),
      });
      expect(s.parse(<String, dynamic>{}), <String, dynamic>{});
      expect(s.safeParse(<String, dynamic>{'nick': null}).success, false);
      expect(s.parse(<String, dynamic>{'nick': 'd'}), <String, dynamic>{
        'nick': 'd',
      });
    });

    test('nullable allows null, not missing', () {
      ObjectSchema s = v.object(<String, Schema<Object?>>{
        'nick': v.string().nullable(),
      });
      expect(s.parse(<String, dynamic>{'nick': null}), <String, dynamic>{
        'nick': null,
      });
      expect(s.safeParse(<String, dynamic>{}).errors, <String, String>{
        'nick': 'The nick is required',
      });
    });

    test('nullish allows both', () {
      ObjectSchema s = v.object(<String, Schema<Object?>>{
        'nick': v.string().nullish(),
      });
      expect(s.safeParse(<String, dynamic>{}).success, true);
      expect(s.safeParse(<String, dynamic>{'nick': null}).success, true);
      expect(s.safeParse(<String, dynamic>{'nick': 1}).success, false);
    });

    test('defaultTo fills a missing value', () {
      ObjectSchema s = v.object(<String, Schema<Object?>>{
        'page': v.coerce.int().min(1).defaultTo(1),
      });
      expect(s.parse(<String, dynamic>{}), <String, dynamic>{'page': 1});
      expect(s.parse(<String, dynamic>{'page': '3'}), <String, dynamic>{
        'page': 3,
      });
      expect(s.safeParse(<String, dynamic>{'page': '0'}).success, false);
    });

    test('top level optional returns null for undefined', () {
      expect(v.string().optional().parse(undefined), null);
    });
  });

  group('transform |', () {
    test('changes output type', () {
      TransformSchema<String, int> s = v.string().transform<int>((
        String value,
      ) {
        return value.length;
      });
      expect(s.parse('dox'), 3);
    });

    test('does not run on invalid input', () {
      int calls = 0;
      TransformSchema<String, int> s = v.string().min(5).transform<int>((
        String value,
      ) {
        calls++;
        return value.length;
      });
      expect(s.safeParse('dox').success, false);
      expect(calls, 0);
    });

    test('refine after transform sees new value', () {
      TransformSchema<String, int> s = v
          .string()
          .transform<int>(int.parse)
          .refine((int value) {
            return value.isEven;
          }, message: 'must be even');
      expect(s.parse('4'), 4);
      expect(s.safeParse('3').issues.first.message, 'must be even');
    });
  });

  group('refine and superRefine |', () {
    test('refine keeps schema methods', () {
      StringSchema s = v
          .string()
          .refine((String value) {
            return value != 'admin';
          }, message: 'The {field} is taken')
          .min(3);
      expect(s.safeParse('admin').issues.first.message, 'The value is taken');
      expect(s.safeParse('ab').success, false);
      expect(s.safeParse('dox').success, true);
    });

    test('object refine with path', () {
      ObjectSchema s = v
          .object(<String, Schema<Object?>>{
            'password': v.string(),
            'confirm': v.string(),
          })
          .refine(
            (Map<String, dynamic> data) {
              return data['password'] == data['confirm'];
            },
            message: 'Passwords do not match',
            path: <Object>['confirm'],
          );
      ParseResult<Map<String, dynamic>> result = s.safeParse(<String, dynamic>{
        'password': 'a',
        'confirm': 'b',
      });
      expect(result.errors, <String, String>{
        'confirm': 'Passwords do not match',
      });
    });

    test('object refine skipped when fields fail', () {
      int calls = 0;
      ObjectSchema s = v
          .object(<String, Schema<Object?>>{'a': v.string()})
          .refine((Map<String, dynamic> data) {
            calls++;
            return true;
          });
      s.safeParse(<String, dynamic>{});
      expect(calls, 0);
    });

    test('superRefine adds many issues', () {
      ListSchema<int> s = v.list(v.int()).superRefine((
        List<int> list,
        RuleContext context,
      ) {
        for (int i = 0; i < list.length; i++) {
          if (list[i] < 0) {
            context.addIssue('No negative numbers', path: <Object>[i]);
          }
        }
      });
      ParseResult<List<int>> result = s.safeParse(<int>[1, -1, -2]);
      expect(result.errors.keys.toList(), <String>['1', '2']);
    });
  });

  group('async |', () {
    Future<bool> isFree(String email) async {
      await Future<void>.delayed(Duration.zero);
      return email != 'taken@dox.dev';
    }

    test('refineAsync works with parseAsync', () async {
      StringSchema s = v.string().email().refineAsync(
        isFree,
        message: 'Email taken',
      );
      expect(await s.parseAsync('new@dox.dev'), 'new@dox.dev');
      ParseResult<String> result = await s.safeParseAsync('taken@dox.dev');
      expect(result.issues.first.message, 'Email taken');
    });

    test('sync parse throws for async schema', () {
      ObjectSchema s = v.object(<String, Schema<Object?>>{
        'email': v.string().refineAsync(isFree),
      });
      expect(s.isAsync, true);
      expect(() {
        s.parse(<String, dynamic>{'email': 'a'});
      }, throwsStateError);
    });

    test('nested async inside list and object', () async {
      ObjectSchema s = v.object(<String, Schema<Object?>>{
        'users': v.list(
          v.object(<String, Schema<Object?>>{
            'email': v.string().refineAsync(isFree, message: 'taken'),
          }),
        ),
      });
      ParseResult<Map<String, dynamic>> result = await s.safeParseAsync(
        <String, dynamic>{
          'users': <Map<String, dynamic>>[
            <String, dynamic>{'email': 'ok@dox.dev'},
            <String, dynamic>{'email': 'taken@dox.dev'},
          ],
        },
      );
      expect(result.errors, <String, String>{'users.1.email': 'taken'});
    });

    test('superRefineAsync', () async {
      StringSchema s = v.string().superRefineAsync((
        String value,
        RuleContext context,
      ) async {
        if (!await isFree(value)) {
          context.addIssue('taken', code: 'unique');
        }
      });
      ParseResult<String> result = await s.safeParseAsync('taken@dox.dev');
      expect(result.issues.first.code, 'unique');
    });

    test('parseAsync throws ValidationException', () async {
      await expectLater(
        v.string().parseAsync(1),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
