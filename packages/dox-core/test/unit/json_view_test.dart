import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/json.dart'
    show advanceEncode, giveBackJsonBytes, jsonBytesLent, jsonBytesView;
import 'package:dox_core/utils/json_bytes_encoder.dart';
import 'package:test/test.dart';

import '../dtos/dtos.dart';
import '../dtos/response.dto.dart';
import '../utils/test_app_key.dart';

/// encodes JSON while it is encoded: its toJson() calls the encoder
class _Inner {
  _Inner(this.encoder, this.value);
  final JsonBytesEncoder encoder;
  final Object? value;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'inner': utf8.decode(encoder.convert(value)),
      'view': utf8.decode(encoder.convertView(value)),
    };
  }
}

/// has writeJson() and no toJson()
class _OnlyWriter implements JsonWritable {
  @override
  void writeJson(JsonWriter writer) {
    writer.startObject();
    writer.endObject();
  }
}

/// a value of each kind, different for each [n]
Object? _value(int n) {
  return <String, dynamic>{
    'n': n,
    'text': 'é 😀 "q" ${'x' * (n % 50)}',
    'list': List<int>.generate(n % 9, (int i) => i * n),
    'deep': <String, dynamic>{'a': n.isEven, 'b': n / 3, 'c': null},
  };
}

void main() {
  group('the view of the encoder |', () {
    test('a view has the right bytes, and the buffer is lent', () {
      JsonBytesEncoder encoder = JsonBytesEncoder(advanceEncode);
      Uint8List view = encoder.convertView(_value(1));
      expect(utf8.decode(view), jsonEncode(_value(1)));
      expect(encoder.isLent, isTrue);
      encoder.giveBack(view);
      expect(encoder.isLent, isFalse);
    });

    test('while lent, other calls do not change the view', () {
      JsonBytesEncoder encoder = JsonBytesEncoder(advanceEncode);
      Uint8List view = encoder.convertView(_value(1));
      List<int> before = List<int>.of(view);

      Uint8List other = encoder.convert(_value(2));
      Uint8List second = encoder.convertView(_value(3));
      expect(utf8.decode(other), jsonEncode(_value(2)));
      expect(utf8.decode(second), jsonEncode(_value(3)));
      expect(view, before);

      /// the second view is a copy: it is not lent
      encoder.giveBack(second);
      expect(encoder.isLent, isTrue);
      expect(view, before);

      encoder.giveBack(view);
      expect(encoder.isLent, isFalse);
    });

    test('a copy given back does nothing', () {
      JsonBytesEncoder encoder = JsonBytesEncoder(advanceEncode);
      Uint8List view = encoder.convertView(_value(1));
      encoder.giveBack(Uint8List.fromList(view));
      encoder.giveBack(<int>[]);
      expect(encoder.isLent, isTrue);
      encoder.giveBack(view);
      expect(encoder.isLent, isFalse);
    });

    test('after it is given back, the buffer is used again', () {
      JsonBytesEncoder encoder = JsonBytesEncoder(advanceEncode);
      Uint8List first = encoder.convertView(<int>[1]);
      encoder.giveBack(first);
      Uint8List next = encoder.convertView(<int>[2]);
      // the same memory: the old view now shows the new bytes
      expect(utf8.decode(first), '[2]');
      expect(utf8.decode(next), '[2]');
      encoder.giveBack(next);
    });

    test('an error is not lent', () {
      JsonBytesEncoder encoder = JsonBytesEncoder(advanceEncode);
      expect(
        () => encoder.convertView(<Object>[1, Object()]),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
      expect(encoder.isLent, isFalse);
      Uint8List view = encoder.convertView(<int>[1]);
      expect(utf8.decode(view), '[1]');
      encoder.giveBack(view);
    });

    test('an encode inside an encode, with and without a lent view', () {
      JsonBytesEncoder encoder = JsonBytesEncoder(advanceEncode);
      Object? value = <String, dynamic>{
        'a': _Inner(encoder, _value(5)),
        'b': <int>[1, 2],
      };
      String want = jsonEncode(<String, dynamic>{
        'a': <String, dynamic>{
          'inner': jsonEncode(_value(5)),
          'view': jsonEncode(_value(5)),
        },
        'b': <int>[1, 2],
      });
      expect(utf8.decode(encoder.convert(value)), want);
      Uint8List view = encoder.convertView(value);
      expect(utf8.decode(view), want);

      /// lent now: the inner calls write into new buffers
      List<int> before = List<int>.of(view);
      expect(utf8.decode(encoder.convert(value)), want);
      expect(view, before);
      encoder.giveBack(view);
      expect(encoder.isLent, isFalse);
    });

    test('a view of a body larger than the buffer it keeps', () {
      JsonBytesEncoder encoder = JsonBytesEncoder(advanceEncode);
      String huge = 'é' * (1 << 20);
      Uint8List view = encoder.convertView(huge);
      List<int> before = List<int>.of(view);
      expect(utf8.decode(encoder.convert(_value(1))), jsonEncode(_value(1)));
      expect(view, before);
      encoder.giveBack(view);
      Uint8List small = encoder.convertView(<int>[1]);
      expect(utf8.decode(small), '[1]');
      encoder.giveBack(small);
    });

    /// Random steps: make a view, make a copy, give a view back. After each
    /// step, every view that is not given back must still have its bytes.
    test('random steps: a view keeps its bytes until it is given back', () {
      JsonBytesEncoder encoder = JsonBytesEncoder(advanceEncode);
      Random random = Random(17);
      List<(Uint8List, List<int>)> views = <(Uint8List, List<int>)>[];
      for (int step = 0; step < 20000; step++) {
        int n = random.nextInt(1000);
        switch (random.nextInt(4)) {
          case 0:
            Uint8List view = encoder.convertView(_value(n));
            expect(utf8.decode(view), jsonEncode(_value(n)));
            views.add((view, List<int>.of(view)));
          case 1:
            expect(
              utf8.decode(encoder.convert(_value(n))),
              jsonEncode(_value(n)),
            );
          case 2:
            if (views.isNotEmpty) {
              (Uint8List, List<int>) one = views.removeAt(
                random.nextInt(views.length),
              );
              encoder.giveBack(one.$1);
            }
          case 3:
            Object? bad = <Object>[n, Object()];
            expect(() => encoder.convertView(bad), throwsA(anything));
        }
        for ((Uint8List, List<int>) one in views) {
          expect(one.$1, one.$2, reason: 'step $step');
        }
      }
      for ((Uint8List, List<int>) one in views) {
        encoder.giveBack(one.$1);
      }
      expect(encoder.isLent, isFalse);
    });
  });

  group('CoreFlags.sdkJsonEncoder |', () {
    tearDown(() {
      Dox().initialize(AppConfig(appKey: testAppKey));
    });

    test('off: the Dox encoder and a lent view', () {
      Dox().initialize(AppConfig(appKey: testAppKey));
      Uint8List view = jsonBytesView(_value(1));
      expect(jsonBytesLent, isTrue);
      giveBackJsonBytes(view);
      expect(jsonBytesLent, isFalse);
    });

    test('on: the same JSON, from the encoder of the SDK', () {
      Dox().initialize(
        AppConfig(
          appKey: testAppKey,
          dtos: testDtos,
          flags: const CoreFlags(sdkJsonEncoder: true),
        ),
      );
      for (int n = 0; n < 200; n++) {
        String want = jsonEncode(_value(n));
        expect(utf8.decode(JSON.bytes(_value(n))), want);
        Uint8List view = jsonBytesView(_value(n));
        expect(utf8.decode(view), want);

        /// not a part of a shared buffer: nothing is lent
        expect(jsonBytesLent, isFalse);
        giveBackJsonBytes(view);
      }

      /// a date, a DTO and a list of them
      expect(
        utf8.decode(JSON.bytes(<String, dynamic>{'at': DateTime.utc(2024)})),
        '{"at":"2024-01-01T00:00:00.000Z"}',
      );
      ProductView product = const ProductView(
        id: 1,
        productName: 'p',
        price: 1,
        inStock: true,
      );
      expect(
        utf8.decode(JSON.bytes(<ProductView>[product])),
        '[{"id":1,"product_name":"p","price":1.0,"in_stock":true,'
        '"sold_at":null}]',
      );
    });

    test('on: a class with only writeJson() needs a toJson()', () {
      Dox().initialize(
        AppConfig(
          appKey: testAppKey,
          flags: const CoreFlags(sdkJsonEncoder: true),
        ),
      );
      expect(
        () => JSON.bytes(_OnlyWriter()),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );

      /// off: the Dox encoder calls writeJson()
      Dox().initialize(AppConfig(appKey: testAppKey));
      expect(utf8.decode(JSON.bytes(_OnlyWriter())), '{}');
    });

    test('CoreFlags.all() does not turn it on', () {
      expect(const CoreFlags.all().sdkJsonEncoder, isFalse);
    });
  });
}
