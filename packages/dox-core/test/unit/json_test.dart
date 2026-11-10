import 'dart:convert';

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

class JsonSerializableObject {
  Map<String, String> toJson() {
    return <String, String>{'success': 'true'};
  }
}

void main() {
  group('JSON |', () {
    test('stringify & parse', () {
      Map<String, dynamic> data = <String, dynamic>{
        'name': 'dox',
        'date': DateTime(2023),
      };
      String jsonString = JSON.stringify(data);
      expect(jsonString.contains('dox'), true);

      Map<String, dynamic> jsond = JSON.parse(jsonString);
      expect(jsond['name'], 'dox');
      expect(jsond['date'], '2023-01-01T00:00:00.000');
    });

    test('json serializable object', () {
      String jsonString = JSON.stringify(JsonSerializableObject());
      expect(jsonString.contains('success'), true);
    });

    test('map with a DateTime and an object with toJson, round trip', () {
      String text = JSON.stringify(<String, dynamic>{
        'at': DateTime.utc(2023),
        'obj': JsonSerializableObject(),
      });
      expect(JSON.parse(text), <String, dynamic>{
        'at': '2023-01-01T00:00:00.000Z',
        'obj': <String, dynamic>{'success': 'true'},
      });
    });

    test('bytes with a DateTime and a toJson object', () {
      List<int> b = JSON.bytes(<String, dynamic>{
        'at': DateTime.utc(2023),
        'obj': JsonSerializableObject(),
      });
      expect(
        utf8.decode(b),
        '{"at":"2023-01-01T00:00:00.000Z","obj":{"success":"true"}}',
      );
    });

    test('bytes and parseBytes round trip, non-ASCII', () {
      Map<String, dynamic> x = <String, dynamic>{'a': 'é 日本 😀'};
      List<int> b = JSON.bytes(x);
      expect(b, utf8.encode(JSON.stringify(x)));
      expect(JSON.parseBytes(b), x);
    });

    test('parseBytes throws FormatException for bad input', () {
      expect(() => JSON.parseBytes(<int>[0xff]), throwsFormatException);
      expect(() => JSON.parseBytes(utf8.encode('{')), throwsFormatException);
    });

    test('parseBytes returns a date as a String', () {
      Object? r = JSON.parseBytes(
        JSON.bytes(<String, dynamic>{'at': DateTime.utc(2023)}),
      );
      expect((r as Map<String, dynamic>)['at'], '2023-01-01T00:00:00.000Z');
    });

    test('a value with no toJson fails the same way in both paths', () {
      expect(
        () => JSON.bytes(Object()),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
      expect(
        () => JSON.stringify(Object()),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
    });
  });
}
