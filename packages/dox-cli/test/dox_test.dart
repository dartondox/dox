import 'package:dox/dox.dart';
import 'package:test/test.dart';

void main() {
  group('string format test', () {
    test('toPascalWithFirstLetterLowerCase', () {
      String res1 = toPascalWithFirstLetterLowerCase('CamelCase');
      String res2 = toPascalWithFirstLetterLowerCase('camel_case');
      String res3 = toPascalWithFirstLetterLowerCase('Camel_Case');
      String res4 = toPascalWithFirstLetterLowerCase('Camel_case');
      String res5 = toPascalWithFirstLetterLowerCase('camelCase');
      String res6 = toPascalWithFirstLetterLowerCase('camel_Case');

      expect(res1, 'camelCase');
      expect(res2, 'camelCase');
      expect(res3, 'camelCase');
      expect(res4, 'camelCase');
      expect(res5, 'camelCase');
      expect(res6, 'camelCase');
    });
  });
}
