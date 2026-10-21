import 'package:dox_validation/dox_validation.dart';
import 'package:test/test.dart';

void main() {
  group('list |', () {
    test('parses each item with typed output', () {
      List<String> out = v.list(v.string()).parse(<Object>['a', 'b']);
      expect(out, <String>['a', 'b']);
    });

    test('issue path has the index', () {
      ParseResult<List<int>> result = v.list(v.int()).safeParse(<Object>[
        1,
        'x',
        3,
      ]);
      expect(result.issues.single.path, <Object>[1]);
    });

    test('min, max, nonEmpty', () {
      expect(v.list(v.int()).min(2).safeParse(<int>[1]).success, false);
      expect(v.list(v.int()).max(1).safeParse(<int>[1, 2]).success, false);
      expect(v.list(v.int()).nonEmpty().safeParse(<int>[]).success, false);
    });

    test('rejects non list', () {
      expect(
        v.list(v.int()).safeParse('x').issues.first.message,
        'The value must be an array',
      );
    });
  });

  group('object |', () {
    ObjectSchema user = v.object(<String, Schema<Object?>>{
      'name': v.string().min(2),
      'address': v.object(<String, Schema<Object?>>{'city': v.string()}),
      'tags': v.list(v.string()),
    });

    test('valid input', () {
      Map<String, dynamic> out = user.parse(<String, dynamic>{
        'name': 'dox',
        'address': <String, dynamic>{'city': 'Yangon'},
        'tags': <String>['a'],
      });
      expect(out['address'], <String, dynamic>{'city': 'Yangon'});
    });

    test('nested paths in issues', () {
      ParseResult<Map<String, dynamic>> result = user.safeParse(
        <String, dynamic>{
          'name': 'd',
          'address': <String, dynamic>{'city': 5},
          'tags': <Object>['a', 2],
        },
      );
      expect(result.errors, <String, String>{
        'name': 'The name must be at least 2 character',
        'address.city': 'The city must be a string',
        'tags.1': 'The tags must be a string',
      });
      expect(result.issues[1].path, <Object>['address', 'city']);
    });

    test('parse throws ValidationException with all issues', () {
      try {
        user.parse(<String, dynamic>{});
        fail('should throw');
      } on ValidationException catch (e) {
        expect(e.issues.length, 3);
        expect(e.errors['name'], 'The name is required');
      }
    });

    test('rejects non map', () {
      expect(user.safeParse('x').issues.first.code, IssueCodes.object);
    });

    test('strip is default', () {
      ObjectSchema s = v.object(<String, Schema<Object?>>{'a': v.int()});
      expect(s.parse(<String, dynamic>{'a': 1, 'b': 2}), <String, dynamic>{
        'a': 1,
      });
    });

    test('strict and passthrough', () {
      ObjectSchema s = v.object(<String, Schema<Object?>>{'a': v.int()});
      ParseResult<Map<String, dynamic>> result = s.strict().safeParse(
        <String, dynamic>{'a': 1, 'b': 2, 'c': 3},
      );
      expect(result.issues.single.code, IssueCodes.unrecognizedKeys);
      expect(
        result.issues.single.message,
        'The value has unknown keys: b, and c',
      );
      expect(
        s.passthrough().parse(<String, dynamic>{'a': 1, 'b': 2}),
        <String, dynamic>{'a': 1, 'b': 2},
      );
    });

    test('pick, omit, extend, partial', () {
      ObjectSchema base = v.object(<String, Schema<Object?>>{
        'a': v.int(),
        'b': v.int(),
      });
      expect(base.pick(<String>['a']).shape.keys, <String>['a']);
      expect(base.omit(<String>['a']).shape.keys, <String>['b']);
      expect(
        base.extend(<String, Schema<Object?>>{'c': v.int()}).shape.keys,
        <String>['a', 'b', 'c'],
      );
      expect(base.partial().safeParse(<String, dynamic>{}).success, true);
      expect(
        base.partial().safeParse(<String, dynamic>{'a': 'x'}).success,
        false,
      );
    });

    test('accepts Map with other generic types', () {
      ObjectSchema s = v.object(<String, Schema<Object?>>{'a': v.string()});
      expect(s.parse(<dynamic, dynamic>{'a': 'x'}), <String, dynamic>{
        'a': 'x',
      });
    });
  });

  group('map |', () {
    test('checks every value', () {
      MapSchema<int> s = v.map(v.int());
      expect(s.parse(<String, int>{'a': 1}), <String, int>{'a': 1});
      expect(
        s.safeParse(<String, Object>{'a': 1, 'b': 'x'}).errors.keys,
        <String>['b'],
      );
    });

    test('checks keys', () {
      MapSchema<int> s = v.map(v.int(), keys: v.string().min(2));
      expect(s.safeParse(<String, int>{'a': 1}).success, false);
      expect(s.safeParse(<String, int>{'ab': 1}).success, true);
    });
  });

  group('union |', () {
    UnionSchema<Object?> s = v.union<Object?>(<Schema<Object?>>[
      v.string(),
      v.int(),
    ]);

    test('first match wins', () {
      expect(s.parse('a'), 'a');
      expect(s.parse(1), 1);
    });

    test('no match gives one union issue', () {
      ParseResult<Object?> result = s.safeParse(true);
      expect(result.issues.single.code, IssueCodes.union);
    });

    test('null is required unless an option allows it', () {
      expect(s.safeParse(null).issues.single.code, IssueCodes.required);
      UnionSchema<Object?> withNull = v.union<Object?>(<Schema<Object?>>[
        v.string(),
        v.literal<Object?>(null).nullable(),
      ]);
      expect(withNull.safeParse(null).success, true);
    });

    test('union of objects', () {
      UnionSchema<Map<String, dynamic>> shapes = v.union<Map<String, dynamic>>(
        <Schema<Map<String, dynamic>>>[
          v.object(<String, Schema<Object?>>{
            'type': v.literal<String>('circle'),
            'r': v.num(),
          }),
          v.object(<String, Schema<Object?>>{
            'type': v.literal<String>('square'),
            'side': v.num(),
          }),
        ],
      );
      expect(
        shapes.parse(<String, dynamic>{'type': 'square', 'side': 2}),
        <String, dynamic>{'type': 'square', 'side': 2},
      );
    });
  });
}
