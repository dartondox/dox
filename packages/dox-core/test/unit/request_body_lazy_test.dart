import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

void main() {
  group('RequestBody.empty |', () {
    test('makes no map until it is read', () {
      RequestBody body = RequestBody.empty();
      expect(body.isMapMade, false);
      expect(body.kind, BodyKind.none);
      expect(body.map, isEmpty);
      expect(body.isMapMade, true);
    });

    test('a write is seen by the next read, same map each time', () {
      RequestBody body = RequestBody.empty();
      body.map['a'] = 1;
      expect(body.map['a'], 1);
      expect(identical(body.map, body.map), true);
    });

    test('two bodies never share a map', () {
      RequestBody one = RequestBody.empty();
      RequestBody two = RequestBody.empty();
      one.map['a'] = 1;
      expect(two.map, isEmpty);
      expect(identical(one.map, two.map), false);
    });

    test('a given map is used as it is', () {
      Map<String, dynamic> given = <String, dynamic>{'x': 1};
      expect(identical(RequestBody(given).map, given), true);
    });
  });
}
