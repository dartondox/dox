import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import '../dtos/laravel.dto.dart';

// Generated code for the DTO options and extra rules, run on the real
// dox_validation.

Map<String, dynamic> _good() {
  return <String, dynamic>{
    'first_name': '  Ann  ',
    'age': '20',
    'terms': 'yes',
    'start': '2024-01-01',
    'end': '2024-02-01',
    'type': 'person',
    'vat': 'x',
    'nick': 'Bob',
    'id': '01ARZ3NDEKTSV4RRFFQ69G5FAV',
    'max': 21,
  };
}

Future<Map<String, String>> _errors(Map<String, dynamic> input) async {
  ParseResult<LaravelRules> result = await LaravelRules.schema.safeValidateMap(
    input,
  );
  return result.errors;
}

void main() {
  test('trim, coerce and the skipped field', () async {
    LaravelRules value = await LaravelRules.schema.validateMap(_good());
    expect(value.firstName, 'Ann');
    expect(value.age, 20);
    expect(value.vat, isNull); // @ExcludeIf: type is person
  });

  test('blank text is missing and the message uses the name', () async {
    expect(
      await _errors(<String, dynamic>{..._good(), 'first_name': '  '}),
      <String, String>{'first_name': 'The first name is required'},
    );
  });

  test('required unless and prohibited', () async {
    expect(
      await _errors(<String, dynamic>{
        ..._good(),
        'type': 'company',
        'debug': null,
      }),
      <String, String>{
        'company': 'The company is required unless type is person',
        'debug': 'The debug is prohibited',
      },
    );
  });

  test('the field rules', () async {
    expect(
      await _errors(<String, dynamic>{
        ..._good(),
        'terms': false,
        'end': '2023-01-01',
        'type': 'company',
        'company': 'Dox',
        'vat': 'ab',
        'nick': '  Ann  ',
        'id': 'x',
        'max': 3,
      }),
      <String, String>{
        'terms': 'The terms must be accepted',
        'end': 'The end must be a date after start',
        'vat': 'The vat must be at least 3 characters',
        'nick': 'The nick and first name must be different',
        'id': 'The id must be a valid ULID',
        'max': 'The max must be greater than age',
      },
    );
  });
}
