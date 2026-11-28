import 'dart:convert';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/json.dart' show advanceEncode, useSdkJsonEncoder;
import 'package:test/test.dart';

import '../serialize/city.dart';
import '../serialize/hidden.dart';
import '../serialize/noshow.dart';
import '../utils/test_app_key.dart';

String _bytes(Object? value) => utf8.decode(JSON.bytes(value));

void _same(Object? value, String want) {
  expect(_bytes(value), want);
  expect(JSON.stringify(value), want);
  useSdkJsonEncoder = true;
  try {
    expect(_bytes(value), want);
  } finally {
    useSdkJsonEncoder = false;
  }
}

/// The classes of this test can not call the generated code of the
/// classes they use. If they did, this file would not compile.
void main() {
  setUp(() {
    Dox().initialize(
      AppConfig(
        appKey: testAppKey,
        dtos: <DtoSchema<Object>>[$RvCityDto],
        container: (IocContainer c) {
          c.jsonWriter($HiddenSerWriter);
          c.jsonWriter($HiddenPlainWriter);
          c.jsonWriter($HiddenCityWriter);
        },
      ),
    );
  });

  test('a serializer of a file that does not see SerializeWriter', () {
    HiddenSer ser = HiddenSer(Thing('x'));
    String want = jsonEncode(ser.toJson(), toEncodable: advanceEncode);
    expect(want, '{"t":{"n":"x"},"ts":[{"n":"x"}]}');
    _same(ser, want);
  });

  test('a plain class of such a file has no writer', () {
    expect(
      () => JSON.bytes(const HiddenPlain(PlainB(1), RvCity(name: 'c'))),
      throwsA(isA<JsonUnsupportedObjectError>()),
    );
  });

  test('a @Dto imported with show goes to the encoder', () {
    _same(
      const HiddenCity(RvCity(name: 'a'), <RvCity>[RvCity(name: 'b')]),
      '{"city":{"name":"a"},"cities":[{"name":"b"}]}',
    );
  });
}
