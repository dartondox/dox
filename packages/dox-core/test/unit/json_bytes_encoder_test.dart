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

/// writes its own JSON, and has a toJson() that must not be used
class _Point implements JsonWritable {
  _Point(this.x, this.name, [this.inner]);
  final int? x;
  final String? name;
  final Object? inner;

  @override
  void writeJson(JsonWriter writer) {
    writer.startObject();
    writer.key('x');
    writer.integer(x);
    writer.key('name');
    writer.string(name);
    writer.key('inner');
    writer.value(inner);
    writer.endObject();
  }

  Map<String, dynamic> toJson() => <String, dynamic>{'wrong': true};
}

/// writes one date
class _At implements JsonWritable {
  _At(this.at);
  final DateTime? at;

  @override
  void writeJson(JsonWriter writer) {
    writer.startObject();
    writer.key('at');
    writer.dateTime(at);
    writer.endObject();
  }
}

/// writes the keys it gets, each with the value 1
class _Keys implements JsonWritable {
  _Keys(this.keys);
  final List<String> keys;

  @override
  void writeJson(JsonWriter writer) {
    writer.startObject();
    for (String key in keys) {
      writer.key(key);
      writer.integer(1);
    }
    writer.endObject();
  }
}

/// throws after it wrote a part of its JSON
class _Broken implements JsonWritable {
  @override
  void writeJson(JsonWriter writer) {
    writer.startObject();
    writer.key('a');
    throw StateError('broken');
  }
}

/// has itself as a value
class _Loop implements JsonWritable {
  @override
  void writeJson(JsonWriter writer) {
    writer.startObject();
    writer.key('me');
    writer.value(this);
    writer.endObject();
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

    test('text of each length with a special character at each place', () {
      // the encoder writes 8 characters at a time and must stop at these
      List<String> specials = <String>[
        '"',
        '\\',
        '\n',
        '\u001f',
        '\u007f',
        '\u0080',
        'é',
        'မ',
        '😀',
        String.fromCharCode(0xD83D),
      ];
      for (int length = 0; length <= 40; length++) {
        String plain = String.fromCharCodes(<int>[
          for (int i = 0; i < length; i++) 0x61 + i % 26,
        ]);
        expect(_own.convert(plain), _sdk.convert(plain), reason: plain);
        for (int at = 0; at < length; at++) {
          for (String special in specials) {
            String text =
                plain.substring(0, at) + special + plain.substring(at + 1);
            expect(
              _own.convert(text),
              _sdk.convert(text),
              reason: 'length $length, ${special.codeUnits} at $at',
            );
          }
        }
      }
    });

    test('8 characters at a time: the edge values of a character', () {
      // 0x1f and 0x20, 0x21 to 0x23, 0x5b to 0x5d, 0x7f and 0x80
      for (int unit in <int>[
        0x1F,
        0x20,
        0x21,
        0x22,
        0x23,
        0x5B,
        0x5C,
        0x5D,
        0x7E,
        0x7F,
        0x80,
        0xFF,
        0x100,
        0x2022,
        0x5C5C,
      ]) {
        for (int at = 0; at < 8; at++) {
          List<int> units = List<int>.filled(16, 0x61)..[at] = unit;
          String text = String.fromCharCodes(units);
          expect(
            _own.convert(text),
            _sdk.convert(text),
            reason: '$unit at $at',
          );
        }
      }
    });

    group('key cache |', () {
      // keys made at run time: equal to each other, but not the same object
      String key(String text) => String.fromCharCodes(text.codeUnits);

      void same(Object? value) {
        expect(
          utf8.decode(_own.convert(value)),
          utf8.decode(_sdk.convert(value)),
        );
      }

      test('a list of maps with the same keys', () {
        same(<Object?>[
          for (int i = 0; i < 50; i++)
            <String, Object?>{
              key('id'): i,
              key('name'): 'row $i',
              key('rating'): <String, Object?>{
                key('score'): i,
                key('count'): 2,
              },
              key('tags'): <String>['a', 'b'],
            },
        ]);
      });

      test('maps with other keys at the same place', () {
        same(<Object?>[
          <String, int>{'a': 1, 'b': 2},
          <String, int>{'b': 1, 'a': 2},
          <String, int>{'a': 1},
          <String, int>{'ab': 1, 'b': 2},
          <String, int>{'a': 1, 'bc': 2, 'c': 3},
          <String, int>{},
          <String, int>{'a': 1, 'b': 2},
        ]);
      });

      test('a key that is the start of the key before it', () {
        same(<Object?>[
          <String, int>{'category_name': 1},
          <String, int>{'category': 1},
          <String, int>{'cat': 1},
          <String, int>{'category_name': 1},
          <String, int>{'': 1},
          <String, int>{'c': 1},
        ]);
      });

      test('keys of 28 to 34 characters, and an empty key', () {
        for (int length in <int>[
          0,
          1,
          5,
          6,
          7,
          13,
          14,
          21,
          22,
          28,
          29,
          30,
          31,
          32,
          33,
          34,
          100,
        ]) {
          String long = 'k' * length;
          same(<Object?>[
            for (int i = 0; i < 4; i++) <String, int>{long: i, 'z': i},
          ]);
        }
      });

      test('keys with an escape or with text that is not ASCII', () {
        for (String text in <String>[
          'a"b',
          'a\\b',
          'a\nb',
          'é',
          'မြန်မာ',
          '😀',
          'a\u007fb',
        ]) {
          same(<Object?>[
            for (int i = 0; i < 4; i++) <String, int>{key(text): i, 'z': i},
          ]);
        }
      });

      test('a map with many keys', () {
        same(<Object?>[
          for (int i = 0; i < 3; i++)
            <String, int>{for (int k = 0; k < 40; k++) 'key$k': k + i},
        ]);
      });

      test('two keys that use the same place of the cache', () {
        // the place of a key is the low 10 bits of its hash code
        Map<int, String> seen = <int, String>{};
        String? first;
        String? second;
        for (int i = 0; second == null; i++) {
          String name = 'key$i';
          String? other = seen[name.hashCode & 1023];
          if (other == null) {
            seen[name.hashCode & 1023] = name;
          } else {
            first = other;
            second = name;
          }
        }
        same(<Object?>[
          for (int i = 0; i < 6; i++)
            <String, int>{first!: i, second: i, first + second: i},
        ]);
        same(<String, int>{second: 1, first!: 2, second + first: 3});
      });

      test('maps in maps', () {
        Object? deep(int level) {
          if (level == 0) return <String, int>{'leaf': 1};
          return <String, Object?>{'level$level': deep(level - 1), 'n': level};
        }

        same(<Object?>[deep(12), deep(12), deep(3)]);
      });

      test('right after a map with a bad key, and after an error', () {
        Map<String, int> row = <String, int>{'id': 1, 'name': 2};
        same(<Object?>[row, row]);
        expect(
          () => _own.convert(<Object?>[
            row,
            <Object, int>{'id': 1, 2: 2},
          ]),
          throwsA(isA<JsonUnsupportedObjectError>()),
        );
        expect(
          () => _own.convert(<String, Object?>{
            'a': <String, Object?>{'id': 1, 'bad': _NoToJson()},
          }),
          throwsA(isA<JsonUnsupportedObjectError>()),
        );
        same(<Object?>[row, row]);
        same(<String, Object?>{'a': row, 'b': row});
      });

      test('random lists of maps from a few keys, same bytes as the SDK', () {
        Random random = Random(11);
        List<String> pool = <String>[
          'id',
          'name',
          'n',
          '',
          'category',
          'category_name',
          'created_at',
          'a_key_of_29_characters_xxxxxx',
          'a_key_of_30_characters_xxxxxxx',
          'a_longer_key_than_the_cache_keeps_in_its_words',
          'é',
          'a"b',
          'မြန်',
        ];
        Object? make(int depth) {
          int kind = random.nextInt(depth > 5 ? 3 : 8);
          if (kind == 0) return random.nextInt(1000);
          if (kind == 1) return 'text ${random.nextInt(99)}';
          if (kind == 2) return random.nextBool();
          if (kind < 5) {
            return <Object?>[
              for (int i = random.nextInt(5); i > 0; i--) make(depth + 1),
            ];
          }
          // most maps of a call have the same keys in the same order
          int first = random.nextInt(4) == 0 ? random.nextInt(pool.length) : 0;
          int count = random.nextInt(4) == 0 ? random.nextInt(6) : 4;
          return <String, Object?>{
            for (int i = 0; i < count; i++)
              key(pool[(first + i) % pool.length]): make(depth + 1),
          };
        }

        for (int i = 0; i < 5000; i++) {
          Object? value = make(0);
          expect(_own.convert(value), _sdk.convert(value), reason: 'value $i');
        }
      });
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

    group('JsonWritable |', () {
      test('an object writes its own JSON, toJson() is not called', () {
        expect(_text(_Point(1, 'a')), '{"x":1,"name":"a","inner":null}');
        expect(
          _text(_Point(null, null)),
          '{"x":null,"name":null,"inner":null}',
        );
        expect(
          _text(_Point(-42, 'é "q" \n 😀')),
          jsonEncode(<String, dynamic>{
            'x': -42,
            'name': 'é "q" \n 😀',
            'inner': null,
          }),
        );
        expect(utf8.decode(JSON.bytes(_Point(1, 'a'))), contains('"x":1'));
      });

      test('in a list, in a map and in another object', () {
        Object? value = <String, dynamic>{
          'list': <_Point>[_Point(1, 'a'), _Point(2, 'b')],
          'one': _Point(3, 'c', _Point(4, 'd', <int>[1, 2])),
        };
        expect(
          _text(value),
          '{"list":[{"x":1,"name":"a","inner":null},'
          '{"x":2,"name":"b","inner":null}],'
          '"one":{"x":3,"name":"c","inner":'
          '{"x":4,"name":"d","inner":[1,2]}}}',
        );
      });

      test('value() takes every kind of value', () {
        for (Object? inner in <Object?>[
          null,
          true,
          false,
          1.5,
          'text',
          <String, dynamic>{},
          <dynamic>[],
          <String, dynamic>{
            'a': <int>[1],
          },
          DateTime.utc(2024),
        ]) {
          expect(
            _text(_Point(1, 'a', inner)),
            jsonEncode(<String, dynamic>{
              'x': 1,
              'name': 'a',
              'inner': inner,
            }, toEncodable: advanceEncode),
          );
        }
      });

      test('dateTime() gives the text of toIso8601String()', () {
        String want(DateTime? at) =>
            '{"at":${at == null ? 'null' : '"${at.toIso8601String()}"'}}';
        List<DateTime?> dates = <DateTime?>[
          null,
          DateTime.utc(2024, 5, 17, 3, 4, 5, 6),
          DateTime.utc(2024, 5, 17, 3, 4, 5, 6, 7),
          DateTime.utc(2024, 12, 31, 23, 59, 59, 999, 999),
          DateTime(2024, 5, 17, 3, 4, 5, 6),
          DateTime(2024, 5, 17, 3, 4, 5, 6, 7),
          DateTime.utc(0),
          DateTime.utc(1),
          DateTime.utc(999, 9, 9),
          DateTime.utc(9999, 12, 31, 23, 59, 59, 999, 999),
          // a sign or 6 digits for the year
          DateTime.utc(10000),
          DateTime.utc(-1),
          DateTime.utc(-10000),
          DateTime.utc(275760, 9, 13),
          DateTime.fromMicrosecondsSinceEpoch(0, isUtc: true),
          DateTime.fromMicrosecondsSinceEpoch(-1, isUtc: true),
          DateTime.fromMicrosecondsSinceEpoch(-1),
        ];
        for (DateTime? at in dates) {
          expect(_text(_At(at)), want(at), reason: '$at');
        }
        Random random = Random(11);
        for (int i = 0; i < 20000; i++) {
          // years 0 to 9999 and some more on each side
          int micros =
              -65000000000000000 +
              (random.nextDouble() * 330000000000000000).floor();
          DateTime at = DateTime.fromMicrosecondsSinceEpoch(
            random.nextInt(3) == 0 ? micros ~/ 1000 * 1000 : micros,
            isUtc: random.nextBool(),
          );
          expect(_text(_At(at)), want(at), reason: '$at');
        }
        // many dates, larger than the first buffer
        List<_At> list = <_At>[
          for (int i = 0; i < 500; i++) _At(DateTime.utc(2024, 1, 1, 0, i)),
        ];
        expect(_text(list), '[${list.map((_At a) => want(a.at)).join(',')}]');
      });

      test('keys: none, long ones and ones with an escape', () {
        expect(_text(_Keys(<String>[])), '{}');
        expect(_text(<_Keys>[_Keys(<String>[]), _Keys(<String>[])]), '[{},{}]');
        for (int length = 1; length <= 70; length++) {
          List<String> keys = <String>['k' * length, 'é' * length, 'z'];
          String want = jsonEncode(<String, int>{for (String k in keys) k: 1});
          expect(_text(_Keys(keys)), want, reason: 'length $length');
          // again, now from the key cache
          expect(_text(_Keys(keys)), want, reason: 'length $length');
        }
        List<String> odd = <String>['a"b', 'a\\b', 'a\nb', '{', '}', ',', ''];
        expect(
          _text(_Keys(odd)),
          jsonEncode(<String, int>{for (String k in odd) k: 1}),
        );
      });

      test('the same keys as a map: one key cache for both', () {
        Map<String, dynamic> map = <String, dynamic>{
          'x': 1,
          'name': 'a',
          'inner': null,
        };
        for (int i = 0; i < 3; i++) {
          expect(_text(map), _text(_Point(1, 'a')));
        }
      });

      test('an error in writeJson()', () {
        expect(
          () => _own.convert(<Object>[1, _Broken()]),
          throwsA(isA<JsonUnsupportedObjectError>()),
        );
        // the encoder works again
        expect(_text(_Point(1, 'a')), '{"x":1,"name":"a","inner":null}');
        expect(
          () => _own.convert(_Point(1, 'a', double.nan)),
          throwsA(isA<JsonUnsupportedObjectError>()),
        );
        expect(_text(<int>[1]), '[1]');
      });

      test('an object that has itself as a value', () {
        expect(
          () => _own.convert(_Loop()),
          throwsA(isA<JsonUnsupportedObjectError>()),
        );
        // the same object two times, not in itself, is fine
        _Point point = _Point(1, 'a');
        expect(
          _text(<_Point>[point, point]),
          '[{"x":1,"name":"a","inner":null},{"x":1,"name":"a","inner":null}]',
        );
      });

      test('many objects, larger than the first buffer', () {
        List<_Point> points = <_Point>[
          for (int i = 0; i < 2000; i++) _Point(i, 'name $i'),
        ];
        expect(
          _text(points),
          jsonEncode(<Map<String, dynamic>>[
            for (int i = 0; i < 2000; i++)
              <String, dynamic>{'x': i, 'name': 'name $i', 'inner': null},
          ]),
        );
      });
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
