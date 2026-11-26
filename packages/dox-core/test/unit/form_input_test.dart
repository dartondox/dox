import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/request/form_input.dart';
import 'package:test/test.dart';

void main() {
  const FormInput form = FormInput();

  Map<String, dynamic> parse(String text) => form.parse(form.pairs(text));

  group('FormInput list index |', () {
    test('plain digits make a list', () {
      expect(parse('k[3]=z'), <String, dynamic>{
        'k': <Object?>['z'],
      });
      expect(parse('k[1]=b&k[0]=a'), <String, dynamic>{
        'k': <Object?>['a', 'b'],
      });
    });

    /// found by the fuzz test: these keys gave `{k: [null]}`
    for (String key in <String>[
      '01',
      '00',
      '-0',
      '+1',
      '0x10',
      '%201',
      '%093',
      '1%20',
      '99999999999999999999',
      '+5000',
    ]) {
      test('a key like [$key] is a map key and keeps its value', () {
        String name = Uri.decodeQueryComponent(key);
        expect(parse('k[$key]=z'), <String, dynamic>{
          'k': <String, dynamic>{name: 'z'},
        });
      });
    }

    test('a plain and a non-plain key together make a map', () {
      expect(parse('k[01]=a&k[x]=b&k[0]=c'), <String, dynamic>{
        'k': <String, dynamic>{'01': 'a', 'x': 'b', '0': 'c'},
      });
    });

    test('a non-plain key in a list item', () {
      expect(parse('k[1][01]=a'), <String, dynamic>{
        'k': <Object?>[
          <String, dynamic>{'01': 'a'},
        ],
      });
    });

    test('an index below 0 or past the limit is refused', () {
      expect(() => parse('k[-1]=z'), throwsA(isA<ValidationException>()));
      expect(() => parse('k[1000]=z'), throwsA(isA<ValidationException>()));
    });

    test('[01] and [1] are two keys, no value is lost', () {
      expect(parse('k[01]=a&k[1]=b'), <String, dynamic>{
        'k': <String, dynamic>{'01': 'a', '1': 'b'},
      });
    });
  });
}
