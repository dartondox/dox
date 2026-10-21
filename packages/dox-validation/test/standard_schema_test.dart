import 'dart:async';

import 'package:dox_validation/dox_validation.dart';
import 'package:test/test.dart';

/// A consumer that only knows the Standard Schema interface.
Future<List<String>> problems(
  StandardSchema<Object?, Object?> schema,
  Object? input,
) async {
  StandardResult<Object?> result = await schema.validate(input);
  List<String> out = <String>[];
  for (StandardIssue issue in result.issues) {
    out.add('${issue.path.join('.')}: ${issue.message}');
  }
  return out;
}

void main() {
  group('StandardSchema |', () {
    test('vendor and version', () {
      StandardSchema<Object?, String> s = v.string();
      expect(s.vendor, 'dox');
      expect(s.version, 1);
    });

    test('every schema type is a StandardSchema', () {
      List<Object> schemas = <Object>[
        v.string(),
        v.int(),
        v.num(),
        v.bool(),
        v.date(),
        v.enumOf<String>(<String>['a']),
        v.literal<int>(1),
        v.list(v.int()),
        v.object(<String, Schema<Object?>>{}),
        v.map(v.int()),
        v.union<Object?>(<Schema<Object?>>[v.int()]),
        v.any(),
        v.file(),
        v.string().optional(),
        v.string().nullable(),
        v.string().defaultTo('x'),
        v.string().transform<int>(int.parse),
        v.fromRules(<String, String>{'a': 'required'}),
      ];
      for (Object schema in schemas) {
        expect(schema, isA<StandardSchema<Object?, Object?>>());
      }
    });

    test('sync validate returns a result, not a Future', () {
      FutureOr<StandardResult<int>> result = v.int().validate(1);
      expect(result, isA<StandardResult<int>>());
      StandardResult<int> sync = result as StandardResult<int>;
      expect(sync.success, true);
      expect(sync.value, 1);
      expect(sync.issues, isEmpty);
    });

    test('async validate returns a Future', () async {
      StringSchema s = v.string().refineAsync((String value) async {
        return value.isNotEmpty;
      });
      FutureOr<StandardResult<String>> result = s.validate('');
      expect(result, isA<Future<StandardResult<String>>>());
      StandardResult<String> done = await result;
      expect(done.success, false);
    });

    test('generic consumer reads issues and paths', () async {
      ObjectSchema s = v.object(<String, Schema<Object?>>{
        'user':
            v.object(<String, Schema<Object?>>{'email': v.string().email()}),
      });
      expect(
          await problems(s, <String, dynamic>{
            'user': <String, dynamic>{'email': 'x'},
          }),
          <String>['user.email: The email is not a valid email']);
    });

    test('a custom StandardSchema works with the same consumer', () async {
      expect(await problems(EvenOnly(), 3), <String>[': must be even']);
    });
  });
}

/// A schema made without dox schemas, to show other libraries can plug in.
class EvenOnly implements StandardSchema<Object?, int> {
  @override
  String get vendor {
    return 'test';
  }

  @override
  int get version {
    return 1;
  }

  @override
  FutureOr<StandardResult<int>> validate(Object? value) {
    if (value is int && value.isEven) {
      return ParseResult<int>.success(value);
    }
    return ParseResult<int>.failure(<ValidationIssue>[
      ValidationIssue(path: <Object>[], code: 'even', message: 'must be even'),
    ]);
  }
}
