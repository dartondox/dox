import 'dart:convert';
import 'dart:math';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/json.dart' show advanceEncode;
import 'package:dox_core/utils/json_bytes_encoder.dart';
import 'package:test/test.dart';

class _Model {
  _Model(this.value);

  final Object? value;

  Object? toJson() => value;
}

class _NoToJson {}

/// Its `toJson()` encodes JSON itself, while the outer call still runs.
class _Reenter {
  Object? toJson() {
    return <String, Object?>{
      'in': utf8.decode(JSON.bytes(<String, int>{'k': 1})),
      'z': 2,
    };
  }
}

/// the encoder of the SDK, set up like `JSON.bytes` was before
final JsonUtf8Encoder _sdk = JsonUtf8Encoder(null, advanceEncode, 1024);

final JsonBytesEncoder _own = JsonBytesEncoder(advanceEncode);

String _text(Object? value) => utf8.decode(_own.convert(value));

/// The bytes as text, or the type of the error.
String _result(List<int> Function() encode) {
  try {
    return base64.encode(encode());
  } catch (error) {
    return 'error ${error.runtimeType}';
  }
}

/// Makes random values: every JSON type, plus the values that must fail.
class _Values {
  final Random _random = Random(7);

  static const List<int> _edgeChars = <int>[
    0x22,
    0x5C,
    0x7F,
    0x80,
    0x7FF,
    0x800,
    0xD7FF,
    0xE000,
    0xFFFF,
  ];

  static const List<int> _edgeInts = <int>[
    0,
    9,
    10,
    -1,
    -10,
    99,
    100,
    999999999999999999,
    1000000000000000000,
    9223372036854775807,
    -9223372036854775807,
    -9223372036854775808,
  ];

  static const List<double> _edgeDoubles = <double>[
    0.0,
    -0.0,
    1.0,
    1e21,
    1e-7,
    double.nan,
    double.infinity,
    double.negativeInfinity,
  ];

  String text() {
    int length = _random.nextInt(_random.nextInt(10) == 0 ? 3000 : 14);
    List<int> units = <int>[];
    for (int i = 0; i < length; i++) {
      switch (_random.nextInt(14)) {
        case 0:
          units.add(_random.nextInt(0x20));
        case 1:
          units.add(_edgeChars[_random.nextInt(_edgeChars.length)]);
        case 2:
          // half of a surrogate pair
          units.add(0xD800 + _random.nextInt(0x800));
        case 3:
          units.add(0xD800 + _random.nextInt(0x400));
          units.add(0xDC00 + _random.nextInt(0x400));
        case 4:
          units.add(_random.nextInt(0x10000));
        default:
          units.add(0x20 + _random.nextInt(0x5F));
      }
    }
    return String.fromCharCodes(units);
  }

  Object? value(int depth) {
    switch (_random.nextInt(depth > 4 ? 9 : 16)) {
      case 0:
        return null;
      case 1:
        return _random.nextBool();
      case 2:
        return _random.nextInt(1 << 32) - (1 << 31);
      case 3:
        return _edgeInts[_random.nextInt(_edgeInts.length)];
      case 4:
        return (_random.nextDouble() - 0.5) * pow(10, _random.nextInt(40) - 20);
      case 5:
        return _edgeDoubles[_random.nextInt(_edgeDoubles.length)];
      case 6:
      case 7:
        return text();
      case 8:
        return DateTime.fromMillisecondsSinceEpoch(
          _random.nextInt(1 << 31) * 1000,
          isUtc: true,
        );
      case 9:
      case 10:
        return <Object?>[
          for (int i = _random.nextInt(6); i > 0; i--) value(depth + 1),
        ];
      case 11:
      case 12:
        Map<Object?, Object?> map = <Object?, Object?>{};
        for (int i = _random.nextInt(6); i > 0; i--) {
          // now and then a key that is not a String
          map[_random.nextInt(60) == 0 ? i : text()] = value(depth + 1);
        }
        return map;
      case 13:
        return _Model(value(depth + 1));
      case 14:
        return _random.nextInt(8) == 0 ? _NoToJson() : <String>['a', 'b'];
      default:
        if (_random.nextInt(40) != 0) return <String, Object?>{};
        List<Object?> self = <Object?>[1];
        self.add(_random.nextBool() ? self : <String, Object?>{'x': self});
        return self;
    }
  }
}

void main() {
  group('JsonBytesEncoder |', () {
    test('same bytes and same kind of error as the SDK, random values', () {
      _Values values = _Values();
      int errors = 0;
      for (int i = 0; i < 30000; i++) {
        Object? value = values.value(0);
        String sdk = _result(() => _sdk.convert(value));
        String own = _result(() => _own.convert(value));
        if (sdk.startsWith('error')) errors++;
        expect(own, sdk, reason: 'value number $i');
      }
      // the test is of no use when the values never fail, or always fail
      expect(errors, inInclusiveRange(300, 10000));
    });

    test('simple values', () {
      expect(_text(null), 'null');
      expect(_text(true), 'true');
      expect(_text(false), 'false');
      expect(_text('dox'), '"dox"');
      expect(_text(<Object?>[]), '[]');
      expect(_text(<String, Object?>{}), '{}');
      expect(_text(<Object?>[1, 'a', null, true]), '[1,"a",null,true]');
      expect(
        _text(<String, Object?>{
          'a': 1,
          'b': <String, Object?>{
            'c': <int>[2, 3],
          },
        }),
        '{"a":1,"b":{"c":[2,3]}}',
      );
    });

    test('integers, also the lowest and the highest', () {
      expect(_text(0), '0');
      expect(_text(7), '7');
      expect(_text(10), '10');
      expect(_text(-1), '-1');
      expect(_text(1234567890), '1234567890');
      expect(_text(9223372036854775807), '9223372036854775807');
      expect(_text(-9223372036854775807), '-9223372036854775807');
      expect(_text(-9223372036854775808), '-9223372036854775808');
    });

    test('doubles are written like toString', () {
      expect(_text(1.5), '1.5');
      expect(_text(1.0), '1.0');
      expect(_text(-0.0), '-0.0');
      expect(_text(1e21), '1e+21');
    });

    test('a double that is not finite is an error', () {
      for (double value in <double>[double.nan, double.infinity]) {
        expect(
          () => _own.convert(value),
          throwsA(isA<JsonUnsupportedObjectError>()),
        );
      }
    });

    test('escapes quotes, backslashes and control characters', () {
      expect(_text('a"b\\c'), r'"a\"b\\c"');
      expect(_text('\b\t\n\f\r'), r'"\b\t\n\f\r"');
      expect(_text('\u0000\u001f'), r'"\u0000\u001f"');
      // DEL needs no escape
      expect(_own.convert('\u007f'), <int>[0x22, 0x7F, 0x22]);
    });

    test('text that is not ASCII becomes UTF-8', () {
      String text = 'é 日本 😀';
      expect(_own.convert(text), utf8.encode('"$text"'));
      expect(_own.convert('plain then é'), utf8.encode('"plain then é"'));
    });

    test('text in many languages, same bytes as the SDK and round trip', () {
      List<String> texts = <String>[
        'မြန်မာစာ ကို JSON အဖြစ် ပြောင်းသည်',
        '日本語のテキスト',
        '中文文本，带标点。',
        '한국어 텍스트',
        'ข้อความภาษาไทย',
        'हिन्दी पाठ',
        'نص عربي',
        'טקסט בעברית',
        'Русский текст',
        'Ελληνικό κείμενο',
        'Tiếng Việt có dấu',
        'café, naïve, Zürich, Ærø',
        // emoji: 4 bytes, a skin tone, a family joined with U+200D, a flag
        '😀 👍🏽 👨‍👩‍👧‍👦 🇲🇲',
        // a letter with a combining mark, and the same letter as one char
        'é é',
        // old scripts and symbols outside the first plane
        '𝒳 𐍈 𝄞',
        'mixed: abc မြန် 日本 😀 "quoted" \\ end\n',
      ];
      for (String text in texts) {
        Map<String, Object?> value = <String, Object?>{
          text: <Object?>[text, text],
        };
        List<int> bytes = _own.convert(value);
        expect(bytes, _sdk.convert(value), reason: text);
        expect(bytes, utf8.encode(jsonEncode(value)), reason: text);
        expect(JSON.parse(bytes), value, reason: text);
      }
    });

    test('each Unicode character, same bytes as the SDK and round trip', () {
      // all code points from U+0000 to U+10FFFF, without the surrogates,
      // in strings of 4096 characters
      StringBuffer part = StringBuffer();
      int count = 0;
      void check() {
        String text = part.toString();
        List<int> bytes = _own.convert(text);
        expect(bytes, _sdk.convert(text), reason: 'ends before $count');
        expect(JSON.parse(bytes), text, reason: 'ends before $count');
        part.clear();
      }

      for (int rune = 0; rune <= 0x10FFFF; rune++) {
        if (rune >= 0xD800 && rune <= 0xDFFF) continue;
        part.writeCharCode(rune);
        count++;
        if (count % 4096 == 0) check();
      }
      check();
      expect(count, 0x110000 - 0x800);
    });

    test('each UTF-16 unit alone, also the halves of a pair', () {
      for (int unit = 0; unit <= 0xFFFF; unit++) {
        String text = String.fromCharCode(unit);
        expect(_own.convert(text), _sdk.convert(text), reason: 'unit $unit');
      }
    });

    test('the edges of 1, 2, 3 and 4 byte UTF-8', () {
      Map<int, List<int>> edges = <int, List<int>>{
        0x7F: <int>[0x7F],
        0x80: <int>[0xC2, 0x80],
        0x7FF: <int>[0xDF, 0xBF],
        0x800: <int>[0xE0, 0xA0, 0x80],
        0xFFFF: <int>[0xEF, 0xBF, 0xBF],
        0x10000: <int>[0xF0, 0x90, 0x80, 0x80],
        0x10FFFF: <int>[0xF4, 0x8F, 0xBF, 0xBF],
      };
      edges.forEach((int rune, List<int> utf8Bytes) {
        expect(_own.convert(String.fromCharCode(rune)), <int>[
          0x22,
          ...utf8Bytes,
          0x22,
        ], reason: 'U+${rune.toRadixString(16)}');
      });
    });

    test('a character that is not ASCII at each place of a long text', () {
      // the fast path stops at the first such character
      for (int at = 0; at < 70; at++) {
        String text = '${'a' * at}မ${'b' * (69 - at)}';
        expect(_own.convert(text), utf8.encode('"$text"'), reason: 'at $at');
      }
    });

    test('random values come back equal after parse', () {
      _Values values = _Values();
      int checked = 0;
      for (int i = 0; i < 20000; i++) {
        Object? value = values.value(0);
        List<int> bytes;
        try {
          bytes = _sdk.convert(value);
        } catch (_) {
          continue;
        }
        // the text that the SDK decoder reads from the SDK bytes
        expect(
          JSON.parse(_own.convert(value)),
          JSON.parse(bytes),
          reason: 'value number $i',
        );
        checked++;
      }
      expect(checked, greaterThan(10000));
    });

    test('half of a surrogate pair is written as an escape', () {
      expect(_text(String.fromCharCode(0xD83D)), r'"\ud83d"');
      expect(_text(String.fromCharCode(0xDE00)), r'"\ude00"');
      expect(_text('a${String.fromCharCode(0xD83D)}b'), r'"a\ud83db"');
    });

    test('a key gets the same escapes as a value', () {
      expect(_text(<String, int>{'a"é': 1}), '{"a\\"é":1}');
    });

    test('DateTime and toJson go through toEncodable', () {
      expect(
        _text(<String, Object?>{
          'at': DateTime.utc(2023),
          'model': _Model(<int>[1]),
        }),
        '{"at":"2023-01-01T00:00:00.000Z","model":[1]}',
      );
    });

    test('an object with no toJson is an error', () {
      expect(
        () => _own.convert(<Object?>[_NoToJson()]),
        throwsA(
          isA<JsonUnsupportedObjectError>().having(
            (JsonUnsupportedObjectError e) => e.unsupportedObject,
            'unsupportedObject',
            isA<_NoToJson>(),
          ),
        ),
      );
    });

    test('a map with a key that is not a String is an error', () {
      expect(
        () => _own.convert(<Object, int>{'a': 1, 2: 2}),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
    });

    test('toEncodable can replace a map with a key that is not a String', () {
      dynamic stringKeys(dynamic object) {
        Map<Object?, Object?> map = object as Map<Object?, Object?>;
        return <String, Object?>{
          for (MapEntry<Object?, Object?> entry in map.entries)
            '${entry.key}': entry.value,
        };
      }

      JsonBytesEncoder own = JsonBytesEncoder(stringKeys);
      JsonUtf8Encoder sdk = JsonUtf8Encoder(null, stringKeys);
      List<Object?> values = <Object?>[
        <Object, int>{1: 2},
        // the bad key comes after a good one: nothing of the map may stay
        <Object, int>{'a': 1, 2: 3},
        <Object?>[
          <String, Object?>{
            'a': <Object, int>{'b': 1, 2: 3},
          },
          4,
        ],
      ];
      for (Object? value in values) {
        expect(
          utf8.decode(own.convert(value)),
          utf8.decode(sdk.convert(value)),
        );
      }
      expect(utf8.decode(own.convert(values[1])), '{"a":1,"2":3}');
    });

    test('a value that holds itself is an error', () {
      List<Object?> list = <Object?>[];
      list.add(list);
      expect(() => _own.convert(list), throwsA(isA<JsonCyclicError>()));

      Map<String, Object?> map = <String, Object?>{};
      map['self'] = <Object?>[map];
      expect(() => _own.convert(map), throwsA(isA<JsonCyclicError>()));
    });

    test('the same value two times is not a cycle', () {
      List<int> shared = <int>[1];
      expect(_text(<Object?>[shared, shared]), '[[1],[1]]');
    });

    test('works again after an error', () {
      expect(() => _own.convert(<Object?>[1, _NoToJson()]), throwsA(anything));
      expect(_text(<int>[1, 2]), '[1,2]');
    });

    test('a toJson that encodes JSON itself does not break the outer call', () {
      expect(utf8.decode(JSON.bytes(_Reenter())), r'{"in":"{\"k\":1}","z":2}');
      expect(
        utf8.decode(JSON.bytes(<String, Object?>{'a': _Reenter(), 'b': 'x'})),
        r'{"a":{"in":"{\"k\":1}","z":2},"b":"x"}',
      );
    });

    test('a body larger than the first buffer', () {
      String long = 'x' * 5000;
      expect(_own.convert(long), utf8.encode('"$long"'));

      List<int> numbers = List<int>.generate(3000, (int i) => i);
      expect(_own.convert(numbers), _sdk.convert(numbers));
    });

    test('a small body after a very large one', () {
      // more than the buffer the encoder keeps
      String huge = 'é' * (1 << 20);
      expect(_own.convert(huge).length, (1 << 21) + 2);
      expect(_text(<String, int>{'a': 1}), '{"a":1}');
    });

    test('each call gives its own bytes', () {
      List<int> first = _own.convert(<int>[1, 2, 3]);
      List<int> second = _own.convert(<String>['abcdefg']);
      expect(utf8.decode(first), '[1,2,3]');
      expect(utf8.decode(second), '["abcdefg"]');
    });
  });
}
