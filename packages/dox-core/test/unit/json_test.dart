import 'package:dox_core/utils/json.dart';
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
  });
}
