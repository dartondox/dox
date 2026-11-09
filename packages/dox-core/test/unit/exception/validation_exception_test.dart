import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

void main() {
  group('ValidationException', () {
    test('a failed check keeps every issue with its rule code', () async {
      ObjectSchema schema = v.object(<String, Schema<Object?>>{
        'name': v.string().min(3),
        'age': v.int(),
      });
      try {
        await const RequestValidator().validateSchema(schema, <String, dynamic>{
          'name': 'ab',
        });
        fail('it should throw');
      } on ValidationException catch (error) {
        expect(error.code, 422);
        expect((error.message as Map<String, String>).keys, <String>[
          'name',
          'age',
        ]);
        List<String> found = <String>[
          for (ValidationIssue issue in error.issues)
            '${issue.dottedPath}:${issue.code}',
        ];
        expect(found, <String>['name:min_length', 'age:required']);
      }
    });

    test('made by hand, it has no issues', () {
      expect(ValidationException().issues, isEmpty);
    });
  });
}
