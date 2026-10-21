import 'package:dox_validation/dox_validation.dart';
import 'package:test/test.dart';

void main() {
  group('toJsonSchema |', () {
    test('string with formats and lengths', () {
      expect(
        v.string().min(3).max(50).email().toJsonSchema(),
        <String, dynamic>{
          'type': 'string',
          'minLength': 3,
          'maxLength': 50,
          'format': 'email',
        },
      );
      expect(v.string().uuid().toJsonSchema()['format'], 'uuid');
      expect(v.string().url().toJsonSchema()['format'], 'uri');
      expect(v.string().datetime().toJsonSchema()['format'], 'date-time');
      expect(
        v.string().regex(RegExp(r'^\d+$')).toJsonSchema()['pattern'],
        r'^\d+$',
      );
    });

    test('numbers', () {
      expect(v.int().min(0).max(10).toJsonSchema(), <String, dynamic>{
        'type': 'integer',
        'minimum': 0,
        'maximum': 10,
      });
      expect(
        v.num().gt(0).lt(1).multipleOf(0.5).toJsonSchema(),
        <String, dynamic>{
          'type': 'number',
          'exclusiveMinimum': 0,
          'exclusiveMaximum': 1,
          'multipleOf': 0.5,
        },
      );
    });

    test('bool, date, enum, literal, any, file', () {
      expect(v.bool().toJsonSchema(), <String, dynamic>{'type': 'boolean'});
      expect(v.date().toJsonSchema(), <String, dynamic>{
        'type': 'string',
        'format': 'date-time',
      });
      expect(
        v.enumOf<String>(<String>['a', 'b']).toJsonSchema(),
        <String, dynamic>{
          'type': 'string',
          'enum': <String>['a', 'b'],
        },
      );
      expect(v.literal<int>(1).toJsonSchema(), <String, dynamic>{
        'type': 'integer',
        'const': 1,
      });
      expect(v.any().toJsonSchema(), <String, dynamic>{});
      expect(v.file().toJsonSchema(), <String, dynamic>{
        'type': 'string',
        'format': 'binary',
      });
    });

    test('nullable, default, describe, example', () {
      expect(v.string().nullable().toJsonSchema(), <String, dynamic>{
        'type': <String>['string', 'null'],
      });
      expect(
        v.enumOf<String>(<String>['a']).nullable().toJsonSchema(),
        <String, dynamic>{
          'anyOf': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'string',
              'enum': <String>['a'],
            },
            <String, dynamic>{'type': 'null'},
          ],
        },
      );
      expect(
        v.int().defaultTo(1).describe('Page number').example(2).toJsonSchema(),
        <String, dynamic>{
          'type': 'integer',
          'default': 1,
          'description': 'Page number',
          'examples': <int>[2],
        },
      );
      expect(
        v.date().defaultTo(DateTime.utc(2024)).toJsonSchema()['default'],
        '2024-01-01T00:00:00.000Z',
      );
    });

    test('object with required list and strict', () {
      ObjectSchema user = v.object(<String, Schema<Object?>>{
        'email': v.string().email().describe('Login email'),
        'name': v.string().optional(),
        'age': v.int().nullable(),
        'role': v.enumOf<String>(<String>['admin', 'user']).defaultTo('user'),
        'tags': v.list(v.string()).max(5),
        'meta': v.map(v.num()),
      }).strict();
      expect(user.toJsonSchema(), <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'email': <String, dynamic>{
            'type': 'string',
            'format': 'email',
            'description': 'Login email',
          },
          'name': <String, dynamic>{'type': 'string'},
          'age': <String, dynamic>{
            'type': <String>['integer', 'null'],
          },
          'role': <String, dynamic>{
            'type': 'string',
            'enum': <String>['admin', 'user'],
            'default': 'user',
          },
          'tags': <String, dynamic>{
            'type': 'array',
            'items': <String, dynamic>{'type': 'string'},
            'maxItems': 5,
          },
          'meta': <String, dynamic>{
            'type': 'object',
            'additionalProperties': <String, dynamic>{'type': 'number'},
          },
        },
        'required': <String>['email', 'age', 'tags', 'meta'],
        'additionalProperties': false,
      });
    });

    test('union', () {
      expect(
        v.union<Object?>(<Schema<Object?>>[v.string(), v.int()]).toJsonSchema(),
        <String, dynamic>{
          'anyOf': <Map<String, dynamic>>[
            <String, dynamic>{'type': 'string'},
            <String, dynamic>{'type': 'integer'},
          ],
        },
      );
    });

    test('transform shows the input shape', () {
      expect(
        v.string().transform<int>(int.parse).toJsonSchema(),
        <String, dynamic>{'type': 'string'},
      );
    });
  });
}
