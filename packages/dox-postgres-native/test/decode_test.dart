import 'dart:typed_data';

import 'package:dox_postgres_native/src/pool.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

// No database needed: the values are encoded with the `postgres` package.
final CodecContext codec = CodecContext.withDefaults();

Uint8List encode(Type<Object> type, Object value) {
  EncodedValue e = codec.typeRegistry.encode(
    TypedValue<Object>(type, value),
    codec,
  ) as EncodedValue;
  return Uint8List.fromList(e.bytes!);
}

/// what the `postgres` package decodes from [bytes]
Object? registry(int oid, Uint8List bytes) =>
    codec.typeRegistry.decode(EncodedValue.binary(bytes, typeOid: oid), codec);

void main() {
  test('uuid, date and json decode like the postgres package', () {
    List<(Type<Object>, Object)> values = <(Type<Object>, Object)>[
      (Type.uuid, '0a1b2c3d-4e5f-6789-abcd-ef0123456789'),
      (Type.date, DateTime.utc(2024, 2, 29)),
      (Type.date, DateTime.utc(1969, 7, 20)),
      (
        Type.json,
        <String, Object>{
          'a': 1,
          'b': <int>[2, 3],
          'é': 'ü',
        },
      ),
      (Type.jsonb, <Object?>[1, 'two', null, true]),
    ];
    for ((Type<Object>, Object) v in values) {
      Uint8List bytes = encode(v.$1, v.$2);
      int oid = v.$1.oid!;
      expect(decodeValue(oid, bytes), registry(oid, bytes), reason: '${v.$2}');
      expect(decodeValue(oid, bytes), v.$2);
    }
  });

  test('numeric keeps all its digits', () {
    List<String> same = <String>[
      '0',
      '1',
      '12345.678900',
      '10000',
      '100000000.5',
      '-42',
      '0.00001234',
      '0.5',
      '123456789012345678901234567890.123456789',
      'NaN',
    ];
    for (String n in same) {
      Uint8List bytes = encode(Type.numeric, n);
      expect(decodeValue(1700, bytes), registry(1700, bytes), reason: n);
      expect(decodeValue(1700, bytes), n);
    }
    // the postgres package gives '-.5' here
    expect(decodeValue(1700, encode(Type.numeric, '-0.5')), '-0.5');
  });

  test('other types still go through the type registry', () {
    Uint8List bytes = encode(Type.interval, Interval(days: 2));
    expect(decodeValue(1186, bytes), Interval(days: 2));
  });
}
